---@generic T: table
---@param tab T
---@return T
function table.shallowcopy(tab)
	local new = {}
	for k, v in pairs(tab) do
		new[k] = v
	end
	return new
end

--- Iterator over table keys.
---@generic K, V
---@param t table<K, V>
---@return fun():K
function table.keys(t)
	local next_fn, state, index = pairs(t)
	return function()
		local k, _v = next_fn(state, index)
		index = k
		if k ~= nil then
			return k
		end
	end
end

--- Iterator over table values.
---@generic K, V
---@param t table<K, V>
---@return fun():V
function table.values(t)
	local next_fn, state, index = pairs(t)
	return function()
		local k, v = next_fn(state, index)
		index = k
		if v ~= nil then
			return v
		end
	end
end
