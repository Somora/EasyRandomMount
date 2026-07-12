local ERM = EasyRandomMount

local fallingRows = {}
local blacklistRows = {}

local function GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        return info and info.name
    end

    return GetSpellInfo and GetSpellInfo(spellID)
end

local function GetActionLabel(action)
    local icon
    if action.type == "item" then
        icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(action.id) or GetItemIcon(action.id)
    else
        icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(action.id) or GetSpellTexture(action.id)
    end

    local iconText = icon and ("|T" .. icon .. ":16:16:0:0|t ") or ""
    return iconText .. (action.name or action.type .. ":" .. action.id)
end

local function GetMountLabel(mountID)
    local name, _, icon
    if C_MountJournal and C_MountJournal.GetMountInfoByID then
        name, _, icon = C_MountJournal.GetMountInfoByID(mountID)
    end

    local iconText = icon and ("|T" .. icon .. ":16:16:0:0|t ") or ""
    return iconText .. (name or ("Mount " .. mountID)) .. " |cff888888(" .. mountID .. ")|r"
end

local function GetSortedBlacklistedMountIDs(blacklistedMounts)
    local mountIDs = {}
    local seen = {}
    for mountID, isBlacklisted in pairs(blacklistedMounts or {}) do
        local numericMountID = tonumber(mountID)
        if isBlacklisted and numericMountID and not seen[numericMountID] then
            seen[numericMountID] = true
            mountIDs[#mountIDs + 1] = numericMountID
        end
    end

    table.sort(mountIDs, function(left, right)
        local leftName = ERM:GetMountName(left) or ""
        local rightName = ERM:GetMountName(right) or ""
        if leftName == rightName then
            return left < right
        end

        return leftName < rightName
    end)

    return mountIDs
end

local function CreateTitle(parent, text)
    local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(text)
    return title
end

local function CreateButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 90, 24)
    button:SetText(text)
    return button
end

local function AddFallingRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(560, 30)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", 6, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWidth(260)

    row.up = CreateButton(row, "Up", 48)
    row.up:SetPoint("RIGHT", -186, 0)

    row.down = CreateButton(row, "Down", 58)
    row.down:SetPoint("LEFT", row.up, "RIGHT", 4, 0)

    row.delete = CreateButton(row, "Delete", 74)
    row.delete:SetPoint("LEFT", row.down, "RIGHT", 4, 0)

    return row
end

local function AddBlacklistRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(540, 30)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", 6, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWidth(400)

    row.delete = CreateButton(row, "Delete", 74)
    row.delete:SetPoint("RIGHT", -6, 0)

    return row
end

local function UpdateBlacklistScroll()
    local panel = ERM.blacklistPanel
    if not panel or not panel.scrollFrame then
        return
    end

    local count = #GetSortedBlacklistedMountIDs(ERM:GetDB().blacklistedMounts)
    local height = math.max(1, count * 34)
    panel.scrollChild:SetHeight(height)

    local maxScroll = math.max(0, height - panel.scrollFrame:GetHeight())
    panel.scrollBar:SetMinMaxValues(0, maxScroll)

    if panel.scrollBar:GetValue() > maxScroll then
        panel.scrollBar:SetValue(maxScroll)
    end

    panel.scrollBar:SetShown(maxScroll > 0)
end

function ERM:RefreshOptions()
    local db = self:GetDB()

    if self.generalPanel then
        self.generalPanel.fallingCheck:SetChecked(db.fallingEnabled)
        self.generalPanel.combatFallbackCheck:SetChecked(db.combatFallbackEnabled)
        self.generalPanel.flyingCheck:SetChecked(db.preferFlyingMounts)
        self.generalPanel.waterCheck:SetChecked(db.preferWaterMounts)
        self.generalPanel.surfaceCheck:SetChecked(db.preferFlyingAtWaterSurface)
        self.generalPanel.flyableCheck:SetChecked(db.preferFlyingOnlyWhenFlyable)
        self.generalPanel.skyridingCheck:SetChecked(db.allowSkyridingMounts)
        self.generalPanel.debugCheck:SetChecked(db.debugEnabled)
        self.generalPanel.favoriteModeButton:SetText("Favorite mode: " .. ERM:GetFavoriteModeLabel())
    end

    if self.fallingPanel then
        for index, action in ipairs(db.falling) do
            local row = fallingRows[index]
            if not row then
                row = AddFallingRow(self.fallingPanel, index)
                row:SetPoint("TOPLEFT", self.fallingPanel.listAnchor, "BOTTOMLEFT", 0, -8 - ((index - 1) * 34))
                fallingRows[index] = row
            end

            row.label:SetText(GetActionLabel(action))
            row.up:SetEnabled(index > 1)
            row.down:SetEnabled(index < #db.falling)
            row:Show()

            row.up:SetScript("OnClick", function()
                db.falling[index], db.falling[index - 1] = db.falling[index - 1], db.falling[index]
                ERM:RefreshOptions()
            end)

            row.down:SetScript("OnClick", function()
                db.falling[index], db.falling[index + 1] = db.falling[index + 1], db.falling[index]
                ERM:RefreshOptions()
            end)

            row.delete:SetScript("OnClick", function()
                table.remove(db.falling, index)
                ERM:RefreshOptions()
            end)
        end

        for index = #db.falling + 1, #fallingRows do
            fallingRows[index]:Hide()
        end
    end

    if self.blacklistPanel then
        local blacklistedMountIDs = GetSortedBlacklistedMountIDs(db.blacklistedMounts)
        self.blacklistPanel.emptyText:SetShown(#blacklistedMountIDs == 0)
        self.blacklistPanel.scrollFrame:SetShown(#blacklistedMountIDs > 0)

        for index, mountID in ipairs(blacklistedMountIDs) do
            local row = blacklistRows[index]
            if not row then
                row = AddBlacklistRow(self.blacklistPanel.scrollChild, index)
                row:SetPoint("TOPLEFT", self.blacklistPanel.scrollChild, "TOPLEFT", 0, -((index - 1) * 34))
                blacklistRows[index] = row
            end

            row.label:SetText(GetMountLabel(mountID))
            row:Show()

            row.delete:SetScript("OnClick", function()
                ERM:SetMountBlacklisted(mountID, false)
                ERM:RefreshOptions()
            end)
        end

        for index = #blacklistedMountIDs + 1, #blacklistRows do
            blacklistRows[index]:Hide()
        end

        UpdateBlacklistScroll()
    end
end

local function AddFallingAction(typeName)
    StaticPopupDialogs.EASYRANDOMMOUNT_ADD_ACTION = {
        text = "Enter " .. typeName .. " ID",
        button1 = OKAY,
        button2 = CANCEL,
        hasEditBox = true,
        OnAccept = function(dialog)
            local editBox = dialog.editBox or dialog.EditBox or (dialog.GetEditBox and dialog:GetEditBox())
            local id = editBox and tonumber(editBox:GetText())
            if not id then
                ERM:Print("Please enter a numeric ID.")
                return
            end

            local name
            if typeName == "item" then
                name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id) or GetItemInfo(id)
            else
                name = GetSpellName(id) or tostring(id)
            end

            local db = ERM:GetDB()
            db.falling[#db.falling + 1] = { type = typeName, id = id, name = name or tostring(id) }
            ERM:RefreshOptions()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopup_Show("EASYRANDOMMOUNT_ADD_ACTION")
end

local function AddBlacklistedMount()
    StaticPopupDialogs.EASYRANDOMMOUNT_ADD_BLACKLISTED_MOUNT = {
        text = "Enter mount ID to blacklist",
        button1 = OKAY,
        button2 = CANCEL,
        hasEditBox = true,
        OnAccept = function(dialog)
            local editBox = dialog.editBox or dialog.EditBox or (dialog.GetEditBox and dialog:GetEditBox())
            local mountID = editBox and tonumber(editBox:GetText())
            if not mountID then
                ERM:Print("Please enter a numeric mount ID.")
                return
            end

            ERM:SetMountBlacklisted(mountID, true)
            ERM:RefreshOptions()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopup_Show("EASYRANDOMMOUNT_ADD_BLACKLISTED_MOUNT")
end

local function BlacklistCurrentMount()
    local mountID = ERM:GetActiveMountID()
    if not mountID then
        ERM:Print("No active mount found.")
        return
    end

    ERM:SetMountBlacklisted(mountID, true)
    ERM:RefreshOptions()
end

local function BlacklistLastMount()
    local mountID = ERM:GetDB().lastMountID
    if not mountID then
        ERM:Print("No last random mount found yet.")
        return
    end

    ERM:SetMountBlacklisted(mountID, true)
    ERM:RefreshOptions()
end

local mainPanel = CreateFrame("Frame")
mainPanel.name = "EasyRandomMount"
ERM.optionsPanel = mainPanel

mainPanel.title = CreateTitle(mainPanel, "EasyRandomMount")

ERM.generalPanel = mainPanel

mainPanel.fallingCheck = CreateFrame("CheckButton", nil, mainPanel, "InterfaceOptionsCheckButtonTemplate")
mainPanel.fallingCheck:SetPoint("TOPLEFT", mainPanel.title, "BOTTOMLEFT", 0, -16)
mainPanel.fallingCheck.Text:SetText("Use falling rescue before summoning a mount")
mainPanel.fallingCheck:SetScript("OnClick", function(self)
    ERM:GetDB().fallingEnabled = self:GetChecked()
end)

mainPanel.combatFallbackCheck = CreateFrame("CheckButton", nil, mainPanel, "InterfaceOptionsCheckButtonTemplate")
mainPanel.combatFallbackCheck:SetPoint("TOPLEFT", mainPanel.fallingCheck, "BOTTOMLEFT", 0, -8)
mainPanel.combatFallbackCheck.Text:SetText("Use class movement abilities in combat")
mainPanel.combatFallbackCheck:SetScript("OnClick", function(self)
    ERM:GetDB().combatFallbackEnabled = self:GetChecked()
end)

mainPanel.flyingCheck = CreateFrame("CheckButton", nil, mainPanel, "InterfaceOptionsCheckButtonTemplate")
mainPanel.flyingCheck:SetPoint("TOPLEFT", mainPanel.combatFallbackCheck, "BOTTOMLEFT", 0, -8)
mainPanel.flyingCheck.Text:SetText("Prefer flying mounts when available")
mainPanel.flyingCheck:SetScript("OnClick", function(self)
    ERM:GetDB().preferFlyingMounts = self:GetChecked()
    ERM:ClearMountCache()
end)

mainPanel.waterCheck = CreateFrame("CheckButton", nil, mainPanel, "InterfaceOptionsCheckButtonTemplate")
mainPanel.waterCheck:SetPoint("TOPLEFT", mainPanel.flyingCheck, "BOTTOMLEFT", 0, -8)
mainPanel.waterCheck.Text:SetText("Prefer water mounts while submerged")
mainPanel.waterCheck:SetScript("OnClick", function(self)
    ERM:GetDB().preferWaterMounts = self:GetChecked()
    ERM:ClearMountCache()
end)

mainPanel.surfaceCheck = CreateFrame("CheckButton", nil, mainPanel, "InterfaceOptionsCheckButtonTemplate")
mainPanel.surfaceCheck:SetPoint("TOPLEFT", mainPanel.waterCheck, "BOTTOMLEFT", 0, -8)
mainPanel.surfaceCheck.Text:SetText("Prefer flying mounts at the water surface")
mainPanel.surfaceCheck:SetScript("OnClick", function(self)
    ERM:GetDB().preferFlyingAtWaterSurface = self:GetChecked()
    ERM:ClearMountCache()
end)

mainPanel.flyableCheck = CreateFrame("CheckButton", nil, mainPanel, "InterfaceOptionsCheckButtonTemplate")
mainPanel.flyableCheck:SetPoint("TOPLEFT", mainPanel.surfaceCheck, "BOTTOMLEFT", 0, -8)
mainPanel.flyableCheck.Text:SetText("Only prefer flying mounts in flyable areas")
mainPanel.flyableCheck:SetScript("OnClick", function(self)
    ERM:GetDB().preferFlyingOnlyWhenFlyable = self:GetChecked()
    ERM:ClearMountCache()
end)

mainPanel.skyridingCheck = CreateFrame("CheckButton", nil, mainPanel, "InterfaceOptionsCheckButtonTemplate")
mainPanel.skyridingCheck:SetPoint("TOPLEFT", mainPanel.flyableCheck, "BOTTOMLEFT", 0, -8)
mainPanel.skyridingCheck.Text:SetText("Allow skyriding mounts")
mainPanel.skyridingCheck:SetScript("OnClick", function(self)
    ERM:GetDB().allowSkyridingMounts = self:GetChecked()
    ERM:ClearMountCache()
end)

mainPanel.debugCheck = CreateFrame("CheckButton", nil, mainPanel, "InterfaceOptionsCheckButtonTemplate")
mainPanel.debugCheck:SetPoint("TOPLEFT", mainPanel.skyridingCheck, "BOTTOMLEFT", 0, -8)
mainPanel.debugCheck.Text:SetText("Enable debug commands")
mainPanel.debugCheck:SetScript("OnClick", function(self)
    ERM:GetDB().debugEnabled = self:GetChecked()
end)

mainPanel.favoriteModeButton = CreateButton(mainPanel, "Favorite mode: All mounts", 220)
mainPanel.favoriteModeButton:SetPoint("TOPLEFT", mainPanel.debugCheck, "BOTTOMLEFT", 0, -16)
mainPanel.favoriteModeButton:SetScript("OnClick", function(self)
    ERM:CycleFavoriteMode()
    self:SetText("Favorite mode: " .. ERM:GetFavoriteModeLabel())
end)

mainPanel:SetScript("OnShow", function()
    ERM:RefreshOptions()
end)

local fallingPanel = CreateFrame("Frame")
fallingPanel.name = "Falling"
fallingPanel.parent = "EasyRandomMount"
ERM.fallingPanel = fallingPanel

fallingPanel.title = CreateTitle(fallingPanel, "Falling")

fallingPanel.addSpell = CreateButton(fallingPanel, "Add spell", 90)
fallingPanel.addSpell:SetPoint("TOPLEFT", fallingPanel.title, "BOTTOMLEFT", 0, -16)
fallingPanel.addSpell:SetScript("OnClick", function()
    AddFallingAction("spell")
end)

fallingPanel.addItem = CreateButton(fallingPanel, "Add item", 90)
fallingPanel.addItem:SetPoint("LEFT", fallingPanel.addSpell, "RIGHT", 8, 0)
fallingPanel.addItem:SetScript("OnClick", function()
    AddFallingAction("item")
end)

fallingPanel.listAnchor = CreateFrame("Frame", nil, fallingPanel)
fallingPanel.listAnchor:SetPoint("TOPLEFT", fallingPanel.addSpell, "BOTTOMLEFT", 0, -12)
fallingPanel.listAnchor:SetSize(560, 1)

fallingPanel:SetScript("OnShow", function()
    ERM:RefreshOptions()
end)

local blacklistPanel = CreateFrame("Frame")
blacklistPanel.name = "Blacklist"
blacklistPanel.parent = "EasyRandomMount"
ERM.blacklistPanel = blacklistPanel

blacklistPanel.title = CreateTitle(blacklistPanel, "Blacklist")

blacklistPanel.addMount = CreateButton(blacklistPanel, "Add mount", 90)
blacklistPanel.addMount:SetPoint("TOPLEFT", blacklistPanel.title, "BOTTOMLEFT", 0, -16)
blacklistPanel.addMount:SetScript("OnClick", AddBlacklistedMount)

blacklistPanel.currentMount = CreateButton(blacklistPanel, "Current", 80)
blacklistPanel.currentMount:SetPoint("LEFT", blacklistPanel.addMount, "RIGHT", 8, 0)
blacklistPanel.currentMount:SetScript("OnClick", BlacklistCurrentMount)

blacklistPanel.lastMount = CreateButton(blacklistPanel, "Last random", 100)
blacklistPanel.lastMount:SetPoint("LEFT", blacklistPanel.currentMount, "RIGHT", 8, 0)
blacklistPanel.lastMount:SetScript("OnClick", BlacklistLastMount)

blacklistPanel.emptyText = blacklistPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
blacklistPanel.emptyText:SetPoint("TOPLEFT", blacklistPanel.addMount, "BOTTOMLEFT", 6, -12)
blacklistPanel.emptyText:SetText("No blacklisted mounts")

blacklistPanel.scrollFrame = CreateFrame("ScrollFrame", nil, blacklistPanel)
blacklistPanel.scrollFrame:SetPoint("TOPLEFT", blacklistPanel.addMount, "BOTTOMLEFT", 0, -12)
blacklistPanel.scrollFrame:SetSize(560, 420)

blacklistPanel.scrollChild = CreateFrame("Frame", nil, blacklistPanel.scrollFrame)
blacklistPanel.scrollChild:SetSize(540, 1)
blacklistPanel.scrollFrame:SetScrollChild(blacklistPanel.scrollChild)

blacklistPanel.scrollBar = CreateFrame("Slider", nil, blacklistPanel.scrollFrame, "UIPanelScrollBarTemplate")
blacklistPanel.scrollBar:SetPoint("TOPLEFT", blacklistPanel.scrollFrame, "TOPRIGHT", -18, -16)
blacklistPanel.scrollBar:SetPoint("BOTTOMLEFT", blacklistPanel.scrollFrame, "BOTTOMRIGHT", -18, 16)
blacklistPanel.scrollBar:SetValueStep(34)
blacklistPanel.scrollBar:SetObeyStepOnDrag(true)
blacklistPanel.scrollBar:SetScript("OnValueChanged", function(self, value)
    blacklistPanel.scrollFrame:SetVerticalScroll(value)
end)
blacklistPanel.scrollBar:Hide()

blacklistPanel.scrollFrame:EnableMouseWheel(true)
blacklistPanel.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
    local current = blacklistPanel.scrollBar:GetValue()
    local minValue, maxValue = blacklistPanel.scrollBar:GetMinMaxValues()
    local nextValue = current - (delta * 34)
    blacklistPanel.scrollBar:SetValue(math.min(maxValue, math.max(minValue, nextValue)))
end)

blacklistPanel:SetScript("OnShow", function()
    ERM:RefreshOptions()
end)

local function GetCategoryID(category)
    if type(category) == "table" and category.GetID then
        return category:GetID()
    end

    return category and category.ID
end

if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterCanvasLayoutSubcategory then
    local category = Settings.RegisterCanvasLayoutCategory(mainPanel, mainPanel.name, mainPanel.name)
    Settings.RegisterCanvasLayoutSubcategory(category, fallingPanel, fallingPanel.name, fallingPanel.name)
    Settings.RegisterCanvasLayoutSubcategory(category, blacklistPanel, blacklistPanel.name, blacklistPanel.name)
    Settings.RegisterAddOnCategory(category)
    ERM.settingsCategoryID = GetCategoryID(category)
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(mainPanel)
    InterfaceOptions_AddCategory(fallingPanel)
    InterfaceOptions_AddCategory(blacklistPanel)
end
