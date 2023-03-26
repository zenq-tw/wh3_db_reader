--==================================================================================================================================--
--                                                          table extensions
--==================================================================================================================================--



if not table.unpack then
    table.unpack = unpack
end


function table.lookup_to_indexed(lookup_table)
    local indexed = {}

    local i = 1
    for key, _ in pairs(lookup_table) do
        indexed[i] = key
        i = i + 1
    end

    return indexed
end


--TODO: rewrite with memreader!
--Author: Vandy (Groove Wizard)
function table.deepcopy(tbl)
	local ret = {}
	for k, v in pairs(tbl) do
		ret[k] = type(v) == 'table' and table.deepcopy(v) or v
	end
	return ret
end

