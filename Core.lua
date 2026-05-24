local addonName = ...

EasyRandomMount = EasyRandomMount or {}
local ERM = EasyRandomMount

BINDING_HEADER_EASYRANDOMMOUNT = "EasyRandomMount"
_G["BINDING_NAME_CLICK EasyRandomMountSecureButton:LeftButton"] = "Summon random mount"
BINDING_NAME_EASYRANDOMMOUNT_REPAIR = "Summon repair mount"
BINDING_NAME_EASYRANDOMMOUNT_AUCTIONHOUSE = "Summon auction house mount"

local DEFAULTS = {
    fallingEnabled = true,
    preferFlyingMounts = true,
    preferWaterMounts = true,
    preferFlyingAtWaterSurface = true,
    preferFlyingOnlyWhenFlyable = true,
    allowSkyridingMounts = true,
    favoriteMode = "all",
    debugEnabled = false,
    lastMountID = nil,
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

local LOW_LEVEL_MOUNT_PATTERNS = {
    "chauffeured mekgineer's chopper",
    "chauffeured mechano-hog",
}

local COMBAT_SPELLS_BY_CLASS = {
    DEATHKNIGHT = { 218999 }, -- Wraith Walk
    DEMONHUNTER = { 192611 }, -- Fel Rush
    DRUID = { 783 }, -- Travel Form
    EVOKER = { 358267 }, -- Hover
    HUNTER = { 186257 }, -- Aspect of the Cheetah
    MAGE = { 130, 1953 }, -- Slow Fall, Blink
    MONK = { 109132 }, -- Roll
    PALADIN = { 190784 }, -- Divine Steed
    PRIEST = { 1706, 121536 }, -- Levitate, Angelic Feather
    ROGUE = { 2983 }, -- Sprint
    SHAMAN = { 2645, 192063, 58875 }, -- Ghost Wolf, Gust of Wind, Spirit Walk
    WARLOCK = { 111400 }, -- Burning Rush
    WARRIOR = { 6544 }, -- Heroic Leap
}

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

    return C_MountJournal and C_MountJournal.IsMounted and C_MountJournal.IsMounted()
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

local function GetUsableMountIDs()
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
        local name, _, _, _, isUsable, _, isFavorite, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        local isFlyingMount = IsFlyingMount(mountID)
        if isCollected and not IsMountBlacklisted(mountID) then
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

            if isUsable then
                mounts[#mounts + 1] = mountID
                if isFavorite then
                    favoriteMounts[#favoriteMounts + 1] = mountID
                end
            end

            if isUsable and isFlyingMount then
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
            return favoriteSurfaceFlyingMounts, availableMountCount
        elseif db.favoriteMode == "prefer" and #favoriteSurfaceFlyingMounts > 0 then
            return favoriteSurfaceFlyingMounts, availableMountCount
        elseif db.favoriteMode == "only" then
            -- Keep looking for any usable favorite below.
        else
            return surfaceFlyingMounts, availableMountCount
        end
    end

    if db.preferWaterMounts and IsPlayerUnderwaterForMounts() and #waterMounts > 0 then
        if db.favoriteMode == "only" and #favoriteWaterMounts > 0 then
            return favoriteWaterMounts, availableMountCount
        elseif db.favoriteMode == "prefer" and #favoriteWaterMounts > 0 then
            return favoriteWaterMounts, availableMountCount
        elseif db.favoriteMode == "only" then
            -- Keep looking for usable favorites in less-specific mount groups.
        else
            return waterMounts, availableMountCount
        end
    end

    if isLowLevelOverrideActive then
        return lowLevelMounts, #lowLevelMounts
    end

    if IsFlyingPreferredHere() and #flyingMounts > 0 then
        if db.favoriteMode == "only" and #favoriteFlyingMounts > 0 then
            return favoriteFlyingMounts, availableMountCount
        elseif db.favoriteMode == "prefer" and #favoriteFlyingMounts > 0 then
            return favoriteFlyingMounts, availableMountCount
        elseif db.favoriteMode == "only" then
            -- Keep looking for any usable favorite below.
        else
            return flyingMounts, availableMountCount
        end
    end

    if db.favoriteMode == "only" then
        return favoriteMounts, availableMountCount
    elseif db.favoriteMode == "prefer" and #favoriteMounts > 0 then
        return favoriteMounts, availableMountCount
    end

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
        "/dismount [mounted]",
        "/stopmacro [mounted]",
    }

    for _, spellID in ipairs(spellIDs or {}) do
        local spellName = GetSpellName(spellID)
        if spellName then
            if spellID == 130 or spellID == 1706 then
                lines[#lines + 1] = "/cast [@player,falling] " .. spellName
            elseif class == "PRIEST" or spellID == 121536 then
                lines[#lines + 1] = "/cast [@player,nofalling] " .. spellName
            elseif spellID == 6544 then
                lines[#lines + 1] = "/cast [@cursor] " .. spellName
            elseif spellID == 1953 then
                lines[#lines + 1] = "/cast [nofalling] " .. spellName
            else
                lines[#lines + 1] = "/cast " .. spellName
            end
        end
    end

    lines[#lines + 1] = "/leavevehicle"
    return table.concat(lines, "\n")
end

function ERM:GetDB()
    EasyRandomMountDB = CopyDefaults(DEFAULTS, EasyRandomMountDB)
    return EasyRandomMountDB
end

function ERM:Print(message)
    print("|cff3dd6d0EasyRandomMount|r " .. tostring(message))
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
        self:Print("Falling rescue cannot cast spells or use items in combat.")
        return "blocked"
    end

    for _, action in ipairs(db.falling) do
        if action.type == "spell" and IsSpellKnownByPlayer(action.id) then
            local spellName = GetSpellName(action.id)
            if spellName then
                return "spell", spellName
            end
        elseif action.type == "item" and IsItemUsable(action.id) then
            local itemName = GetItemName(action.id)
            if itemName then
                return "item", itemName
            end
        end
    end
end

function ERM:GetServiceMountIDs(serviceType)
    local patterns = SERVICE_MOUNT_PATTERNS[serviceType]
    local mounts = {}
    local matchingMountCount = 0

    if not patterns or not C_MountJournal or not C_MountJournal.GetMountIDs then
        return mounts, matchingMountCount
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local name, _, _, _, isUsable, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        if isCollected and not IsMountBlacklisted(mountID) and NameMatchesPatterns(name, patterns) then
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
        self:Print("Cannot summon a mount while in combat.")
        return
    end

    local mounts, matchingMountCount = self:GetServiceMountIDs(serviceType)
    if #mounts == 0 then
        local label = serviceType == "auctionHouse" and "auction house" or "repair"
        if matchingMountCount > 0 then
            self:Print("Your " .. label .. " mount is not available here right now.")
        else
            self:Print("No " .. label .. " mount found.")
        end
        return
    end

    local mountID = mounts[RandomIndex(#mounts)]
    self:GetDB().lastMountID = mountID
    C_MountJournal.SummonByID(mountID)
end

function ERM:SummonRandomMount()
    if IsPlayerMounted() then
        Dismount()
        return
    end

    if InCombatLockdown() then
        self:Print("Cannot summon a mount while in combat.")
        return
    end

    local mounts, availableMountCount = GetUsableMountIDs()
    if #mounts == 0 then
        if availableMountCount > 0 then
            self:Print("Mounting is not allowed here right now.")
        else
            self:Print("No usable mounts found with the current filters.")
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

    if InCombatLockdown() then
        button.easyRandomMountSkipInsecure = true
        return
    end

    button:SetAttribute("type", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("unit", "player")

    local actionType, value = self:GetFallingAction()
    if actionType == "spell" then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", value)
        button:SetAttribute("unit", "player")
        button.easyRandomMountSkipInsecure = true
    elseif actionType == "item" then
        button:SetAttribute("type", "item")
        button:SetAttribute("item", value)
        button:SetAttribute("unit", "player")
        button.easyRandomMountSkipInsecure = true
    elseif actionType == "blocked" then
        button.easyRandomMountSkipInsecure = true
    elseif self:GetDB().fallingEnabled and IsFalling() then
        button.easyRandomMountSkipInsecure = true
        self:Print("No usable falling rescue action found.")
    end
end

function ERM:SecureButtonPostClick(button)
    if InCombatLockdown() then
        return
    end

    button:SetAttribute("type", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("item", nil)
end

function ERM:SecureButtonOnClick(button)
    if button.easyRandomMountSkipInsecure then
        return
    end

    self:Use()
end

function ERM:SetupCombatSecureButton(button)
    button:SetAttribute("spell", nil)
    button:SetAttribute("item", nil)
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext", GetCombatMacroText())
    button:SetAttribute("unit", "player")
    button.easyRandomMountSkipInsecure = true
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
frame:SetScript("OnEvent", function(_, _, loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    ERM:GetDB()
    if math and math.randomseed and time then
        math.randomseed(time())
    end
end)

local secureButton = CreateFrame("Button", "EasyRandomMountSecureButton", UIParent, "SecureActionButtonTemplate")
secureButton:RegisterForClicks("AnyDown")
secureButton:SetScript("PreClick", function(self)
    ERM:SecureButtonPreClick(self)
end)
secureButton:HookScript("OnClick", function(self)
    ERM:SecureButtonOnClick(self)
end)
secureButton:SetScript("PostClick", function(self)
    ERM:SecureButtonPostClick(self)
end)
secureButton:RegisterEvent("PLAYER_REGEN_DISABLED")
secureButton:RegisterEvent("PLAYER_REGEN_ENABLED")
secureButton:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        ERM:SetupCombatSecureButton(self)
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:SetAttribute("type", nil)
        self:SetAttribute("macrotext", nil)
        self:SetAttribute("spell", nil)
        self:SetAttribute("item", nil)
        self:SetAttribute("unit", nil)
        self.easyRandomMountSkipInsecure = false
    end
end)
