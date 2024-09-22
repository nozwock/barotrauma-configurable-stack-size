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


local stacksize = 62

for prefab in ItemPrefab.Prefabs do
    if iterContainsAny(prefab.Tags, { "oxygensource", "weldingfuel" }) then
        prefab.set_MaxStackSize(stacksize)
        prefab.set_MaxStackSizeHoldableOrWearableInventory(stacksize) -- Backpacks
    elseif iterContainsAny(prefab.Tags, { "mobilebattery", "handheldammo", "shotgunammo" }) then
        prefab.set_MaxStackSize(stacksize)
        prefab.set_MaxStackSizeCharacterInventory(math.ceil(prefab.MaxStackSizeCharacterInventory * 2))
        prefab.set_MaxStackSizeHoldableOrWearableInventory(stacksize)
    elseif iterContainsAny(prefab.Tags, { "smallitem" })
        and not iterContainsAny(prefab.Tags, { "weapon", "tool", "scooter", "geneticdevice", "diving", "sonar" })
        and not iterContains(values({ "captainspipe", "handheldterminal" }), prefab.Identifier)
        and not findAny(tostring(prefab.Identifier), { "idcard" }) then
        prefab.set_MaxStackSize(stacksize)
        prefab.set_MaxStackSizeCharacterInventory(stacksize)
        prefab.set_MaxStackSizeHoldableOrWearableInventory(stacksize)
    end
end

