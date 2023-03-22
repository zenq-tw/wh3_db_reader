local mr = assert(_G.memreader)
local T = assert(core:load_global_script('script.db_reader.types'))  ---@module "script.db_reader.types"


--==================================================================================================================================--
--                                                          table extensions
--==================================================================================================================================--



function table.lookup_to_indexed(lookup_table)
    local indexed = {}

    local i = 1
    for key, _ in pairs(lookup_table) do
        indexed[i] = key
        i = i + 1
    end

    return indexed
end


--TODO: rewrite with memreader!
--Author: Vandy (Groove Wizard)
function table.deepcopy(tbl)
	local ret = {}
	for k, v in pairs(tbl) do
		ret[k] = type(v) == 'table' and table.deepcopy(v) or v
	end
	return ret
end



--==================================================================================================================================--
--                                                          other stuff
--==================================================================================================================================--



local base_shift = "044DF700"  -- 0x044DF700


---@param logger LoggerCls
---@return pointer
local function get_db_address(logger)
    local ptr = mr.base
    logger:debug('base game space address is', mr.tostring(ptr))

    ptr = mr.read_pointer(ptr, T.uint32(tonumber(base_shift, 16)))  -- now pointer reffer to some special structure that has pointer to fst db meta table record
    logger:debug('address of unkown service-structure (that helds pointer to DB): ' .. mr.tostring(ptr))
    
    ptr = mr.read_pointer(ptr, T.uint32(0x10))
    
    return ptr 
end


---@return boolean is_constructed
local function check_is_db_constructed()
    return pcall(
        function ()
            ptr = mr.read_pointer(mr.base, T.uint32(tonumber(base_shift, 16)))
            ptr = mr.read_pointer(ptr, T.uint32(0x10))
            mr.read_pointer(ptr)
        end
    )
end


---deal with case when string length is smaller than 16 -> there is no STR structure (as in other cases)
---@param ptr pointer
---@param offset? integer [default "0"] address offset that will be applied before reading
---@param isPtr? boolean [default "false"] should we make dereference before string reading? (anyway offset will be applied fst)
---@param isWide? boolean [default "false"] should we trait string as wchar_t (idk, at least in most cases it should be "false")
---@param safeCapValue? integer [default "2048"] if string cap bigger then this value it will treated like special "small" string
---@return string #null ended string
local function read_string_CA(ptr, offset, isPtr, isWide, safeCapValue)
    offset = offset or 0
    isPtr = isPtr or false
    isWide = isWide or false
    safeCapValue = safeCapValue or 2048

    if isPtr then
        ptr = mr.read_pointer(ptr, T.uint32(offset))
        offset = 0
    end

    local size = mr.read_int32(ptr, T.uint32(offset))
    local cap = mr.read_int32(ptr, T.uint32(offset))
    
    if (
        size >= 0 and
        size <= cap and
        cap <= safeCapValue
    ) then
        return mr.read_string(ptr, T.uint32(offset), false, isWide)
    end

    -- logger:debug('-- small string detected! (' .. mr.tostring(ptr) .. '): --', false, true)

    -- we should have null-terminated string here, so:
    --  iterate over bytes and find fst 0x00 byte -> it is a null-terminator
    --  if it happens at first iteration -> string is empty
    --  if it doesnt happen at all -> string filled with trash or not set at all (OR maybe some of our assumptions was wrong) 
    local byte
	for num_of_bytes_to_read = 0, 15 do
		byte = mr.read_uint8(ptr, T.uint32(offset + num_of_bytes_to_read))
		if byte == 0x00 then
			if num_of_bytes_to_read == 0 then
                return ''  -- empty
            end
			return mr.read(ptr, T.uint32(offset), T.uint32(num_of_bytes_to_read))  -- mr.read() return raw data, so having a null-terminator in string is our responsibility
		end
	end

	return ''  -- trash
end


local function merge_indexed_tables(indexed1, indexed2)
    local lkp1 = table.indexed_to_lookup(indexed1)

    if not lkp1 then
        return
    end

    local merged = {}
    local indexed1_size = #indexed1

    for i=1, indexed1_size do
        merged[i] = indexed1[i]
    end

    local i = indexed1_size + 1
    for j=1, #indexed2 do
        if lkp1[indexed2[j]] == nil then
            merged[i] = indexed2[j]
            i = i + 1 
        end
        
    end

    return merged
end


--- Author: Vandy (Groove Wizard)
--- @param t table
--- @param loop_value number
--- @return table<string>
local function _inner_dump_table(t, loop_value)
    --- @type table<any>
	local table_string = {'{\n'}
	--- @type table<any>
	local temp_table = {}
    for key, value in pairs(t) do
        table_string[#table_string + 1] = string.rep('\t', loop_value + 1)

        if type(key) == "string" then
            table_string[#table_string + 1] = '["'
            table_string[#table_string + 1] = key
            table_string[#table_string + 1] = '"] = '
        elseif type(key) == "number" then
            table_string[#table_string + 1] = '['
            table_string[#table_string + 1] = key
            table_string[#table_string + 1] = '] = '
        else
            table_string[#table_string + 1] = '['
            table_string[#table_string + 1] = tostring(key)
            table_string[#table_string + 1] = '] = '
        end

		if type(value) == "table" then
			temp_table = _inner_dump_table(value, loop_value + 1)
			for i = 1, #temp_table do
				table_string[#table_string + 1] = temp_table[i]
			end
		elseif type(value) == "string" then
			table_string[#table_string + 1] = '[=['
			table_string[#table_string + 1] = value
			table_string[#table_string + 1] = ']=],\n'
		else
			table_string[#table_string + 1] = tostring(value)
			table_string[#table_string + 1] = ',\n'
		end
    end

	table_string[#table_string + 1] = string.rep('\t', loop_value)
    table_string[#table_string + 1] = "},\n"

    return table_string
end




--- Author: Vandy (Groove Wizard)
--- @param t table
--- @return string|boolean
local function dump_table(t)
    if not (type(t) == "table") then
        return false
    end

    --- @type table<any>
    local table_string = {'{\n'}
	--- @type table<any>
	local temp_table = {}

    for key, value in pairs(t) do

        table_string[#table_string + 1] = string.rep('\t', 1)
        if type(key) == "string" then
            table_string[#table_string + 1] = '["'
            table_string[#table_string + 1] = key
            table_string[#table_string + 1] = '"] = '
        elseif type(key) == "number" then
            table_string[#table_string + 1] = '['
            table_string[#table_string + 1] = key
            table_string[#table_string + 1] = '] = '
        else
            --- TODO skip it somehow?
            table_string[#table_string + 1] = '['
            table_string[#table_string + 1] = tostring(key)
            table_string[#table_string + 1] = '] = '
        end

        if type(value) == "table" then
            temp_table = _inner_dump_table(value, 1)
            for i = 1, #temp_table do
                table_string[#table_string + 1] = temp_table[i]
            end
        elseif type(value) == "string" then
            table_string[#table_string + 1] = '[=['
            table_string[#table_string + 1] = value
            table_string[#table_string + 1] = ']=],\n'
        elseif type(value) == "boolean" or type(value) == "number" then
            table_string[#table_string + 1] = tostring(value)
            table_string[#table_string + 1] = ',\n'
        else
            -- unsupported type, technically.
            table_string[#table_string+1] = "nil,\n"
        end
    end

    table_string[#table_string + 1] = "}\n"

    return table.concat(table_string)
end


---@param index {[string]: Key[]}
---@param value string
---@param table_key Key
---@return nil
local function include_key_in_index(index, value, table_key)
    if index[value] == nil then
        index[value] = {}
    end
    table.insert(index[value], table_key)
end


---convert hex string address to correct string that can be used in memreader as address
---@param hex_repr string
---@return pointer
---```
---hex_address = '461F7D30'  -- or ('0x461F7D30')
---ptr = mr.pointer(convert_hex_to_pointer(hex_address))
---address = mr.tostring(ptr)  -- get address where pointer reference to
---out(address)  -- 00000000461F7D30
---```
local function convert_hex_to_pointer(hex_repr)
    -- "0x461F7D30"  ->  "461F7D30"
    if hex_repr:starts_with('0x') then
        hex_repr = hex_repr:sub(3, -1)
    end

    -- "461F7D30"  ->  { "30", "7D", "1F", "46" }
    local chunks = {}
    local chunks_count = 0
    for i = #hex_repr - 1 , 0, -2 do
        chunks_count = chunks_count + 1
        chunks[chunks_count] = hex_repr:sub(i, i+1)
    end

    -- { "30", "7D", "1F", "46" }  ->  { 48, 125, 31, 70 }
    local hex_chunks = {}
    for i=1, chunks_count do
        hex_chunks[i] = tonumber(chunks[i], 16)
    end

    -- { 48, 125, 31, 70 }  ->  { 48, 125, 31, 70, 0, 0, 0, 0 }
    for i = chunks_count + 1, 8 do
        hex_chunks[i] = 0
    end

    -- { 48, 125, 31, 70, 0, 0, 0, 0 }  ->  "\48\125\31\70\0\0\0\0"  ==  address 0x00000000461F7D30
    local res = ''
    for i=1, 8 do
        res = res .. string.char(hex_chunks[i])
    end

    return res
end


---map columns to rows from raw sources
---@param rows any
---@param columns any
---@param key_column string
---@param rows_count? integer
---@param columns_count? integer
---@return table<Key, Record>
local function make_table_data(rows, columns, key_column, rows_count, columns_count)
    rows_count = rows_count or #rows_count
    columns_count = columns_count or #columns_count

    ---@type table<string, Record>
    local records = {}

    local row, record
    for i=1, rows_count do
        row = rows[i]
        record = {}

        for j=1, columns_count do
            record[columns[j]] = row[j]
        end

        records[record[key_column]] = record
    end

    return records
end



--==================================================================================================================================--
--                                                   Public namespace initialization
--==================================================================================================================================--



return {
    read_string_CA=read_string_CA,
    get_db_address=get_db_address,
    check_is_db_constructed=check_is_db_constructed,
    merge_indexed_tables=merge_indexed_tables,
    dump_table=dump_table,
    null_ptr=convert_hex_to_pointer('0x00'),
    include_key_in_index=include_key_in_index,
    convert_hex_to_pointer=convert_hex_to_pointer,
    make_table_data=make_table_data,
}