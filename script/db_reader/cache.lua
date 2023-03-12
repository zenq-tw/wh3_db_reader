local mr = assert(_G.memreader)
local utils = assert(core:load_global_script('script.db_reader.utils'))  ---@module "script.db_reader.utils"

--TODO: make base SessionCache class

--[[
======================================================================================
                                DBReaderSessionCache
======================================================================================
--]]


---@class DBReaderSessionCache
---@field protected _cache_file_path string
---@field protected _cache_header string
---@field protected _log LoggerCls
---@field protected _data DBReaderSessionData
---@field protected __index DBReaderSessionCache
local DBReaderSessionCache = {}
DBReaderSessionCache.__index = DBReaderSessionCache


--@alias CTableKey string | number
--@alias CTableVal string | number | boolean
--@alias CacheableTable table < CTableKey, CTableVal | CacheableTable >

---@class DBReaderSessionData
---@field registry DBRegistryDumpedData
---@field db_reader DBReaderData


---@protected
---@nodiscard
---@param db_address pointer
---@param logger LoggerCls
---@return DBReaderSessionCache
---ONLY FOR INTERNAL USAGE
function DBReaderSessionCache.new(db_address, logger)
    local self = setmetatable({}, DBReaderSessionCache)

    self._cache_file_path = 'data/_db_reader__cache.lua'
    self._log = logger
    self._cache_header = mr.tostring(db_address)
    self._data = {}

    return self
end


---@protected
---@param data DBReaderSessionData | nil
---@return nil
---ONLY FOR INTERNAL USAGE
function DBReaderSessionCache:init(data)
    self._log:enter_context('cache: init')

    if data then
        self._data = data
    else
        self._data = self:_load_data_from_cache_file() or {}
    end

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
    local dumped_data = utils.dump_table(data)
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

    file:write(self._cache_header .. '\n')
    file:write(dumped_data)
    file:flush()
    file:close()

    self._log:debug('data stored in cache file:', self._cache_file_path)
end


---@protected
---@return DBReaderSessionData?
function DBReaderSessionCache:_load_data_from_cache_file()
    local file = self:_open_cache_file('r')
    if not file then return end
    
    local stored_cache_header = file:read("*l")
    self._log:debug('stored cache header is:', stored_cache_header, '; actual:', self._cache_header)
    
    if stored_cache_header ~= self._cache_header then
        self._log:info('found old cache -> return nothing')
        return
    end

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


--[[
======================================================================================
                                Public initialization
======================================================================================
--]]


return DBReaderSessionCache
