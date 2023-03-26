local validators = {}


---@param columns string[]
---@param key_column_id number
---@param nullable_column_ids integer[] | nil
---@param logger LoggerCls
---@return boolean is_valid
function validators.validate_columns(columns, key_column_id, nullable_column_ids, logger)
    if columns == nil then
        logger:error('invalid argument - columns: missing')
        return false
    end

    if not is_table(columns) then
        logger:error('invalid argument - columns: must be string array (Table<number, string>), but not', type(columns))
        return false
    end

    for i, column in pairs(columns) do
        if not is_number(i) then
            logger:error('invalid columns table structure - lua-table key type must be number, but not', type(i))
            logger:info('must be string array (Table<number, string>)')
            return false
        end

        if not is_string(column) then
            logger:error('invalid columns table structure - lua-table value type must be string, but not', type(column))
            logger:info('must be string array (Table<number, string>)')
            return false
        end
    end

    local columns_count = #columns
    if columns_count == 0 then
        logger:error('invalid argument - columns: zero-length')
        return false
    end

    if not is_number(key_column_id) or key_column_id <= 0 then
        logger:error('invalid argument - key_column_id: must be positive number, less or equal then number of columns (', columns_count, '), but not', key_column_id, type(key_column_id))
        return false
    end

    if columns[key_column_id] == nil then
        logger:error('invalid argument - key_column_id: column not found with value', key_column_id)
        return false
    end

    if nullable_column_ids == nil then return true end


    if not is_table(nullable_column_ids) then
        logger:error('invalid argument - nullable_column_ids: must be integer array (Table<number, number>), but not', type(nullable_column_ids))
        return false
    end

    for i, column_id in pairs(nullable_column_ids) do
        if not is_number(i) then
            logger:error('invalid nullable_column_ids table structure - lua-table key type must be number, but not', type(i))
            logger:info('must be string array (Table<number, string>)')
            return false
        end

        if not is_number(column_id) then
            logger:error('invalid nullable_column_ids table structure - lua-table value type must be number, but not', type(column_id))
            logger:info('must be string array (Table<number, string>)')
            return false
        end

        if columns[column_id] == nil then
            logger:error('invalid argument - nullable_column_ids: column with such id not found in columns', column_id)
            return false
        end

        if column_id == key_column_id then
            logger:error('invalid argument - nullable_column_ids: key_column_id cannot be nil', column_id)
            return false
        end
    end

    if #nullable_column_ids >= columns_count then
        logger:error('invalid argument - nullable_column_ids: all columns count less then nullable columns ids count (', #nullable_column_ids, '>', columns_count, ')')
        return false
    end


    return true
end


---validate returned rows 
---@param table_meta DBTableMeta
---@param results RawTableData | nil
---@param logger LoggerCls
---@return boolean is_valid, integer? rows_count
function validators.check_builder_results(table_meta, results, logger)
    if results == nil then
        logger:error('builder didnt provide a results - something goes wrong?')
        return false
    end

    if not is_table(results) then
        logger:error('invalid result type:', type(results)):info('expected structure:  {columns: string[], rows: any[], key_column_id: number}' )
        return false    
    end

    local rows = results.rows

    if not is_table(rows) then
        logger:error('rows is not a table'):info('expected structure: Table<number, Table<number, string | number | boolean> >')
        return false
    end

    if #rows == 0 then
        logger:error('no rows (zero-length array)')
        return false
    end

    local columns_count = #table_meta.columns
    local row_pos = 0
    local type_

    for i, row in pairs(rows) do
        row_pos = row_pos + 1

        if not is_number(i) then
            logger:error('invalid row at', row_pos, ': lua-table key type must be number, not', type(i))
            logger:info('expected structure: Table<number, Table<number, string | number | boolean> >')
            return false
        end
        if not is_table(row) then
            logger:error('invalid row at', row_pos, ': invalid lua-table value type', type(row))
            logger:info('expected structure: Table<number, Table<number, string | number | boolean> >')
            return false
        end

        for field_pos=1, columns_count do
            type_ = type(row[field_pos])

            if type_ == "nil" then
                if not table_meta.nullable_columns_ids_lookup[field_pos] then
                    logger:error('invalid row at', row_pos, '- invalid field at', field_pos, ': nil value not allowed for column', table_meta.columns_lookup[field_pos])
                    return false
                end

            elseif not (
                type_ == 'string'
                or type_ == 'number'
                or type_ == 'boolean' 
            ) then
                logger:error('invalid row at', row_pos, '- invalid field at', field_pos, ': invalid lua-table value type', type_)
                logger:info('expected structure: Table<number, Table<number, string | number | boolean> >')
                return false
            end
        end

    end



    if results.indexes ~= nil then
        
        local index_pos = 0
        local table_keys_pos = 0
        
        for column, index in pairs(results.indexes) do
            index_pos = index_pos + 1

            type_ = type(column)
            if not (type_ == 'string' or type_ == 'number' or type_ == 'boolean') then
                logger:error('invalid index at', index_pos, ': lua-table key type must be <string | number | boolean>, not', type_)
                return false
            end

            if not table_meta.columns_lookup[column] then
                logger:error('invalid index for', column, ': index key not a table column:', table.concat(table_meta.columns, ', '))
                for col, value in pairs(table_meta.columns_lookup) do
                    logger:debug('TEST lkp: col =', col, '; value =', value)
                end
                return false
            end

            if not is_table(index) then
                logger:error('invalid index for column', column, ': index type must be Table <string | number | boolean, Key[]>, not', type(index))
                return false
            end

            for index_key, table_keys in pairs(index) do
                type_ = type(index_key)
                if not (type_ == 'string' or type_ == 'number') then
                    logger:error('invalid index for', column, '- invalid index key: lua-table key type must be <string | number>, not', type_)
                    return false
                end

                if not is_table(table_keys) then
                    logger:error('invalid index for column', column, 'with value', index_key, '- invalid table keys mapping type: must be Indexed Table (Key[]), not', type_)
                    return false
                end

                table_keys_pos = 0
                for i, table_key in pairs(table_keys) do
                    table_keys_pos = table_keys_pos + 1
                    
                    if not is_number(i) then
                        logger:error('invalid index for column', column, 'with value', index_key, '- table keys mapping at ', table_keys_pos, ': lua-table key type must be number, not', type(i))
                        logger:info('expected structure: Indexed Table (Key[])')
                        return false
                    end

                    type_ = type(table_key)
                    if not (type_ == 'string' or type_ == 'number' or type_ == 'boolean') then
                        logger:error('invalid index for column', column, 'with value', index_key, ': lua-table value type must be <string | number | boolean>, not', type_)
                        return false
                    end
                end
            end

        end
    end

    return true, row_pos
end


---@param table_meta? DBTableMeta
---@param logger LoggerCls
---@return boolean
function validators.is_valid_table_meta(table_meta, logger)
    if table_meta == nil then
        logger:error('ERROR: table meta not found -> skip')
        return false
    end

    if table_meta.name == nil then
        logger:error('ERROR: invalid table meta: no name -> skip')
        return false
    end

    if table_meta.ptr == nil then
        logger:error('ERROR: invalid table meta: no pointer -> skip')
        return false
    end

    if table_meta.columns == nil then
        logger:error('ERROR: invalid table meta: no columns -> skip')
        return false
    end

    if table_meta.columns_lookup == nil then
        logger:error('ERROR: invalid table meta: no columns_lookup -> skip')
        return false
    end

    if table_meta.key_column == nil then
        logger:error('ERROR: invalid table meta: no key_column -> skip')
        return false
    end

    return true
end


---@param info? ExtractorInfo
---@param logger LoggerCls
---@return boolean
function validators.is_valid_extractor_info(info, logger)
    if info == nil then
        logger:error('ERROR: no extractor info returned -> skip')
        return false
    end

    if not is_table(info) then
        logger:error('ERROR: invalid extractor info returned: it is not a table -> skip')
        return false
    end

    if not is_string(info.table_name)  then
        logger:error('ERROR: invalid extractor info returned: no valid name -> skip')
        return false
    end

    if not is_table(info.columns) then
        logger:error('ERROR: invalid extractor info returned: columns is not a table -> skip')
        return false
    end

    if not is_number(info.key_column_id) then
        logger:error('ERROR: invalid extractor info returned: no valid key_column_id -> skip')
        return false
    end

    if not is_function(info.extractor) then
        logger:error('ERROR: invalid extractor info returned: no valid extractor function -> skip')
        return false
    end

    if info.nullable_column_ids ~= nil and not is_table(info.nullable_column_ids) then
        logger:error('ERROR: invalid extractor info returned: nullable_column_ids is not a nil, but also it is not a table -> skip')
        return false
    end

    return true
end


return validators
