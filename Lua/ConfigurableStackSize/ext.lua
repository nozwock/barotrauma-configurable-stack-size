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

---@generic T: table
---@param tab T
---@param _visited? table<table, table>
---@return T
function table.deepcopy(tab, _visited)
	_visited = _visited or {}

	-- If the table has already been copied, return the reference to the copied table
	if _visited[tab] then
		return _visited[tab]
	end

	local copy = {}

	-- Mark the current table as visited and store the reference to the new copy
	_visited[tab] = copy

	for k, v in pairs(tab) do
		if type(v) == "table" then
			copy[k] = table.deepcopy(v, _visited)
		else
			copy[k] = v
		end
	end

	return copy
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
