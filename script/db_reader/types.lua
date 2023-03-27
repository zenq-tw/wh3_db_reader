---@diagnostic disable: return-type-mismatch



---@alias Column string
---@alias Key string|number
---@alias Field Key|boolean

---@alias TIndex<T> {[T]: nil | {count: integer, array: T[]}}

---@alias RawTableIndexes {[Column]: table <Field, Key[]>}
---@alias RawTableData {rows: Field[][], indexes: RawTableIndexes | nil}
---@alias TableDataExtractor fun(ptr: pointer, logger: LoggerCls): RawTableData | nil

---@class ExtractorInfo
---@field table_name string name of table for which extractor is registered
---@field columns string[] array of table columns
---@field key_column_id number table key column (position in `columns` array)
---@field nullable_column_ids integer[] | nil table columns whose values can be <nil> (positions in `columns` array)
---@field extractor TableDataExtractor function that will extract table data

---@alias Record {[Column]: Field}

---@alias TableKeys { count: integer, array: Key[] }
---@alias TableIndexes { [Column]: { [Field]: TableKeys } }

---@class DBTable
---@field count integer
---@field records table <Key, Record>
---@field indexes TableIndexes | nil


---@class DBTableMeta
---@field name string
---@field idx integer relative position inside DB space 
---@field ptr pointer pointer to DB Table object itself
---@field columns Column[]
---@field columns_lookup {Column: true}
---@field nullable_columns_ids_lookup {integer: true}
---@field key_column Column


---@class DBRegistryData
---@field count integer
---@field tables {[string]: DBTableMeta}


---@class DBTableDumpedMeta
---@field name string
---@field idx integer
---@field ptr_hex string  -- [difference here] because raw pointers dumped as userdata objs with tostring() in cache file
---@field columns Column[]
---@field key_column Column


---@class DBRegistryDumpedData
---@field count integer
---@field tables {[string]: DBTableDumpedMeta}


---@class DBData
---@field count integer
---@field tables {[string]: DBTable | nil} table data


---@class DBReaderData
---@field requested_tables string[]
---@field loaded_tables DBData


---@class DBReaderCustomContext
---@field get_db_reader fun(): DBReader


---cast to uint32
---@param value integer
---@return uint32
local function to_uint32(value) return value end


---cast to pointer
---@param value any
---@return pointer
local function to_pointer(value) return value end 


return {
    uint32=to_uint32,
    ptr=to_pointer,
}



--[[
==================================================================================================================================
                                Type definition for retrieved tables (can be used in client code)
==================================================================================================================================
--]]


--------------------------------------------- action_results_additional_outcomes --------------------------------------------------

---@alias Record__action_results_additional_outcomes {key: string, action_result_key: string, outcome: string, value: number, effect_record: string | nil, effect_scope_record: string | nil}

---@class DBTable__action_results_additional_outcomes: DBTable
---@field records table <string, Record__action_results_additional_outcomes>
---@field indexes {outcome: TIndex<string>, action_result_key: TIndex<string>}


------------------------------------------------------ agent_actions --------------------------------------------------------------

---@alias Record__agent_actions {unique_id: string, ability: string, agent: string, critical_failure: string, failure: string, opportune_failure: string, success: string, critical_success: string, cannot_fail: string, critical_failure_proportion_modifier: number, opportune_failure_proportion_modifier: number, critical_success_proportion_modifier: number, chance_of_success: integer, icon_path: string}

---@class DBTable__agent_actions: DBTable
---@field records table <string, Record__agent_actions>
---@field indexes nil


------------------------------------------------- armed_citizenry_unit_groups -----------------------------------------------------

---@alias Record__armed_citizenry_unit_groups {unit_group: string}

---@class DBTable__armed_citizenry_unit_groups: DBTable
---@field records table <string, Record__armed_citizenry_unit_groups>
---@field indexes nil


----------------------------------------- armed_citizenry_units_to_unit_groups_junctions -------------------------------------------

---@alias Record__armed_citizenry_units_to_unit_groups_junctions {id: string, priority: integer, unit: string, unit_group: string}

---@class DBTable__armed_citizenry_units_to_unit_groups_junctions: DBTable
---@field records table <string, Record__armed_citizenry_units_to_unit_groups_junctions>
---@field indexes {unit: TIndex<string>, unit_group: TIndex<string>}


-------------------------------------------- building_level_armed_citizenry_junctions ----------------------------------------------

---@alias Record__building_level_armed_citizenry_junctions {id: string, building_level: string, unit_group: string}

---@class DBTable__building_level_armed_citizenry_junctions: DBTable
---@field records table <string, Record__building_level_armed_citizenry_junctions>
---@field indexes {building_level: TIndex<string>, unit_group: TIndex<string>}