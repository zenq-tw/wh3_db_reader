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

