local functools = {}



---Lazy execution of supplied function
---@generic OriginRetVal
---@param func fun(...): OriginRetVal
---@param ... any
---@return fun(): OriginRetVal
function functools.lazy(func, ...) 
    local args = {...}
    return function ()
        return func(table.unpack(args))
    end
end



--TODO: rewrite better when LuaServer will support generic varargs in return:
--```lua
-- @param func fun(...): ...<T>
-- @return ...<T> returned_data
--```

---Safe execution of supplied function (all errors will be catched and returned as state and msg)
---@param func fun(...)
---@param ... any
---@return boolean is_success, string? err_msg, any[]? returned_data
function functools.safe(func, ...) 
    local results = table.pack(pcall(func, ...))

    if results[1] == false then
        return false, results[2], nil
    end

    results.n = nil
    table.remove(results, 1)

    return true, nil, results
end



--==================================================================================================================================--
--                                                   Public namespace initialization
--==================================================================================================================================--


return functools