local zlib = assert(core:load_global_script('script.db_reader.zlib.header'))  ---@module "script.db_reader.zlib.header"

--TODO: make base SessionCache class

--[[
======================================================================================
                                DBReaderSessionCache
======================================================================================
--]]


---@class DBReaderSessionCache
---@field protected _cache_file_path string
---@field protected _log LoggerCls
---@field protected _data DBReaderSessionData
---@field protected _cache_stored_flag_key string
---@field protected __index DBReaderSessionCache
local DBReaderSessionCache = {
    _cache_stored_flag_key = 'DB_READER_CACHE_STORED_FLAG',
    _cache_file_path = 'data/.db_reader__cache.lua',
}


--@alias CTableKey string | number
--@alias CTableVal string | number | boolean
--@alias CacheableTable table < CTableKey, CTableVal | CacheableTable >

---@class DBReaderSessionData
---@field registry DBRegistryDumpedData
---@field db_reader DBReaderData


---@protected
---@nodiscard
---@generic Cls: DBReaderSessionCache
---@param cls Cls
---@param logger LoggerCls
---@return Cls
---ONLY FOR INTERNAL USAGE
function DBReaderSessionCache.new(cls, logger)
    logger:enter_context('cache: new')

    cls.__index = cls
    local instance = setmetatable({}, cls)  --[[@as DBReaderSessionCache]]


    instance._log = logger
    instance._data = {}


    logger:debug('created'):leave_context()

    return instance
end


---@protected
---@param data DBReaderSessionData | nil
---@return nil
---ONLY FOR INTERNAL USAGE
function DBReaderSessionCache:init(data)
    self._log:enter_context('cache: init')

    if data ~= nil then
        self._log:debug('use provided data')

    elseif self:_is_cache_stored() then
        self._log:debug('cache flag is set as stored -> trying to load data from file')
        data = self:_load_data_from_cache_file()

    else
        self._log:debug('cache flag is not set -> no data')
    end

    self._data = data or {}
    self._log:info('done'):leave_context()
end


--[[
======================================================================================
                            DBReaderSessionCache: public methods
======================================================================================
--]]


---store session cache
---@param registry DBRegistryDumpedData
---@param db_reader DBReaderData
---@return boolean is_success
---ONLY FOR INTERNAL USAGE
function DBReaderSessionCache:set(registry, db_reader)
    self._log:enter_context('cache: set'):debug('starting')

    ---@type DBReaderSessionData
    local data = {
        registry=registry,
        db_reader=db_reader,
    }
    self:_dump_data_to_cache_file(data)
    self:init(data)

    self._log:info('done'):leave_context()
    return true
end


---load session cache
---@return DBRegistryDumpedData?, DBReaderData?
---ONLY FOR INTERNAL USAGE
function DBReaderSessionCache:get() 
    self._log:enter_context('cache: get')
    
    local registry = self._data.registry
    local db_reader = self._data.db_reader
    
    if registry and not db_reader then
        self._log:error('invalid cache: registry exist, but db_reader not'):leave_context()
        return
    end

    self._log:info('done'):leave_context()
    return registry, db_reader
end


--[[
======================================================================================
                      DBReaderSessionCache: Internal functions and methods
======================================================================================
--]]


---@protected
---@param data DBReaderSessionData
function DBReaderSessionCache:_dump_data_to_cache_file(data)
    local dumped_data = zlib.table.dump(data)
    if not is_string(dumped_data) then
        self._log:error('failed to dump table')
        return false
    end

    ---@cast dumped_data string
    dumped_data = 'return ' .. dumped_data
    self._log:debug('data dumped')

    local file = self:_open_cache_file('w')
    if not file then return false end
    self._log:debug('cache file opened')

    file:write(dumped_data)
    file:flush()
    file:close()

    self:_set_cache_stored_state(true)

    self._log:debug('data stored in cache file:', self._cache_file_path)
end


---@protected
---@return DBReaderSessionData?
function DBReaderSessionCache:_load_data_from_cache_file()
    local file = self:_open_cache_file('r')
    if not file then return end

    local dumped_data = file:read("*a")

    file:close()
    if not dumped_data then
        self._log:debug('no data in cache file')
        return
    end
    self._log:debug('cache data loaded from file type:', type(dumped_data), '| value:'):debug(dumped_data)  --TODO: remove?

    ---@cast dumped_data string
    local eval, err_msg = loadstring(dumped_data)
    if not eval then
        self._log:error('failed to compile loaded data:', tostring(err_msg))
        return 
    end

    local data = eval()
    if not data then
        self._log:error('no data:', tostring(data), type(data))
        return
    end

    self._log:debug('cache data retrieved')

    if not is_table(data) then
        self._log:error('invalid data stored in cache! type:', type(data), '| value:', tostring(data))
        return 
    end


    return data
end


---@protected
---@param mod 'r' | 'w'
---@return file*?
function DBReaderSessionCache:_open_cache_file(mod)
    mod = mod or 'r'
    local file, err_msg = io.open(self._cache_file_path, mod)

    if not file then
        self._log:error('failed to open cache file (' .. self._cache_file_path .. '):', tostring(err_msg))
        return
    end

    return file
end


---@return boolean is_stored
function DBReaderSessionCache:_is_cache_stored()
    return core:svr_load_bool(self._cache_stored_flag_key)
end


---@param is_stored boolean 
---@return nil
function DBReaderSessionCache:_set_cache_stored_state(is_stored)
    core:svr_save_bool(self._cache_stored_flag_key, is_stored)
    self._log:debug('cache flag set to:', is_stored)
end


--[[
======================================================================================
                                Public initialization
======================================================================================
--]]


return DBReaderSessionCache
