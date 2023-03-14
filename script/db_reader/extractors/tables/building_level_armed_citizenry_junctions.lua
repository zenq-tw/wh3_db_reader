local mr = assert(_G.memreader)

local T = assert(core:load_global_script('script.db_reader.types'))  ---@module "script.db_reader.types"
local utils = assert(core:load_global_script('script.db_reader.utils'))  ---@module "script.db_reader.utils"


---@type ExtractorInfo
return {
    table_name='building_level_armed_citizenry_junctions',
    columns={'id', 'building_level', 'unit_group'},
    key_column_id=1,

    ---@type TableDataExtractor
    extractor=function(ptr, logger)
        logger:debug('table meta address is:', mr.tostring(ptr))
    
        local guard_value = 10000
        local rows_count = mr.read_int32(ptr, T.uint32(0x08))
    
        if rows_count > guard_value then
            logger:error('probably invalid base pointer or invalid array size value in structure ( >', guard_value, '):', rows_count)
            return
        end
    
        local array_ptr = mr.read_pointer(ptr, T.uint32(0x10))
        local node_ptr = mr.read_pointer(ptr, T.uint32(0x30))  -- address of records linked list tail 
        logger:debug('list tail (addr):', mr.tostring(node_ptr), 'array (addr):', mr.tostring(array_ptr))
    
        local rows = {}
        local indexes = {
            ['building_level']={},
            ['unit_group']={},
        }
    
        logger:add_indent()
        local record_pos, record_ptr
        local id
        local building_lvl_ptr, building_lvl
        local group_ptr, group_key

        while not mr.eq(node_ptr, utils.null_ptr) do
            logger:debug('node ptr:', mr.tostring(node_ptr))

            id = utils.read_string_CA(node_ptr, 0x10)
            logger:debug('id:', id)
            
            record_pos = mr.read_uint32(node_ptr, T.uint32(0x20))
            logger:debug('record_pos:', record_pos)
            record_ptr = mr.read_pointer(array_ptr, T.uint32(0x08 * record_pos))
            logger:debug('record_ptr:', mr.tostring(record_ptr))

            building_lvl_ptr = mr.read_pointer(record_ptr, T.uint32(0x08))
            logger:debug('building_lvl_ptr:', mr.tostring(building_lvl_ptr))
            building_lvl = utils.read_string_CA(building_lvl_ptr, 0x08, true)
            logger:debug('building_lvl:', building_lvl)

            group_ptr = mr.read_pointer(record_ptr, T.uint32(0x10))  -- armed_citizen_group instance address
            logger:debug('group_ptr:', mr.tostring(group_ptr))
            group_key = utils.read_string_CA(group_ptr, 0x08)
            logger:debug('group_key:', group_key)

            utils.include_key_in_index(indexes['building_level'], building_lvl, id)
            utils.include_key_in_index(indexes['unit_group'], group_key, id)

            table.insert(rows, {id, building_lvl, group_key})
            logger:debug('id:', id, 'building_lvl:', building_lvl, 'unit_group:', group_key)

            node_ptr = mr.read_pointer(node_ptr)  -- getting node->prev pointer
        end
        logger:remove_indent()

        return {
            rows=rows,
            indexes=indexes,
        }
    end
}