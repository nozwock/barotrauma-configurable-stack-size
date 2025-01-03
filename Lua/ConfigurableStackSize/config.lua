require("ConfigurableStackSize.ext")
local utils = require("ConfigurableStackSize.utils")

local mod = {}

---@type string
local modPath = ...

---@alias OperationType
---|> "*"
---| "+"
---| "="

---@alias OperationKey
---|> "MaxStackSizeAll"
---| "MaxStackSize"
---| "MaxStackSizeCharacterInventory"
---| "MaxStackSizeHoldableOrWearableInventory"

---@class Config
local Config = {
	operationType = utils.Set.new({ "*", "+", "=" }),
	operationKey = utils.Set.new({
		"MaxStackSizeAll",
		"MaxStackSize",
		"MaxStackSizeCharacterInventory",
		"MaxStackSizeHoldableOrWearableInventory",
	}),
	--- This is what actually serializes.
	---@class ConfigData
	data = {
		---@type integer
		version = 1, -- For migrations. Assume current version if not present
		---@class ContainerOptions
		containerOptions = {
			-- todo?: Should container sizes be bound by ContainerOptions.maxStackSize?
			maxStackSize = 64,
			characterInventoryCapacity = 32,
			mobileContainerCapacity = 32,
			crateContainerCapacity = 64,
			stationaryContainerCapacity = 64,
		},
		---@alias ItemPatches ItemPatch[]
		---@type ItemPatches
		itemPatches = {},
	},
	filename = "config.json",
}
local _ConfigMetaTable = {
	__index = Config,
	---@param cfg Config
	__tostring = function(cfg)
		return json.serialize(cfg.data)
	end,
}
local _ConfigDataMetaTable = { __index = Config.data }
setmetatable(Config, _ConfigMetaTable)

local _ItemPatchMetaTable = {
	---@class ItemPatch
	__index = {
		applyOnlyToStackables = true,
		---@type string[]
		tags = {},
		---@type string[]
		identifiers = {},
		---@type ItemPatchOperation[]
		operations = {},
	},
}

-- Have to type param type list this instead of class/field because luals won't look at fields
-- when trying to cast and fail early saying can't convert one type to another, and so can't have
-- "OptionalTypes" for params.

---@param cfg_data { version: integer?, containerOptions: ContainerOptions?, itemPatches: ItemPatches }
---@param filename? string
---@return Config
function Config.new(cfg_data, filename)
	if not cfg_data.version then
		cfg_data.version = Config.data.version
	end
	if not cfg_data.containerOptions then
		cfg_data.containerOptions = table.shallowcopy(Config.data.containerOptions)
	end

	local cfg = {
		data = cfg_data --[[@as ConfigData]],
	}
	setmetatable(cfg.data, _ConfigDataMetaTable)
	setmetatable(cfg, _ConfigMetaTable)
	---@cast cfg Config

	if filename then
		cfg.filename = filename
	end

	return cfg
end

---@class ItemPatchOperation
---@field operation OperationType
---@field key OperationKey
---@field value number|string The `string` variant is to be validated at runtime where the value will be used

---@param t { applyOnlyToStackables: boolean?, tags: string[]?, identifiers: string[]?, operations: ItemPatchOperation[]? }
function Config.newItemPatch(t)
	setmetatable(t, _ItemPatchMetaTable)
	return t --[[@type ItemPatch]]
end

---@param cfg_data table
---@return Config
function Config.tryFrom(cfg_data)
	---@cast cfg_data ConfigData

	---@param list any[]
	---@param type_ string
	local function allOfTypeInList(list, type_)
		if type(list) ~= "table" then
			return false
		end

		for _, v in pairs(list) do
			if type(v) ~= type_ then
				return false
			end
		end

		return true
	end

	if type(cfg_data) ~= "table" then
		error("ConfigData must be a table")
	end

	setmetatable(cfg_data, _ConfigDataMetaTable)
	if
		not (
			type(cfg_data.version) == "number"
			and type(cfg_data.itemPatches) == "table"
			and allOfTypeInList(cfg_data.containerOptions, "number")
		)
	then
		error("ConfigData's fields have invalid value type")
	end

	for _, itemPatch in pairs(cfg_data.itemPatches) do
		if type(itemPatch) ~= "table" then
			error("ItemPatch must be a table")
		end
		setmetatable(itemPatch, _ItemPatchMetaTable)

		if
			not (
				type(itemPatch.applyOnlyToStackables) == "boolean"
				and allOfTypeInList(itemPatch.tags, "string")
				and allOfTypeInList(itemPatch.identifiers, "string")
				and allOfTypeInList(itemPatch.operations, "table")
			)
		then
			error("ItemPatch's fields have invalid value type")
		end

		for _, operation in pairs(itemPatch.operations) do
			---@cast operation ItemPatchOperation

			if not (operation.operation and operation.key and operation.value) then
				error("Operation is missing required fields")
			end

			if not Config.operationType:has(operation.operation) then
				error(string.format("Invalid operation type: ", operation.operation))
			end
			if not Config.operationKey:has(operation.key) then
				error(string.format("Invalid operation key: ", operation.key))
			end

			if not (type(operation.value) == "number" or type(operation.value) == "string") then
				error("Operation's field `value` must be a number or string")
			end
		end
	end

	return Config.new(cfg_data)
end

---@param filename? string
function Config.getFilePath(filename)
	return modPath .. "/" .. (filename or Config.filename)
end

---@param filename? string
function Config:storeToDisk(filename)
	File.Write(self.getFilePath(filename or self.filename), tostring(self))
end

---@param s string
---@return Config
function Config.tryLoadFromString(s)
	return Config.tryFrom(json.parse(s))
end

---@param filename? string
---@return Config
function Config.tryLoadFromDiskOrDefault(filename)
	local filepath = Config.getFilePath(filename)
	if File.Exists(filepath) then
		local cfg = Config.tryFrom(json.parse(File.Read(filepath)))
		if filename then
			cfg.filename = filename
		end
		return cfg
	else
		local cfg = Config.new(table.shallowcopy(Config.default.data), filename)
		cfg:storeToDisk()
		return cfg
	end
end

-- Arbitrary max item stacksize limit is (6 bits, i.e. 2 ^ 6 - 1) = 63
-- Likely there due to network optimizations.
-- https://github.com/FakeFishGames/Barotrauma/blob/0e8fb6569d2810e2f8ad5fb17b4bba546cc5739a/Barotrauma/BarotraumaShared/SharedSource/Items/Inventory.cs#L13
Config.default = Config.new({
	itemPatches = {
		Config.newItemPatch({
			applyOnlyToStackables = false,
			tags = {
				"oxygensource",
				"weldingfuel",
				-- For wrench and screwdriver
				"simpletool",
				"multitool",
			},
			identifiers = { "bikehorn", "toyhammer", "spinelingspikeloot" },
			operations = {
				{ key = "MaxStackSize", operation = "=", value = "{maxStackSize}" },
				-- Leave character inventory stack size as is.
				{ key = "MaxStackSizeHoldableOrWearableInventory", operation = "=", value = "{maxStackSize}" },
			},
		}),
		Config.newItemPatch({
			applyOnlyToStackables = false,
			tags = { "mobilebattery", "handheldammo", "shotgunammo", "smgammo", "handcannonammo" },
			operations = {
				{ key = "MaxStackSize", operation = "=", value = "{maxStackSize}" },
				{ key = "MaxStackSizeCharacterInventory", operation = "*", value = 2 },
				{ key = "MaxStackSizeHoldableOrWearableInventory", operation = "=", value = "{maxStackSize}" },
			},
		}),
		Config.newItemPatch({
			-- Every small item should've max stack everywhere, excluding
			-- those that shouldn't stack at all in the first place
			tags = { "smallitem" },
			operations = {
				{ key = "MaxStackSize", operation = "=", value = "{maxStackSize}" },
				{ key = "MaxStackSizeCharacterInventory", operation = "=", value = "{characterInventoryCapacity}" },
				{ key = "MaxStackSizeHoldableOrWearableInventory", operation = "=", value = "{maxStackSize}" },
			},
		}),
	},
})

mod.Config = Config

return mod
