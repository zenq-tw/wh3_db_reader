local mr = assert(_G.memreader)
local zlib = assert(core:load_global_script('script.db_reader.zlib.header'))  ---@module "script.db_reader.zlib.header"

local T = assert(core:load_global_script('script.db_reader.types'))  ---@module "script.db_reader.types"
local utils = assert(core:load_global_script('script.db_reader.utils'))  ---@module "script.db_reader.utils"


local lazy = zlib.functools.lazy
local xor = zlib.functools.xor



---@enum OutcomesEnum
local KNOWN_OUTCOMES_ENUM = {
    [0]  = 'agent_wounded',
    [14] = 'containing_army_unit_xp_gain',
    [15] = 'target_agent_wounded',
    [16] = 'target_agent_killed',
    [19] = 'target_army_damage_units',
    [20] = 'target_army_damage_single_unit',
    [38] = 'target_settlement_single_building_damaged',
    [39] = 'target_settlement_garrison_units_damaged',
    [43] = 'generic_bonus_value',
    [44] = 'damage_walls',
    [46] = 'infect_with_plague',
    [47] = 'agent_killed',
    [48] = 'target_settlement_exposed',
    [51] = 'downgrade_settlement_and_damage_buildings',
    [52] = 'target_ruined_settlement_occupied',
    [54] = 'establish_foreign_slots',
}



---@type ExtractorInfo
return {
    table_name='action_results_additional_outcomes',
    columns={
        'key',
        'action_result_key',
        'outcome',
        'value',
        'effect_record',
        'effect_scope_record',
        -- 'fixme',                         -- failed to find
        -- 'opportune_failure_weighting',   -- failed to find
        -- 'affects_target',                -- failed to find
        -- 'advancement_stage',             -- failed to find
    },
    key_column_id=1,
    nullable_column_ids={
        5,
        6,
    },

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


        local next_array_element_shift = T.uint32(0x08)
        local rows, id = {}, 0

        local array_elem_data_ptr, sub_structure_ptr, one_exist_but_not_another

        local indexes = {}  ---@type {outcome: TRawIndex<string>, action_result_key: TRawIndex<string>}

        local outcome_index = zlib.collections.defaultdict(  ---@type defaultdict<string, Id[]>
            zlib.functools.factories.table
        )
        local action_result_key_index = zlib.collections.defaultdict(  ---@type defaultdict<string, Id[]>
            zlib.functools.factories.table
        )

        indexes.outcome = outcome_index
        indexes.action_result_key = action_result_key_index

        local key, action_result_key, value
        local outcome_enum_member, outcome_raw_value
        local effect_record, effect_scope_record

        logger:add_indent()
        for i=1, rows_count do
            logger:debug('address of', i, 'array elem (== ptr to record struct):', lazy(mr.tostring, ptr))

            array_elem_data_ptr = mr.read_pointer(ptr)
            logger:debug('address of', i, 'record struct:', lazy(mr.tostring, array_elem_data_ptr))


            --================================== Fields Parsing ==================================--
            
            key = utils.read_string_CA(array_elem_data_ptr, 0x30)
            logger:debug(i, 'key:', key)

            action_result_key = utils.read_string_CA(array_elem_data_ptr, 0x08)
            logger:debug(i, 'action_result_key:', action_result_key)

            value = mr.read_float(array_elem_data_ptr, 0x1C)
            logger:debug(i, 'value:', value)


            ------------------------------------ Effect & EffectScope ------------------------------------


            sub_structure_ptr = mr.read_pointer(array_elem_data_ptr, 0x20)
            logger:debug('address of', i, 'record Effect sub-struct:', lazy(mr.tostring, sub_structure_ptr))
            
            if mr.eq(sub_structure_ptr, utils.null_address) then
                effect_record = nil
            else
                effect_record = utils.read_string_CA(sub_structure_ptr, 0x08) 
            end
            logger:debug(i, 'effect_record:', tostring(effect_record))


            sub_structure_ptr = mr.read_pointer(array_elem_data_ptr, 0x28)
            logger:debug('address of', i, 'record EffectScope sub-struct:', lazy(mr.tostring, sub_structure_ptr))
            
            if mr.eq(sub_structure_ptr, utils.null_address) then
                effect_scope_record = nil
            else
                effect_scope_record = utils.read_string_CA(sub_structure_ptr, 0x08)
            end
            logger:debug(i, 'effect_scope_record:', tostring(effect_scope_record))

            one_exist_but_not_another = xor(effect_record, effect_scope_record)
            if one_exist_but_not_another then
                logger:error('invalid record?: "effect" or "scope_effect" is missing (but another one is present)! key =', key)
            end

            ------------------------------------ Outcome ------------------------------------


            outcome_raw_value = mr.read_uint32(array_elem_data_ptr, 0x18)
            logger:debug(i, 'outcome (raw):', outcome_raw_value)
            outcome_enum_member = KNOWN_OUTCOMES_ENUM[outcome_raw_value]

            if outcome_enum_member == nil then 
                logger:error('Uknown "outcome" raw key found:', outcome_raw_value, 'in record #', i, ', with key:', key, '; Skip this record!')
            else
                logger:debug(i, 'outcome (enum):', outcome_enum_member)

            --================================== End Parsing ==================================--

                id = id + 1

                table.insert(outcome_index[outcome_enum_member], id)
                table.insert(action_result_key_index[action_result_key], id)

                rows[id] = {
                    key,
                    action_result_key,
                    outcome_enum_member,
                    value,
                    effect_record,
                    effect_scope_record,
                    -- fixme,
                    -- opportune_failure_weighting,
                    -- affects_target,
                    -- advancement_stage,
                }

            end

            ptr = mr.add(ptr, next_array_element_shift)  -- next array element address
        end
        logger:remove_indent()

        return {
            rows=rows,
            indexes=indexes,
        }
    end
}
