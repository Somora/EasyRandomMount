local ERM = EasyRandomMount

local isMountJournalHooked = false
local menuMountID
local menuMountIndex

local menu = CreateFrame("Frame", "EasyRandomMountJournalMenu", UIParent, "UIDropDownMenuTemplate")

local function GetButtonMountInfo(button)
    local mountID = button and button.mountID
    local mountIndex = button and (button.index or button.mountIndex)
    local elementData = button and button.GetElementData and button:GetElementData()

    if elementData then
        mountID = mountID or elementData.mountID or elementData.mountId
        mountIndex = mountIndex or elementData.index or elementData.mountIndex or elementData.displayIndex
    end

    if not mountID and mountIndex and C_MountJournal and C_MountJournal.GetDisplayedMountID then
        mountID = C_MountJournal.GetDisplayedMountID(mountIndex)
    end

    if not mountID and mountIndex and C_MountJournal and C_MountJournal.GetDisplayedMountInfo then
        local _, _, _, _, _, _, _, _, _, _, _, displayedMountID = C_MountJournal.GetDisplayedMountInfo(mountIndex)
        mountID = displayedMountID
    end

    return mountID, mountIndex
end

function ERM:DebugMountJournalFocus()
    local frames = {}
    if GetMouseFoci then
        frames = { GetMouseFoci() }
    elseif GetMouseFocus then
        frames = { GetMouseFocus() }
    end

    if #frames == 0 then
        self:Print("No mouse focus frames found.")
        return
    end

    for index, frame in ipairs(frames) do
        local mountID, mountIndex = GetButtonMountInfo(frame)
        local name = frame.GetName and frame:GetName() or tostring(frame)
        local elementData = frame.GetElementData and frame:GetElementData()

        self:Print("Focus " .. index .. ": " .. tostring(name)
            .. " mountID=" .. tostring(mountID)
            .. " index=" .. tostring(mountIndex)
            .. " hasElementData=" .. tostring(elementData ~= nil))
    end
end

local function GetMountFavoriteState(mountID, mountIndex)
    local _, _, _, _, _, _, isFavorite = C_MountJournal.GetMountInfoByID(mountID)
    local canSetFavorite = true

    if not mountIndex and C_MountJournal.GetMountIDs then
        for index, listedMountID in ipairs(C_MountJournal.GetMountIDs()) do
            if listedMountID == mountID then
                mountIndex = index
                break
            end
        end
    end

    if mountIndex and C_MountJournal.GetIsFavorite then
        isFavorite, canSetFavorite = C_MountJournal.GetIsFavorite(mountIndex)
    end

    return isFavorite, canSetFavorite, mountIndex
end

local function AddMenuButton(text, func, checked, disabled)
    local info = UIDropDownMenu_CreateInfo()
    info.text = text
    info.func = func
    info.checked = checked
    info.disabled = disabled
    info.isNotRadio = true
    info.notCheckable = true
    info.minWidth = 220
    info.padding = 16
    info.leftPadding = 16
    UIDropDownMenu_AddButton(info, 1)
end

local function InitializeMenu()
    local mountID = menuMountID
    local mountIndex = menuMountIndex
    if not mountID then
        return
    end

    local mountName = ERM:GetMountName(mountID) or "Mount"
    local isFavorite, canSetFavorite, favoriteMountIndex = GetMountFavoriteState(mountID, mountIndex)
    local isBlacklisted = ERM:IsMountBlacklisted(mountID)

    AddMenuButton("Mount", function()
        C_MountJournal.SummonByID(mountID)
    end)

    AddMenuButton(isFavorite and "Remove Favorite" or "Set Favorite", function()
        if favoriteMountIndex and C_MountJournal.SetIsFavorite then
            C_MountJournal.SetIsFavorite(favoriteMountIndex, not isFavorite)
        end
    end, isFavorite, not favoriteMountIndex or not canSetFavorite)

    AddMenuButton(isBlacklisted and "Remove from EasyRandomMount blacklist" or "Blacklist in EasyRandomMount", function()
        ERM:SetMountBlacklisted(mountID, not ERM:IsMountBlacklisted(mountID))

        if ERM:IsMountBlacklisted(mountID) then
            ERM:Print("Blacklisted mount " .. mountName .. ".")
        else
            ERM:Print("Removed mount " .. mountName .. " from the blacklist.")
        end

        if ERM.RefreshOptions then
            ERM:RefreshOptions()
        end
    end, isBlacklisted)
end

local function ShowMenu(button, mountID, mountIndex)
    menuMountID = mountID
    menuMountIndex = mountIndex
    UIDropDownMenu_Initialize(menu, InitializeMenu, "MENU")
    ToggleDropDownMenu(1, nil, menu, "cursor", 3, -3)
end

local function HookMountButton(button)
    if not button or button.EasyRandomMountHooked then
        return
    end

    if not button.GetScript or not button.SetScript then
        return
    end

    if not (button.mountID or button.index or button.mountIndex or button.GetElementData) then
        return
    end

    if not button.HasScript or button:HasScript("OnClick") then
        local originalOnClick = button:GetScript("OnClick")
        button:SetScript("OnClick", function(self, mouseButton, ...)
            if mouseButton == "RightButton" then
                local mountID, mountIndex = GetButtonMountInfo(self)
                if mountID then
                    ShowMenu(self, mountID, mountIndex)
                    return
                end
            end

            if originalOnClick then
                originalOnClick(self, mouseButton, ...)
            end
        end)
    end

    if not button.HasScript or button:HasScript("OnMouseDown") then
        local originalOnMouseDown = button:GetScript("OnMouseDown")
        button:SetScript("OnMouseDown", function(self, mouseButton, ...)
            if mouseButton == "RightButton" then
                local mountID, mountIndex = GetButtonMountInfo(self)
                if mountID then
                    ShowMenu(self, mountID, mountIndex)
                    return
                end
            end

            if originalOnMouseDown then
                originalOnMouseDown(self, mouseButton, ...)
            end
        end)
    end

    button.EasyRandomMountHooked = true
end

local function HookFrameTree(frame)
    if not frame or not frame.GetChildren then
        return
    end

    HookMountButton(frame)

    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        HookFrameTree(child)
    end
end

local function HookMountJournalButtons()
    if not MountJournal then
        return
    end

    if MountJournal.ScrollBox and MountJournal.ScrollBox.ForEachFrame then
        MountJournal.ScrollBox:ForEachFrame(HookMountButton)
    end

    if MountJournal.ListScrollFrame and MountJournal.ListScrollFrame.buttons then
        for _, button in ipairs(MountJournal.ListScrollFrame.buttons) do
            HookMountButton(button)
        end
    end

    HookFrameTree(MountJournal)
end

local function HookMountJournal()
    if not MountJournal then
        return
    end

    HookMountJournalButtons()

    if not isMountJournalHooked and hooksecurefunc and MountJournal_UpdateMountList then
        hooksecurefunc("MountJournal_UpdateMountList", HookMountJournalButtons)
        isMountJournalHooked = true
    end

    if not isMountJournalHooked and MountJournal.ScrollBox and MountJournal.ScrollBox.SetScript then
        MountJournal.ScrollBox:HookScript("OnShow", HookMountJournalButtons)
        isMountJournalHooked = true
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName == "Blizzard_Collections" then
        HookMountJournal()
    elseif event == "PLAYER_LOGIN" then
        HookMountJournal()
    end
end)

C_Timer.After(1, HookMountJournal)
C_Timer.After(3, HookMountJournal)
