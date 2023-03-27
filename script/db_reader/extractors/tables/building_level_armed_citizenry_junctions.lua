local mr = assert(_G.memreader)

local T = assert(core:load_global_script('script.db_reader.types'))  ---@module "script.db_reader.types"
local func = assert(core:load_global_script('script.db_reader.functools'))  ---@module "script.db_reader.functools"
local collections = assert(core:load_global_script('script.db_reader.collections'))  ---@module "script.db_reader.collections"
local utils = assert(core:load_global_script('script.db_reader.utils'))  ---@module "script.db_reader.utils"



---@alias Record__building_level_armed_citizenry_junctions {id: string, building_level: string, unit_group: string}

---@class DBTable__building_level_armed_citizenry_junctions: DBTable
---@field records table <string, Record__building_level_armed_citizenry_junctions>
---@field indexes {building_level: TIndex<string>, unit_group: TIndex<string>}


---@type ExtractorInfo
return {
    table_name='building_level_armed_citizenry_junctions',
    columns={'id', 'building_level', 'unit_group'},
    key_column_id=1,

    ---@type TableDataExtractor
    extractor=function(ptr, logger)
        logger:debug('table meta address is:', func.lazy(mr.tostring, ptr))
    
        local guard_value = 10000
        local rows_count = mr.read_int32(ptr, T.uint32(0x08))
    
        if rows_count > guard_value then
            logger:error('probably invalid base pointer or invalid array size value in structure ( >', guard_value, '):', rows_count)
            return
        end
    
        local array_ptr = mr.read_pointer(ptr, T.uint32(0x10))
        local node_ptr = mr.read_pointer(ptr, T.uint32(0x30))  -- address of records linked list tail 
        logger:debug('list tail (addr):', func.lazy(mr.tostring, node_ptr), 'array (addr):', func.lazy(mr.tostring, array_ptr))
    
        local rows = {}

        local indexes = {}  ---@type {building_level: TIndex<string>, unit_group: TIndex<string>}
        local building_level_index = collections.defaultdict(collections.factories.table)   ---@type defaultdict<string, Key[]>
        local unit_group_index = collections.defaultdict(collections.factories.table)  ---@type defaultdict<string, Key[]>
    
        indexes.building_level = building_level_index
        indexes.unit_group = unit_group_index

        logger:add_indent()

        local record_pos, record_ptr
        local id
        local building_lvl_ptr, building_lvl
        local group_ptr, group_key

        while not mr.eq(node_ptr, utils.null_address) do
            logger:debug('node ptr:', func.lazy(mr.tostring, node_ptr))

            id = utils.read_string_CA(node_ptr, 0x10)
            logger:debug('id:', id)
            
            record_pos = mr.read_uint32(node_ptr, T.uint32(0x20))
            logger:debug('record_pos:', record_pos)
            record_ptr = mr.read_pointer(array_ptr, T.uint32(0x08 * record_pos))
            logger:debug('record_ptr:', func.lazy(mr.tostring, record_ptr))

            building_lvl_ptr = mr.read_pointer(record_ptr, T.uint32(0x08))
            logger:debug('building_lvl_ptr:', func.lazy(mr.tostring, building_lvl_ptr))
            building_lvl = utils.read_string_CA(building_lvl_ptr, 0x08, true)
            logger:debug('building_lvl:', building_lvl)

            group_ptr = mr.read_pointer(record_ptr, T.uint32(0x10))  -- armed_citizen_group instance address
            logger:debug('group_ptr:', func.lazy(mr.tostring, group_ptr))
            group_key = utils.read_string_CA(group_ptr, 0x08)
            logger:debug('group_key:', group_key)

            table.insert(building_level_index[building_lvl], id)
            table.insert(unit_group_index[group_key], id)

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
