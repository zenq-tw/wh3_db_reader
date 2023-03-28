local mr = assert(_G.memreader)

local T = assert(core:load_global_script('script.db_reader.types'))  ---@module "script.db_reader.types"
local func = assert(core:load_global_script('script.db_reader.functools'))  ---@module "script.db_reader.functools"
local utils = assert(core:load_global_script('script.db_reader.utils'))  ---@module "script.db_reader.utils"



---@type ExtractorInfo
return {
    table_name='armed_citizenry_unit_groups',
    columns={'unit_group'},
    key_column_id=1,

    ---@type TableDataExtractor
    extractor=function(ptr, logger)
        logger:debug('table meta address is:', func.lazy(mr.tostring, ptr))

        local guard_value = 5000
        local rows_count = mr.read_int32(ptr, T.uint32(0x08))
        
        if rows_count > 5000 then
            logger:error('probably invalid base pointer or invalid array size value in structure ( >', guard_value, '):', rows_count)
            return
        end

        ptr = mr.read_pointer(ptr, T.uint32(0x10))
        logger:debug('address of fst array elem:', func.lazy(mr.tostring, ptr))

        local array_elem_data_ptr, value
        local rows = {}
        local next_array_element_shift = T.uint32(0x08)

        logger:add_indent()
        for id=1, rows_count do
            logger:debug('address of', id, 'array elem (== ptr to record struct):', func.lazy(mr.tostring, ptr))

            array_elem_data_ptr = mr.read_pointer(ptr)
            logger:debug('address of', id, 'record struct:', func.lazy(mr.tostring, array_elem_data_ptr))

            value = utils.read_string_CA(array_elem_data_ptr, 0x08)
            logger:debug(id, 'value:', value)

            rows[id] = {value}

            ptr = mr.add(ptr, next_array_element_shift)  -- next array element address
        end
        logger:remove_indent()
        
        return {
            rows=rows,
        }
    end
}
