local addonName = ...

EasyRandomMount = EasyRandomMount or {}
local ERM = EasyRandomMount

BINDING_HEADER_EASYRANDOMMOUNT = "EasyRandomMount"
_G["BINDING_NAME_CLICK EasyRandomMountSecureButton:LeftButton"] = "Summon random mount"
_G["BINDING_NAME_CLICK EasyRandomMountRepairSecureButton:LeftButton"] = "Summon repair mount"
_G["BINDING_NAME_CLICK EasyRandomMountAuctionHouseSecureButton:LeftButton"] = "Summon auction house mount"

local DEFAULTS = {
    fallingEnabled = true,
    preferFlyingMounts = true,
    preferWaterMounts = true,
    preferFlyingAtWaterSurface = true,
    preferFlyingOnlyWhenFlyable = true,
    allowSkyridingMounts = true,
    combatFallbackEnabled = true,
    favoriteMode = "all",
    debugEnabled = false,
    lastMountID = nil,
    blacklistRevision = 0,
    blacklistedMounts = {},
    falling = {
        { type = "spell", id = 130, name = "Slow Fall" },
        { type = "spell", id = 1706, name = "Levitate" },
        { type = "spell", id = 125883, name = "Zen Flight" },
        { type = "spell", id = 131347, name = "Glide" },
        { type = "spell", id = 164862, name = "Flap" },
        { type = "item", id = 182729, name = "Hearty Dragon Plume" },
        { type = "item", id = 131811, name = "Rocfeather Skyhorn Kite" },
    },
}

local function CopyDefaults(source, target)
    if type(source) ~= "table" then
        return target
    end

    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            target[key] = CopyDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

local FLYING_MOUNT_TYPES = {
    [247] = true,
    [248] = true,
}

local SKYRIDING_MOUNT_TYPES = {
    [402] = true,
    [424] = true,
    [436] = true,
}

local WATER_MOUNT_TYPES = {
    [231] = true,
    [232] = true,
    [254] = true,
    [407] = true,
    [408] = true,
    [412] = true,
}

local SERVICE_MOUNT_PATTERNS = {
    repair = {
        "traveler's tundra mammoth",
        "traveller's tundra mammoth",
        "grand expedition yak",
    },
    auctionHouse = {
        "mighty caravan brutosaur",
        "trader's gilded brutosaur",
    },
}

local SERVICE_MOUNT_PRIORITY_PATTERNS = {
    repair = {
        "grand expedition yak",
    },
}

local LOW_LEVEL_MOUNT_PATTERNS = {
    "chauffeured mekgineer's chopper",
    "chauffeured mechano-hog",
}

local SLOW_GROUND_MOUNT_PATTERNS = {
    "riding turtle",
    "sea turtle",
}

local COMBAT_SPELLS_BY_CLASS = {
    DEATHKNIGHT = { 218999 }, -- Wraith Walk
    DRUID = { 783 }, -- Travel Form
    EVOKER = { 358267 }, -- Hover
    HUNTER = { 186257 }, -- Aspect of the Cheetah
    MAGE = { 130 }, -- Slow Fall
    PALADIN = { 190784 }, -- Divine Steed
    PRIEST = { 1706 }, -- Levitate
    ROGUE = { 2983 }, -- Sprint
    SHAMAN = { 2645, 58875 }, -- Ghost Wolf, Spirit Walk
}

local DRUID_TRAVEL_FORM_SPELL_ID = 783

local function GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name
    end

    return GetSpellInfo and GetSpellInfo(spellID)
end

local function IsSpellUsable(spellID)
    local name = GetSpellName(spellID)
    if not name then
        return false
    end

    local usable, noMana
    if C_Spell and C_Spell.IsSpellUsable then
        usable, noMana = C_Spell.IsSpellUsable(spellID)
    elseif IsUsableSpell then
        usable, noMana = IsUsableSpell(spellID)
    else
        return false
    end

    return usable and not noMana
end

local function IsSpellKnownByPlayer(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(spellID)
    elseif IsPlayerSpell then
        return IsPlayerSpell(spellID)
    elseif IsSpellKnown then
        return IsSpellKnown(spellID)
    end

    return GetSpellName(spellID) ~= nil
end

local function IsItemUsable(itemID)
    if GetItemCount(itemID, false, true) <= 0 then
        return false
    end

    local usable, noMana
    if C_Item and C_Item.IsUsableItem then
        usable, noMana = C_Item.IsUsableItem(itemID)
    else
        usable, noMana = IsUsableItem(itemID)
    end

    if not usable or noMana then
        return false
    end

    local start, duration, enabled
    if C_Item and C_Item.GetItemCooldown then
        start, duration, enabled = C_Item.GetItemCooldown(itemID)
    else
        start, duration, enabled = GetItemCooldown(itemID)
    end

    return enabled == 1 and (start == 0 or duration == 0)
end

local function IsItemOwned(itemID)
    return GetItemCount(itemID, false, true) > 0
end

local function GetItemName(itemID)
    if C_Item and C_Item.GetItemNameByID then
        return C_Item.GetItemNameByID(itemID)
    end

    return GetItemInfo(itemID)
end

local function IsFlyingMount(mountID)
    if not C_MountJournal.GetMountInfoExtraByID then
        return false
    end

    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    local db = EasyRandomMount:GetDB()
    return FLYING_MOUNT_TYPES[mountTypeID] == true or (db.allowSkyridingMounts and SKYRIDING_MOUNT_TYPES[mountTypeID] == true)
end

local function IsWaterMount(mountID)
    if not C_MountJournal.GetMountInfoExtraByID then
        return false
    end

    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    return WATER_MOUNT_TYPES[mountTypeID] == true
end

local function IsMountBlacklisted(mountID)
    local db = EasyRandomMount:GetDB()
    return db.blacklistedMounts and (db.blacklistedMounts[mountID] == true or db.blacklistedMounts[tostring(mountID)] == true)
end

local function IsPlayerSubmerged()
    return IsSubmerged and IsSubmerged()
end

local function GetBreathTimerScale()
    if not GetMirrorTimerInfo then
        return
    end

    local timerCount = MIRRORTIMER_NUMTIMERS or 3
    for index = 1, timerCount do
        local timer, _, _, scale = GetMirrorTimerInfo(index)
        if timer == "BREATH" then
            return scale
        end
    end
end

local function IsPlayerSwimmingAtSurface()
    if not IsSwimming or not IsSwimming() then
        return false
    end

    local db = EasyRandomMount:GetDB()
    if not db.preferFlyingAtWaterSurface then
        return false
    end

    local breathScale = GetBreathTimerScale()
    if breathScale and breathScale < 0 then
        return false
    end

    return IsFlyableArea and IsFlyableArea()
end

local function IsPlayerUnderwaterForMounts()
    if not IsPlayerSubmerged() then
        return false
    end

    return not IsPlayerSwimmingAtSurface()
end

local function IsFlyingPreferredHere()
    local db = EasyRandomMount:GetDB()
    if not db.preferFlyingMounts then
        return false
    end

    if IsPlayerSwimmingAtSurface() then
        return true
    end

    if db.preferFlyingOnlyWhenFlyable and IsFlyableArea and not IsFlyableArea() then
        return false
    end

    return true
end

local function IsPlayerMounted()
    if IsMounted and IsMounted() then
        return true
    end

    if C_MountJournal and C_MountJournal.IsMounted and C_MountJournal.IsMounted() then
        return true
    end

    if C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.GetMountInfoByID then
        for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
            local _, _, _, isActive = C_MountJournal.GetMountInfoByID(mountID)
            if isActive then
                return true
            end
        end
    end

    return false
end

local function IsLowLevelMountOverrideActive()
    local level = UnitLevel and UnitLevel("player")
    return level and level >= 1 and level <= 9
end

local function IsLowLevelMount(name)
    if not name then
        return false
    end

    local lowerName = string.lower(name)
    for _, pattern in ipairs(LOW_LEVEL_MOUNT_PATTERNS) do
        if string.find(lowerName, pattern, 1, true) then
            return true
        end
    end

    return false
end

local function IsSlowGroundMount(name)
    if not name then
        return false
    end

    local lowerName = string.lower(name)
    for _, pattern in ipairs(SLOW_GROUND_MOUNT_PATTERNS) do
        if string.find(lowerName, pattern, 1, true) then
            return true
        end
    end

    return false
end

local function IsMountAvailableToCharacter(isCollected, hideOnChar)
    return isCollected and not hideOnChar
end

local function GetMountCacheKey()
    local db = EasyRandomMount:GetDB()
    local flyable = IsFlyableArea and IsFlyableArea() and "1" or "0"
    local swimming = IsSwimming and IsSwimming() and "1" or "0"
    local submerged = IsPlayerSubmerged() and "1" or "0"
    local surface = IsPlayerSwimmingAtSurface() and "1" or "0"
    local level = UnitLevel and UnitLevel("player") or 0

    return table.concat({
        flyable,
        swimming,
        submerged,
        surface,
        tostring(level),
        db.preferFlyingMounts and "1" or "0",
        db.preferWaterMounts and "1" or "0",
        db.preferFlyingAtWaterSurface and "1" or "0",
        db.preferFlyingOnlyWhenFlyable and "1" or "0",
        db.allowSkyridingMounts and "1" or "0",
        db.favoriteMode or "all",
        tostring(db.blacklistRevision or 0),
    }, ":")
end

local function GetUsableMountIDs()
    local cacheKey = GetMountCacheKey()
    local cache = EasyRandomMount.mountCache
    if cache and cache.key == cacheKey then
        return cache.mounts, cache.availableMountCount
    end

    local mounts = {}
    local lowLevelMounts = {}
    local favoriteMounts = {}
    local flyingMounts = {}
    local surfaceFlyingMounts = {}
    local favoriteFlyingMounts = {}
    local favoriteSurfaceFlyingMounts = {}
    local waterMounts = {}
    local favoriteWaterMounts = {}
    local isSwimmingAtSurface = IsPlayerSwimmingAtSurface()
    local isLowLevelOverrideActive = IsLowLevelMountOverrideActive()
    local availableMountCount = 0

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return mounts, availableMountCount
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local name, _, _, _, isUsable, _, isFavorite, _, _, hideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        local isFlyingMount = IsFlyingMount(mountID)
        local isSlowGroundMount = IsSlowGroundMount(name)
        if IsMountAvailableToCharacter(isCollected, hideOnChar) and not IsMountBlacklisted(mountID) then
            availableMountCount = availableMountCount + 1

            if isLowLevelOverrideActive and isUsable and IsLowLevelMount(name) then
                lowLevelMounts[#lowLevelMounts + 1] = mountID
            end

            if isFlyingMount and isSwimmingAtSurface then
                surfaceFlyingMounts[#surfaceFlyingMounts + 1] = mountID
                if isFavorite then
                    favoriteSurfaceFlyingMounts[#favoriteSurfaceFlyingMounts + 1] = mountID
                end
            end

            if isUsable and not isSlowGroundMount then
                mounts[#mounts + 1] = mountID
                if isFavorite then
                    favoriteMounts[#favoriteMounts + 1] = mountID
                end
            end

            if isUsable and isFlyingMount and not isSlowGroundMount then
                flyingMounts[#flyingMounts + 1] = mountID
                if isFavorite then
                    favoriteFlyingMounts[#favoriteFlyingMounts + 1] = mountID
                end
            end

            if isUsable and IsWaterMount(mountID) then
                waterMounts[#waterMounts + 1] = mountID
                if isFavorite then
                    favoriteWaterMounts[#favoriteWaterMounts + 1] = mountID
                end
            end
        end
    end

    local db = EasyRandomMount:GetDB()

    if IsFlyingPreferredHere() and isSwimmingAtSurface and #surfaceFlyingMounts > 0 then
        if db.favoriteMode == "only" and #favoriteSurfaceFlyingMounts > 0 then
            mounts = favoriteSurfaceFlyingMounts
        elseif db.favoriteMode == "prefer" and #favoriteSurfaceFlyingMounts > 0 then
            mounts = favoriteSurfaceFlyingMounts
        elseif db.favoriteMode == "only" then
            -- Keep looking for any usable favorite below.
        else
            mounts = surfaceFlyingMounts
        end

        if mounts == favoriteSurfaceFlyingMounts or mounts == surfaceFlyingMounts then
            EasyRandomMount.mountCache = { key = cacheKey, mounts = mounts, availableMountCount = availableMountCount }
            return mounts, availableMountCount
        end
    end

    if db.preferWaterMounts and IsPlayerUnderwaterForMounts() and #waterMounts > 0 then
        if db.favoriteMode == "only" and #favoriteWaterMounts > 0 then
            mounts = favoriteWaterMounts
        elseif db.favoriteMode == "prefer" and #favoriteWaterMounts > 0 then
            mounts = favoriteWaterMounts
        elseif db.favoriteMode == "only" then
            -- Keep looking for usable favorites in less-specific mount groups.
        else
            mounts = waterMounts
        end

        if mounts == favoriteWaterMounts or mounts == waterMounts then
            EasyRandomMount.mountCache = { key = cacheKey, mounts = mounts, availableMountCount = availableMountCount }
            return mounts, availableMountCount
        end
    end

    if isLowLevelOverrideActive then
        EasyRandomMount.mountCache = { key = cacheKey, mounts = lowLevelMounts, availableMountCount = #lowLevelMounts }
        return lowLevelMounts, #lowLevelMounts
    end

    if IsFlyingPreferredHere() and #flyingMounts > 0 then
        if db.favoriteMode == "only" and #favoriteFlyingMounts > 0 then
            mounts = favoriteFlyingMounts
        elseif db.favoriteMode == "prefer" and #favoriteFlyingMounts > 0 then
            mounts = favoriteFlyingMounts
        elseif db.favoriteMode == "only" then
            -- Keep looking for any usable favorite below.
        else
            mounts = flyingMounts
        end

        if mounts == favoriteFlyingMounts or mounts == flyingMounts then
            EasyRandomMount.mountCache = { key = cacheKey, mounts = mounts, availableMountCount = availableMountCount }
            return mounts, availableMountCount
        end
    end

    if db.favoriteMode == "only" then
        mounts = favoriteMounts
    elseif db.favoriteMode == "prefer" and #favoriteMounts > 0 then
        mounts = favoriteMounts
    end

    EasyRandomMount.mountCache = { key = cacheKey, mounts = mounts, availableMountCount = availableMountCount }
    return mounts, availableMountCount
end

local function RandomIndex(max)
    if math and math.random then
        return math.random(max)
    end

    return random(max)
end

local function NameMatchesPatterns(name, patterns)
    if not name then
        return false
    end

    local lowerName = string.lower(name)
    for _, pattern in ipairs(patterns) do
        if string.find(lowerName, pattern, 1, true) then
            return true
        end
    end

    return false
end

local function GetPreferredServiceMountID(serviceType, mounts)
    local priorityPatterns = SERVICE_MOUNT_PRIORITY_PATTERNS[serviceType]
    if not priorityPatterns or #mounts == 0 then
        return mounts[RandomIndex(#mounts)]
    end

    for _, pattern in ipairs(priorityPatterns) do
        for _, mountID in ipairs(mounts) do
            local name = C_MountJournal.GetMountInfoByID(mountID)
            if NameMatchesPatterns(name, { pattern }) then
                return mountID
            end
        end
    end

    return mounts[RandomIndex(#mounts)]
end

local function GetPlayerClassFileName()
    local class = UnitClassBase and UnitClassBase("player")
    if class and COMBAT_SPELLS_BY_CLASS[class] then
        return class
    end

    if UnitClass then
        local _, englishClass = UnitClass("player")
        if englishClass and COMBAT_SPELLS_BY_CLASS[englishClass] then
            return englishClass
        end
    end

    return class
end

local function GetCombatMacroText()
    local class = GetPlayerClassFileName()
    local spellIDs = class and COMBAT_SPELLS_BY_CLASS[class]
    local lines = {
        "/dismount",
        "/stopmacro [mounted]",
    }

    if EasyRandomMount:GetDB().combatFallbackEnabled then
        for _, spellID in ipairs(spellIDs or {}) do
            local spellName = GetSpellName(spellID)
            if spellName then
                if spellID == 130 or spellID == 1706 then
                    lines[#lines + 1] = "/cast [@player,falling] " .. spellName
                else
                    lines[#lines + 1] = "/cast " .. spellName
                end
            end
        end
    end

    lines[#lines + 1] = "/leavevehicle"
    return table.concat(lines, "\n")
end

local function GetDismountMacroText()
    return "/dismount"
end

local function GetDruidTravelFormSpellName()
    if GetPlayerClassFileName() ~= "DRUID" or not IsSpellKnownByPlayer(DRUID_TRAVEL_FORM_SPELL_ID) then
        return
    end

    return GetSpellName(DRUID_TRAVEL_FORM_SPELL_ID)
end

local function IsPlayerMoving()
    if not GetUnitSpeed then
        return false
    end

    return (GetUnitSpeed("player") or 0) > 0
end

local function SetSecureSpellAction(button, spellName)
    button:SetAttribute("type", "spell")
    button:SetAttribute("type1", "spell")
    button:SetAttribute("*type1", "spell")
    button:SetAttribute("macrotext", nil)
    button:SetAttribute("macrotext1", nil)
    button:SetAttribute("*macrotext1", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("item1", nil)
    button:SetAttribute("*item1", nil)
    button:SetAttribute("spell", spellName)
    button:SetAttribute("spell1", spellName)
    button:SetAttribute("*spell1", spellName)
    button:SetAttribute("unit", "player")
    button:SetAttribute("unit1", "player")
    button:SetAttribute("*unit1", "player")
end

function ERM:GetDB()
    EasyRandomMountDB = CopyDefaults(DEFAULTS, EasyRandomMountDB)
    return EasyRandomMountDB
end

function ERM:Print(message)
    print("|cff3dd6d0EasyRandomMount|r " .. tostring(message))
end

function ERM:PrintThrottled(key, message, seconds)
    local now = GetTime and GetTime() or time()
    self.printThrottle = self.printThrottle or {}
    if self.printThrottle[key] and now - self.printThrottle[key] < (seconds or 3) then
        return
    end

    self.printThrottle[key] = now
    self:Print(message)
end

function ERM:ClearMountCache()
    self.mountCache = nil
end

function ERM:GetMountName(mountID)
    if C_MountJournal and C_MountJournal.GetMountInfoByID then
        local name = C_MountJournal.GetMountInfoByID(mountID)
        return name
    end
end

function ERM:GetActiveMountID()
    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local _, _, _, isActive = C_MountJournal.GetMountInfoByID(mountID)
        if isActive then
            return mountID
        end
    end
end

function ERM:SetMountBlacklisted(mountID, isBlacklisted)
    mountID = tonumber(mountID)
    if not mountID then
        return
    end

    local db = self:GetDB()
    db.blacklistedMounts[mountID] = isBlacklisted and true or nil
    db.blacklistedMounts[tostring(mountID)] = nil
    db.blacklistRevision = (db.blacklistRevision or 0) + 1
    self:ClearMountCache()
end

function ERM:GetFavoriteModeLabel()
    local mode = self:GetDB().favoriteMode
    if mode == "only" then
        return "Only favorites"
    elseif mode == "prefer" then
        return "Prefer favorites"
    end

    return "All mounts"
end

function ERM:CycleFavoriteMode()
    local db = self:GetDB()
    if db.favoriteMode == "all" then
        db.favoriteMode = "prefer"
    elseif db.favoriteMode == "prefer" then
        db.favoriteMode = "only"
    else
        db.favoriteMode = "all"
    end

    self:ClearMountCache()
    return db.favoriteMode
end

function ERM:IsMountBlacklisted(mountID)
    return IsMountBlacklisted(mountID)
end

function ERM:GetFallingAction()
    local db = self:GetDB()
    if not db.fallingEnabled or not IsFalling() then
        return
    end

    if InCombatLockdown() then
        return "blocked"
    end

    local hasKnownOrOwnedAction = false
    for _, action in ipairs(db.falling) do
        if action.type == "spell" and IsSpellKnownByPlayer(action.id) then
            hasKnownOrOwnedAction = true
            local spellName = GetSpellName(action.id)
            if spellName then
                return "spell", spellName
            end
        elseif action.type == "item" and IsItemOwned(action.id) then
            hasKnownOrOwnedAction = true
            if IsItemUsable(action.id) then
                local itemName = GetItemName(action.id)
                if itemName then
                    return "item", itemName
                end
            end
        end
    end

    return hasKnownOrOwnedAction and "unusable" or "missing"
end

function ERM:GetServiceMountIDs(serviceType)
    local patterns = SERVICE_MOUNT_PATTERNS[serviceType]
    local mounts = {}
    local matchingMountCount = 0

    if not patterns or not C_MountJournal or not C_MountJournal.GetMountIDs then
        return mounts, matchingMountCount
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local name, _, _, _, isUsable, _, _, _, _, hideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        if IsMountAvailableToCharacter(isCollected, hideOnChar) and not IsMountBlacklisted(mountID) and NameMatchesPatterns(name, patterns) then
            matchingMountCount = matchingMountCount + 1
            if isUsable then
                mounts[#mounts + 1] = mountID
            end
        end
    end

    return mounts, matchingMountCount
end

function ERM:SummonServiceMount(serviceType)
    if IsPlayerMounted() then
        Dismount()
        return
    end

    if InCombatLockdown() then
        self:PrintThrottled("serviceMountCombat", "Cannot summon a mount while in combat.", 3)
        return
    end

    local mounts, matchingMountCount = self:GetServiceMountIDs(serviceType)
    if #mounts == 0 then
        local label = serviceType == "auctionHouse" and "auction house" or "repair"
        if matchingMountCount > 0 then
            self:PrintThrottled(serviceType .. "MountUnavailable", "Your " .. label .. " mount is not available here right now.", 3)
        else
            self:PrintThrottled(serviceType .. "MountMissing", "No " .. label .. " mount found.", 3)
        end
        return
    end

    local mountID = GetPreferredServiceMountID(serviceType, mounts)
    self:GetDB().lastMountID = mountID
    C_MountJournal.SummonByID(mountID)
end

function ERM:SummonRandomMount()
    if IsPlayerMounted() then
        Dismount()
        return
    end

    if InCombatLockdown() then
        self:PrintThrottled("randomMountCombat", "Cannot summon a mount while in combat.", 3)
        return
    end

    local mounts, availableMountCount = GetUsableMountIDs()
    if #mounts == 0 then
        if availableMountCount > 0 then
            self:PrintThrottled("mountingNotAllowed", "Mounting is not allowed here right now.", 3)
        else
            self:PrintThrottled("noUsableMounts", "No usable mounts found with the current filters.", 3)
        end
        return
    end

    local mountID = mounts[RandomIndex(#mounts)]
    self:GetDB().lastMountID = mountID
    C_MountJournal.SummonByID(mountID)
end

function ERM:Use()
    self:SummonRandomMount()
end

function ERM:SecureButtonPreClick(button)
    button.easyRandomMountSkipInsecure = false
    button.easyRandomMountWasMounted = IsPlayerMounted()

    if InCombatLockdown() then
        button.easyRandomMountSkipInsecure = true
        return
    end

    button:SetAttribute("spell", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("unit", "player")

    if button.easyRandomMountWasMounted then
        return
    end

    if button.easyRandomMountMode ~= "random" then
        return
    end

    local actionType, value = self:GetFallingAction()
    if actionType == "spell" then
        SetSecureSpellAction(button, value)
        button.easyRandomMountSkipInsecure = true
    elseif actionType == "item" then
        button:SetAttribute("type", "item")
        button:SetAttribute("type1", "item")
        button:SetAttribute("*type1", "item")
        button:SetAttribute("macrotext", nil)
        button:SetAttribute("macrotext1", nil)
        button:SetAttribute("*macrotext1", nil)
        button:SetAttribute("item", value)
        button:SetAttribute("item1", value)
        button:SetAttribute("*item1", value)
        button:SetAttribute("unit", "player")
        button:SetAttribute("unit1", "player")
        button:SetAttribute("*unit1", "player")
        button.easyRandomMountSkipInsecure = true
    elseif actionType == "blocked" then
        button.easyRandomMountSkipInsecure = true
        self:PrintThrottled("fallingBlocked", "Falling rescue cannot cast spells or use items in combat.", 3)
    elseif actionType == "unusable" then
        button.easyRandomMountSkipInsecure = true
        self:PrintThrottled("fallingUnusable", "No usable falling rescue action found.", 3)
    elseif actionType == "missing" then
        button.easyRandomMountSkipInsecure = true
    elseif not actionType then
        local mounts = GetUsableMountIDs()
        local travelFormName = (#mounts == 0 or IsPlayerMoving()) and GetDruidTravelFormSpellName()
        if travelFormName then
            SetSecureSpellAction(button, travelFormName)
            button.easyRandomMountSkipInsecure = true
        end
    end
end

function ERM:SecureButtonPostClick(button)
    if InCombatLockdown() then
        return
    end

    button:SetAttribute("spell", nil)
    button:SetAttribute("spell1", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("item1", nil)
    button:SetAttribute("type", "macro")
    button:SetAttribute("type1", "macro")
    button:SetAttribute("*type1", "macro")
    button:SetAttribute("macrotext", GetDismountMacroText())
    button:SetAttribute("macrotext1", GetDismountMacroText())
    button:SetAttribute("*macrotext1", GetDismountMacroText())
    button:SetAttribute("unit", "player")
    button:SetAttribute("unit1", "player")
    button:SetAttribute("*unit1", "player")
end

function ERM:SecureButtonOnClick(button)
    if button.easyRandomMountSkipInsecure then
        return
    end

    if button.easyRandomMountWasMounted then
        if not InCombatLockdown() and IsPlayerMounted() then
            Dismount()
        end
        return
    end

    if button.easyRandomMountMode == "repair" then
        self:SummonServiceMount("repair")
    elseif button.easyRandomMountMode == "auctionHouse" then
        self:SummonServiceMount("auctionHouse")
    else
        self:Use()
    end
end

function ERM:SetupCombatSecureButton(button)
    button:SetAttribute("spell", nil)
    button:SetAttribute("spell1", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("item1", nil)
    button:SetAttribute("type", "macro")
    button:SetAttribute("type1", "macro")
    button:SetAttribute("*type1", "macro")
    button:SetAttribute("macrotext", GetCombatMacroText())
    button:SetAttribute("macrotext1", GetCombatMacroText())
    button:SetAttribute("*macrotext1", GetCombatMacroText())
    button:SetAttribute("unit", "player")
    button:SetAttribute("unit1", "player")
    button:SetAttribute("*unit1", "player")
    button.easyRandomMountSkipInsecure = true
end

function ERM:SetupDismountSecureButton(button)
    button:SetAttribute("spell", nil)
    button:SetAttribute("spell1", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("item1", nil)
    button:SetAttribute("type", "macro")
    button:SetAttribute("type1", "macro")
    button:SetAttribute("*type1", "macro")
    button:SetAttribute("macrotext", GetDismountMacroText())
    button:SetAttribute("macrotext1", GetDismountMacroText())
    button:SetAttribute("*macrotext1", GetDismountMacroText())
    button:SetAttribute("unit", "player")
    button:SetAttribute("unit1", "player")
    button:SetAttribute("*unit1", "player")
    button.easyRandomMountSkipInsecure = false
end

function ERM:MigrateServiceKeybindings()
    if not GetBindingKey or not SetBindingClick or InCombatLockdown() then
        return
    end

    local changed = false
    local migrations = {
        EASYRANDOMMOUNT_REPAIR = "EasyRandomMountRepairSecureButton",
        EASYRANDOMMOUNT_AUCTIONHOUSE = "EasyRandomMountAuctionHouseSecureButton",
    }

    for oldBindingName, buttonName in pairs(migrations) do
        local key1, key2 = GetBindingKey(oldBindingName)
        for _, key in ipairs({ key1, key2 }) do
            if key and SetBindingClick(key, buttonName, "LeftButton") then
                changed = true
            end
        end
    end

    if changed and SaveBindings and GetCurrentBindingSet then
        SaveBindings(GetCurrentBindingSet())
    end
end

SLASH_EASYRANDOMMOUNT1 = "/erm"
SLASH_EASYRANDOMMOUNT2 = "/easyrandommount"
SlashCmdList.EASYRANDOMMOUNT = function(input)
    input = (input or ""):lower()

    if input == "falling" then
        local db = ERM:GetDB()
        db.fallingEnabled = not db.fallingEnabled
        ERM:Print("Falling rescue is now " .. (db.fallingEnabled and "enabled." or "disabled."))
        if ERM.RefreshOptions then
            ERM:RefreshOptions()
        end
        return
    end

    if input == "combat" then
        local db = ERM:GetDB()
        db.combatFallbackEnabled = not db.combatFallbackEnabled
        ERM:Print("Combat class abilities are now " .. (db.combatFallbackEnabled and "enabled." or "disabled."))
        if ERM.RefreshOptions then
            ERM:RefreshOptions()
        end
        return
    end

    if input == "flying" then
        local db = ERM:GetDB()
        db.preferFlyingMounts = not db.preferFlyingMounts
        ERM:Print("Flying mount preference is now " .. (db.preferFlyingMounts and "enabled." or "disabled."))
        if ERM.RefreshOptions then
            ERM:RefreshOptions()
        end
        return
    end

    if input == "water" then
        local db = ERM:GetDB()
        db.preferWaterMounts = not db.preferWaterMounts
        ERM:Print("Water mount preference is now " .. (db.preferWaterMounts and "enabled." or "disabled."))
        if ERM.RefreshOptions then
            ERM:RefreshOptions()
        end
        return
    end

    if input == "surface" then
        local db = ERM:GetDB()
        db.preferFlyingAtWaterSurface = not db.preferFlyingAtWaterSurface
        ERM:Print("Flying at water surface is now " .. (db.preferFlyingAtWaterSurface and "enabled." or "disabled."))
        if ERM.RefreshOptions then
            ERM:RefreshOptions()
        end
        return
    end

    if input == "flyable" then
        local db = ERM:GetDB()
        db.preferFlyingOnlyWhenFlyable = not db.preferFlyingOnlyWhenFlyable
        ERM:Print("Only prefer flying in flyable areas is now " .. (db.preferFlyingOnlyWhenFlyable and "enabled." or "disabled."))
        if ERM.RefreshOptions then
            ERM:RefreshOptions()
        end
        return
    end

    if input == "skyriding" then
        local db = ERM:GetDB()
        db.allowSkyridingMounts = not db.allowSkyridingMounts
        ERM:Print("Skyriding mounts are now " .. (db.allowSkyridingMounts and "allowed." or "ignored."))
        if ERM.RefreshOptions then
            ERM:RefreshOptions()
        end
        return
    end

    if input == "favorites" then
        ERM:CycleFavoriteMode()
        ERM:Print("Favorite mode: " .. ERM:GetFavoriteModeLabel() .. ".")
        if ERM.RefreshOptions then
            ERM:RefreshOptions()
        end
        return
    end

    if input == "debug" then
        local db = ERM:GetDB()
        db.debugEnabled = not db.debugEnabled
        ERM:Print("Debug mode is now " .. (db.debugEnabled and "enabled." or "disabled."))
        if ERM.RefreshOptions then
            ERM:RefreshOptions()
        end
        return
    end

    if input == "debugjournal" and ERM:GetDB().debugEnabled and ERM.DebugMountJournalFocus then
        ERM:DebugMountJournalFocus()
        return
    end

    if input == "debugjournal" then
        ERM:Print("Debug commands are disabled. Use /erm debug first.")
        return
    end

    if input == "repair" then
        ERM:SummonServiceMount("repair")
        return
    end

    if input == "ah" or input == "auctionhouse" then
        ERM:SummonServiceMount("auctionHouse")
        return
    end

    local blacklistID = input:match("^blacklist%s+(%d+)$")
    if blacklistID then
        local mountID = tonumber(blacklistID)
        ERM:SetMountBlacklisted(mountID, true)
        ERM:Print("Blacklisted mount " .. (ERM:GetMountName(mountID) or mountID) .. ".")
        if ERM.RefreshOptions then
            ERM:RefreshOptions()
        end
        return
    end

    if input == "blacklistcurrent" then
        local mountID = ERM:GetActiveMountID()
        if not mountID then
            ERM:Print("No active mount found.")
            return
        end

        ERM:SetMountBlacklisted(mountID, true)
        ERM:Print("Blacklisted mount " .. (ERM:GetMountName(mountID) or mountID) .. ".")
        if ERM.RefreshOptions then
            ERM:RefreshOptions()
        end
        return
    end

    if input == "blacklistlast" then
        local mountID = ERM:GetDB().lastMountID
        if not mountID then
            ERM:Print("No last random mount found yet.")
            return
        end

        ERM:SetMountBlacklisted(mountID, true)
        ERM:Print("Blacklisted last random mount " .. (ERM:GetMountName(mountID) or mountID) .. ".")
        if ERM.RefreshOptions then
            ERM:RefreshOptions()
        end
        return
    end

    local unblacklistID = input:match("^unblacklist%s+(%d+)$")
    if unblacklistID then
        local mountID = tonumber(unblacklistID)
        ERM:SetMountBlacklisted(mountID, false)
        ERM:Print("Removed mount " .. (ERM:GetMountName(mountID) or mountID) .. " from the blacklist.")
        if ERM.RefreshOptions then
            ERM:RefreshOptions()
        end
        return
    end

    if input == "options" and Settings and Settings.OpenToCategory and ERM.settingsCategoryID then
        Settings.OpenToCategory(ERM.settingsCategoryID)
        return
    end

    if input == "options" and InterfaceOptionsFrame_OpenToCategory and ERM.optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(ERM.optionsPanel)
        return
    end

    ERM:Print("/erm - use random mount")
    ERM:Print("/erm repair - summon a repair mount")
    ERM:Print("/erm ah - summon an auction house mount")
    ERM:Print("/erm falling - toggle falling rescue")
    ERM:Print("/erm combat - toggle combat class abilities")
    ERM:Print("/erm flying - toggle flying mount preference")
    ERM:Print("/erm water - toggle water mount preference")
    ERM:Print("/erm surface - toggle flying at water surface")
    ERM:Print("/erm favorites - cycle favorite mode")
    ERM:Print("/erm skyriding - toggle skyriding mounts")
    ERM:Print("/erm flyable - toggle flying only in flyable areas")
    ERM:Print("/erm blacklist <mountID> - never summon this mount")
    ERM:Print("/erm blacklistcurrent - blacklist your active mount")
    ERM:Print("/erm blacklistlast - blacklist the last random mount")
    ERM:Print("/erm unblacklist <mountID> - allow this mount again")
    ERM:Print("/erm options - open options")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("COMPANION_UPDATE")
frame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event ~= "ADDON_LOADED" then
        ERM:ClearMountCache()
        return
    end

    if loadedAddonName ~= addonName then
        return
    end

    ERM:GetDB()
    ERM:MigrateServiceKeybindings()
    if math and math.randomseed and time then
        math.randomseed(time())
    end
end)

local function CreateEasyRandomMountSecureButton(name, mode)
    local button = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    button.easyRandomMountMode = mode
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetScript("PreClick", function(self)
        ERM:SecureButtonPreClick(self)
    end)
    button:HookScript("OnClick", function(self)
        ERM:SecureButtonOnClick(self)
    end)
    button:SetScript("PostClick", function(self)
        ERM:SecureButtonPostClick(self)
    end)
    button:RegisterEvent("PLAYER_REGEN_DISABLED")
    button:RegisterEvent("PLAYER_REGEN_ENABLED")
    button:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            ERM:SetupCombatSecureButton(self)
        elseif event == "PLAYER_REGEN_ENABLED" then
            ERM:SetupDismountSecureButton(self)
        end
    end)

    ERM:SetupDismountSecureButton(button)
    return button
end

CreateEasyRandomMountSecureButton("EasyRandomMountSecureButton", "random")
CreateEasyRandomMountSecureButton("EasyRandomMountRepairSecureButton", "repair")
CreateEasyRandomMountSecureButton("EasyRandomMountAuctionHouseSecureButton", "auctionHouse")
