LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.ItemPrefab"], "set_MaxStackSize")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.ItemPrefab"], "set_MaxStackSizeCharacterInventory")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.ItemPrefab"], "set_MaxStackSizeHoldableOrWearableInventory")
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.ItemContainer"], "maxStackSize")

require("Mod.ext")
local utils = require("Mod.utils")
local config = require("Mod.config")

local Config = config.Config

---@class PrefabRollback
local PrefabRollback = {
	---@type table<string, StackSizeState>
	itemPrefabs = {},
}
function PrefabRollback:storeStackSizeState(item_prefab)
	---@class StackSizeState
	local state = {
		MaxStackSize = item_prefab.MaxStackSize,
		MaxStackSizeCharacterInventory = item_prefab.MaxStackSizeCharacterInventory,
		MaxStackSizeHoldableOrWearableInventory = item_prefab.MaxStackSizeHoldableOrWearableInventory,
	}

	self.itemPrefabs[tostring(item_prefab.Identifier)] = state
end
function PrefabRollback:rollbackStackSizeStates()
	for id, state in pairs(self.itemPrefabs) do
		local item_prefab = ItemPrefab.GetItemPrefab(id)
		item_prefab.set_MaxStackSize(state.MaxStackSize)
		item_prefab.set_MaxStackSizeCharacterInventory(state.MaxStackSizeCharacterInventory)
		item_prefab.set_MaxStackSizeHoldableOrWearableInventory(state.MaxStackSizeHoldableOrWearableInventory)
	end
end

local cfg = Config.tryLoadFromDiskOrDefault()
local containerSizes = cfg.data.containerOptions
-- todo?: Should container sizes be bound by ContainerOptions.maxStackSize?

-- Patching MaxStackSize of containers
-- This doesn't persist, so no need for cleanup
-- Taken from Stack Size 128x Lua
--
-- Containers have their own MaxStackSize which dictates the max allowed stack for items within that container
Hook.Patch("Barotrauma.Items.Components.ItemContainer", "set_MaxStackSize", {
	"System.Int32",
}, function(instance, ptable)
	if instance.maxStackSize > 1 and instance.maxStackSize < 64 then
		-- todo: do proper matching of tags, not some substring match
		---@type string
		local tags = instance.Item.Tags

		if string.match(tags, "mobilecontainer") or string.match(tags, "scooter") then
			instance.maxStackSize = containerSizes.mobileContainerCapacity
		elseif string.match(tags, "crate") then
			instance.maxStackSize = containerSizes.crateContainerCapacity
		elseif string.match(tags, "container") then
			instance.maxStackSize = containerSizes.stationaryContainerCapacity
		elseif ptable["value"] >= 64 then
			instance.maxStackSize = containerSizes.maxStackSize
		end
		-- Don't catch all here using `else`, as that would include even container slots of weapons, etc. which is used to hold ammo
	end
end, Hook.HookMethodType.After)

for prefab in ItemPrefab.Prefabs do
	-- Using `ipairs` here since we want to do this in a ordered top-down manner.
	for _, itemPatch in ipairs(cfg.data.itemPatches) do
		if itemPatch.applyOnlyToStackables and prefab.MaxStackSize == 1 then
			goto continue
		end

		-- Only apply the first ItemPatch on a ItemPrefab
		if PrefabRollback.itemPrefabs[tostring(prefab.Identifier)] then
			break
		end

		if
			utils.iterContainsAny(prefab.Tags, itemPatch.tags)
			or utils.iterContains(table.values(itemPatch.identifiers), tostring(prefab.Identifier))
		then
			PrefabRollback:storeStackSizeState(prefab)
			local operationsDone = utils.Set.new()

			-- note: By default, some items may have their MaxStackSizeCharacterInventory and/or MaxStackSizeHoldableOrWearableInventory
			-- set to -1, which means that MaxStackSizeCharacterInventory will use the value of MaxStackSize and MaxStackSizeHoldableOrWearableInventory
			-- will use the value of MaxStackSizeCharacterInventory
			--
			-- So we're making them independent of each other here, since we might want MaxStackSizeCharacterInventory
			-- to remain at 1 while we modify MaxStackSize to something else, etc.
			prefab.set_MaxStackSizeCharacterInventory(math.abs(prefab.MaxStackSizeCharacterInventory))
			prefab.set_MaxStackSizeHoldableOrWearableInventory(math.abs(prefab.MaxStackSizeHoldableOrWearableInventory))

			for _, op in pairs(itemPatch.operations) do
				---@alias ItemPrefabStackSizeField
				---|> "MaxStackSize"
				---| "MaxStackSizeCharacterInventory"
				---| "MaxStackSizeHoldableOrWearableInventory"

				---@param prefab_field ItemPrefabStackSizeField
				---@param value number
				---@return number
				local function evalOperationValue(prefab_field, value)
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
					-- todo: allow `op.value` to be a string referencing values from containerOptions
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
		end

		::continue::
	end
end

Hook.Add("stop", "MoreStackSize.stop", function()
	--- Reverting on exit to menu, since the ItemPrefab changes seem to persist.
	--- This prevents cases where for eg. you went back to main menu from an SP session, and then to join
	--- some MP server after disabling this mod, but the issue is that those stack sizes changes are still
	--- present and so, they'll cause syncing issues in MP, with stack sizes being different for client and server
	PrefabRollback:rollbackStackSizeStates()
end)
