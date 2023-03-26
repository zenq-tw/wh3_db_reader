
local table_name = 'agent_actions'


local function test() 

    core:add_listener(
        'Test_CM_DBReaderCreated',
        'DBReaderCreated',
        true,
        function (context)
            ---@cast context DBReaderCustomContext
            local db = context:get_db_reader()
            _G.db_reader = db
            ModLog('XXX db_reader CM TEST: is requested?: ' .. tostring(db:request_table(table_name)))
        end,
        false
    )


    core:add_listener(
        'Test_CM_DBReaderInitialized',
        'DBReaderInitialized',
        function (context)
            ---@cast context DBReaderCustomContext
            local is_loaded = context:get_db_reader():is_table_loaded(table_name)
            ModLog('XXX db_reader CM TEST: is loaded?: ' .. tostring(is_loaded))
            return is_loaded
        end,
        function (context)

            ---@cast context DBReaderCustomContext
            local db = context.get_db_reader()
            local table = assert(db:get_table(table_name))

            ModLog('type(table)=' .. type(table))
            ModLog('type(table.count)=' .. type(table.count))
            ModLog('type(table.indexes)=' .. type(table.indexes))
            ModLog('type(table.records)=' .. type(table.records))

            ModLog('-----------------------------------------------------------------------')
            
            ModLog(table_name)
            ModLog('table.count=' .. table.count)

            for id, record in pairs(table.records) do
                ModLog(id .. ':')
                for field, value in pairs(record) do
                    ModLog('  ' .. tostring(field) .. '=' .. tostring(value) .. ';')
                end
            end

            ModLog('-----------------------------------------------------------------------')

            if table.indexes == nil then
                ModLog('no indexes')
                return
            end

            local indexes_count = 0
            for _, _ in pairs(table.indexes) do
                indexes_count = indexes_count + 1
            end

            ModLog('count of table.indexes=' .. indexes_count)
            for field, values_index in pairs(table.indexes) do
                ModLog(field .. ':')
                for value, table_keys in pairs(values_index) do
                    ModLog('  ' .. value .. ':')
                    for i, key in pairs(table_keys) do
                        ModLog('    ' .. i .. ': ' .. key)
                    end
                end
            end
            
        end,
        false
    )

end


return test
