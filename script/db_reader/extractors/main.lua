local validators = assert(core:load_global_script('script.db_reader.validators'))  ---@module "script.db_reader.validators"

--[[
======================================================================================
                                ExtractorsRegistry
======================================================================================
--]]

---@class ExtractorsRegistry
---@field protected _extractors {[string]: TableDataExtractor}
---@field protected _extractors_dir string
---@field protected _db_registry DBRegistry
---@field protected _log LoggerCls
---@field protected __index ExtractorsRegistry
ExtractorsRegistry = {
    _extractors_dir='/script/db_reader/extractors/tables/'
}


---@protected
---@nodiscard
---@generic Cls
---@param cls Cls
---@param db_registry DBRegistry 
---@param logger LoggerCls
---@return Cls
---ONLY FOR INTERNAL USAGE
function ExtractorsRegistry.new(cls, db_registry, logger)
    logger:enter_context('extractors: new')

    cls.__index = cls
    local instance = setmetatable({}, cls)

    instance._log = logger
    instance._db_registry = db_registry
    instance._extractors = {}

    logger:debug('created'):leave_context()
    return instance
end


---@protected
---@return nil
---ONLY FOR INTERNAL USAGE
function ExtractorsRegistry:init()
    self._log:enter_context('extractors: init')

    self:_load_table_extractors()

    self._log:debug('done'):leave_context()
end


--[[
======================================================================================
                            ExtractorsRegistry: public methods
======================================================================================
--]]


---@param table_name string
---@return boolean
function ExtractorsRegistry:is_registered(table_name)
    return self:get_for_table(table_name) ~= nil
end


---@param table_name string
---@return TableDataExtractor?
function ExtractorsRegistry:get_for_table(table_name)
    return self._extractors[table_name]
end



---specific table data extractor registration method
---@param table_name string name of table for which extractor is registered
---@param columns string[] array of table columns
---@param key_column_id number table key column (position in `columns` array)
---@param extractor TableDataExtractor function that will extract table data
---@param nullable_column_ids integer[] | nil table columns whose values can be <nil> (positions in `columns` array)
---@return boolean is_registered  
function ExtractorsRegistry:register_table_extractor(table_name, columns, key_column_id, extractor, nullable_column_ids)
    self._log:enter_context('extractors: register extractor', table_name)

    if not is_string(table_name) then
        self._log:error('invalid argument - table_name: must be a string, not', type(table_name)):leave_context()
        return false
    end


    is_valid = validators.validate_table_columns(columns, key_column_id, nullable_column_ids, self._log)
    if not is_valid then
        self._log:leave_context()
        return false
    end
    

    if self._extractors[table_name] ~= nil then
        self._log:error('attempting to overwrite already registered extractor!'):leave_context()
        return false
    end


    self._extractors[table_name] = extractor

    local table_meta = self._db_registry.tables[table_name]
    table_meta.columns = columns
    table_meta.key_column = columns[key_column_id]

    local lkp = table.indexed_to_lookup(columns)  ---@cast lkp table
    table_meta.columns_lookup = lkp 

    local nullable_column_ids_lookup = {}
    if nullable_column_ids ~= nil then
        for i=1, #nullable_column_ids do
            nullable_column_ids_lookup[nullable_column_ids[i]] = true
        end
    end

    table_meta.nullable_columns_ids_lookup = nullable_column_ids_lookup
    
    self._log:info('successfully registered'):leave_context()
    return true
end


--[[
======================================================================================
                      ExtractorsRegistry: Internal functions and methods
======================================================================================
--]]


---@protected
function ExtractorsRegistry:_load_table_extractors()
    self._log:debug('looking for extractors in directory:', self._extractors_dir)
    
    local extractor_file_paths = core:get_filepaths_from_folder(self._extractors_dir, '*.lua')
    if not extractor_file_paths then
        self._log:error('get_filepaths_from_folder() - returned nothing')
        return
    end

    self._log:debug('found', #extractor_file_paths, 'extractors in', self._extractors_dir)

    local is_registered
    local loaded_extractors_count = 0
    
    for i, path in pairs(extractor_file_paths) do
        is_registered = self:_process_extractor_path(i, path)

        if is_registered then
            loaded_extractors_count = loaded_extractors_count + 1 
        end
    end

    self._log:info('loaded', loaded_extractors_count, 'extractors')
end


---@protected
---@param i integer
---@param path string
---@return boolean
function ExtractorsRegistry:_process_extractor_path(i, path)
    path = string.sub(path, 1, -5)  -- remove file extension
    self._log:debug('loading extractor #' .. i, 'at path:', path)
    
    
    local info = core:load_global_script(path)
    if not validators.is_valid_extractor_info(info, self._log) then
        self._log:debug('failed')
        return false
    end
    
    ---@cast info ExtractorInfo
    local is_registered = self:register_table_extractor(
        info.table_name,
        info.columns,
        info.key_column_id,
        info.extractor,
        info.nullable_column_ids
    )
    if not is_registered then
        self._log:debug('failed register extractor for:', info.table_name)
        return false
    end

    self._log:debug('loaded and registered extractor for:', info.table_name)
    return true
end



--[[
======================================================================================
                                Public initialization
======================================================================================
--]]


return ExtractorsRegistry
