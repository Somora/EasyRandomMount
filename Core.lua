local addonName = ...

EasyRandomMount = EasyRandomMount or {}
local ERM = EasyRandomMount

BINDING_HEADER_EASYRANDOMMOUNT = "EasyRandomMount"
BINDING_NAME_EASYRANDOMMOUNT_RANDOM = "Summon random mount"

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

local function CastSpell(spellID)
    if C_Spell and C_Spell.CastSpellByID then
        C_Spell.CastSpellByID(spellID)
    elseif CastSpellByID then
        CastSpellByID(spellID)
    end
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

local function UseItem(itemID)
    if C_Item and C_Item.UseItemByID then
        C_Item.UseItemByID(itemID)
    else
        UseItemByName(GetItemInfo(itemID) or itemID)
    end
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

local function GetUsableMountIDs()
    local mounts = {}
    local favoriteMounts = {}
    local flyingMounts = {}
    local surfaceFlyingMounts = {}
    local favoriteFlyingMounts = {}
    local favoriteSurfaceFlyingMounts = {}
    local waterMounts = {}
    local favoriteWaterMounts = {}
    local isSwimmingAtSurface = IsPlayerSwimmingAtSurface()
    local availableMountCount = 0

    if not C_MountJournal or not C_MountJournal.GetMountIDs then
        return mounts, availableMountCount
    end

    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local _, _, _, _, isUsable, _, isFavorite, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
        local isFlyingMount = IsFlyingMount(mountID)
        if isCollected and not IsMountBlacklisted(mountID) then
            availableMountCount = availableMountCount + 1

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

function ERM:TryFallingAction()
    local db = self:GetDB()
    if not db.fallingEnabled or not IsFalling() then
        return false
    end

    for _, action in ipairs(db.falling) do
        if action.type == "spell" and IsSpellUsable(action.id) then
            CastSpell(action.id)
            return true
        elseif action.type == "item" and IsItemUsable(action.id) then
            UseItem(action.id)
            return true
        end
    end

    return false
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
    if self:TryFallingAction() then
        return
    end

    self:SummonRandomMount()
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
