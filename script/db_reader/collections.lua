local collections = {}

--==================================================================================================================================--
--                                                          defaultdict
--==================================================================================================================================--


---@generic T
---@alias TFactory<T> fun(key: any): T

---@type {table: TFactory<table>, string: TFactory<string>, number: TFactory<number>}
collections.type_factories = {
    table = (function (key) return {} end),
    string = (function (key) return '' end),
    number = (function (key) return 0 end),
}

---@generic K, V
---@alias defaultdict<K, V>  {[K]: V}

---@generic K, V
---@param default_value_factory TFactory<V>
---@return defaultdict<K, V>
function collections.defaultdict(default_value_factory)
    if type(default_value_factory) ~= 'function' then
        if type(default_value_factory) == 'string' and collections.type_factories[default_value_factory] ~= nil then
            default_value_factory = collections.type_factories[default_value_factory]
        else
            error('invalid default value factory')
        end
    end

    local t = {}
    local metatable = {}
    metatable.__index = function(table, key)
        rawset(table, key, default_value_factory(key))
        return rawget(table, key)
    end
    return setmetatable(t, metatable)
end


--==================================================================================================================================--
--                                                        NonOverwritableDict
--==================================================================================================================================--


---@alias TNonRewritableDict<K, V> {[K]: V}

---### will raise error on key overwriting
---@param dict_id_hint? string string identifying the dictionary in the raised error message
---@param nil_values? boolean default is `false`
---@param allow_same_values_assignment? boolean default is `true`
---@return table
---to drop all current content perform call on instance: `dict_instance()`
collections.NonRewritableDict = function (dict_id_hint, nil_values, allow_same_values_assignment)
    if type(nil_values) ~= "boolean" then nil_values = false end
    if type(allow_same_values_assignment) ~= "boolean" then allow_same_values_assignment = true end

    local data = {}

    local get_value = function(t, k) return rawget(data, k) end
    local set_value = function(t, k, v) return rawset(data, k, v) end
    local is_valid_assignment = function (old_value, new_value) return old_value == nil end

    if nil_values then
        local converted_nil = '\0'
        local current_value
        get_value = function(t, k)
            current_value = rawget(data, k)
            if current_value == converted_nil then current_value = nil end
            return current_value
        end
        set_value = function(t, k, v)
            if v == nil then v = converted_nil end
            rawset(data, k, v)
        end

        if allow_same_values_assignment then
            is_valid_assignment = function (old_value, new_value)
                if old_value == nil then return true end
                if new_value == nil then return old_value == converted_nil end

                return old_value == new_value
            end    
        end    

    elseif allow_same_values_assignment then
        is_valid_assignment = function (old_value, new_value) return old_value == nil or old_value == new_value end
    end
    
    local const_err_msg_part
    if dict_id_hint == nil then
        const_err_msg_part = "attempting to overwrite dict key '"
    else
        const_err_msg_part = "attempting to overwrite " .. dict_id_hint .. " key '"
    end
    
    local form_error_msg = function (key, old_value, new_value)
        return const_err_msg_part .. key .. "' with new value = " .. tostring(new_value) .. ' (old = ' .. tostring(old_value) .. ')'
    end

    
    local meta ={
        __call=function () data = {} end,  -- clear dict content
        __index=get_value,
        __newindex=function (non_rewritable_dict, key, new_value)
            current_value = rawget(data, key)
            print(key, tostring(current_value), tostring(new_value))
            assert(
                is_valid_assignment(current_value, new_value),
                form_error_msg(key, non_rewritable_dict[key], new_value)
            )
            set_value(non_rewritable_dict, key, new_value)
        end,
    }

    return setmetatable({}, meta)
end


--==================================================================================================================================--
--                                                   Public namespace initialization
--==================================================================================================================================--



return collections
