# DBReader - TW:Warhammer3 utility

1. [Introduction](#introduction)
2. [Status](#status)
    * [List of supported tables](#supported-tables)
3. [Usage](#usage)
4. [API](#api)
5. [Future Plans](#future-plans)
6. [Contribute](#contribute)
7. [Credits](#credits)



## Introduction

### What is it?
Lua mod for in-game database access at runtime.

### Why?
CA gives modders only partial access to in-game data. This utility is designed to decrease the gap between what the game knows and what modders have access to, at least in terms of game database.

For one of my mods, I needed real-time data from some tables for which there is no interface provided by the developers. Usually in such situations, tables are simply extracted using RPFM and then used as is. However, I did not want the mod to work only with the vanilla game, or produce a bunch of submods for all occasions. This is how the idea of the DBReader utility was born.

When I made the basic functionality, implemented the extraction of the tables I needed and successfully applied it to my mods that are not yet released on Steam, I thought that such a utility could be useful to the modding community and maybe someone would like to join to its maintenance and / or its development

### How it works?

The game itself does not use DB files at runtime. Instead, it parses the game's base tables, merges them with tables from mods, and then uses this data to create internal objects that it then works with. Interestingly, at the same time, it builds something like an array of meta-headers of the tables themselves, saves some initial data there and adds some links to in-game objects that used the data of these tables to build them.

DBReader as early as possible in the game loading process builds a registry of available tables and after that, according to the list of table requests, it tries to restore the merged tables from these "meta-headers" and in-game objects using the [`memreader`](https://github.com/Cpecific/twwh2-memreader) (kindly provided by CPecific). The table data is returned as a lua table with records count and sometimes with indexes built on them for ease of use.

**The obvious disadvantage of this approach is that potentially with each update I will have to edit the extractors code and / or the way to get the base address of the database. This will take time. So keep this in mind if you plan to use DBReader in your mods.**


## Status

DBReader is currently in beta. It just works and I was able to use it in my mods, but bugs are still possible.

I would appreciate any feedback and bug reports.

### Supported DB tables <a name="supported-tables"></a>:
> This list will be updated as support for new tables is added.
* armed_citizenry_unit_groups
* armed_citizenry_units_to_unit_groups_junctions


## Usage

The utility triggers the following events which you must listen for in order to use DBReader:
* `DBReaderCreated` - notifies that DBReader is ready to register requests for tables and custom extractors.
* `DBReaderInitialized` - notifies that the requested tables have been restored from the game memory and now they can be obtained by third-party mods. However, if there were errors during the construction of the table, the data may not be available.

Example:
```lua
local table_data = {  -- assume you have the contents of a table from a vanilla game here
    ...
}


--- ... main code of your mod is here ...


local table_name = 'armed_citizenry_units_to_unit_groups_junctions'

core:add_listener(
    'MyModDBTableRequest',
    'DBReaderCreated',
    true,
    ---@param context DBReaderCustomContext
    function (context)
        local db = context:get_db_reader()
        local is_requested = db:request_table(table_name)
        
        if not is_requested then
            out('failed to request in-game db table data: ' .. table_name)
        end
    end,
    false  -- this event only happens once so we can safely remove our listener
)


core:add_listener(
    'MyModGetDBTableData',
    'DBReaderInitialized',
    ---@param context DBReaderCustomContext
    function (context)
        local db = context:get_db_reader()
        return db:is_table_loaded(table_name)
    end,
    ---@param context DBReaderCustomContext
    function (context)
        local db = context.get_db_reader()
        local db_table = assert(db:get_table(table_name))

        table_data = db_table.records
        out('table data extracted: ' .. table_name .. ' (' .. table.count .. ' records)')

        -- also db_table has `indexes` field that you might be interested in:
        -- db_table.indexes : nil | { Column: { Value: TableKey[] } }

        -- ... anything else you want to do with that data ...
    end,
    false  -- this event only happens once so we can safely remove our listener
)
```

Registering your own table extractor (if you have one):

```lua
local function some_table_extractor(pointer) ... end


core:add_listener(
    'MyModRegisterDBTableExtractor',
    'DBReaderCreated',
    true,
    ---@param context DBReaderCustomContext
    function (context)
        local db = context:get_db_reader()
        local is_registered = db:register_table_extractor(
            'some_table_name',   -- name of the table for which extractor is being registered
            {'key_col', 'col1',  ..., 'colN'},   -- array of table columns
            1,   -- position of table key column in `columns` array
            some_table_extractor
        )
        
        if not is_requested then
            out('failed to register custom table extractor: no such table or extractor for it already exist')
        end
    end,
    false  -- this event only happens once so we can safely remove our listener
)
```

## API
### DBReader

#### `DBReader:request_table(table_name)`
Request table hook
* **parameters:**
    |pos| name   | type | description |
    |:--|:-------|:-----|:------------|
    |1|table_name|`string`|name of a table (without `_tables` postfix)|

* **returns:**
    |pos| name   | type | description |
    |:--|:-------|:-----|:------------|
    |1|is_requested|`boolean` | is required table exist in registry and table data extractor registered for it?|


#### `DBReader:is_table_loaded(table_name)`
Check if table data has been successfully restored from memory
* **parameters:**
    |pos| name   | type | description |
    |:--|:-------|:-----|:------------|
    |1|table_name|`string`|name of a table (without `_tables` postfix)|

* **returns:**
    |pos| name   | type | description |
    |:--|:-------|:-----|:------------|
    |1|is_loaded|`boolean` | is required table loaded?|


#### `DBReader:get_table(table_name)`
Get extracted database table data
* **parameters:**
    |pos| name   | type | description |
    |:--|:-------|:-----|:------------|
    |1|table_name|`string`|name of a table (without `_tables` postfix)|

* **returns:**
    |pos| name   | type | description |
    |:--|:-------|:-----|:------------|
    |1|table|[`DBTable`](#DBTable) or `nil` |table data or `nil`, if it was not loaded|


#### `DBReader:register_table_extractor(table_name, columns, key_column_id, extractor)`
Specific table data extractor registration method
* **parameters:**
    |pos| name   | type | description |
    |:--|:-------|:-----|:------------|
    |1|table_name|`string`|name of a table (without `_tables` postfix)|
    |2|columns|`string[]`|array of table columns|
    |3|key_column_id|`number`|table key column (position in `columns` array)|
    |4|extractor|[`TableDataExtractor`](#TableDataExtractor)|function that will extract table data|

* **returns:**
    |pos| name   | type | description |
    |:--|:-------|:-----|:------------|
    |1|is_registered|`boolean`|is extractor registered?|


### Types Definition

> 1\.  you can read `script/db_reader/types.lua` for a more complete list of defined types
>
> 2\. see [notes](#notes) below this list if you have troubles reading the following definitions

#### `DBTable`
```
DBTable := {
    'count': integer
    'records': { [Key]: Record }
    'indexes': TableIndexes | nil
}
```
#### `Key`
```
Key := string | number
```
#### `Record`
```
Record := { [Column]: Field }
```
#### `Column`
```
Column := string
```
#### `Field`
```
Field := string | number | boolean
```
#### `TableIndexes`
```
TableIndexes := {
    [Column]: { [Field]: Key[] }
}
```
#### `TableDataExtractor`
```
TableDataExtractor := function (
    ptr: pointer,
    logger: LoggerCls
) -> TableData | nil
```
#### `TableData`
```
TableData := {
    'rows': Field[][],
    'indexes': TableIndexes | nil
}
```
---

#### __Notes__:
> More about used notations you can read [here](https://github.com/LuaLS/lua-language-server/wiki/Annotations)
1. `{'name': <type>}` - means table with key `name` existed with type: `<type>`
    * example: 
        ```lua
        ---@type {'name': number}
        print(type(a))           -- table
        print(type(a.name))      -- number
        print(type(a.other_key)) -- nil
        
        ```
2. `{ [<type1>]: <type2> }` - means table where keys are `<type1>` and values are  `<type2>`
    * example: 
        ```lua
        ---@type { [string]: number }
        print(type(a))          -- table
        for key, value in pairs(a) do
            print(type(key))    -- string
            print(type(value))  -- number
        end
        ```
3. `<type>[]` - means __indexed array__ of `<type>`
    * i.e. `table` with __key__ as `number` and __value__ as `<type>`
    * `table < number, <type> >`
    * example: `string[] := table<number, string>`
        * example: 
        ```lua
        ---@type string[]
        print(type(a))           -- table
        print(type(a[1]))        -- string or nil (if missed)
        print(type(a[2]))        -- string or nil (if missed)
        print(type(a.other_key)) -- nil
        
        ```



## Contribute
Read `CONTRIBUTING.md` at the root of the repository.

## Future Plans <a name="future-plans"></a>

0. support more tables :-)
1. improve contribution documents
    1. upload my ReClass.net project
    2. make it more people-friendly (verbose?))
2. add support of MCT
    1. DB tables export in common formats (tsv, csv)?
    2. View tables content in game?


## Credits
* __Cpecific__ - for `memreader`, all of his code examples and comments about it.
* __Vandy (Groove Wizard)__ - for the tutorials on the wiki and the many replies to people all over the discord modding channel.
* __Da Modding Den__ Discord channel - I spent hours reading the discussions on this channel and got a lot of the answers I needed. Thank you guys.
