LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.ItemPrefab"], "set_MaxStackSize")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.ItemPrefab"], "set_MaxStackSizeCharacterInventory")
LuaUserData.MakeMethodAccessible(Descriptors["Barotrauma.ItemPrefab"], "set_MaxStackSizeHoldableOrWearableInventory")

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
local holdableContainerCapacity = 32 -- from observation only, not checked
local characterInventoryCapacity = holdableContainerCapacity

-- todo: Modify MaxStackSize of containers too.
-- Containers have their own MaxStackSize which dictates the max allowed stack for items within that container

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
		})
	then
		-- Don't change the player inventory stack size for these items
		prefab.set_MaxStackSize(maxStackSize)
		prefab.set_MaxStackSizeCharacterInventory(math.abs(prefab.MaxStackSizeCharacterInventory))
		prefab.set_MaxStackSizeHoldableOrWearableInventory(maxStackSize) -- WearableInventory applies to Toolbelts/Backpacks
	elseif iterContainsAny(prefab.Tags, { "mobilebattery", "handheldammo", "shotgunammo" }) then
		-- Only double the item's stack size in player inventory, and max verywhere else
		prefab.set_MaxStackSize(maxStackSize)
		prefab.set_MaxStackSizeCharacterInventory(
			math.min(characterInventoryCapacity, math.abs(prefab.MaxStackSizeCharacterInventory) * 2)
		)
		prefab.set_MaxStackSizeHoldableOrWearableInventory(maxStackSize)
	elseif iterContainsAny(prefab.Tags, { "smallitem" }) and prefab.MaxStackSize > 1 then
		-- Every small item should've max stack everywhere, excluding
		-- those that shouldn't stack at all in the first place
		prefab.set_MaxStackSize(maxStackSize)
		prefab.set_MaxStackSizeCharacterInventory(characterInventoryCapacity)
		prefab.set_MaxStackSizeHoldableOrWearableInventory(maxStackSize)
	end
end
