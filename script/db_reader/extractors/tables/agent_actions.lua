local mr = assert(_G.memreader)

local T = assert(core:load_global_script('script.db_reader.types'))  ---@module "script.db_reader.types"
local func = assert(core:load_global_script('script.db_reader.functools'))  ---@module "script.db_reader.functools"
local utils = assert(core:load_global_script('script.db_reader.utils'))  ---@module "script.db_reader.utils"



---@type ExtractorInfo
return {
    table_name='agent_actions',
    columns={
        'unique_id',
        'ability',
        'agent',
        -- 'attribute',                             -- failed to find
        -- 'target_attribute',                      -- failed to find
        'critical_failure',
        'failure',
        'opportune_failure',
        'success',
        'critical_success',
        'cannot_fail',
        -- 'localized_action_name',                 -- can be extracted, but useless?
        -- 'localized_action_description',          -- can be extracted, but useless?
        'critical_failure_proportion_modifier',
        'opportune_failure_proportion_modifier',
        'critical_success_proportion_modifier',
        'chance_of_success',
        -- 'voiceover',                             -- failed to find
        'icon_path',
        -- 'show_action_info_in_ui',                -- failed to find
        -- 'subculture',                            -- failed to find
        -- 'succeed_always_override',               -- failed to find
        -- 'order',                                 -- failed to find
    },
    key_column_id=1,

    ---@type TableDataExtractor
    extractor=function(ptr, logger)
        logger:debug('table meta address is:', func.lazy(mr.tostring, ptr))
    
        local guard_value = 1000
        local rows_count = mr.read_int32(ptr, T.uint32(0x08))
    
        if rows_count > guard_value then
            logger:error('probably invalid base pointer or invalid array size value in structure ( >', guard_value, '):', rows_count)
            return
        end
    
        ptr = mr.read_pointer(ptr, T.uint32(0x10))
        logger:debug('array (fst elem addr):', func.lazy(mr.tostring, ptr))


        local next_array_element_shift = T.uint32(0x08)
        local rows = {}

        local array_elem_data_ptr, sub_structure_ptr
        local unique_id, ability, agent
        local critical_failure, failure, opportune_failure, success, critical_success, cannot_fail
        local critical_failure_modifier, opportune_failure_modifier, critical_success_modifier, chance_of_success
        local icon_path

        logger:add_indent()
        for i=1, rows_count do
            logger:debug('address of', i, 'array elem (== ptr to record struct):', func.lazy(mr.tostring, ptr))

            array_elem_data_ptr = mr.read_pointer(ptr)
            logger:debug('address of', i, 'record struct:', func.lazy(mr.tostring, array_elem_data_ptr))


             ------------------------------------ Fields Parsing ------------------------------------


            unique_id = utils.read_string_CA(array_elem_data_ptr, 0x08)
            logger:debug(i, 'unique_id:', unique_id)


            ------------------------------------ Ability & Agent ------------------------------------


            sub_structure_ptr = mr.read_pointer(array_elem_data_ptr, 0x18)
            logger:debug('address of', i, 'record Ability sub-struct:', func.lazy(mr.tostring, sub_structure_ptr))
            ability = utils.read_string_CA(sub_structure_ptr, 0x08)
            logger:debug(i, 'ability:', ability)



            sub_structure_ptr = mr.read_pointer(array_elem_data_ptr, 0x20)
            logger:debug('address of', i, 'record Agent sub-struct:', func.lazy(mr.tostring, sub_structure_ptr))
            agent = utils.read_string_CA(sub_structure_ptr, 0x08, true)
            logger:debug(i, 'agent:', agent)


            ------------------------------------ Action Results ------------------------------------


            sub_structure_ptr = mr.read_pointer(array_elem_data_ptr, 0x40)
            logger:debug('address of', i, 'record ActionResult sub-struct (critical_failure):', func.lazy(mr.tostring, sub_structure_ptr))
            critical_failure = utils.read_string_CA(sub_structure_ptr, 0x08)
            logger:debug(i, 'critical_failure:', critical_failure)


            sub_structure_ptr = mr.read_pointer(array_elem_data_ptr, 0x48)
            logger:debug('address of', i, 'record ActionResult sub-struct (failure):', func.lazy(mr.tostring, sub_structure_ptr))
            failure = utils.read_string_CA(sub_structure_ptr, 0x08)
            logger:debug(i, 'failure:', failure)


            sub_structure_ptr = mr.read_pointer(array_elem_data_ptr, 0x50)
            logger:debug('address of', i, 'record ActionResult sub-struct (opportune_failure):', func.lazy(mr.tostring, sub_structure_ptr))
            opportune_failure = utils.read_string_CA(sub_structure_ptr, 0x08)
            logger:debug(i, 'opportune_failure:', opportune_failure)


            sub_structure_ptr = mr.read_pointer(array_elem_data_ptr, 0x58)
            logger:debug('address of', i, 'record ActionResult sub-struct (success):', func.lazy(mr.tostring, sub_structure_ptr))
            success = utils.read_string_CA(sub_structure_ptr, 0x08)
            logger:debug(i, 'success:', success)


            sub_structure_ptr = mr.read_pointer(array_elem_data_ptr, 0x60)
            logger:debug('address of', i, 'record ActionResult sub-struct (critical_success):', func.lazy(mr.tostring, sub_structure_ptr))
            critical_success = utils.read_string_CA(sub_structure_ptr, 0x08)
            logger:debug(i, 'critical_success:', critical_success)


            sub_structure_ptr = mr.read_pointer(array_elem_data_ptr, 0x68)
            logger:debug('address of', i, 'record ActionResult sub-struct (cannot_fail):', func.lazy(mr.tostring, sub_structure_ptr))
            cannot_fail = utils.read_string_CA(sub_structure_ptr, 0x08)
            logger:debug(i, 'cannot_fail:', cannot_fail)


            ------------------------------------ Proportion Modifiers ------------------------------------


            critical_success_modifier = mr.read_float(array_elem_data_ptr, 0xA0)
            logger:debug(i, 'critical_success_proportion_modifier:', critical_success_modifier)

            opportune_failure_modifier = mr.read_float(array_elem_data_ptr, 0xA4)
            logger:debug(i, 'opportune_failure_proportion_modifier:', opportune_failure_modifier)

            critical_failure_modifier = mr.read_float(array_elem_data_ptr, 0xA8)
            logger:debug(i, 'critical_failure_proportion_modifier:', critical_failure_modifier)


            ------------------------------------ Other stuff ------------------------------------


            chance_of_success = mr.read_uint32(array_elem_data_ptr, 0xAC)
            logger:debug(i, 'chance_of_success:', chance_of_success)


            icon_path = utils.read_string_CA(array_elem_data_ptr, 0xB8)
            logger:debug(i, 'icon_path:', icon_path)


            ------------------------------------ End Parsing ------------------------------------


            table.insert(rows, {
                unique_id,
                ability,
                agent,
                -- attribute,
                -- target_attribute,
                critical_failure,
                failure,
                opportune_failure,
                success,
                critical_success,
                cannot_fail,
                -- localized_action_name,
                -- localized_action_description,
                critical_failure_modifier,
                opportune_failure_modifier,
                critical_success_modifier,
                chance_of_success,
                -- voiceover,
                icon_path,
                -- show_action_info_in_ui,
                -- subculture,
                -- succeed_always_override,
                -- order,
            })

            ptr = mr.add(ptr, next_array_element_shift)  -- next array element address
        end
        logger:remove_indent()

        return {
            rows=rows,
            indexes=nil,
        }
    end
}
