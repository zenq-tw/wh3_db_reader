--==================================================================================================================================--
--                                                          defaultdict
--==================================================================================================================================--


---@generic T
---@alias TFactory<T> fun(key: any): T

---@type {table: TFactory<table>, string: TFactory<string>, number: TFactory<number>}
local type_factories = {
    table = (function (key) return {} end),
    string = (function (key) return '' end),
    number = (function (key) return 0 end),
}

---@generic K, V
---@alias defaultdict<K, V>  {[K]: V}

---@generic K, V
---@param default_value_factory TFactory<V>
---@return defaultdict<K, V>
local function defaultdict(default_value_factory)
    if type(default_value_factory) ~= 'function' then
        if type(default_value_factory) == 'string' and type_factories[default_value_factory] ~= nil then
            default_value_factory = type_factories[default_value_factory]
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
--                                                   Public namespace initialization
--==================================================================================================================================--



return {
    defaultdict=defaultdict,
    factories=type_factories,
}
