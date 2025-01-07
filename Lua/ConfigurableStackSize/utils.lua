local utils = {}

local modPath = ...

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

do
	-- LuaUserData.MakeMethodAccessible(Descriptors["System.IO.File"], "Create")
	LuaUserData.RegisterType("System.IO.FileStream")
	LuaUserData.RegisterType("System.IO.BufferedStream")
	LuaUserData.RegisterType("System.IO.StreamWriter")
	local BufferedStream = LuaUserData.CreateStatic("System.IO.BufferedStream")
	local StreamWriter = LuaUserData.CreateStatic("System.IO.StreamWriter")

	---@type table<string, StreamWriter>
	local openedStreams = {}

	---@class System.IO.StreamWriter
	---@field WriteLine fun(_:string)
	---@field Write fun(_:string)
	---@field Flush fun()
	---@field Close fun()

	---@param filename string
	---@return StreamWriter
	function utils.getPersistentFileStream(filename)
		if openedStreams[filename] then
			return openedStreams[filename]
		end

		-- todo: Create or something instead of OpenWrite
		local fileStream = File.OpenWrite(modPath .. "/" .. filename)
		local streamWriter = StreamWriter(BufferedStream(fileStream))

		---@class StreamWriter
		---@field WriteLine fun(_:string)
		---@field Write fun(_:string)
		---@field Flush fun()
		local streamWriterWrapper = {
			_filename = filename,
			---@type System.IO.StreamWriter
			_stream = streamWriter,
		}

		function streamWriterWrapper.Close()
			openedStreams[streamWriterWrapper._filename] = nil
			streamWriterWrapper._stream.Close()
		end
		function streamWriterWrapper.Dispose()
			streamWriterWrapper.Close()
		end

		setmetatable(streamWriterWrapper, { __index = streamWriter })

		openedStreams[filename] = streamWriterWrapper

		return streamWriterWrapper
	end

	Hook.Add("stop", function()
		for _, stream in pairs(openedStreams) do
			stream.Close()
		end
	end)
end

utils.Set = Set

return utils
