local mr = assert(_G.memreader)

local T = assert(core:load_global_script('script.db_reader.types'))  ---@module "script.db_reader.types"
local collections = assert(core:load_global_script('script.db_reader.collections'))  ---@module "script.db_reader.collections"
local utils = assert(core:load_global_script('script.db_reader.utils'))  ---@module "script.db_reader.utils"


---@alias TIndex__armed_citizenry_units_to_unit_groups_junctions {[string]: nil | {count: integer, array: string[]}}
---@alias Record__armed_citizenry_units_to_unit_groups_junctions {id: string, priority: integer, unit: string, unit_group: string}
---@alias Indexes__armed_citizenry_units_to_unit_groups_junctions {unit: TIndex__armed_citizenry_units_to_unit_groups_junctions, unit_group: TIndex__armed_citizenry_units_to_unit_groups_junctions}

---@class DBTable__armed_citizenry_units_to_unit_groups_junctions: DBTable
---@field records table <string, Record__armed_citizenry_units_to_unit_groups_junctions>
---@field indexes Indexes__armed_citizenry_units_to_unit_groups_junctions


---@type ExtractorInfo
return {
    table_name='armed_citizenry_units_to_unit_groups_junctions',
    columns={'id', 'priority', 'unit', 'unit_group'},
    key_column_id=1,

    ---@type TableDataExtractor
    extractor=function(ptr, logger)
        logger:debug('table meta address is:', mr.tostring(ptr))
    
        local guard_value = 5000
        local rows_count = mr.read_int32(ptr, T.uint32(0x08))
    
        if rows_count > guard_value then
            logger:error('probably invalid base pointer or invalid array size value in structure ( >', guard_value, '):', rows_count)
            return
        end
    
        local node_ptr = mr.read_pointer(ptr, T.uint32(0x30))  -- address of records linked list tail 
        local array_ptr = mr.read_pointer(ptr, T.uint32(0x10))
        logger:debug('list tail (addr):', mr.tostring(node_ptr), 'array (addr):', mr.tostring(array_ptr))
    
        local unit_key, group_key, priority
        local rows = {}

        local indexes = {}  ---@type Indexes__armed_citizenry_units_to_unit_groups_junctions
        local unit_index = collections.defaultdict(collections.factories.table)   ---@type defaultdict<string, Key[]>
        local group_index = collections.defaultdict(collections.factories.table)  ---@type defaultdict<string, Key[]>

        indexes.unit = unit_index
        indexes.unit_group = group_index
    
        logger:add_indent()
        local record_pos, id, record_ptr, unit_ptr, group_ptr

        while not mr.eq(node_ptr, utils.null_address) do
            logger:debug('node ptr:', mr.tostring(node_ptr))

            id = utils.read_string_CA(node_ptr, 0x10)
            logger:debug('id:', id)
            
            record_pos = mr.read_uint32(node_ptr, T.uint32(0x20))
            logger:debug('record_pos:', record_pos)
            record_ptr = mr.read_pointer(array_ptr, T.uint32(0x08 * record_pos))
            logger:debug('record_ptr:', mr.tostring(record_ptr))

            priority = mr.read_int32(record_ptr, T.uint32(0x18))
            logger:debug('priority:', priority)

            unit_ptr = mr.read_pointer(record_ptr, T.uint32(0x08))
            logger:debug('unit_ptr:', mr.tostring(unit_ptr))
            unit_key = utils.read_string_CA(unit_ptr, 0x0378)
            logger:debug('unit_key:', unit_key)

            group_ptr = mr.read_pointer(record_ptr, T.uint32(0x10))  -- armed_citizen_group instance address
            logger:debug('group_ptr:', mr.tostring(group_ptr))
            group_key = utils.read_string_CA(group_ptr, 0x08)
            logger:debug('group_key:', group_key)

            table.insert(unit_index[unit_key], id)
            table.insert(group_index[group_key], id)
            
            table.insert(rows, {id, priority, unit_key, group_key})
            logger:debug('id:', id, 'priority:', priority, 'unit:', unit_key, 'unit_group:', group_key)

            node_ptr = mr.read_pointer(node_ptr)  -- getting node->prev pointer
        end
        logger:remove_indent()

        return {
            rows=rows,
            indexes=indexes,
        }
    end
}
