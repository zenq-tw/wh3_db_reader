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


local mr                    = assert(_G.memreader)
local utils                 = assert(core:load_global_script('script.db_reader.utils'))             ---@module "script.db_reader.utils" 
local zlib                  = assert(core:load_global_script('script.db_reader.zlib.header'))              ---@module "script.db_reader.zlib.header" 
    
local DBReader              = assert(core:load_global_script('script.db_reader.main'))              ---@type DBReader
local DBRegistry            = assert(core:load_global_script('script.db_reader.registry'))          ---@type DBRegistry
local DBReaderSessionCache  = assert(core:load_global_script('script.db_reader.cache'))             ---@type DBReaderSessionCache
local ExtractorsRegistry    = assert(core:load_global_script('script.db_reader.extractors.main'))   ---@type ExtractorsRegistry



local created_event         = 'DBReaderCreated'
local initialized_event     = 'DBReaderInitialized'


local logger = zlib.logging.Logger:new('db_reader')


--[[
======================================================================================
                                       Setup
======================================================================================
--]]

logger:enter_context('setup'):info('Game version =', zlib.functools.lazy(common.game_version)):info('DBReader version =', DBReader.version)

local db_address = utils.get_db_address(logger)
if db_address == nil then
    logger:info('failed to initialize - database address not found'):leave_context()
    return
end
logger:info('address of DB (actual fst meta table entry, but who cares):', zlib.functools.lazy(mr.tostring, db_address))

local cache = DBReaderSessionCache:new(logger)
cache:init()

local registry_data, db_reader_data = cache:get()
local registry = DBRegistry:_new(db_address, logger)


local extractors    ---@type ExtractorsRegistry
local db_reader     ---@type DBReader


local function _setup_runtime_dependencies()
    logger:enter_context('dependencies')

    registry:_init(registry_data)

    extractors = ExtractorsRegistry:new(registry, logger)
    extractors:init()

    logger:leave_context()
end


local function _start_db_reader()
    logger:enter_context('db_reader')

    db_reader = DBReader:_new(db_address, registry, extractors, logger)
    logger:info('created')

    
    logger:info('trigger event', created_event)
    core:trigger_custom_event(
        created_event,
        {get_db_reader=db_reader}
    )


    db_reader:_init(db_reader_data)
    logger:info('trigger event', initialized_event)

    core:trigger_custom_event(
        initialized_event,
        {get_db_reader=db_reader}
    )


    logger:info('caching internal data...')
    registry_data = registry:_get_data_for_cache()
    db_reader_data = db_reader:_get_data_for_cache()


    local is_cached = cache:set(registry_data, db_reader_data)
    if is_cached then
        logger:info('internal data cached')    
    else
        logger:info('failed to cache data!')
    end

    logger:leave_context()
end



--[[
======================================================================================
                        Initialization in different game modes
======================================================================================
--]]



if core:is_campaign() then
    _setup_runtime_dependencies()

    core:add_listener(
        'DBReaderCreation',
        'ScriptEventAllModsLoaded',
        true,
        _start_db_reader,
        false
    )

    logger:leave_context()

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
                logger:info('failed to initialize in frontend mode - DB was not constructed'):leave_context()
                return
            end
            _setup_runtime_dependencies()

            logger:leave_context()


            _start_db_reader()
        end,
        1
    )

end
