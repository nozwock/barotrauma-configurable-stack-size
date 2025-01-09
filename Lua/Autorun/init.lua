-- Make extensions available for all from here on.
require("ConfigurableStackSize.ext")
local state = require("ConfigurableStackSize.state") -- Shared state via require
local config = require("ConfigurableStackSize.config")
local patches = require("ConfigurableStackSize.patches")
local network = require("ConfigurableStackSize.network")
local utils = require("ConfigurableStackSize.utils")

local Config = config.Config

---@param cfg Config
local function runClientPatches(cfg)
	patches.runContainersPatch(cfg.data.containerOptions)
	patches.runItemPrefabsPatch(cfg)
end

local logFilename = state.modName .. ".log"

if Game.IsSingleplayer then
	local cfg = Config.tryLoadFromDiskOrDefault("singleplayer_config.json")

	state.logging = cfg.data.logging
	if state.logging then
		utils.logger:openSink(logFilename)
	end

	patches.runBypassMaxStackSizeLimit()
	runClientPatches(cfg)
elseif SERVER then
	local cfg = Config.tryLoadFromDiskOrDefault("multiplayer_config.json")

	state.logging = cfg.data.logging
	if state.logging then
		utils.logger:openSink(logFilename)
	end

	network.server.setSendConfigHandler(function()
		return cfg
	end)
	runClientPatches(cfg)
elseif CLIENT and Game.IsMultiplayer then
	-- Don't enable state.logging for mp client, code in patches will break
	network.client.setReceiveConfigHandler(function(serializedConfig)
		runClientPatches(Config.tryLoadFromString(serializedConfig))
	end)
	network.client.requestReceiveConfig()
else
	error("Should be unreachable!")
end
