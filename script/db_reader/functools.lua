local functools = {}



---Lazy execution
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



--==================================================================================================================================--
--                                                   Public namespace initialization
--==================================================================================================================================--


return functools