local mct = get_mct()
local mct_mod = mct:register_mod("db_reader")

mct_mod:set_title('Database Reader')
mct_mod:set_author('ZenQ')
mct_mod:set_description('Tool for modders to read game database tables at runtime.')


local reload_cache_trigger = mct_mod:add_new_option('reload_cache_trigger', 'checkbox')
reload_cache_trigger:set_default_value(false)
reload_cache_trigger:set_text('Change status of checkbox to trigger db data reloading')
reload_cache_trigger:set_tooltip_text("Sorry for that, but there is no button control in MCT yet (or I'm a dumb that cannot find a correct way to do this right :) )")
reload_cache_trigger:set_is_global(true)




local logging_lvl_dropdown = mct_mod:add_new_option('logging_lvl', 'dropdown')

logging_lvl_dropdown:add_dropdown_value('error', 'error', 'only messages with level ERROR will output to logfile', true)
logging_lvl_dropdown:add_dropdown_value('info', 'info', 'messages with level ERROR and INFO will output to logfile', false)
logging_lvl_dropdown:add_dropdown_value('debug', 'debug', 'all messages will output to logfile', false)
logging_lvl_dropdown:set_is_global(true)

-- mct_mod:set_log_file_path('log__db_reader.txt')

