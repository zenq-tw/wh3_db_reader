---@diagnostic disable: invisible


if core:is_battle() then   --TODO: add battle mode support?
    ModLog('db_reader: unsupported game mode (battle)')
    return
end


if (
    core:is_campaign() and 
    cm.game_interface:model():is_multiplayer()  --TODO: add multiplayer support?
) then
    ModLog('db_reader: unsupported game mode (multiplayer campaign)')
    return
end


--[[
======================================================================================
                                    dependecies
======================================================================================
--]]


local mr = assert(_G.memreader)
local utils = assert(core:load_global_script('script.db_reader.utils'))  ---@module "script.db_reader.utils" 
local logging = _G.zenq_logging
    
local DBReader = assert(core:load_global_script('script.db_reader.main'))  ---@type DBReader
local DBRegistry = assert(core:load_global_script('script.db_reader.registry'))  ---@type DBRegistry
local DBReaderSessionCache = assert(core:load_global_script('script.db_reader.cache')) ---@type DBReaderSessionCache
local ExtractorsRegistry = assert(core:load_global_script('script.db_reader.extractors.main')) ---@type ExtractorsRegistry



local created_event = 'DBReaderCreated'
local initialized_event = 'DBReaderInitialized'



--[[
======================================================================================
                                internal functions
======================================================================================
--]]

---@alias LoggingSetup {logger: LoggerCls, logging_exported: boolean, info: fun(msg: string): nil}

---@return LoggingSetup
local function _setup_logging()
    local info, logger

    if logging == nil then 
        -- trying to provide access to db_reader features without logging module being exported
        logging = {}
        setmetatable(logging, {
            __call = function () return logging end,
            __index = function () return logging end,
        })
        logging_exported = false
        
    else
        logging_exported = true
    end

    ---@type LoggerCls
    logger = logging.Logger('db_reader')
    logger:set_log_lvl(logging.lvl.debug) --TODO: remove
    
    info = function(msg) ModLog(msg); logger:info(msg) end

    if logging_exported then
        info('db_reader: logger created')
    else
        info('db_reader: logging module not found - no log will appear')
    end

    return {logger=logger, info=info, logging_exported=logging_exported}
end


--[[
======================================================================================
                                       Setup
======================================================================================
--]]



local l = _setup_logging()
l.info('db_reader: version = ' .. tostring(DBReader.version))

local db_address = utils.get_db_address(l.logger)
if db_address == nil then
    l.info('db_reader: failed to initialize - database address not found')
    return
end
l.info('db_reader: address of DB (actual fst meta table entry, but who cares): ' .. mr.tostring(db_address))

local cache = DBReaderSessionCache.new(db_address, l.logger)
cache:init()

local registry_data, db_reader_data = cache:get()
local registry = DBRegistry.new(db_address, l.logger)


local extractors  ---@type ExtractorsRegistry
local db_reader  ---@type DBReader



local function _setup()
    registry:init(registry_data)

    extractors = ExtractorsRegistry.new(registry, l.logger)
    extractors:init()

    core:add_listener(
        'DBReaderCreation',
        'ScriptEventAllModsLoaded',
        true,
        function()
            db_reader = DBReader.new(db_address, registry, extractors, l.logger)
            l.info('db_reader: created')

            l.info('db_reader: trigger event ' .. created_event .. '...')
            core:trigger_custom_event(created_event, {get_db_reader=db_reader})
            l.info('db_reader: event ' .. created_event .. ' triggered')

            db_reader:init(db_reader_data)

            l.info('db_reader: trigger event ' .. initialized_event .. '...')
            core:trigger_custom_event(initialized_event, {get_db_reader=db_reader})
            l.info('db_reader: event ' .. initialized_event .. ' triggered')

            registry_data = registry:get_data_for_cache()
            db_reader_data = db_reader:get_data_for_cache()
            cache:set(registry_data, db_reader_data)
        end,
        false
    )
end

local function _setup_db_reader_in_frontend_mode(callback_name, max_count)
    local calls_count = 0
    local callback = function()
        calls_count = calls_count + 1
        ModLog('db_reader: repeated callback #' .. calls_count);
        
        if utils.check_is_db_constructed() then
            tm:remove_real_callback(callback_name)
            ModLog('db_reader: repeated callback removed - DB is accessible')

            _setup()

            return
        end

        if max_count > 10 then
            tm:remove_real_callback(callback_name)
            ModLog('db_reader: repeated callback removed - max retry count')
        end
    end

    ---@cast tm timer_manager
    core:add_ui_created_callback(function() tm:repeat_real_callback(callback, 100, callback_name); end)
end


if core:is_campaign() then
    _setup()

else -- frontend
    _setup_db_reader_in_frontend_mode('setup_db_reader_in_frontend_mode', 10)

end
