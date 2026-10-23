-- Run from the repository root with Lua 5.1: lua tests/compatibility.lua
local combat, mounted, falling, swimming, submerged = false, false, false, false, false
local secretAuras, auraCalls, dismounts, summons = false, 0, 0, 0
local itemCount, cooldownEnabled, cooldownStart, cooldownDuration = 1, true, 0, 0
local itemUsable, knownAura = true, false
local secret = {}
local frames, messages = {}, {}
local frameMethods = {}
local function newFrame(name)
    local frame = setmetatable({ scripts = {}, events = {}, attrs = {} }, { __index = frameMethods })
    frame.Text = setmetatable({}, { __index = frameMethods })
    if name then _G[name] = frame end
    frames[#frames + 1] = frame
    return frame
end
function frameMethods:SetScript(name, callback) self.scripts[name] = callback end
function frameMethods:HookScript(name, callback) self.scripts[name] = callback end
function frameMethods:RegisterEvent(event) self.events[event] = true end
function frameMethods:RegisterUnitEvent(event, unit) self.events[event] = unit end
function frameMethods:SetAttribute(key, value)
    assert(not combat, 'protected attribute changed during combat: ' .. key)
    self.attrs[key] = value
end
function frameMethods:GetAttribute(key) return self.attrs[key] end
function frameMethods:CreateFontString() return newFrame() end
function frameMethods:SetText(value) self.text = value end
function frameMethods:GetText() return self.text end
function frameMethods:SetChecked(value) self.checked = value end
function frameMethods:GetChecked() return self.checked end
function frameMethods:GetHeight() return 420 end
function frameMethods:GetValue() return 0 end
for _, name in ipairs({ 'RegisterForClicks', 'SetPoint', 'SetSize', 'SetWidth', 'SetHeight',
    'SetJustifyH', 'SetScrollChild', 'SetMinMaxValues', 'SetValueStep', 'SetObeyStepOnDrag',
    'Hide', 'Show', 'SetShown', 'SetEnabled', 'EnableMouseWheel', 'SetVerticalScroll', 'SetValue' }) do
    frameMethods[name] = function() end
end
CreateFrame = function(_, name) return newFrame(name) end
UIParent = newFrame()
SlashCmdList, StaticPopupDialogs = {}, {}
OKAY, CANCEL = 'Okay', 'Cancel'
InCombatLockdown = function() return combat end
IsMounted = function() return mounted end
IsFalling = function() return falling end
IsSwimming = function() return swimming end
IsSubmerged = function() return submerged end
IsFlyableArea = function() return true end
UnitLevel = function() return 80 end
UnitClassBase = function() return 'MAGE' end
GetTime = function() return 100 end
Dismount = function() assert(not combat); dismounts = dismounts + 1 end
issecretvalue = function(value) return value == secret end
print = function(value) messages[#messages + 1] = value end
C_AddOns = { GetAddOnMetadata = function() return 'test-version' end }
C_SpellBook = { IsSpellKnown = function() return false end }
C_Spell = {
    GetSpellInfo = function() return { name = 'Slow Fall' } end,
    GetSpellTexture = function() return nil end,
}
C_Item = {
    GetItemCount = function(id, bank, uses)
        assert(bank == false and uses == true)
        return id == 182729 and itemCount or 0
    end,
    IsUsableItem = function() return itemUsable, false end,
    GetItemCooldown = function() return cooldownStart, cooldownDuration, cooldownEnabled end,
    GetItemNameByID = function() return 'Hearty Dragon Plume' end,
    GetItemIconByID = function() return nil end,
}
C_Secrets = { ShouldAurasBeSecret = function() return secretAuras end }
C_UnitAuras = {
    GetPlayerAuraBySpellID = function()
        assert(not secretAuras, 'restricted direct aura lookup')
        auraCalls = auraCalls + 1
        return knownAura and {} or nil
    end,
    GetAuraDataByIndex = function(_, index)
        assert(not secretAuras, 'restricted aura scan')
        auraCalls = auraCalls + 1
        if index == 1 then return { spellId = secret, name = secret } end
    end,
}
C_MountJournal = {
    GetMountIDs = function() return { 101, 202 } end,
    GetMountInfoByID = function(id)
        return 'Mount ' .. id, 1, 1, false, true, 1, false, false, nil, false, true, id
    end,
    GetMountInfoExtraByID = function(id) return nil, nil, nil, nil, id == 101 and 247 or 231 end,
    SummonByID = function(id) assert(not combat); summons = summons + 1; _G.lastSummon = id end,
    GetDisplayedMountInfo = function(index)
        assert(index == 7)
        return 'Displayed mount', 1, 1, false, true, 1, false, false, nil, false, true, 202
    end,
}
assert(loadfile('Core.lua'))('EasyRandomMount')
local ERM = EasyRandomMount
local button = EasyRandomMountSecureButton
local function checkItem(expected)
    ERM:GetDB().falling = { { type = 'item', id = 182729 } }
    falling = true
    local action = ERM:GetFallingAction()
    assert(action == expected, 'unexpected falling action: ' .. tostring(action))
end
-- Retail API only: the removed globals intentionally do not exist.
checkItem('item')
ERM:SecureButtonPreClick(button)
assert(button.attrs.type == 'item' and button.attrs.item == 'Hearty Dragon Plume')
ERM:SecureButtonPostClick(button)
assert(button.attrs.type == 'macro' and button.attrs.macrotext:find('/cast', 1, true))
cooldownEnabled = false; checkItem('unusable')
cooldownEnabled = true; cooldownStart, cooldownDuration = 1, 60; checkItem('unusable')
cooldownStart, cooldownDuration = 0, 0
itemUsable = false; checkItem('unusable'); itemUsable = true
itemCount = 0; checkItem('missing'); itemCount = 1
local modernCount, modernCooldown = C_Item.GetItemCount, C_Item.GetItemCooldown
C_Item.GetItemCount, C_Item.GetItemCooldown = nil, nil
GetItemCount, GetItemCooldown = modernCount, function() return 0, 0, 1 end
checkItem('item')
GetItemCount, GetItemCooldown = nil, nil
checkItem('missing') -- Missing optional APIs must not crash.
C_Item.GetItemCount, C_Item.GetItemCooldown = modernCount, modernCooldown
local knownSpell = C_SpellBook.IsSpellKnown
C_SpellBook.IsSpellKnown = function() return true end
ERM:GetDB().falling = { { type = 'spell', id = 130 } }
ERM:SecureButtonPreClick(button)
assert(button.attrs.type == 'spell' and button.attrs.spell == 'Slow Fall')
ERM:SecureButtonPostClick(button)
assert(button.attrs.type == 'macro')
C_SpellBook.IsSpellKnown = knownSpell
falling = false
swimming, submerged, secretAuras = true, true, true
local callsBefore = auraCalls
ERM:ClearMountCache(); ERM:SummonRandomMount()
assert(auraCalls == callsBefore and lastSummon == 202, 'restricted aura path must prefer water')
secretAuras = false
ERM:ClearMountCache(); ERM:SummonRandomMount()
assert(lastSummon == 101, 'readable auras with no water breathing must allow surface preference')
knownAura = true
ERM:ClearMountCache(); ERM:SummonRandomMount()
assert(lastSummon == 202, 'known water breathing must keep underwater preference')
swimming, submerged, knownAura = false, false, false
-- Both click edges arrive; only the edge used by the secure template may summon.
for _, keyDown in ipairs({ false, true }) do
    GetCVarBool = function() return keyDown end
    local before = summons
    for _, down in ipairs({ true, false }) do
        button.scripts.PreClick(button, 'LeftButton', down)
        button.scripts.OnClick(button, 'LeftButton', down)
        button.scripts.PostClick(button, 'LeftButton', down)
    end
    assert(summons == before + 1, 'key press summoned more than once')
end
-- Secure actions must already be prepared before lockdown begins.
local macro = button.attrs.macrotext
assert(macro:find('/cast [@player,combat,nomounted] Slow Fall', 1, true))
assert(not macro:find('falling', 1, true), 'unsupported macro conditional')
assert(macro:find('/cast', 1, true) < macro:find('/dismount', 1, true))
for _, frame in ipairs(frames) do assert(not frame.events.PLAYER_REGEN_DISABLED) end
combat, mounted = true, true
local summonCount, dismountCount = summons, dismounts
for _, frame in ipairs(frames) do
    if frame.events.SPELLS_CHANGED then frame.scripts.OnEvent(frame, 'SPELLS_CHANGED') end
end
ERM:SecureButtonPreClick(button); ERM:SecureButtonOnClick(button); ERM:SecureButtonPostClick(button)
ERM:RefreshSecureButtons(); ERM:SummonRandomMount(); ERM:SummonServiceMount('repair')
assert(summons == summonCount and dismounts == dismountCount, 'insecure combat action attempted')
SlashCmdList.EASYRANDOMMOUNT('combat') -- Deferred while locked down.
assert(button.attrs.macrotext == macro)
combat, mounted = false, false
for _, frame in ipairs(frames) do
    if frame.events.PLAYER_REGEN_ENABLED then frame.scripts.OnEvent(frame, 'PLAYER_REGEN_ENABLED') end
end
assert(not button.attrs.macrotext:find('/cast', 1, true), 'combat toggle was not applied after combat')
SlashCmdList.EASYRANDOMMOUNT('combat')
assert(button.attrs.macrotext:find('/cast', 1, true), 'combat toggle was not applied immediately')
-- UNIT_AURA unit tokens may be secret: filter at event registration instead.
for _, frame in ipairs(frames) do
    if frame.events.UNIT_AURA then
        assert(frame.events.UNIT_AURA == 'player')
        frame.scripts.OnEvent(frame, 'UNIT_AURA', secret)
    end
end
assert(loadfile('Options.lua'))()
-- Uncached data must not fall through to removed icon/name globals.
C_Item.GetItemNameByID = function() return nil end
ERM:RefreshOptions()
combat = true
ERM.generalPanel.combatFallbackCheck:SetChecked(false)
ERM.generalPanel.combatFallbackCheck.scripts.OnClick(ERM.generalPanel.combatFallbackCheck)
combat = false
ERM:RefreshSecureButtons()
assert(not button.attrs.macrotext:find('/cast', 1, true))
StaticPopup_Show = function() end
ERM.fallingPanel.addItem.scripts.OnClick()
StaticPopupDialogs.EASYRANDOMMOUNT_ADD_ACTION.OnAccept({ editBox = { GetText = function() return '182729' end } })
assert(ERM:GetDB().falling[#ERM:GetDB().falling].name == '182729')
ERM.fallingPanel.addSpell.scripts.OnClick()
StaticPopupDialogs.EASYRANDOMMOUNT_ADD_ACTION.OnAccept({ editBox = { GetText = function() return '130' end } })
ERM:RefreshOptions()
local menuCallback
Menu = { ModifyMenu = function(tag, callback)
    assert(tag == 'MENU_MOUNT_COLLECTION_MOUNT'); menuCallback = callback
end }
assert(loadfile('MountJournal.lua'))()
local toggle, checked
local root = {
    CreateDivider = function() end,
    CreateCheckbox = function(_, _, isChecked, callback) checked, toggle = isChecked, callback end,
}
menuCallback(nil, root, 7)
assert(not checked()); toggle(); assert(checked() and ERM:IsMountBlacklisted(202))
toggle(); assert(not checked())
menuCallback({ index = 7 }, root) -- The live menu tag supplies no context data.
toggle(); assert(ERM:IsMountBlacklisted(202)); toggle()
menuCallback({ GetParent = function() return { index = 7 } end }, root)
toggle(); assert(ERM:IsMountBlacklisted(202)); toggle()
GetMouseFoci = function() return { { mountID = 202 } } end
ERM:DebugMountJournalFocus()
assert(messages[#messages]:find('mountID=202', 1, true))
SlashCmdList.EASYRANDOMMOUNT('version')
assert(messages[#messages]:find('test-version', 1, true))
io.write('PASS: item APIs, cooldowns, secret auras, mount pools, combat lockdown, options, menu, version\n')
