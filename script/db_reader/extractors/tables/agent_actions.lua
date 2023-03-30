local mr = assert(_G.memreader)
local zlib = assert(core:load_global_script('script.db_reader.zlib.header'))  ---@module "script.db_reader.zlib.header"

local T = assert(core:load_global_script('script.db_reader.types'))  ---@module "script.db_reader.types"
local utils = assert(core:load_global_script('script.db_reader.utils'))  ---@module "script.db_reader.utils"


local lazy = zlib.functools.lazy



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
        logger:debug('table meta address is:', lazy(mr.tostring, ptr))
    
        local guard_value = 1000
        local rows_count = mr.read_int32(ptr, T.uint32(0x08))
    
        if rows_count > guard_value then
            logger:error('probably invalid base pointer or invalid array size value in structure ( >', guard_value, '):', rows_count)
            return
        end
    
        ptr = mr.read_pointer(ptr, T.uint32(0x10))
        logger:debug('array (fst elem addr):', lazy(mr.tostring, ptr))


        ------------------------------------ Variables definition ------------------------------------


        local next_array_element_shift = T.uint32(0x08)
        local rows = {}

        local indexes = {}  ---@type {critical_failure: TRawIndex<string>, failure: TRawIndex<string>, opportune_failure: TRawIndex<string>, success: TRawIndex<string>, critical_success: TRawIndex<string>, cannot_fail: TRawIndex<string> }

        indexes.critical_failure    = zlib.collections.defaultdict(zlib.functools.factories.table)   ---@type defaultdict<string, Id[]>
        indexes.failure             = zlib.collections.defaultdict(zlib.functools.factories.table)   ---@type defaultdict<string, Id[]>
        indexes.opportune_failure   = zlib.collections.defaultdict(zlib.functools.factories.table)   ---@type defaultdict<string, Id[]>
        indexes.success             = zlib.collections.defaultdict(zlib.functools.factories.table)   ---@type defaultdict<string, Id[]>
        indexes.critical_success    = zlib.collections.defaultdict(zlib.functools.factories.table)   ---@type defaultdict<string, Id[]>
        indexes.cannot_fail         = zlib.collections.defaultdict(zlib.functools.factories.table)   ---@type defaultdict<string, Id[]>

        local array_elem_data_ptr, sub_structure_ptr
        local unique_id, ability, agent
        local critical_failure, failure, opportune_failure, success, critical_success, cannot_fail
        local critical_failure_modifier, opportune_failure_modifier, critical_success_modifier, chance_of_success
        local icon_path


        ------------------------------------ Action Results combined index stuff ------------------------------------


        local action_already_in_index = zlib.collections.defaultdict(zlib.functools.factories.table)   ---@type defaultdict<string, {[Id]: true}>
        local action_result

        ---@param offset number
        ---@param record_id integer
        ---@param type string
        ---@return string
        local read_action_result = function(offset, record_id, type)
            sub_structure_ptr = mr.read_pointer(array_elem_data_ptr, offset)
            logger:debug('address of', record_id, 'record ActionResult sub-struct (', type , '):', lazy(mr.tostring, sub_structure_ptr))

            action_result = utils.read_string_CA(sub_structure_ptr, 0x08)
            logger:debug(record_id, type, '=', action_result)

            table.insert(indexes[type][action_result], record_id)

            return action_result
        end


        --========================================================================================--
        --================================== Reading table data ==================================--
        --========================================================================================--


        logger:add_indent()
        for id=1, rows_count do
            logger:debug('address of', id, 'array elem (== ptr to record struct):', lazy(mr.tostring, ptr))

            array_elem_data_ptr = mr.read_pointer(ptr)
            logger:debug('address of', id, 'record struct:', lazy(mr.tostring, array_elem_data_ptr))


             ------------------------------------ Fields Parsing ------------------------------------


            unique_id = utils.read_string_CA(array_elem_data_ptr, 0x08)
            logger:debug(id, 'unique_id:', unique_id)


            ------------------------------------ Ability & Agent ------------------------------------


            sub_structure_ptr = mr.read_pointer(array_elem_data_ptr, 0x18)
            logger:debug('address of', id, 'record Ability sub-struct:', lazy(mr.tostring, sub_structure_ptr))
            ability = utils.read_string_CA(sub_structure_ptr, 0x08)
            logger:debug(id, 'ability:', ability)



            sub_structure_ptr = mr.read_pointer(array_elem_data_ptr, 0x20)
            logger:debug('address of', id, 'record Agent sub-struct:', lazy(mr.tostring, sub_structure_ptr))
            agent = utils.read_string_CA(sub_structure_ptr, 0x08, true)
            logger:debug(id, 'agent:', agent)


            ------------------------------------ Action Results ------------------------------------


            critical_failure  = read_action_result(0x40, id, 'critical_failure')
            failure           = read_action_result(0x48, id, 'failure')
            opportune_failure = read_action_result(0x50, id, 'opportune_failure')
            success           = read_action_result(0x58, id, 'success')
            critical_success  = read_action_result(0x60, id, 'critical_success')
            cannot_fail       = read_action_result(0x68, id, 'cannot_fail')


            ------------------------------------ Proportion Modifiers ------------------------------------


            critical_success_modifier = mr.read_float(array_elem_data_ptr, 0xA0)
            logger:debug(id, 'critical_success_proportion_modifier:', critical_success_modifier)

            opportune_failure_modifier = mr.read_float(array_elem_data_ptr, 0xA4)
            logger:debug(id, 'opportune_failure_proportion_modifier:', opportune_failure_modifier)

            critical_failure_modifier = mr.read_float(array_elem_data_ptr, 0xA8)
            logger:debug(id, 'critical_failure_proportion_modifier:', critical_failure_modifier)


            ------------------------------------ Other stuff ------------------------------------


            chance_of_success = mr.read_uint32(array_elem_data_ptr, 0xAC)
            logger:debug(id, 'chance_of_success:', chance_of_success)


            icon_path = utils.read_string_CA(array_elem_data_ptr, 0xB8)
            logger:debug(id, 'icon_path:', icon_path)


            ------------------------------------ End Parsing ------------------------------------


            rows[id] = {
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
            }

            ptr = mr.add(ptr, next_array_element_shift)  -- next array element address
        end
        logger:remove_indent()

        return {
            rows=rows,
            indexes=indexes,
        }
    end
}
