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


---```lua
---XOR (^)
---xor(true, true) = false
---xor(true, false) = true
---xor(false, true) = true
---xor(false, false) = false
---```
---@param value1 any
---@param value2 any
---@return boolean
function functools.xor(value1, value2)
    return (value1 or value2) and not (value1 and value2)
end


--==================================================================================================================================--
--                                                   Public namespace initialization
--==================================================================================================================================--


return functools