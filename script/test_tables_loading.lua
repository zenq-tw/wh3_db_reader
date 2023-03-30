
local table_names = {
    'action_results_additional_outcomes',
    'agent_actions',
    'armed_citizenry_unit_groups',
    'armed_citizenry_units_to_unit_groups_junctions',
    'building_level_armed_citizenry_junctions',
}


local function test() 

    core:add_listener(
        'Test_CM_DBReaderCreated',
        'DBReaderCreated',
        true,
        ---@param context DBReaderCustomContext
        function (context)
            local db = context:get_db_reader()
            _G.db_reader = db
            for i=1, #table_names do
                ModLog('XXX db_reader CM TEST: "' .. table_names[i] .. '" is requested?: ' .. tostring(db:request_table(table_names[i])))
            end
        end,
        false
    )


    core:add_listener(
        'Test_CM_DBReaderInitialized',
        'DBReaderInitialized',
        true,
        ---@param context DBReaderCustomContext
        function (context)
            local db = context.get_db_reader()

            local loaded_tables = {}
            local tbl, table_name, indexes_count
            for i=1, #table_names do
                ModLog('-----------------------------------------------------------------------')
                table_name = table_names[i]
                tbl = db:is_table_loaded(table_name)
                
                if not tbl then 
                    ModLog('XXX db_reader CM TEST: table "' .. table_name .. '" - !!! NOT LOADED !!!')
                else
                    ModLog('XXX db_reader CM TEST: table "' .. table_name .. '" loaded')
                    table.insert(loaded_tables, table_name)
                end
            end
            
            ModLog('=======================================================================')
            ModLog('=======================================================================')
            ModLog('=======================================================================')
            ModLog('=======================================================================')
            ModLog('=======================================================================')

            ModLog('#loaded_tables=' .. tostring(#loaded_tables))

            for i=1, #loaded_tables do
                ModLog('=======================================================================')

                ModLog('TABLE: ' .. loaded_tables[i])

                tbl = assert(db:get_table(loaded_tables[i]))

                ModLog('type(table)=' .. type(tbl))
                ModLog('type(table.count)=' .. type(tbl.count))
                ModLog('type(table.pk)=' .. type(tbl.pk))
                ModLog('type(table.indexes)=' .. type(tbl.indexes))

                ModLog('-----------------------------------------------------------------------')
                
                ModLog('table.count=' .. tbl.count)

                for id=1, tbl.count do
                    ModLog(id .. ':')
                    for field, value in pairs(tbl[id]) do
                        ModLog('  ' .. tostring(field) .. '=' .. tostring(value) .. ';')
                    end
                end

                ModLog('-----------------------------------------------------------------------')

                if tbl.indexes == nil then
                    ModLog('no indexes')
                else
                    indexes_count = 0
                    for _, _ in pairs(tbl.indexes) do
                        indexes_count = indexes_count + 1
                    end

                    ModLog('count of table.indexes=' .. indexes_count)

                    for field, values_index in pairs(tbl.indexes) do
                        ModLog(field .. ':')
                        for value, table_keys in pairs(values_index) do
                            ModLog('  ' .. value .. ' (' .. table_keys.count .. '):')
                            for j=1, table_keys.count do
                                ModLog('    ' .. j .. ': ' .. table_keys[j])
                            end
                        end
                    end
                end
            end
        end,
        false
    )

end


return test