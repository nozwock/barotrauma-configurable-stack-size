local state = require("ConfigurableStackSize.state")
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

---@param s string
---@param list (string|number)[]
---@return boolean
function utils.findAny(s, list)
	for _, p in ipairs(list) do
		if string.find(s, p) ~= nil then
			return true
		end
	end
	return false
end

---@param iter fun():string|number
---@param pat string|number
---@return boolean
function utils.iterFind(iter, pat)
	for it in iter do
		if string.find(it, pat) ~= nil then
			return true
		end
	end
	return false
end

---@param iter fun():string|number
---@param list (string|number)[]
---@return boolean
function utils.iterFindAny(iter, list)
	for _, p in ipairs(list) do
		if utils.iterFind(iter, p) then
			return true
		end
	end
	return false
end

---@generic T
---@param iter fun():T
---@param val T
---@return boolean
function utils.iterContains(iter, val)
	for it in iter do
		if it == val then
			return true
		end
	end
	return false
end

---@generic T
---@param iter fun():T
---@param list T[]
---@return boolean
function utils.iterContainsAny(iter, list)
	for _, v in ipairs(list) do
		if utils.iterContains(iter, v) then
			return true
		end
	end
	return false
end

local logger = {
	---@type file*?
	sink = nil,
}

---@param filename string
---@param dir? string
function logger:openSink(filename, dir)
	if self.sink then
		self.sink:close()
		self.sink = nil
	end

	if not dir then
		dir = state.modPath
	end

	local file, errmsg = io.open(dir .. "/" .. filename, "w")
	if errmsg then
		self:warn(errmsg)
	end

	self.sink = file
	if self.sink then
		self.sink:setvbuf("line")
	end

	-- Assuming that file* will be closed by itself when lua ends
end

function logger:flush()
	if self.sink then
		self.sink:flush()
	end
end

---@param msg string
---@param to_console? boolean
---@param console_log fun(msg: string)
---@param file_log fun(msg: string)
local function _log(msg, to_console, console_log, file_log)
	to_console = to_console == nil and true or to_console
	if to_console or not logger.sink then
		console_log(msg)
	else
		if not state.logging then
			return
		end

		file_log(msg)
	end
end

---@param msg string
local function _logToFile(msg)
	if logger.sink then
		logger.sink:write(string.gsub(msg, "%s$", "") .. "\n")
	end
end

---@param msg string
---@param to_console? boolean
local function _getLogMsg(msg, to_console)
	to_console = to_console == nil and true or to_console
	return to_console and string.format("[%s] %s", state.modName, msg) or msg
end

---@param msg string
---@param to_console? boolean
function logger:log(msg, to_console)
	_log(_getLogMsg(msg, to_console), to_console, function(msg_)
		state.static.DebugConsole.Log(msg_)
	end, _logToFile)
end

---@param msg string
---@param to_console? boolean
function logger:warn(msg, to_console)
	_log(_getLogMsg(msg, to_console), to_console, function(msg_)
		state.static.DebugConsole.LogError(msg_, Color.Yellow --[[@as any]])
	end, _logToFile)
end

---@param msg string
---@param to_console? boolean
function logger:error(msg, to_console)
	_log(_getLogMsg(msg, to_console), to_console, function(msg_)
		state.static.DebugConsole.LogError(msg_)
	end, _logToFile)
end

utils.Set = Set
utils.logger = logger

return utils
