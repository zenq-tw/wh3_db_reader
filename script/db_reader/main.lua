local functools = assert(core:load_global_script('script.db_reader.functools'))  ---@module "script.db_reader.functools"
local collections = assert(core:load_global_script('script.db_reader.collections'))  ---@module "script.db_reader.collections"
local validators = assert(core:load_global_script('script.db_reader.validators'))  ---@module "script.db_reader.validators"
local utils = assert(core:load_global_script('script.db_reader.utils'))  ---@module "script.db_reader.utils"

assert(core:load_global_script('script.db_reader.extensions'))  ---@module "script.db_reader.extensions"


--[[
======================================================================================
                                      DBReader
======================================================================================
--]]


---@class DBReader
---@field version string
---@field protected _db_address pointer
---@field protected _registry DBRegistry count of table entries found
---@field protected _extractors ExtractorsRegistry
---@field protected _requested_tables string[]
---@field protected _loaded_tables DBData
---@field protected _log LoggerCls
---@field protected _initialized boolean
---@field protected __index DBReader
local DBReader = {
    version='0.0.1',
}
DBReader.__index = DBReader


---@protected
---@nodiscard
---@param db_address pointer
---@param registry DBRegistry
---@param extractors ExtractorsRegistry
---@param logger LoggerCls
---@return DBReader
---ONLY FOR INTERNAL USAGE
function DBReader.new(db_address, registry, extractors, logger)
    local self = setmetatable({}, DBReader)
    self._log = logger

    self._log:enter_context('db: new')

    self._db_address = db_address
    self._registry = registry
    self._extractors = extractors

    self._loaded_tables = {}
    self._requested_tables = {}
    self._initialized = false

    self._log:debug('created'):leave_context()
    return self
end


---@protected
---@param data? DBReaderData
---ONLY FOR INTERNAL USAGE
function DBReader:init(data)
    self._log:enter_context('db: init')

    if data ~= nil then
        self._loaded_tables = data.loaded_tables

        local merged_table = utils.merge_indexed_tables(self._requested_tables, data.requested_tables)
        if merged_table then
            self._requested_tables = merged_table    
        end
    end

    self:_load_requested_tables()

    self._initialized = true
    self._log:debug('initialized'):leave_context()
end


---return data to be cached in a game save so we can recreate DBReader in future
---@protected
---@return DBReaderData
---ONLY FOR INTERNAL USAGE
function DBReader:get_data_for_cache()
    self._log:enter_context('db: get cache data'):debug('collecting...')
    
    local data = {
        requested_tables=self._requested_tables,
        loaded_tables=self._loaded_tables,
    }

    self._log:info('done'):leave_context()

    return data
end


---@protected
---ONLY FOR INTERNAL USAGE
function DBReader:reload()
    self._log:enter_context('db: reload'):debug('reloading...')

    self._loaded_tables = {}
    self:_load_requested_tables()

    self._log:info('reloaded'):leave_context()
end


--[[
======================================================================================
                            DBReader: public methods
======================================================================================
--]]



---request table hook - use it in client code at start of stript
---@param table_name string
---@return boolean is_available is required table exist and table data builder registered
function DBReader:request_table(table_name)
    self._log:enter_context('db: table request', table_name)

    if self._requested_tables[table_name] ~= nil and self._loaded_tables[table_name] ~= nil then
        self._log:debug('already loaded'):leave_context()
        return true
    end

    if self._registry.tables[table_name] == nil then
        self._log:error('requested table doesnt exist'):leave_context()
        return false
    end

    if not self._extractors:is_registered(table_name) then
        self._log:error('requested table doesnt have a registered data extractor'):leave_context()
        return false
    end

    table.insert(self._requested_tables, table_name)
    self._log:info('request successfully registered')

    if self._initialized then
        self._log:debug('already initialized, so try to load table right now')
        self:_load_table_mid_game(table_name)
    end

    self._log:leave_context()
    return true
end

---check if table data loaded from memory
---@param table_name string
---@return boolean
function DBReader:is_table_loaded(table_name)
    self._log:enter_context('db: check table', table_name)

    local res = (self._loaded_tables[table_name] ~= nil)
    
    self._log:debug('exist? =', res):leave_context()
    return res
end


---get extracted db table 
---@param table_name string
---@return DBTable?
function DBReader:get_table(table_name)
    self._log:enter_context('db: get table', table_name)

    local db_table = self._loaded_tables[table_name]
    if db_table == nil then
        self._log:error('requested table is not available'):leave_context()
        return
    end
    
    db_table = table.deepcopy(db_table)

    self._log:debug('table copy returned'):leave_context()
    return db_table
end


---specific table data extractor registration method
---@param table_name string name of table for which extractor is registered
---@param columns string[] array of table columns
---@param key_column_id number table key column (position in `columns` array)
---@param extractor TableDataExtractor function that will extract table data
---@return boolean is_registered  
function DBReader:register_table_extractor(table_name, columns, key_column_id, extractor)
    self._log:enter_context('db: register extractor', table_name)

    local is_registered = self._extractors:register_table_extractor(table_name, columns, key_column_id, extractor)

    self._log:leave_context()
    return is_registered
end


--[[
======================================================================================
                      DBReader: Internal functions and methods
======================================================================================
--]]


---@protected
function DBReader:_load_requested_tables()
    self._log:enter_context('load tables'):debug('start loading requested tables:'):info('requested tables count:', #self._requested_tables)

    local meta
    for i, table_name in ipairs(self._requested_tables) do
        self._log:enter_context(table_name):debug(i, '- processing requested db table:', table_name)

        if self._loaded_tables[table_name] ~= nil then
            self._log:debug('table already loaded -> skip')
        else
            meta = self._registry.tables[table_name]
            self:_load_table_safe(meta)
        end

        self._log:leave_context()
    end

    self._log:debug('done'):leave_context()
end


---@protected
---@param meta DBTableMeta
function DBReader:_load_table_safe(meta)
    local is_success, error_msg = functools.safe(self._process_table, self, meta)
    if not is_success then
        self._log:error('failed to load table data:', error_msg)
    end
end


---@protected
---@param meta DBTableMeta
function DBReader:_load_table(meta)
    local data = self:_process_table(meta)

    if data == nil then
        self._log:error('failed to extract table data')
        return
    end

    self._loaded_tables[meta.name] = data
    self._log:debug('table data extracted and stored')
end



---@protected
---@param table_meta? DBTableMeta
---@return DBTable? db_table
function DBReader:_process_table(table_meta)
    if not validators.is_valid_table_meta(table_meta, self._log) then
        return
    end

    ---@cast table_meta DBTableMeta
    if not self._extractors:is_registered(table_meta.name) then
        self._log:error('ERROR: table extractor not found -> skip')
        return
    end
    

    local table_data, rows_count = self:_extract_table_data(table_meta)
    if table_data == nil then
        self._log:error('failed to extract table data -> skip')
        return
    end

    ---@cast rows_count integer
    return self:_build_table(table_meta, table_data, rows_count)
end


---@protected
---@param table_meta DBTableMeta
---@param table_data RawTableData
---@param rows_count integer
---@return DBTable? db_table
function DBReader:_build_table(table_meta, table_data, rows_count)
    self._log:enter_context('build'):debug('building table data, count of records:', rows_count)

    local records = utils.make_table_data(table_data.rows, table_meta.columns, table_meta.key_column, rows_count)

    local prepared_indexes = nil
    if table_data.indexes ~= nil then
        is_valid, prepared_indexes = self:_check_indexes_integrity(records, table_data.indexes)
        if not is_valid then
            self._log:error('index integrity violation')
            return
        end
    end

    local db_table = {  ---@type DBTable
        count=rows_count,
        records=records,
        indexes=prepared_indexes,
    }

    self._log:debug('table data was built'):leave_context()
    return db_table
end

---@param records table <Key, Record>
---@param indexes RawTableIndexes
---@return boolean is_valid, TableIndexes? prepared_indexes
function DBReader:_check_indexes_integrity(records, indexes)
    local prepared_indexes = collections.defaultdict(collections.factories.table)  ---@type defaultdict<Column, {[Field]: TableKeys}>
    local keys
    local counter

    for column, index in pairs(indexes) do
        for value, table_keys in pairs(index) do
            keys, counter = {}, 0

            for i, key in pairs(table_keys) do
                if not is_number(i) then
                    self._log:error('invalid index for column', column, 'with value', value, '- table keys must be an array')    
                end

                if records[key] == nil then
                    self._log:error('invalid index for column', column, 'with value', value, '- record with such key not found:', key)
                    return false 
                end

                counter = i
                keys[i] = key
            end
            
            prepared_indexes[column][value] = {
                count=counter,
                array=keys,
            }
        end
    end

    return true, prepared_indexes
end


---@protected
---@param table_name string
function DBReader:_load_table_mid_game(table_name)
    self._log:enter_context('load table mid-game', table_name)

    self:_load_table_safe(self._registry.tables[table_name])

    self._log:info('done'):leave_context()
end


---@protected
---@param table_meta DBTableMeta
---@return RawTableData? table_data, integer? rows_count 
function DBReader:_extract_table_data(table_meta)
    self._log:enter_context('extract')

    local extractor = assert(self._extractors:get_for_table(table_meta.name))
    local results = extractor(table_meta.ptr, self._log)
    
    local is_valid_results, rows_count = validators.check_builder_results(table_meta, results, self._log)
    if not is_valid_results then
        self._log:error('invalid extracter results'):leave_context()  
        return
    end

    self._log:leave_context()
    return results, rows_count
end







--[[
======================================================================================
                                Public initialization
======================================================================================
--]]


return DBReader
