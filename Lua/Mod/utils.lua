---@class UtilsModule
local utils = {}

---@class Set
local Set = {
	---@type table<SetValue, true?>
	data = {},
}
local _SetMetaTable = {
	__index = Set,
}

---@alias SetValue string|number

---@param list? (string|number)[]
---@return Set
function Set.new(list)
	local set = {
		data = {},
	}
	setmetatable(set, _SetMetaTable)
	---@cast set Set

	if list then
		for _, v in pairs(list) do
			set:add(v)
		end
	end

	return set
end

---@param v SetValue
function Set:add(v)
	self.data[v] = true
end

---@param v SetValue
function Set:remove(v)
	for k, _ in pairs(self.data) do
		if k == v then
			self.data[k] = nil
			break
		end
	end
end

---@param v SetValue
---@return boolean
function Set:has(v)
	return self.data[v] == true
end

utils.Set = Set

return utils
