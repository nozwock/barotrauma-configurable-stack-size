---@generic T
---@param tab T: table
---@return T
function table.shallowcopy(tab)
	local new = {}
	for k, v in pairs(tab) do
		new[k] = v
	end
	return new
end
