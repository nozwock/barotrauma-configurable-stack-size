local state = {
	modName = "ConfigurableStackSize",
	---@type string
	modPath = ...,
	logging = false,
	configDir = Game.SaveFolder .. "/ModConfigs",
}
File.CreateDirectory(state.configDir)

state.static = {
	DebugConsole = LuaUserData.CreateStatic("Barotrauma.DebugConsole") --[[@as Barotrauma.DebugConsole]],
}

return state
