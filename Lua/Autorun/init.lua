require("ConfigurableStackSize.ext") -- Make extensions available for all from here on.
local config = require("ConfigurableStackSize.config")
local patches = require("ConfigurableStackSize.patches")
local network = require("ConfigurableStackSize.network")

local Config = config.Config

-- todo: look into whether the config files will be downloaded by the client too or not, and if so
-- figure out how to exclude them

---@param cfg Config
local function runClientPatches(cfg)
	patches.runContainersPatch(cfg.data.containerOptions)
	patches.runItemPrefabsPatch(cfg)
end

if Game.IsSingleplayer then
	local cfg = Config.tryLoadFromDiskOrDefault("singleplayer_config.json")
	patches.runBypassMaxStackSizeLimit()
	runClientPatches(cfg)
elseif SERVER then
	local cfg = Config.tryLoadFromDiskOrDefault("multiplayer_config.json")
	network.server.setSendConfigHandler(function()
		return cfg
	end)
	runClientPatches(cfg)
elseif CLIENT and Game.IsMultiplayer then
	network.client.setReceiveConfigHandler(function(serializedConfig)
		runClientPatches(Config.tryLoadFromString(serializedConfig))
	end)
	network.client.requestReceiveConfig()
end
