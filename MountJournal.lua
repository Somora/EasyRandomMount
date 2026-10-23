local ERM = EasyRandomMount

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
        frames = GetMouseFoci() or {}
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

-- Extend Blizzard's menu without replacing its row scripts or mount/favorite actions.
if Menu and Menu.ModifyMenu then
    Menu.ModifyMenu("MENU_MOUNT_COLLECTION_MOUNT", function(owner, rootDescription, mountIndex)
        local mountID
        if type(mountIndex) == "number" then
            mountID = select(12, C_MountJournal.GetDisplayedMountInfo(mountIndex))
        else
            mountID = GetButtonMountInfo(owner)
            if not mountID and owner and owner.GetParent then
                mountID = GetButtonMountInfo(owner:GetParent())
            end
        end
        if not mountID then
            return
        end

        rootDescription:CreateDivider()
        rootDescription:CreateCheckbox("EasyRandomMount blacklist", function()
            return ERM:IsMountBlacklisted(mountID)
        end, function()
            ERM:SetMountBlacklisted(mountID, not ERM:IsMountBlacklisted(mountID))
            if ERM.RefreshOptions then
                ERM:RefreshOptions()
            end
        end)
    end)
end
