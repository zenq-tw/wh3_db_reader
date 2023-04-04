local mr = assert(_G.memreader)
local zlib = assert(core:load_global_script('script.db_reader.zlib.header'))  ---@module "script.db_reader.zlib.header"

local T = assert(core:load_global_script('script.db_reader.types'))  ---@module "script.db_reader.types"


local utils = {}


--==================================================================================================================================--
--                                                          db related stuff
--==================================================================================================================================--


local base_shift = "044DF700"  -- 0x044DF700


---@param logger LoggerCls
---@return pointer
function utils.get_db_address(logger)
    local ptr = mr.base
    logger:debug('base game space address is:', zlib.functools.lazy(mr.tostring, ptr))

    ptr = mr.read_pointer(ptr, T.uint32(tonumber(base_shift, 16)))  -- now pointer reffer to some special structure that has pointer to fst db meta table record
    logger:debug('address of unkown service-structure (that helds pointer to DB):', zlib.functools.lazy(mr.tostring, ptr))
    
    ptr = mr.read_pointer(ptr, T.uint32(0x10))
    
    return ptr 
end


---deal with case when string length is smaller than 16 -> there is no STR structure (as in other cases)
---@param ptr pointer
---@param offset? integer [default "0"] address offset that will be applied before reading
---@param isPtr? boolean [default "false"] should we make dereference before string reading? (anyway offset will be applied fst)
---@param isWide? boolean [default "false"] should we trait string as wchar_t (idk, at least in most cases it should be "false")
---@param safeCapValue? integer [default "2048"] if string cap bigger then this value it will treated like special "small" string
---@return string #null ended string
function utils.read_string_CA(ptr, offset, isPtr, isWide, safeCapValue)
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


---convert hex string address to correct string that can be used in memreader as address
---@param hex_repr string
---@return string
---```
---hex_address = '461F7D30'  -- or ('0x461F7D30')
---ptr = mr.pointer(convert_hex_to_address(hex_address))
---address = mr.tostring(ptr)  -- get address where pointer reference to
---out(address)  -- 00000000461F7D30
---```
function utils.convert_hex_to_address(hex_repr)
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


utils.null_address = utils.convert_hex_to_address('0x00')


---@param db_address pointer
---@return boolean is_constructed
function utils.check_is_db_constructed(db_address)
    return pcall(
        function ()
            assert(not mr.eq(mr.read_pointer(db_address), utils.null_address))
        end
    )
end


---@param index {[string]: Id[]}
---@param value string
---@param table_key Id
---@return nil
function utils.include_key_in_index(index, value, table_key)
    if index[value] == nil then
        index[value] = {}
    end
    table.insert(index[value], table_key)
end


---map columns to rows from raw sources
---@param rows any
---@param columns any
---@param key_column string
---@param rows_count? integer
---@param columns_count? integer
---@return {[Id]: Record} records, {[PrimaryKey]: Id} pk
function utils.make_table_data(rows, columns, key_column, rows_count, columns_count)
    rows_count = rows_count or #rows
    columns_count = columns_count or #columns

    local records = {}  ---@type table<Id, Record>
    local pk = zlib.collections.NonRewritableDict('PrimaryKeyToId', true, false)  ---@type TNonRewritableDict<PrimaryKey, Id>

    local row, record
    for id=1, rows_count do
        row = rows[id]
        record = {}

        for j=1, columns_count do
            record[columns[j]] = row[j]
        end

        records[id] = record
        pk[record[key_column]] = id
    end

    return records, pk
end


--==================================================================================================================================--
--                                                   Public namespace initialization
--==================================================================================================================================--



return utils
