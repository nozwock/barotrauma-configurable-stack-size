local utils = require("ConfigurableStackSize.utils")
local state = require("ConfigurableStackSize.state")

local mod = {}

---@class Rollback
local Rollback = {
	---@type table<string, StackSizeState>
	itemPrefabs = {},
	---@type table<string, integer>
	itemContainerComponents = {},
}

local logger = utils.newLogger("patch.log")

function Rollback:storeItemPrefabStackSize(item_prefab)
	---@class StackSizeState
	local state_ = {
		MaxStackSize = item_prefab.MaxStackSize,
		MaxStackSizeCharacterInventory = item_prefab.MaxStackSizeCharacterInventory,
		MaxStackSizeHoldableOrWearableInventory = item_prefab.MaxStackSizeHoldableOrWearableInventory,
	}

	self.itemPrefabs[tostring(item_prefab.Identifier)] = state_
end
function Rollback:rollbackItemPrefabStackSizes()
	for id, state_ in pairs(self.itemPrefabs) do
		local item_prefab = ItemPrefab.GetItemPrefab(id)
		item_prefab.set_MaxStackSize(state_.MaxStackSize)
		item_prefab.set_MaxStackSizeCharacterInventory(state_.MaxStackSizeCharacterInventory)
		item_prefab.set_MaxStackSizeHoldableOrWearableInventory(state_.MaxStackSizeHoldableOrWearableInventory)
	end
end
---@param component Barotrauma.Items.Components.ItemContainer
---@param stack_size integer
function Rollback:storeInitialItemContainerCompStackSize(component, stack_size)
	local id = tostring(component.Item.Prefab.Identifier)

	if not self.itemContainerComponents[id] then
		self.itemContainerComponents[id] = stack_size
	end
end

--- Singleplayer only!
--- Taken from 'Stack Size 128x Lua.'
---
--- https://steamcommunity.com/sharedfiles/filedetails/?id=2961866549
function mod.runBypassMaxStackSizeLimit()
	if not Game.IsSingleplayer then
		return
	end

	LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.ItemPrefab"], "maxStackSize")
	LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.ItemPrefab"], "maxStackSizeCharacterInventory")
	LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.ItemPrefab"], "maxStackSizeHoldableOrWearableInventory")

	LuaUserData.RegisterType("ConfigurableStackSize.ReflectionExtensions")
	local Int32Type = LuaUserData.RegisterType("System.Int32")

	local ReflectionExtensions = LuaUserData.CreateStatic("ConfigurableStackSize.ReflectionExtensions")

	-- MaxStackWithExtra does the max value bound in the getter of ItemPrefab's MaxStackSize
	local MaxStackWithExtraInternalIdentifier = ReflectionExtensions.FindMethodNameRegex(
		"Barotrauma.ItemPrefab",
		[[<GetMaxStackSize>g__MaxStackWithExtra\|[_\d]+]]
	)

	if MaxStackWithExtraInternalIdentifier == "" then
		print("Failed to find the internal identifier for method MaxStackWithExtra")
		return
	end

	-- Bypassing max value bound on setters
	Hook.Patch("Barotrauma.ItemPrefab", MaxStackWithExtraInternalIdentifier, {
		"System.Int32",
		"System.Int32",
	}, function(_instance, ptable)
		ptable.ReturnValue =
			LuaUserData.CreateUserDataFromDescriptor(ptable["maxStackSize"] + ptable["extraStackSize"], Int32Type)
	end, Hook.HookMethodType.After)

	Hook.Patch("Barotrauma.ItemPrefab", "set_MaxStackSize", {
		"System.Int32",
	}, function(instance, ptable)
		instance.maxStackSize = ptable["value"]
	end, Hook.HookMethodType.After)

	Hook.Patch("Barotrauma.ItemPrefab", "set_MaxStackSizeCharacterInventory", {
		"System.Int32",
	}, function(instance, ptable)
		instance.maxStackSizeCharacterInventory = ptable["value"]
	end, Hook.HookMethodType.After)

	Hook.Patch("Barotrauma.ItemPrefab", "set_MaxStackSizeHoldableOrWearableInventory", {
		"System.Int32",
	}, function(instance, ptable)
		instance.maxStackSizeHoldableOrWearableInventory = ptable["value"]
	end, Hook.HookMethodType.After)
end

-- todo: validate stack size numbers for < 1

--- Taken from 'Stack Size 128x Lua.'
--- Patches MaxStackSize of containers.
--- note: ~~The changes don't persist, so no need for a cleanup.~~ This was a lie, they do persist until the next session
--- where these values will get re-evaluated...
--- So, that means you can't do stuff like `if instance.maxStackSize < 64`, that could end up skipping stuff
---
--- Containers have their own MaxStackSize which dictates the max allowed stack for items within that container.
---@param containerSizes ContainerOptions
function mod.runContainersPatch(containerSizes)
	LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.ItemContainer"], "maxStackSize")

	Hook.Patch("Barotrauma.Items.Components.ItemContainer", "set_MaxStackSize", {
		"System.Int32",
	}, function(instance, ptable)
		---@cast instance Barotrauma.Items.Components.ItemContainer

		-- Incase the user sets maxStackSize to 1 for one or more container group.
		if instance.maxStackSize > 1 or Rollback.itemContainerComponents[tostring(instance.Item.Prefab.Identifier)] then
			local item = instance.Item

			Rollback:storeInitialItemContainerCompStackSize(instance, ptable["value"])

			if item.HasTag("mobilecontainer") or item.HasTag("scooter") then
				instance.maxStackSize = containerSizes.mobileContainerCapacity
			elseif item.HasTag("crate") then
				instance.maxStackSize = containerSizes.crateContainerCapacity
			elseif item.HasTag("container") then
				instance.maxStackSize = containerSizes.stationaryContainerCapacity
			elseif ptable["value"] >= 64 then
				instance.maxStackSize = containerSizes.maxStackSize
			end
			-- Don't catch all here using `else`, as that would include even container slots of weapons, etc. which is used to hold ammo

			if state.logging then
				local log = {
					patchType = "container",
					name = tostring(item.Prefab.Name),
					identifier = tostring(item.Prefab.Identifier),
					tags = item.Tags,
					maxStackSize = {
						before = ptable["value"],
						after = instance.maxStackSize,
					},
				}
				if log.maxStackSize.before ~= log.maxStackSize.after then
					logger.WriteLine(json.serialize(log))
					logger.Flush()
				end
			end
		end
	end, Hook.HookMethodType.After)
end

---@param cfg Config
function mod.runItemPrefabsPatch(cfg)
	local containerSizes = cfg.data.containerOptions

	Rollback:rollbackItemPrefabStackSizes()

	LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.ItemPrefab"], "set_MaxStackSize")
	LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.ItemPrefab"], "set_MaxStackSizeCharacterInventory")
	LuaUserData.MakeMethodAccessible(
		Descriptors["Barotrauma.ItemPrefab"],
		"set_MaxStackSizeHoldableOrWearableInventory"
	)

	for prefab in ItemPrefab.Prefabs do
		-- Using `ipairs` here since we want to do this in a ordered top-down manner.
		for idx, itemPatch in ipairs(cfg.data.itemPatches) do
			if itemPatch.applyOnlyToStackables and prefab.MaxStackSize == 1 then
				goto continue
			end

			-- Only apply the first ItemPatch on a ItemPrefab
			if Rollback.itemPrefabs[tostring(prefab.Identifier)] then
				break
			end

			if
				utils.iterContainsAny(prefab.Tags, itemPatch.tags)
				or utils.iterContains(table.values(itemPatch.identifiers), tostring(prefab.Identifier))
			then
				Rollback:storeItemPrefabStackSize(prefab)

				local log
				if state.logging then
					log = {
						patchType = "item",
						patchIdx = idx,
						name = tostring(prefab.Name),
						identifier = tostring(prefab.Identifier),
						MaxStackSize = {
							before = prefab.MaxStackSize,
						},
						MaxStackSizeCharacterInventory = {
							before = prefab.MaxStackSizeCharacterInventory,
						},
						MaxStackSizeHoldableOrWearableInventory = {
							before = prefab.MaxStackSizeHoldableOrWearableInventory,
						},
					}
				end
				local operationsDone = utils.Set.new()

				-- note: By default, some items may have their MaxStackSizeCharacterInventory and/or MaxStackSizeHoldableOrWearableInventory
				-- set to -1, which means that MaxStackSizeCharacterInventory will use the value of MaxStackSize and MaxStackSizeHoldableOrWearableInventory
				-- will use the value of MaxStackSizeCharacterInventory
				--
				-- So we're making them independent of each other here, since we might want MaxStackSizeCharacterInventory
				-- to remain at 1 while we modify MaxStackSize to something else, etc.
				prefab.set_MaxStackSizeCharacterInventory(math.abs(prefab.MaxStackSizeCharacterInventory))
				prefab.set_MaxStackSizeHoldableOrWearableInventory(
					math.abs(prefab.MaxStackSizeHoldableOrWearableInventory)
				)

				for _, op in pairs(itemPatch.operations) do
					---@alias ItemPrefabStackSizeField
					---|> "MaxStackSize"
					---| "MaxStackSizeCharacterInventory"
					---| "MaxStackSizeHoldableOrWearableInventory"

					---@param prefab_field ItemPrefabStackSizeField
					---@param value number|string
					---@return number
					local function evalOperationValue(prefab_field, value)
						if type(value) == "string" then
							local var_name = string.match(value, "^%s*{%s*(%a[%w_]*)%s*}%s*$")
							if not var_name then
								error(string.format("Operation value has invalid syntax: `%s`", value))
							end

							if not containerSizes[var_name] then
								error(
									string.format("Could not found variable named `%s` for Operation value", var_name)
								)
							end

							value = containerSizes[var_name]
						end

						if op.operation == "+" then
							return prefab[prefab_field] + value
						elseif op.operation == "*" then
							return prefab[prefab_field] * value
						elseif op.operation == "=" then
							return value
						else
							error("unreachable")
						end
					end

					-- Not allowing repeat operations on the same key for now...
					if operationsDone[op.key] then
						goto continue
					end
					operationsDone:add(op.key)

					--- What have I done...
					if op.key == "MaxStackSizeAll" then
						prefab.set_MaxStackSize(evalOperationValue("MaxStackSize", op.value))
						prefab.set_MaxStackSizeCharacterInventory(
							math.min(
								containerSizes.characterInventoryCapacity,
								evalOperationValue("MaxStackSizeCharacterInventory", op.value)
							)
						)
						prefab.set_MaxStackSizeHoldableOrWearableInventory(
							evalOperationValue("MaxStackSizeHoldableOrWearableInventory", op.value)
						)
					elseif op.key == "MaxStackSize" then
						prefab.set_MaxStackSize(evalOperationValue("MaxStackSize", op.value))
					elseif op.key == "MaxStackSizeCharacterInventory" then
						prefab.set_MaxStackSizeCharacterInventory(
							math.min(
								containerSizes.characterInventoryCapacity,
								evalOperationValue("MaxStackSizeCharacterInventory", op.value)
							)
						)
					elseif op.key == "MaxStackSizeHoldableOrWearableInventory" then
						prefab.set_MaxStackSizeHoldableOrWearableInventory(
							evalOperationValue("MaxStackSizeHoldableOrWearableInventory", op.value)
						)
					else
						error("unreachable")
					end

					::continue::
				end

				if state.logging then
					log.MaxStackSize.after = prefab.MaxStackSize
					log.MaxStackSizeCharacterInventory.after = prefab.MaxStackSizeCharacterInventory
					log.MaxStackSizeHoldableOrWearableInventory.after = prefab.MaxStackSizeHoldableOrWearableInventory
					logger.WriteLine(json.serialize(log))
				end
			end

			::continue::
		end
	end

	if state.logging then
		logger.Flush()
	end

	Hook.Add("stop", "ConfigurableStackSize.stop", function()
		--- Reverting on exit to menu, since the ItemPrefab changes seem to persist.
		--- This prevents cases where for eg. you went back to main menu from an SP session, and then to join
		--- some MP server after disabling this mod, but the issue is that those stack sizes changes are still
		--- present and so, they'll cause syncing issues in MP, with stack sizes being different for client and server
		Rollback:rollbackItemPrefabStackSizes()
	end)
end

return mod
