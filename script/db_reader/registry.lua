local mr = assert(_G.memreader)

local T = assert(core:load_global_script('script.db_reader.types'))  ---@module "script.db_reader.types"
local functools = assert(core:load_global_script('script.db_reader.functools'))  ---@module "script.db_reader.functools"
local utils = assert(core:load_global_script('script.db_reader.utils'))  ---@module "script.db_reader.utils"


--[[
======================================================================================
                                      DBRegistry
======================================================================================
--]]


---@class DBRegistry
---@field count integer count of table entries found
---@field tables {[string]: DBTableMeta} table info entity
---@field protected _log LoggerCls
---@field protected _db_address pointer
---@field protected _initialized boolean
---@field protected __index DBRegistry
local DBRegistry = {}
DBRegistry.__index = DBRegistry


---@protected
---@nodiscard
---@param db_address pointer
---@param logger LoggerCls
---@return DBRegistry
---ONLY FOR INTERNAL USAGE
function DBRegistry.new(db_address, logger)
    local self = setmetatable({}, DBRegistry)

    self.count = 0
    self.tables = {}

    self._db_address = db_address
    self._log = logger

    return self
end


---@param old_table DBTableMeta
---@return DBTableDumpedMeta
local function _prepare_table_for_dump(old_table)
    local new_table = table.deepcopy(old_table)
    new_table.ptr_hex = mr.tostring(new_table.ptr)
    new_table.ptr = nil

    return new_table
end


---@param restored_table DBTableDumpedMeta
---@return DBTableMeta
local function _prepare_table_restored_from_dump(restored_table)
    local new_table = table.deepcopy(restored_table)
    new_table.ptr = tonumber(new_table.ptr_hex, 16)
    new_table.ptr_hex = nil

    return new_table
end


---@protected
---@param data? DBRegistryDumpedData
---ONLY FOR INTERNAL USAGE
function DBRegistry:init(data)
    self._log:enter_context('registry: init')

    if data then
        self.count = data.count
        for name, restored_table in pairs(data.tables) do
            self.tables[name] = _prepare_table_restored_from_dump(restored_table)
        end
    else
        self._log:debug('------------------------------------------------------------------------------------'):info('reading db tables names')
    
        local is_success, err_msg, results = functools.safe(self._get_db_tables, self, self._db_address)
        if not is_success then
            self._log:error('failed:', err_msg)
            return
        end

        ---@cast results {[1]: integer, [2]: {[string]: DBTableMeta}}

        self.count = results[1]
        self.tables = results[2]
    end

    self._log:info('done'):leave_context()
end


---return data to be cached in a game save so we can recreate DBRegistry in future
---@protected
---@return DBRegistryDumpedData
---ONLY FOR INTERNAL USAGE
function DBRegistry:get_data_for_cache()
    self._log:enter_context('registry'):debug('collecting cache data')

    local prepared_tables = {}
    for name, old_table in pairs(self.tables) do
        prepared_tables[name] = _prepare_table_for_dump(old_table)
    end

    local data = {
        count=self.count,
        tables=prepared_tables,
    }

    self._log:debug('done'):leave_context()
    return data
end


--[[
======================================================================================
                      DBRegistry: Internal functions and methods
======================================================================================
--]]


---@protected
---@param cur_ptr pointer
---@return number count, {[string]: DBTableMeta} meta
function DBRegistry:_get_db_tables(cur_ptr)
    local table, table_name, table_ptr
    local entities_count, tables_count = 0, 0
    local guard_value = 2000  -- force stop after reading of 2_000 entries - just to be safe if at some point of time we didnt went abroad DB space

    ---@type {[string]: DBTableMeta}
    local tables = {}
    
    self._log:add_indent()

    local skip_after_object = T.uint32(0x10)  -- 8 from pointer to prev elem  +  8 (skip padding) = 16 [10] = 10 [16]
    local skip_after_delimiter = T.uint32(0x28)  -- border string (16=0x10) + padding x2 (16=0x10) + some pointer to unicode dll (8) = 0x28 [16]


    for i=1, guard_value do
        self._log:enter_context(i .. ' entity (' .. mr.tostring(cur_ptr) .. ')')

        table_name, table_ptr = self:_get_db_table_name(cur_ptr)
        if table_name == nil then
            self._log:debug('skipped')
        else
            ---@cast table_ptr pointer
            ---@type DBTableMeta
            table = {
                name=table_name,
                ptr=table_ptr,
                idx=tables_count,
            }
            tables[table_name] = table
            tables_count = tables_count + 1
        end
        entities_count = entities_count + 1

        cur_ptr = T.ptr(mr.add(cur_ptr, skip_after_object))

        if not self:_is_delimiter_exist(cur_ptr) then
            self._log:debug('no delimiter found -> we done OR smth weird happened (we went aboard db table entities space?) -> done'):leave_context()
            break
        end

        cur_ptr = T.ptr(mr.add(cur_ptr, skip_after_delimiter))
        self._log:leave_context()
    end
    self._log:remove_indent():debug('N of entities found ( tables, skipped ):', entities_count, '(', tables_count, entities_count - tables_count, ')')

    if entities_count == guard_value then
        self._log:debug('there could be more tables - looks like we stopped by the matching boundary guard value', guard_value)
    end

    return tables_count, tables
end


---@protected
---@param cur_ptr pointer
---@return boolean
function DBRegistry:_is_valid_db_table_structure(cur_ptr)
    -- 0x58 should be the last pointer in structure, so padding should be right after that field:
    -- 00 00 00 00 00 00 00 00
    -- 00 00 00 00 00 00 00 00
    self._log:enter_context('check table structure'):debug('cur_ptr is',  mr.tostring(cur_ptr))

    if cur_ptr == 0x0 then
        self._log:debug('invalid ptr == 0x0 -> exit'):leave_context()
        return false
    end

    local offset = T.uint32(0x60)  -- end of a table structure
    local size_uint32 = 0x4
    local luaNumber

    for _=1, 4 do
        luaNumber = mr.read_uint32(cur_ptr, offset)
        self._log:debug('border_value (' .. _ .. ') =', luaNumber, '[should be equal to', 0x00000000, '= 0x00000000]')
        
        if luaNumber ~= 0x00000000 then
            self._log:debug('value ~= 0x00000000 -> exit'):leave_context()
            return false
        end

        offset = T.uint32(offset + size_uint32)
    end

    self._log:leave_context()
    return true
end


---@protected
---@param cur_ptr pointer
---@return string? DBTableName, pointer? DBTablePointer 
function DBRegistry:_get_db_table_name(cur_ptr)
    self._log:enter_context('get table name'):debug('ptr of table entry in db is:', mr.tostring(cur_ptr))

    local ptr = mr.read_pointer(cur_ptr)  -- get node with table name 
    self._log:debug('ptr of table itself is:', mr.tostring(ptr))

    if not self:_is_valid_db_table_structure(ptr) then    
        self._log:debug('table structure is not valid'):leave_context()
        return
    end
    
    local name = utils.read_string_CA(ptr, 0x58, true)
    
    self._log:debug(name, '->', mr.tostring(ptr)):leave_context()
    return name, ptr
end


---@protected
---@param cur_ptr pointer
---@return boolean
function DBRegistry:_is_delimiter_exist(cur_ptr)
    -- border should look like that:
    -- FF FF FF FF FF FF FF FF
    -- FF FF FF FF 00 00 00 00
    self._log:enter_context('check delimeter'):debug('cur_ptr is ',  mr.tostring(cur_ptr))

    if cur_ptr == 0x0 then
        self._log:debug('invalid ptr == 0x0 -> exit'):leave_context()
        return false
    end

    local offset = T.uint32(0)
    local size_uint32 = 0x4
    local luaNumber

    for _=1, 3 do
        luaNumber = mr.read_uint32(cur_ptr, offset)
        self._log:debug('border_value (' .. _ .. ') =', luaNumber, '[should be equal to', 0xFFFFFFFF, '= 0xFFFFFFFF]')
        
        if luaNumber ~= 0xFFFFFFFF then
            self._log:debug('value ~= 0xFFFFFFFF -> exit'):leave_context()
            return false
        end

        offset = T.uint32(offset + size_uint32)
    end


    luaNumber = mr.read_uint32(cur_ptr, offset)  -- offset == 0x12
    self._log:debug('border_value (4) =', luaNumber, '[should be equal to', 0x00000000, '= 0x00000000]')

    if luaNumber ~= 0x00000000 then
        self._log:debug('value ~= 0x00000000 -> exit'):leave_context()
        return false
    end

    self._log:leave_context()
    return true
end


return DBRegistry
