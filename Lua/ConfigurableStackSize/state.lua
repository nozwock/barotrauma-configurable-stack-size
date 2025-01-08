local state = {
	modName = "ConfigurableStackSize",
	logging = false,
	configDir = Game.SaveFolder .. "/ModConfigs",
}

File.CreateDirectory(state.configDir)

return state
