require("ConfigurableStackSize.ext") -- Make extensions available for all from here on.
local config = require("ConfigurableStackSize.config")
local patches = require("ConfigurableStackSize.patches")

local Config = config.Config

-- todo: handle config syncing in multiplayer
-- todo: have separate config for sp and mp
-- todo: look into whether the config files will be downloaded by the client too or not, and if so
-- figure out how to exclude them

local cfg = Config.tryLoadFromDiskOrDefault()
-- todo?: Should container sizes be bound by ContainerOptions.maxStackSize?

patches.runBypassMaxStackSizeLimit()
patches.runContainersPatch(cfg.data.containerOptions)
patches.runItemPrefabsPatch(cfg)
