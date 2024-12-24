LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.ItemPrefab"], "set_MaxStackSize")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.ItemPrefab"], "set_MaxStackSizeCharacterInventory")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.ItemPrefab"], "set_MaxStackSizeHoldableOrWearableInventory")
LuaUserData.MakeFieldAccessible(Descriptors["Barotrauma.Items.Components.ItemContainer"], "maxStackSize")

local function values(t)
	local f, s, i = pairs(t)
	return function()
		local _, v = f(s, i)
		i = _
		if v ~= nil then
			return v
		end
	end
end

local function findAny(s, list)
	for _, p in ipairs(list) do
		if string.find(s, p) ~= nil then
			return true
		end
	end
	return false
end

local function iterFind(iter, pat)
	for v in iter do
		if string.find(v, pat) ~= nil then
			return true
		end
	end
	return false
end

local function iterFindAny(iter, list)
	for _, p in ipairs(list) do
		if iterFind(iter, p) then
			return true
		end
	end
	return false
end

local function iterContains(iter, val)
	for v in iter do
		if v == val then
			return true
		end
	end
	return false
end

local function iterContainsAny(iter, list)
	for _, v in ipairs(list) do
		if iterContains(iter, v) then
			return true
		end
	end
	return false
end

local function debugItemStackSize(prefab)
	print(
		string.format(
			"%s (max:%d, hotbar:%d, container:%d)",
			tostring(prefab.Identifier),
			prefab.MaxStackSize,
			prefab.MaxStackSizeCharacterInventory,
			prefab.MaxStackSizeHoldableOrWearableInventory
		)
	)
end

local PrefabRollback = {}
function PrefabRollback.storeStackSizeState(self, item_prefab)
	if not self.items then
		---@type table<string, StackSizeState>
		self.items = {}
	end

	---@class StackSizeState
	local state = {
		MaxStackSize = item_prefab.MaxStackSize,
		MaxStackSizeCharacterInventory = item_prefab.MaxStackSizeCharacterInventory,
		MaxStackSizeHoldableOrWearableInventory = item_prefab.MaxStackSizeHoldableOrWearableInventory,
	}

	self.items[item_prefab.Identifier] = state
end
function PrefabRollback.rollbackStackSizeStates(self)
	if not self.items then
		return
	end

	for id, state in pairs(self.items) do
		local item_prefab = ItemPrefab.GetItemPrefab(id)
		item_prefab.set_MaxStackSize(state.MaxStackSize)
		item_prefab.set_MaxStackSizeCharacterInventory(state.MaxStackSizeCharacterInventory)
		item_prefab.set_MaxStackSizeHoldableOrWearableInventory(state.MaxStackSizeHoldableOrWearableInventory)
	end
end

-- Arbitrary max limit is (6 bits, i.e. 2 ^ 6 - 1) = 63
-- Likely there due to network syncing.
-- https://github.com/FakeFishGames/Barotrauma/blob/0e8fb6569d2810e2f8ad5fb17b4bba546cc5739a/Barotrauma/BarotraumaShared/SharedSource/Items/Inventory.cs#L13
--
-- Picking up an even number before 63, as max.
--
-- Not increasing stack size above 63 despite it being possible,
-- as it'd either impact network performance or not work outright
-- without some heavy changes to both server and client code.
local maxStackSize = 62
local mobileContainerCapacity = 64
local stationaryContainerCapacity = 64
local crateCapacity = stationaryContainerCapacity
local characterInventoryCapacity = mobileContainerCapacity

-- Patching MaxStackSize of containers
-- This doesn't persist, so no need for cleanup
-- Taken from Stack Size 128x Lua
--
-- Containers have their own MaxStackSize which dictates the max allowed stack for items within that container
Hook.Patch("Barotrauma.Items.Components.ItemContainer", "set_MaxStackSize", {
	"System.Int32",
}, function(instance, _ptable)
	if instance.maxStackSize > 1 and instance.maxStackSize < 64 then
		local tags = instance.Item.Tags

		if string.match(tags, "mobilecontainer") or string.match(tags, "scooter") then
			instance.maxStackSize = mobileContainerCapacity
		elseif string.match(tags, "crate") then
			instance.maxStackSize = crateCapacity
		elseif string.match(tags, "container") then
			instance.maxStackSize = stationaryContainerCapacity
		else
			instance.maxStackSize = maxStackSize
		end
	end
end, Hook.HookMethodType.After)

-- note: By default, some items may have their MaxStackSizeCharacterInventory and/or MaxStackSizeHoldableOrWearableInventory
-- set to -1, which means that MaxStackSizeCharacterInventory will use the value of MaxStackSize and MaxStackSizeHoldableOrWearableInventory
-- will use the value of MaxStackSizeCharacterInventory

for prefab in ItemPrefab.Prefabs do
	if
		iterContainsAny(prefab.Tags, {
			"oxygensource",
			"weldingfuel",
			-- For wrench and screwdriver
			"simpletool",
			"multitool",
		}) or iterContains(values({ "bikehorn", "toyhammer" }), tostring(prefab.Identifier))
	then
		-- Don't change the player inventory stack size for these items
		PrefabRollback:storeStackSizeState(prefab)
		prefab.set_MaxStackSize(maxStackSize)
		prefab.set_MaxStackSizeCharacterInventory(math.abs(prefab.MaxStackSizeCharacterInventory))
		prefab.set_MaxStackSizeHoldableOrWearableInventory(maxStackSize) -- WearableInventory applies to Toolbelts/Backpacks
	elseif
		-- todo: Only double the item's stack size in player inventory, and max verywhere else
		-- for ammo items in particular...
		iterContainsAny(prefab.Tags, { "mobilebattery", "handheldammo", "shotgunammo", "smgammo", "handcannonammo" })
		or iterContainsAny(prefab.Tags, { "smallitem" }) and prefab.MaxStackSize > 1
	then
		-- Every small item should've max stack everywhere, excluding
		-- those that shouldn't stack at all in the first place
		PrefabRollback:storeStackSizeState(prefab)
		prefab.set_MaxStackSize(maxStackSize)
		prefab.set_MaxStackSizeCharacterInventory(characterInventoryCapacity)
		prefab.set_MaxStackSizeHoldableOrWearableInventory(maxStackSize)
	end
end

Hook.Add("stop", "MoreStackSize.stop", function()
	--- Reverting on exit to menu, since the ItemPrefab changes seem to persist.
	--- This prevents cases where for eg. you went back to main menu from an SP session, and then to join
	--- some MP server after disabling this mod, but the issue is that those stack sizes changes are still
	---  present and so, they'll cause syncing issues in MP, with stack sizes being different for client and server
	PrefabRollback:rollbackStackSizeStates()
end)
