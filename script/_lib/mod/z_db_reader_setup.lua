---@diagnostic disable: invisible


--[[
======================================================================================
                                    guard clauses
======================================================================================
--]]


if core:is_battle() then   --TODO: add battle mode support?
    ModLog('db_reader: unsupported game mode - battle')
    return
end


if (
    core:is_campaign() and 
    cm.game_interface:model():is_multiplayer()  --TODO: add multiplayer support?
) then
    ModLog('db_reader: unsupported game mode - multiplayer campaign')
    return
end


--[[
======================================================================================
                                    dependencies
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

local cache = DBReaderSessionCache.new(l.logger)
cache:init()

local registry_data, db_reader_data = cache:get()
local registry = DBRegistry:_new(db_address, l.logger)


local extractors  ---@type ExtractorsRegistry
local db_reader  ---@type DBReader


local function _init_runtime_dependencies()
    registry:_init(registry_data)

    extractors = ExtractorsRegistry:new(registry, l.logger)
    extractors:init()
end


local function _setup_db_reader()
    db_reader = DBReader:_new(db_address, registry, extractors, l.logger)
    l.info('db_reader: created')

    l.info('db_reader: trigger event ' .. created_event .. '...')
    core:trigger_custom_event(created_event, {get_db_reader=db_reader})
    l.info('db_reader: event ' .. created_event .. ' triggered')

    db_reader:_init(db_reader_data)

    l.info('db_reader: trigger event ' .. initialized_event .. '...')
    core:trigger_custom_event(initialized_event, {get_db_reader=db_reader})
    l.info('db_reader: event ' .. initialized_event .. ' triggered')

    l.info('db_reader: caching internal data...')
    registry_data = registry:_get_data_for_cache()
    db_reader_data = db_reader:_get_data_for_cache()

    local is_cached = cache:set(registry_data, db_reader_data)
    if is_cached then
        l.info('db_reader: internal data cached')    
    else
        l.info('db_reader: failed to cache data!')
    end
end



--[[
======================================================================================
                        Initialization in different game modes
======================================================================================
--]]



if core:is_campaign() then
    _init_runtime_dependencies()

    core:add_listener(
        'DBReaderCreation',
        'ScriptEventAllModsLoaded',
        true,
        _setup_db_reader,
        false
    )

else -- [frontend]
     -- for other modes there should be guard clauses at the beginning of this script

    -- In frontend mode, DB will not be constructed after the 'ScriptEventAllModsLoaded' or 'UICreated' events triggered,
    -- but we don't have any events after them until the game menu is shown (at least I don't know of any).
    -- Therefore, we will have to run DBReader initialization right after user will see the menu. 
    -- We can set up a callback at the earliest time the screen is displayed by registering tm:real_callback() with the smallest interval possible (1ms).
    -- Unfortunately, this will lead to a slight freeze immediately after Menu is shown to the user,
    -- and with internal logging enabled, to a long freeze.

    core:get_tm():callback(
        function ()
            if not utils.check_is_db_constructed(db_address) then
                l.info('db_reader: failed to initialize in frontend mode - DB was not constructed')
                return
            end
            _init_runtime_dependencies()
            _setup_db_reader()
        end,
        1
    )

end
