local ADDON_NAME, ns = ...
local Tracker = {}
ns.Tracker = Tracker

-- Maps itemEquipLoc strings to inventory slot IDs.
-- For dual-slot gear (rings, trinkets), both slots are listed;
-- we compare against the lowest equipped ilvl so any slot can be filled.
local EQUIP_LOC_SLOTS = {
    INVTYPE_HEAD           = {1},
    INVTYPE_NECK           = {2},
    INVTYPE_SHOULDER       = {3},
    INVTYPE_CHEST          = {5},
    INVTYPE_ROBE           = {5},
    INVTYPE_WAIST          = {6},
    INVTYPE_LEGS           = {7},
    INVTYPE_FEET           = {8},
    INVTYPE_WRIST          = {9},
    INVTYPE_HAND           = {10},
    INVTYPE_FINGER         = {11, 12},
    INVTYPE_TRINKET        = {13, 14},
    INVTYPE_CLOAK          = {15},
    INVTYPE_WEAPON         = {16},
    INVTYPE_2HWEAPON       = {16},
    INVTYPE_WEAPONMAINHAND = {16},
    INVTYPE_SHIELD         = {17},
    INVTYPE_WEAPONOFFHAND  = {17},
    INVTYPE_HOLDABLE       = {17},
}

local QUALITY_NAMES = {"Poor", "Common", "Uncommon", "Rare", "Epic", "Legendary"}

-- Armor types each class can equip (highest tier only — e.g. Warriors can wear Plate but not Cloth).
-- Weapons/jewelry have no armor type so they are always allowed (nil subType check below).
local CLASS_ARMOR_TYPES = {
    WARRIOR     = {Plate=true},
    PALADIN     = {Plate=true},
    DEATHKNIGHT = {Plate=true},
    HUNTER      = {Mail=true},
    SHAMAN      = {Mail=true},
    EVOKER      = {Mail=true},
    DRUID       = {Leather=true},
    MONK        = {Leather=true},
    ROGUE       = {Leather=true},
    DEMONHUNTER = {Leather=true},
    MAGE        = {Cloth=true},
    PRIEST      = {Cloth=true},
    WARLOCK     = {Cloth=true},
}

local ARMOR_SUBTYPES = {Plate=true, Mail=true, Leather=true, Cloth=true}

local function CanUseArmorType(unit, itemSubType)
    if not itemSubType or not ARMOR_SUBTYPES[itemSubType] then return true end
    local _, classFilename = UnitClass(unit)
    if not classFilename then return true end
    local allowed = CLASS_ARMOR_TYPES[classFilename]
    return allowed and allowed[itemSubType] or false
end

local inTrackedInstance = false

local function IsInTrackedInstance()
    local isIn, kind = IsInInstance()
    return isIn and (kind == "party" or kind == "raid")
end

local function GetUnitByName(name)
    if UnitName("player") == name then return "player" end
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitName(unit) == name then return unit end
    end
    for i = 1, 40 do
        local unit = "raid" .. i
        if UnitName(unit) == name then return unit end
    end
    return nil
end

-- Returns the lowest equipped ilvl for the given player across all valid slots for equipLoc.
-- Returns 0 if any slot is empty, nil if unit cannot be resolved or equipLoc is not trackable.
local function GetLooterEquippedLevel(playerName, equipLoc)
    local slots = EQUIP_LOC_SLOTS[equipLoc]
    if not slots then return nil end
    local unit = GetUnitByName(playerName)
    if not unit then return nil end
    local lowest = math.huge
    for _, slotId in ipairs(slots) do
        local link = GetInventoryItemLink(unit, slotId)
        if not link then return 0 end
        local ilvl = select(1, C_Item.GetDetailedItemLevelInfo(link))
        if ilvl and ilvl < lowest then
            lowest = ilvl
        end
    end
    return lowest == math.huge and nil or lowest
end

-- Returns the lowest equipped item level across all valid slots for equipLoc.
-- Returns 0 if any slot is empty (empty slot = always an upgrade).
-- Returns nil if equipLoc is not trackable.
local function GetLowestEquippedLevel(equipLoc)
    local slots = EQUIP_LOC_SLOTS[equipLoc]
    if not slots then return nil end

    local lowest = math.huge
    for _, slotId in ipairs(slots) do
        local link = GetInventoryItemLink("player", slotId)
        if not link then
            return 0
        end
        local _, _, _, ilvl = C_Item.GetItemInfo(link)
        if ilvl and ilvl < lowest then
            lowest = ilvl
        end
    end

    return lowest == math.huge and nil or lowest
end

local function PassesQualityFilter(db, quality, itemLink)
    local threshold = db.debug and 0 or db.minQuality
    if (quality or 0) >= threshold then return true end
    ns.addon:Debug("Skipping (quality " .. (QUALITY_NAMES[(quality or 0) + 1] or "?") ..
        " below threshold " .. (QUALITY_NAMES[threshold + 1] or "?") .. "): " .. itemLink)
    return false
end

-- Returns equippedLevel (may be nil/0) and isUpgrade for the local player.
local function GetSelfUpgradeInfo(equipLoc, lootedLevel)
    if not equipLoc or equipLoc == "" or not EQUIP_LOC_SLOTS[equipLoc] then
        return nil, false
    end
    local equippedLevel = GetLowestEquippedLevel(equipLoc)
    local isUpgrade = equippedLevel ~= nil and lootedLevel > equippedLevel
    return equippedLevel, isUpgrade
end

-- Returns looterEquippedLevel (may be nil) and whether the looter already outgears the slot.
local function GetLooterUpgradeInfo(playerName, equipLoc, lootedLevel, _, isSelf)
    if isSelf then return nil, false end
    local looterEquippedLevel = GetLooterEquippedLevel(playerName, equipLoc)
    local looterHasHigherIlvl = looterEquippedLevel ~= nil and looterEquippedLevel > lootedLevel
    return looterEquippedLevel, looterHasHigherIlvl
end

local function TrySendWhisper(db, playerName, itemLink, isUpgrade, isSelf, looterHasHigherIlvl)
    if db.debug then return false end
    if not (isUpgrade and db.autoWhisper and not isSelf) then return false end
    if db.whisperOnlyIfLooterOutgearsSlot and not looterHasHigherIlvl then return false end
    ns.SendWhisper(playerName, itemLink)
    return true
end

local function ProcessLoot(playerName, itemLink)
    local addon = ns.addon
    local db    = addon.db.profile
    local _, _, quality, lootedLevel, _, _, itemSubType, _, equipLoc = C_Item.GetItemInfo(itemLink)

    if not lootedLevel then
        addon:Debug("Item data unavailable for: " .. itemLink)
        return
    end

    if not PassesQualityFilter(db, quality, itemLink) then return end

    local looterUnit = GetUnitByName(playerName)
    if not db.debug and looterUnit and not CanUseArmorType(looterUnit, itemSubType) then
        addon:Debug("Skipping (armor type " .. (itemSubType or "?") .. " not usable by " .. playerName .. "): " .. itemLink)
        return
    end

    local equippedLevel, isUpgrade = GetSelfUpgradeInfo(equipLoc, lootedLevel)
    local isSelf                   = playerName == UnitName("player")
    if db.debug then isUpgrade = true; isSelf = false end
    local looterEquippedLevel, looterHasHigherIlvl = GetLooterUpgradeInfo(playerName, equipLoc, lootedLevel, isUpgrade, isSelf)

    if db.debug then
        addon:Debug(string.format("  quality=%s  ilvl=%d  equippedIlvl=%s  looterIlvl=%s  loc=%s  upgrade=%s",
            QUALITY_NAMES[(quality or 0) + 1] or "?",
            lootedLevel,
            tostring(equippedLevel),
            tostring(looterEquippedLevel),
            equipLoc or "none",
            tostring(isUpgrade)))
    end

    local wasWhispered = TrySendWhisper(db, playerName, itemLink, isUpgrade, isSelf, looterHasHigherIlvl)
    ns.UI:AddLootEntry(playerName, itemLink, isUpgrade, isSelf, wasWhispered, looterEquippedLevel)
end

local function OnLootMessage(_, text)
    if not IsInTrackedInstance() then return end
    if not ns.addon.db.profile.enabled then return end

    local itemId = text:match("|Hitem:(%d+):")
    if not itemId then return end

    local playerName
    if text:match("^You receive") then
        local name, realm = UnitName("player")
        playerName = (realm and realm ~= "") and (name .. "-" .. realm) or name
    else
        local shortName = text:match("^(.+) receives? loot:")
        if not shortName then return end
        local unit = GetUnitByName(shortName)
        local fullName, realm = UnitName(unit or "")
        if fullName and realm and realm ~= "" then
            playerName = fullName .. "-" .. realm
        else
            playerName = shortName
        end
    end
    if not playerName then return end

    local function proceed(safeLink)
        if ns.addon.db.profile.debug then
            ns.addon:Debug("CHAT_MSG_LOOT  player=" .. playerName .. "  link=" .. safeLink)
        end
        local _, _, _, lootedLevel = C_Item.GetItemInfo(safeLink)
        if lootedLevel then
            ProcessLoot(playerName, safeLink)
        else
            C_Timer.After(0.5, function() ProcessLoot(playerName, safeLink) end)
        end
    end

    local _, safeLink = C_Item.GetItemInfo(tonumber(itemId))
    if safeLink then
        proceed(safeLink)
    else
        local item = C_Item.CreateFromItemID(tonumber(itemId))
        item:ContinueOnItemLoad(function()
            local _, loadedLink = C_Item.GetItemInfo(tonumber(itemId))
            if loadedLink then proceed(loadedLink) end
        end)
    end
end

local function OnZoneChanged()
    local nowIn = IsInTrackedInstance()
    if nowIn and not inTrackedInstance then
        ns.UI:Clear()
    end
    inTrackedInstance = nowIn
end

function Tracker:Enable()
    local addon = ns.addon
    addon:RegisterEvent("CHAT_MSG_LOOT", OnLootMessage)
    addon:RegisterEvent("ZONE_CHANGED_NEW_AREA", OnZoneChanged)
    inTrackedInstance = IsInTrackedInstance()
end

function Tracker:Disable()
    local addon = ns.addon
    addon:UnregisterEvent("CHAT_MSG_LOOT")
    addon:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
end
