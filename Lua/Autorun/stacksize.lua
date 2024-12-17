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

-- Arbitrary max limit is (6 bits, i.e. 2 ^ 6 - 1) = 63
-- Likely there due to network syncing.
-- https://github.com/FakeFishGames/Barotrauma/blob/0e8fb6569d2810e2f8ad5fb17b4bba546cc5739a/Barotrauma/BarotraumaShared/SharedSource/Items/Inventory.cs#L13
--
-- Picking up an even number before 63, as max.
--
-- Not increasing stack size above 63 despite it being possible,
-- as it'd either impact network performance or not work outright
-- without some heavy changes to both server and client code.
local MAX_STACK_SIZE = 62

for prefab in ItemPrefab.Prefabs do
	if iterContainsAny(prefab.Tags, { "oxygensource", "weldingfuel" }) then
		-- Don't change the player inventory stack size for these items
		prefab.set_MaxStackSize(MAX_STACK_SIZE)
		prefab.set_MaxStackSizeHoldableOrWearableInventory(MAX_STACK_SIZE) -- WearableInventory applies to Toolbelts/Backpacks
	elseif iterContainsAny(prefab.Tags, { "mobilebattery", "handheldammo", "shotgunammo" }) then
		-- Only double the item's stack size in player inventory, and max verywhere else
		prefab.set_MaxStackSize(MAX_STACK_SIZE)
		prefab.set_MaxStackSizeCharacterInventory(math.ceil(prefab.MaxStackSizeCharacterInventory * 2))
		prefab.set_MaxStackSizeHoldableOrWearableInventory(MAX_STACK_SIZE)
	elseif iterContainsAny(prefab.Tags, { "smallitem" }) and prefab.MaxStackSize > 1 then
		-- Every small item should've max stack everywhere, excluding
		-- those that shouldn't stack at all in the first place
		prefab.set_MaxStackSize(MAX_STACK_SIZE)
		prefab.set_MaxStackSizeCharacterInventory(MAX_STACK_SIZE)
		prefab.set_MaxStackSizeHoldableOrWearableInventory(MAX_STACK_SIZE)
	end
end
