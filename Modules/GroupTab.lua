-- Modules\GroupTab.lua
-- Group Creation tab + roster-sync logic.

local LibStubRef = _G.LibStub
if type(LibStubRef) ~= "function" and type(LibStubRef) ~= "table" then
    return
end

local Echoes = LibStubRef("AceAddon-3.0"):GetAddon("Echoes", true) or _G.Echoes
if type(Echoes) ~= "table" then
    Echoes = {}
end
_G.Echoes = Echoes
local AceGUI = LibStub("AceGUI-3.0")

-- Lua compatibility: some environments provide `table.unpack` but not global `unpack`.
local t_unpack = (type(table) == "table" and type(table.unpack) == "function" and table.unpack) or unpack
if type(t_unpack) ~= "function" then
    t_unpack = function(t, i, j)
        i = i or 1
        j = j or #t
        if i > j then return end
        return t[i], t_unpack(t, i + 1, j)
    end
end

local EchoesDB = _G.EchoesDB or {}

local Clamp = Echoes.Clamp
local Echoes_Print = Echoes.Print
local SetEchoesFont = Echoes.SetEchoesFont
local ECHOES_FONT_FLAGS = Echoes.ECHOES_FONT_FLAGS

local SkinSimpleGroup = Echoes.SkinSimpleGroup
local SkinInlineGroup = Echoes.SkinInlineGroup
local SkinButton = Echoes.SkinButton
local SkinDropdown = Echoes.SkinDropdown
local SkinEditBox = Echoes.SkinEditBox

local GROUP_TEMPLATES = Echoes.GROUP_TEMPLATES
local GROUP_SLOT_OPTIONS = Echoes.GROUP_SLOT_OPTIONS
local DEFAULT_CYCLE_VALUES = Echoes.DEFAULT_CYCLE_VALUES
local GetCycleValuesForRightText = Echoes.GetCycleValuesForRightText

local Echoes_NormalizeName = Echoes.NormalizeName
local Echoes_IsNameInGroup = Echoes.IsNameInGroup
local Echoes_GetPlayerSpecLabel = Echoes.GetPlayerSpecLabel

local function Echoes_Log(msg)
    if Echoes and Echoes.Log then
        Echoes:Log("INFO", msg)
    end
end

------------------------------------------------------------
-- Group Creation tab (unchanged layout)
------------------------------------------------------------
function Echoes:BuildGroupTab(container)
    -- Refresh SavedVariables reference (defensive) and ensure built-in presets exist.
    EchoesDB = _G.EchoesDB or EchoesDB or {}
    if self.EnsureDefaults then
        self:EnsureDefaults()
    end

    Echoes_Log("GroupTab: build")

    -- Ensure shared lists/functions are initialized (load-order safety).
    GROUP_TEMPLATES = Echoes.GROUP_TEMPLATES or GROUP_TEMPLATES or { "10 Man", "25 Man" }
    GROUP_SLOT_OPTIONS = Echoes.GROUP_SLOT_OPTIONS or GROUP_SLOT_OPTIONS or {
        "None",
        "Paladin",
        "Death Knight",
        "Warrior",
        "Shaman",
        "Hunter",
        "Druid",
        "Rogue",
        "Priest",
        "Warlock",
        "Mage",
        "Altbot",
    }
    DEFAULT_CYCLE_VALUES = Echoes.DEFAULT_CYCLE_VALUES or DEFAULT_CYCLE_VALUES or {
        { label = "None", icon = "Interface\\Icons\\INV_Misc_QuestionMark" },
    }
    if type(Echoes.GetCycleValuesForRightText) == "function" then
        GetCycleValuesForRightText = Echoes.GetCycleValuesForRightText
    elseif type(GetCycleValuesForRightText) ~= "function" then
        GetCycleValuesForRightText = function()
            return DEFAULT_CYCLE_VALUES
        end
    end

    -- Flat pane (no scrolling). The GROUP frame size is designed to fit the full grid.
    container:SetLayout("List")

    -- Row height for slot rows. Keep everything on one line (icon + dropdown + optional Name button).
    -- Slightly taller for readability, but not so tall that the 5x2 grid wastes space.
    local INPUT_HEIGHT = 22
    local ROW_H = INPUT_HEIGHT
    local GROUP_LABEL_H = 12
    -- Compact, consistent height for the group slot grid. Without explicit heights,
    -- AceGUI containers default to a fairly tall value which looks like a huge empty panel.
    local SLOT_GROUP_H = (5 * ROW_H) + 26 + GROUP_LABEL_H

    local PRESET_COUNT = #GROUP_TEMPLATES
    -- Use a large numeric key so AceGUI's sorted dropdown puts this at the end.
    local NEW_PRESET_KEY = 99999

    local function GetMaxTemplateIndex()
        local maxIdx = PRESET_COUNT
        if EchoesDB.groupTemplates then
            for k in pairs(EchoesDB.groupTemplates) do
                local n = tonumber(k)
                if n and n > maxIdx then maxIdx = n end
            end
        end
        if EchoesDB.groupTemplateNames then
            for k in pairs(EchoesDB.groupTemplateNames) do
                local n = tonumber(k)
                if n and n > maxIdx then maxIdx = n end
            end
        end
        return maxIdx
    end

    -- Clamp template index to presets + any user templates.
    EchoesDB.groupTemplateIndex = Clamp(tonumber(EchoesDB.groupTemplateIndex) or 1, 1, GetMaxTemplateIndex())

    local topGroup = AceGUI:Create("SimpleGroup")
    topGroup:SetFullWidth(true)
    -- Anchor header widgets manually so the EditBox and Dropdown line up perfectly.
    topGroup:SetLayout("None")
    if topGroup.SetAutoAdjustHeight then topGroup:SetAutoAdjustHeight(false) end
    topGroup:SetHeight(INPUT_HEIGHT)
    SkinSimpleGroup(topGroup)

    local groupSlotsRow = AceGUI:Create("SimpleGroup")
    groupSlotsRow:SetFullWidth(true)
    groupSlotsRow:SetLayout("None")
    if groupSlotsRow.SetAutoAdjustHeight then groupSlotsRow:SetAutoAdjustHeight(false) end
    groupSlotsRow:SetHeight(INPUT_HEIGHT)
    container:AddChild(groupSlotsRow)

    local modeRow = AceGUI:Create("SimpleGroup")
    modeRow:SetFullWidth(true)
    modeRow:SetLayout("None")
    if modeRow.SetAutoAdjustHeight then modeRow:SetAutoAdjustHeight(false) end
    modeRow:SetHeight(0)
    container:AddChild(modeRow)

    groupSlotsRow:AddChild(topGroup)

    if groupSlotsRow.frame and topGroup.frame then
        topGroup.frame:ClearAllPoints()
        topGroup.frame:SetPoint("TOPLEFT", groupSlotsRow.frame, "TOPLEFT", 0, 0)
        topGroup.frame:SetPoint("BOTTOMRIGHT", groupSlotsRow.frame, "BOTTOMRIGHT", 0, 0)
    end

    local modePad = AceGUI:Create("SimpleGroup")
    modePad:SetFullWidth(true)
    modePad:SetLayout("Flow")
    if modePad.SetAutoAdjustHeight then modePad:SetAutoAdjustHeight(false) end
    modePad:SetHeight(0)
    container:AddChild(modePad)

    local nameEdit = AceGUI:Create("EditBox")
    nameEdit:SetLabel("")
    nameEdit:SetText("")
    nameEdit:SetHeight(INPUT_HEIGHT)
    topGroup:AddChild(nameEdit)
    SkinEditBox(nameEdit)
    if nameEdit.DisableButton then nameEdit:DisableButton(true) end

    if nameEdit.frame and topGroup.frame then
        nameEdit.frame:ClearAllPoints()
        nameEdit.frame:SetPoint("TOPLEFT", topGroup.frame, "TOPLEFT", 8, 0)
        nameEdit.frame:SetPoint("BOTTOMLEFT", topGroup.frame, "BOTTOMLEFT", 8, 0)
        if nameEdit.frame.SetWidth then nameEdit.frame:SetWidth(240) end
    end

    local function GetTemplateDisplayName(i)
        i = tonumber(i)
        if not i then return "" end
        -- Allow user-defined names even for built-in presets.
        if EchoesDB.groupTemplateNames and EchoesDB.groupTemplateNames[i] and EchoesDB.groupTemplateNames[i] ~= "" then
            return tostring(EchoesDB.groupTemplateNames[i])
        end
        if i <= PRESET_COUNT then
            return GROUP_TEMPLATES[i] or ("Template " .. tostring(i))
        end
        local tpl = EchoesDB.groupTemplates and EchoesDB.groupTemplates[i]
        if tpl and tpl.name and tpl.name ~= "" then
            return tostring(tpl.name)
        end
        return "Preset " .. tostring(i - PRESET_COUNT)
    end

    local function BuildTemplateValues()
        local vals = {}
        local maxIdx = GetMaxTemplateIndex()
        for i = 1, maxIdx do
            vals[i] = GetTemplateDisplayName(i)
        end
        vals[NEW_PRESET_KEY] = "<New Preset>"
        return vals
    end

    local templateValues = BuildTemplateValues()

    local templateDrop = AceGUI:Create("Dropdown")
    templateDrop:SetLabel("")
    templateDrop:SetList(templateValues)
    templateDrop:SetValue(EchoesDB.groupTemplateIndex or 1)
    templateDrop:SetHeight(INPUT_HEIGHT)
    self.UI.groupTemplateNameEdit = nameEdit
    self.UI.groupTemplateDrop = templateDrop

    local function GroupTabSafeStep(label, fn)
        local ok, err = pcall(fn)
        if not ok then
            Echoes_Log("GroupTab error at " .. tostring(label) .. ": " .. tostring(err))
        end
        return ok, err
    end

    local function SetButtonEnabled(btn, enabled)
        if not btn then return end
        if btn.SetDisabled then btn:SetDisabled(not enabled) end
        if btn.frame and btn.frame.SetAlpha then
            btn.frame:SetAlpha(enabled and 1 or 0.45)
        end
        if btn.text and btn.text.SetTextColor then
            if enabled then
                btn.text:SetTextColor(0.90, 0.85, 0.70, 1)
            else
                btn.text:SetTextColor(0.55, 0.55, 0.55, 1)
            end
        end
    end


    local saveBtn
    local deleteBtn

    local function RefreshTemplateHeader(selectedIndex)
        local idx = tonumber(selectedIndex) or (EchoesDB.groupTemplateIndex or 1)
        EchoesDB.groupTemplateIndex = idx

        local displayName = GetTemplateDisplayName(idx)
        if nameEdit and nameEdit.SetText then
            nameEdit:SetText(displayName or "")
        end

        -- Allow renaming any preset (including 10/25) since we also allow saving over them.
        local allowRename = true
        if nameEdit and nameEdit.SetDisabled then
            nameEdit:SetDisabled(not allowRename)
        end
        if nameEdit and nameEdit.editbox and nameEdit.editbox.SetTextColor then
            if allowRename then
                nameEdit.editbox:SetTextColor(0.90, 0.85, 0.70, 1)
            else
                nameEdit.editbox:SetTextColor(0.55, 0.55, 0.55, 1)
            end
        end

        -- Allow saving over built-in presets. Only block Delete on built-ins.
        SetButtonEnabled(saveBtn, true)
        local allowDelete = (idx and idx > PRESET_COUNT) and true or false
        SetButtonEnabled(deleteBtn, allowDelete)
    end


    -- Forward declarations (used by template helpers below, populated later).
    local slotValues = {}
    local ALTBOT_INDEX
    local DISPLAY_TO_CLASSFILE
    local CLASSFILE_TO_DISPLAY
    local NormalizeAltbotClassText


    local function NormalizeAltbotName(name)
        name = tostring(name or "")
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then return nil end
        return string.upper(name:sub(1, 1)) .. string.lower(name:sub(2))
    end


    local function ClearEmptySlot(slot)
        if not slot or slot._EchoesMember then return end

        if slot.classDrop and slot.classDrop.SetList and slot.classDrop.SetValue then
            slot.classDrop._EchoesSuppress = true
            slot.classDrop:SetList(slotValues)
            slot.classDrop:SetValue(1) -- None
            slot.classDrop._EchoesSelectedValue = 1
            slot.classDrop._EchoesAltbotName = nil
            slot.classDrop._EchoesAltbotClassText = nil
            slot.classDrop._EchoesAltbotClassText = nil
            if slot.classDrop.dropdown then
                slot.classDrop.dropdown._EchoesFilledClassFile = nil
            end
            slot.classDrop._EchoesSuppress = nil

            if self.UI and self.UI._GroupSlotApplyColor then
                self.UI._GroupSlotApplyColor(slot.classDrop, 1)
            end
            if slot.classDrop._EchoesUpdateNameButtonVisibility then
                slot.classDrop._EchoesUpdateNameButtonVisibility(1)
            end
        end

        if slot.cycleBtn then
            slot.cycleBtn.values = { t_unpack(DEFAULT_CYCLE_VALUES) }
            slot.cycleBtn.index = 1
            slot.cycleBtn._EchoesLocked = false
            if slot.cycleBtn._EchoesCycleUpdate then slot.cycleBtn._EchoesCycleUpdate(slot.cycleBtn) end
        end
    end

    local function LoadPreset(templateIndex)
        local idx = tonumber(templateIndex) or 1

        local function GetTemplateSlots(template)
            if type(template) ~= "table" then return nil end
            if type(template.slots) == "table" then return template.slots end
            -- Legacy formats
            if type(template.groups) == "table" then return template.groups end
            if type(template[1]) == "table" then return template end
            return nil
        end

        local tpl = EchoesDB.groupTemplates and EchoesDB.groupTemplates[idx]
        local slots = GetTemplateSlots(tpl)
        if (not slots) and self.EnsureDefaults then
            -- If defaults weren't initialized for some reason (or SVs were partially wiped),
            -- rebuild and retry once.
            self:EnsureDefaults()
            tpl = EchoesDB.groupTemplates and EchoesDB.groupTemplates[idx]
            slots = GetTemplateSlots(tpl)
        end
        if not slots or not self.UI or not self.UI.groupSlots then return end

        -- Always clear empty slots first so loading is deterministic.
        for g = 1, 5 do
            for p = 1, 5 do
                local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                if slot then
                    ClearEmptySlot(slot)
                end
            end
        end

        -- Build a stable per-position plan for specs (used both for icon persistence and Set Talents later).
        self._EchoesPlannedTalentByPos = {}
        for g = 1, 5 do
            self._EchoesPlannedTalentByPos[g] = {}
            for p = 1, 5 do
                local entry = slots[g] and slots[g][p]
                if entry and type(entry) == "table" then
                    local classText = tostring(entry.class or "")
                    if classText == "Altbot" then
                        local altClass = NormalizeAltbotClassText(entry.altClassText)
                        if altClass and altClass ~= "" then
                            classText = altClass
                        end
                    end
                    self._EchoesPlannedTalentByPos[g][p] = {
                        classText = classText,
                        specLabel = tostring(entry.specLabel or ""),
                    }
                else
                    self._EchoesPlannedTalentByPos[g][p] = nil
                end
            end
        end

        for g = 1, 5 do
            for p = 1, 5 do
                if not (g == 1 and p == 5) then
                    local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                    if slot and slot.classDrop and slot.classDrop.SetValue then
                        local entry = slots[g] and slots[g][p]
                        if entry and type(entry) == "table" then
                        local classText = tostring(entry.class or "None")
                        local desiredIndex = 1
                        for i, v in ipairs(slotValues) do
                            if v == classText then
                                desiredIndex = i
                                break
                            end
                        end

                        local altbotName = (desiredIndex == ALTBOT_INDEX) and NormalizeAltbotName(entry.altName) or nil
                        local altbotClassText = (desiredIndex == ALTBOT_INDEX) and NormalizeAltbotClassText(entry.altClassText) or nil
                        local specLabel = entry.specLabel and tostring(entry.specLabel) or nil

                        if slot._EchoesMember then
                            slot._EchoesSavedConfig = {
                                valueIndex = desiredIndex,
                                altbotName = altbotName,
                                altbotClassText = altbotClassText,
                                specLabel = specLabel,
                            }
                        else
                            slot.classDrop._EchoesSuppress = true
                            slot.classDrop:SetList(slotValues)
                            slot.classDrop:SetValue(desiredIndex)
                            slot.classDrop._EchoesSelectedValue = desiredIndex
                            if desiredIndex == ALTBOT_INDEX then
                                slot.classDrop._EchoesAltbotName = altbotName
                                slot.classDrop._EchoesAltbotClassText = altbotClassText
                            else
                                slot.classDrop._EchoesAltbotName = nil
                                slot.classDrop._EchoesAltbotClassText = nil
                            end
                            if slot.classDrop.dropdown then
                                slot.classDrop.dropdown._EchoesFilledClassFile = nil
                            end
                            slot.classDrop._EchoesSuppress = nil
                        end

                        if slot.cycleBtn then
                            local classForCycle = classText
                            if classText == "Altbot" and altbotClassText and altbotClassText ~= "" then
                                classForCycle = altbotClassText
                            end
                            local vals = GetCycleValuesForRightText(classForCycle)
                            slot.cycleBtn.values = { t_unpack(vals) }
                            local want = specLabel
                            local chosen = 1
                            if want and want ~= "" then
                                for i, it in ipairs(slot.cycleBtn.values) do
                                    if type(it) == "table" and it.label == want then
                                        chosen = i
                                        break
                                    end
                                end
                            end
                            slot.cycleBtn.index = chosen
                            if slot.cycleBtn._EchoesCycleUpdate then slot.cycleBtn._EchoesCycleUpdate(slot.cycleBtn) end
                        end

                        if not slot._EchoesMember then
                            if self.UI._GroupSlotApplyColor then
                                self.UI._GroupSlotApplyColor(slot.classDrop, desiredIndex)
                            end
                            if slot.classDrop._EchoesUpdateNameButtonVisibility then
                                slot.classDrop._EchoesUpdateNameButtonVisibility(desiredIndex)
                            end
                        end
                    end
                    end
                end
            end
        end

        -- Always show the player in Group 1, Slot 5 (class-colored).
        do
            local slot = self.UI.groupSlots[1] and self.UI.groupSlots[1][5]
            local classFile = (type(UnitClass) == "function") and select(2, UnitClass("player")) or nil
            local playerName = (type(UnitName) == "function") and UnitName("player") or nil
            local classText
            if classFile then
                local map = {
                    PALADIN = "Paladin",
                    DEATHKNIGHT = "Death Knight",
                    WARRIOR = "Warrior",
                    SHAMAN = "Shaman",
                    HUNTER = "Hunter",
                    DRUID = "Druid",
                    ROGUE = "Rogue",
                    PRIEST = "Priest",
                    WARLOCK = "Warlock",
                    MAGE = "Mage",
                }
                classText = map[classFile]
            end

            if slot and slot.classDrop then
                local displayText = playerName or classText or "Player"
                slot._EchoesMember = { isPlayer = true, name = playerName or "", classFile = classFile }

                slot.classDrop._EchoesSuppress = true
                slot.classDrop:SetList({ [1] = displayText })
                slot.classDrop:SetValue(1)
                slot.classDrop._EchoesSelectedValue = 1
                slot.classDrop._EchoesAltbotName = nil
                slot.classDrop._EchoesAltbotClassText = nil
                if slot.classDrop.dropdown then
                    slot.classDrop.dropdown._EchoesFilledClassFile = classFile
                end
                slot.classDrop._EchoesSuppress = nil

                if slot.classDrop.text and slot.classDrop.text.SetTextColor and classFile then
                    local colors = rawget(_G, "RAID_CLASS_COLORS")
                    local c = colors and colors[classFile]
                    if c then
                        slot.classDrop.text:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)
                    end
                end

                if slot.classDrop.SetDisabled then slot.classDrop:SetDisabled(true) end
                if slot.classDrop.dropdown and slot.classDrop.dropdown.EnableMouse then
                    slot.classDrop.dropdown:EnableMouse(false)
                end
                if slot.classDrop.button then
                    if slot.classDrop.button.Disable then slot.classDrop.button:Disable() end
                end

                if slot.cycleBtn and slot.cycleBtn.frame then
                    if slot.cycleBtn.frame.Hide then slot.cycleBtn.frame:Hide() end
                    if slot.cycleBtn.frame.EnableMouse then slot.cycleBtn.frame:EnableMouse(false) end
                end

                if classText then
                    self._EchoesPlannedTalentByPos = self._EchoesPlannedTalentByPos or {}
                    self._EchoesPlannedTalentByPos[1] = self._EchoesPlannedTalentByPos[1] or {}
                    self._EchoesPlannedTalentByPos[1][5] = {
                        classText = classText,
                        specLabel = Echoes_GetPlayerSpecLabel and Echoes_GetPlayerSpecLabel(classFile) or "",
                    }
                end
            end
        end
    end

    local function SavePreset(templateIndex)
        local idx = tonumber(templateIndex) or 1
        if not self.UI or not self.UI.groupSlots then
            Echoes_Log("GroupTab: SavePreset failed (UI not ready)")
            return false
        end

        Echoes_Log("GroupTab: SavePreset start idx=" .. tostring(idx))

        EchoesDB.groupTemplates = EchoesDB.groupTemplates or {}
        EchoesDB.groupTemplateNames = EchoesDB.groupTemplateNames or {}

        local newName = nil
        if nameEdit and nameEdit.editbox and nameEdit.editbox.GetText then
            newName = tostring(nameEdit.editbox:GetText() or "")
            newName = newName:gsub("^%s+", ""):gsub("%s+$", "")
            if newName == "" then newName = nil end
        end
        if newName then
            EchoesDB.groupTemplateNames[idx] = newName
        end

        local tpl = { name = newName or GetTemplateDisplayName(idx), slots = {} }
        local entryCount = 0
        for g = 1, 5 do
            tpl.slots[g] = {}
            for p = 1, 5 do
                local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                local entry = nil
                if slot then
                    if slot._EchoesMember and slot._EchoesMember.name and not slot._EchoesMember.isPlayer then
                        -- If you're currently grouped, treat roster members as Altbot-by-name.
                        local classText = CLASSFILE_TO_DISPLAY[slot._EchoesMember.classFile or ""]
                        entry = {
                            class = "Altbot",
                            altName = tostring(slot._EchoesMember.name),
                            specLabel = slot.cycleBtn and slot.cycleBtn._EchoesSpecLabel or nil,
                            altClassText = classText,
                        }
                    elseif (not slot._EchoesMember) and slot.classDrop then
                        local dd = slot.classDrop
                        local value = dd._EchoesSelectedValue or dd.value or 1
                        local classText = slotValues[value] or "None"
                        if classText ~= "None" then
                            local altName = dd._EchoesAltbotName
                            altName = NormalizeAltbotName(altName)
                            local altClassText = dd._EchoesAltbotClassText
                            altClassText = NormalizeAltbotClassText(altClassText)

                            local specLabel = slot.cycleBtn and slot.cycleBtn._EchoesSpecLabel or nil
                            if specLabel == "None" then specLabel = nil end

                            entry = { class = classText, altName = altName, specLabel = specLabel, altClassText = altClassText }
                        end
                    end
                end
                if entry then
                    entryCount = entryCount + 1
                end
                tpl.slots[g][p] = entry
            end
        end

        EchoesDB.groupTemplates[idx] = tpl
        Echoes_Log("GroupTab: SavePreset done idx=" .. tostring(idx) .. " name=" .. tostring(tpl.name) .. " entries=" .. tostring(entryCount))
        return true
    end

    GroupTabSafeStep("templateDrop:SetCallback", function()
        templateDrop:SetCallback("OnValueChanged", function(widget, event, value)
            if templateDrop._EchoesSuppress then return end

            Echoes_Log("GroupTab: template selected value=" .. tostring(value))

            local prev = EchoesDB.groupTemplateIndex or 1
            if value == NEW_PRESET_KEY then
                -- Revert immediately; creation will select the new preset.
                templateDrop._EchoesSuppress = true
                templateDrop:SetValue(prev)
                templateDrop._EchoesSuppress = nil

                self:ShowNamePrompt({
                    title = "New Preset",
                    initialText = "",
                    onAccept = function(text)
                        local name = tostring(text or "")
                        name = name:gsub("^%s+", ""):gsub("%s+$", "")
                        if name == "" then return end

                        EchoesDB.groupTemplates = EchoesDB.groupTemplates or {}
                        EchoesDB.groupTemplateNames = EchoesDB.groupTemplateNames or {}

                        local newIndex = GetMaxTemplateIndex() + 1
                        EchoesDB.groupTemplateIndex = newIndex
                        EchoesDB.groupTemplateNames[newIndex] = name

                        local vals = BuildTemplateValues()
                        if templateDrop and templateDrop.SetList then
                            templateDrop:SetList(vals)
                        end
                        templateDrop._EchoesSuppress = true
                        templateDrop:SetValue(newIndex)
                        templateDrop._EchoesSuppress = nil
                        RefreshTemplateHeader(newIndex)
                        EchoesDB.groupTemplates[newIndex] = EchoesDB.groupTemplates[newIndex] or { name = name, slots = {} }
                        Echoes_Log("GroupTab: new preset created index=" .. tostring(newIndex) .. " name=" .. tostring(name))
                        LoadPreset(newIndex)
                    end,
                })
                return
            end

            EchoesDB.groupTemplateIndex = value
            RefreshTemplateHeader(value)
            LoadPreset(value)
        end)
    end)
    GroupTabSafeStep("topGroup:AddChild(templateDrop)", function()
        topGroup:AddChild(templateDrop)
    end)
    GroupTabSafeStep("SkinDropdown(templateDrop)", function()
        SkinDropdown(templateDrop)
    end)

    GroupTabSafeStep("templateDrop frame layout", function()
        if templateDrop.frame and topGroup.frame and nameEdit.frame then
            templateDrop.frame:ClearAllPoints()
            templateDrop.frame:SetPoint("TOP", topGroup.frame, "TOP", 0, 0)
            templateDrop.frame:SetPoint("BOTTOM", topGroup.frame, "BOTTOM", 0, 0)
            templateDrop.frame:SetPoint("LEFT", nameEdit.frame, "RIGHT", 10, 0)
            if templateDrop.frame.SetWidth then templateDrop.frame:SetWidth(240) end
        end
    end)

    GroupTabSafeStep("RefreshTemplateHeader", function()
        RefreshTemplateHeader(EchoesDB.groupTemplateIndex or 1)
    end)

    GroupTabSafeStep("saveBtn build", function()
        saveBtn = AceGUI:Create("Button")
        saveBtn._EchoesLogId = "GroupTab.Save"
        saveBtn:SetText("Save")
        saveBtn:SetHeight(INPUT_HEIGHT)
        saveBtn:SetCallback("OnClick", function()
            local idx = tonumber(EchoesDB.groupTemplateIndex) or 1
            if not SavePreset(idx) then return end

            Echoes_Log("GroupTab: preset saved index=" .. tostring(idx))

            local vals = BuildTemplateValues()
            if templateDrop and templateDrop.SetList then
                templateDrop:SetList(vals)
            end
            RefreshTemplateHeader(idx)

            Echoes_Print("Group setup saved.")
        end)
        topGroup:AddChild(saveBtn)
        SkinButton(saveBtn)
    end)

    if saveBtn.frame and topGroup.frame and templateDrop.frame then
        saveBtn.frame:ClearAllPoints()
        saveBtn.frame:SetPoint("TOP", topGroup.frame, "TOP", 0, 0)
        saveBtn.frame:SetPoint("BOTTOM", topGroup.frame, "BOTTOM", 0, 0)
        saveBtn.frame:SetPoint("LEFT", templateDrop.frame, "RIGHT", 10, 0)
        if saveBtn.frame.SetWidth then saveBtn.frame:SetWidth(88) end
    end

    GroupTabSafeStep("deleteBtn build", function()
        deleteBtn = AceGUI:Create("Button")
        deleteBtn._EchoesLogId = "GroupTab.Delete"
        deleteBtn:SetText("Delete")
        deleteBtn:SetHeight(INPUT_HEIGHT)
        deleteBtn:SetCallback("OnClick", function()
            local idx = tonumber(EchoesDB.groupTemplateIndex) or 1
            if idx <= PRESET_COUNT then return end
            if EchoesDB.groupTemplates then
                EchoesDB.groupTemplates[idx] = nil
            end
            if EchoesDB.groupTemplateNames then
                EchoesDB.groupTemplateNames[idx] = nil
            end

            local newMax = GetMaxTemplateIndex()
            if idx > newMax then
                EchoesDB.groupTemplateIndex = Clamp(newMax, 1, newMax)
            end

            local vals = BuildTemplateValues()
            if templateDrop and templateDrop.SetList then
                templateDrop:SetList(vals)
            end
            if templateDrop and templateDrop._EchoesSuppress ~= true and templateDrop.SetValue then
                templateDrop._EchoesSuppress = true
                templateDrop:SetValue(EchoesDB.groupTemplateIndex or 1)
                templateDrop._EchoesSuppress = nil
            end
            RefreshTemplateHeader(EchoesDB.groupTemplateIndex or 1)
            Echoes_Print("Group setup deleted.")
            Echoes_Log("GroupTab: preset deleted index=" .. tostring(idx))
        end)
        topGroup:AddChild(deleteBtn)
        SkinButton(deleteBtn)
    end)

    if deleteBtn.frame and topGroup.frame and saveBtn.frame then
        deleteBtn.frame:ClearAllPoints()
        deleteBtn.frame:SetPoint("TOPRIGHT", topGroup.frame, "TOPRIGHT", -8, 0)
        deleteBtn.frame:SetPoint("BOTTOMRIGHT", topGroup.frame, "BOTTOMRIGHT", -8, 0)
        if deleteBtn.frame.SetWidth then deleteBtn.frame:SetWidth(88) end
    end

    -- Ensure Save stays just left of Delete.
    if saveBtn.frame and deleteBtn.frame then
        saveBtn.frame:ClearAllPoints()
        saveBtn.frame:SetPoint("TOP", topGroup.frame, "TOP", 0, 0)
        saveBtn.frame:SetPoint("BOTTOM", topGroup.frame, "BOTTOM", 0, 0)
        saveBtn.frame:SetPoint("RIGHT", deleteBtn.frame, "LEFT", -10, 0)
        if saveBtn.frame.SetWidth then saveBtn.frame:SetWidth(88) end
    end

    -- Apply initial disabled state
    RefreshTemplateHeader(EchoesDB.groupTemplateIndex or 1)

    local headerPadBottom = AceGUI:Create("SimpleGroup")
    headerPadBottom:SetFullWidth(true)
    headerPadBottom:SetLayout("Flow")
    -- Keep this tight so the grid starts higher.
    headerPadBottom:SetHeight(0)
    container:AddChild(headerPadBottom)
    -- Group Slots panel
    -- Use SimpleGroup instead of InlineGroup to avoid InlineGroup's reserved title space and
    -- border/content anchoring quirks (which can cause children to appear outside the window).
    local gridPanel = AceGUI:Create("SimpleGroup")
    gridPanel:SetFullWidth(true)
    gridPanel:SetLayout("List")
    gridPanel.noAutoHeight = true
    gridPanel:SetHeight((SLOT_GROUP_H * 2) + 26)
    SkinSimpleGroup(gridPanel)
    if gridPanel.frame and gridPanel.frame.SetBackdropColor then
        gridPanel.frame:SetBackdropColor(0.06, 0.06, 0.06, 0.12)
    end
    container:AddChild(gridPanel)
    local gridGroup = AceGUI:Create("SimpleGroup")
    gridGroup:SetFullWidth(true)
    gridGroup:SetLayout("List")
    gridGroup.noAutoHeight = true
    gridGroup:SetHeight((SLOT_GROUP_H * 2) + 2)
    SkinSimpleGroup(gridGroup)
    if gridGroup.frame and gridGroup.frame.SetBackdropColor then
        gridGroup.frame:SetBackdropColor(0.06, 0.06, 0.06, 0.08)
    end
    gridPanel:AddChild(gridGroup)

    local gridRow1 = AceGUI:Create("SimpleGroup")
    gridRow1:SetFullWidth(true)
    gridRow1:SetLayout("Flow")
    gridRow1:SetHeight(SLOT_GROUP_H)
    gridGroup:AddChild(gridRow1)

    local gridRow2 = AceGUI:Create("SimpleGroup")
    gridRow2:SetFullWidth(true)
    gridRow2:SetLayout("Flow")
    gridRow2:SetHeight(SLOT_GROUP_H)
    gridGroup:AddChild(gridRow2)

    local function FixRow2Position()
        if gridRow2.frame and gridRow1.frame then
            gridRow2.frame:ClearAllPoints()
            gridRow2.frame:SetPoint("TOPLEFT", gridRow1.frame, "BOTTOMLEFT", 0, 40)
            gridRow2.frame:SetPoint("TOPRIGHT", gridRow1.frame, "BOTTOMRIGHT", 0, 40)
            if gridRow2.frame.SetHeight then gridRow2.frame:SetHeight(SLOT_GROUP_H) end
        end
    end

    local origGridGroupDoLayout = gridGroup.DoLayout
    gridGroup.DoLayout = function(self, ...)
        if origGridGroupDoLayout then
            origGridGroupDoLayout(self, ...)
        end
        FixRow2Position()
    end
    FixRow2Position()

    local gridBottomPad = AceGUI:Create("SimpleGroup")
    gridBottomPad:SetFullWidth(true)
    gridBottomPad:SetLayout("Flow")
    gridBottomPad:SetHeight(20)
    gridGroup:AddChild(gridBottomPad)

    -- Layout groups in a 3x2 grid (3 on first row, 2 on second row)
    local COLUMN_CONFIG = {
        { rows = 5 }, { rows = 5 }, { rows = 5 }, { rows = 5 }, { rows = 5 },
    }

    slotValues = {}
    for i, v in ipairs(GROUP_SLOT_OPTIONS) do
        slotValues[i] = v
    end

    ALTBOT_INDEX = nil
    for i, v in ipairs(slotValues) do
        if v == "Altbot" then
            ALTBOT_INDEX = i
            break
        end
    end

    self.UI._AltbotIndex = ALTBOT_INDEX

    DISPLAY_TO_CLASSFILE = {
        ["Paladin"] = "PALADIN",
        ["Death Knight"] = "DEATHKNIGHT",
        ["Warrior"] = "WARRIOR",
        ["Shaman"] = "SHAMAN",
        ["Hunter"] = "HUNTER",
        ["Druid"] = "DRUID",
        ["Rogue"] = "ROGUE",
        ["Priest"] = "PRIEST",
        ["Warlock"] = "WARLOCK",
        ["Mage"] = "MAGE",
    }

    CLASSFILE_TO_DISPLAY = {
        ["PALADIN"] = "Paladin",
        ["DEATHKNIGHT"] = "Death Knight",
        ["WARRIOR"] = "Warrior",
        ["SHAMAN"] = "Shaman",
        ["HUNTER"] = "Hunter",
        ["DRUID"] = "Druid",
        ["ROGUE"] = "Rogue",
        ["PRIEST"] = "Priest",
        ["WARLOCK"] = "Warlock",
        ["MAGE"] = "Mage",
    }

    NormalizeAltbotClassText = function(text)
        text = tostring(text or "")
        text = text:gsub("^%s+", ""):gsub("%s+$", "")
        if text == "" then return nil end

        if DISPLAY_TO_CLASSFILE[text] then return text end
        local key = text:upper():gsub("%s+", "")
        if key == "DEATHKNIGHT" then return "Death Knight" end
        if CLASSFILE_TO_DISPLAY[key] then return CLASSFILE_TO_DISPLAY[key] end

        return nil
    end

    local UpdatePrivateDropdownText

    local function GetAltbotClassFileByName(name)
        name = tostring(name or "")
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then return nil end
        if Echoes_NormalizeName then
            name = Echoes_NormalizeName(name)
        end
        local n = NormalizeAltbotName(name)
        if not n or n == "" then return nil end
        local db = EchoesDB and EchoesDB.altbotData
        if not db then return nil end
        local key1 = n:lower()
        local key2 = name:lower()
        local entry = db[key1] or db[key2]
        if entry and entry.classFile then
            return entry.classFile
        end
        return nil
    end

    local function RememberAltbotClassFromFallback(altbotName, fallbackText)
        if not altbotName or altbotName == "" then return end
        local classText = NormalizeAltbotClassText and NormalizeAltbotClassText(fallbackText) or nil
        if not classText or classText == "" then return end
        local classFile = DISPLAY_TO_CLASSFILE and DISPLAY_TO_CLASSFILE[classText]
        if not classFile or classFile == "" then return end

        EchoesDB = _G.EchoesDB or EchoesDB or {}
        EchoesDB.altbotData = EchoesDB.altbotData or {}

        local keyName = tostring(altbotName or "")
        if Echoes_NormalizeName then
            keyName = Echoes_NormalizeName(keyName)
        end
        keyName = NormalizeAltbotName(keyName) or keyName
        if not keyName or keyName == "" then return end

        local lk = keyName:lower()
        local existing = EchoesDB.altbotData[lk]
        if not existing or not existing.classFile or existing.classFile == "" then
            EchoesDB.altbotData[lk] = { name = keyName, classFile = classFile }
        end
    end

    local function ResolveAltbotClassText(altbotName, fallbackText)
        local classFile = altbotName and GetAltbotClassFileByName(altbotName) or nil
        if classFile and classFile ~= "" then
            return CLASSFILE_TO_DISPLAY and CLASSFILE_TO_DISPLAY[classFile] or nil
        end

        local text = NormalizeAltbotClassText and NormalizeAltbotClassText(fallbackText) or nil
        if text and text ~= "" then
            RememberAltbotClassFromFallback(altbotName, text)
            return text
        end
        return nil
    end

    self.ResolveAltbotClassText = ResolveAltbotClassText

    local function ApplyDropdownTextColor(dropdownWidget, r, g, b, a)
        if dropdownWidget and dropdownWidget.text and dropdownWidget.text.SetTextColor then
            dropdownWidget.text:SetTextColor(r, g, b, a or 1)
        end
        if dropdownWidget and dropdownWidget.dropdown and dropdownWidget.dropdown._EchoesPrivateText and dropdownWidget.dropdown._EchoesPrivateText.SetTextColor then
            dropdownWidget.dropdown._EchoesPrivateText:SetTextColor(r, g, b, a or 1)
        end
    end

    local function ApplyGroupSlotSelectedTextColor(dropdownWidget, value)
        if not dropdownWidget or not dropdownWidget.text or not dropdownWidget.text.SetTextColor then return end
        if dropdownWidget.dropdown and dropdownWidget.dropdown._EchoesForceDisabledGrey then
            ApplyDropdownTextColor(dropdownWidget, 0.55, 0.55, 0.55, 1)
            return
        end

        local display = slotValues[value]
        Echoes_Log("GroupTab: ApplyGroupSlotSelectedTextColor value=" .. tostring(value) .. " display=" .. tostring(display))
        if display == "None" or not display then
            ApplyDropdownTextColor(dropdownWidget, 0.60, 0.60, 0.60, 1)
            return
        end

        if display == "Altbot" then
            local altName = dropdownWidget._EchoesAltbotName
            local classFile = GetAltbotClassFileByName(altName)
            local colors = rawget(_G, "RAID_CLASS_COLORS")
            local c = classFile and colors and colors[classFile]
            if c then
                ApplyDropdownTextColor(dropdownWidget, c.r or 1, c.g or 1, c.b or 1, 1)
                if dropdownWidget.dropdown then
                    dropdownWidget.dropdown._EchoesFilledClassFile = classFile
                end
            else
                ApplyDropdownTextColor(dropdownWidget, 0.90, 0.85, 0.70, 1)
                if dropdownWidget.dropdown then
                    dropdownWidget.dropdown._EchoesFilledClassFile = nil
                end
            end
            if dropdownWidget._EchoesAltbotName and dropdownWidget._EchoesAltbotName ~= "" and dropdownWidget.text.SetText then
                dropdownWidget.text:SetText(dropdownWidget._EchoesAltbotName)
            end
            if UpdatePrivateDropdownText then
                UpdatePrivateDropdownText(dropdownWidget)
            end
            return
        end

        local classFile = DISPLAY_TO_CLASSFILE[display]
        local colors = rawget(_G, "RAID_CLASS_COLORS")
        local c = classFile and colors and colors[classFile]
        if c then
            ApplyDropdownTextColor(dropdownWidget, c.r or 1, c.g or 1, c.b or 1, 1)
        else
            ApplyDropdownTextColor(dropdownWidget, 0.90, 0.85, 0.70, 1)
        end
        if UpdatePrivateDropdownText then
            UpdatePrivateDropdownText(dropdownWidget)
        end
    end

    UpdatePrivateDropdownText = function(dd)
        if not dd or not dd.dropdown or not dd.dropdown._EchoesPrivateText or not dd.dropdown._EchoesPrivateText.SetText then return end
        local valueIndex = dd._EchoesSelectedValue or dd.value or 1
        local display = slotValues[valueIndex]
        local displayText
        if display == "Altbot" and dd._EchoesAltbotName and dd._EchoesAltbotName ~= "" then
            displayText = dd._EchoesAltbotName
        else
            displayText = dd.text and dd.text.GetText and dd.text:GetText() or ""
        end
        dd.dropdown._EchoesPrivateText:SetText(tostring(displayText or ""))
        if dd.text and dd.text.GetTextColor and dd.dropdown._EchoesPrivateText.SetTextColor then
            local r, g, b, a = dd.text:GetTextColor()
            if r and g and b then
                dd.dropdown._EchoesPrivateText:SetTextColor(r, g, b, a or 1)
            end
        end
    end

    -- Expose helpers for roster-driven updates.
    self.UI._GroupSlotApplyColor = ApplyGroupSlotSelectedTextColor
    self.UI._GroupSlotSlotValues = slotValues

    self.UI.groupSlots = {}

    for colIndex, cfg in ipairs(COLUMN_CONFIG) do
        local col = AceGUI:Create("InlineGroup")
        col:SetTitle("")
        if col.titletext and col.titletext.SetText then
            col.titletext:SetText("")
            if col.titletext.Hide then col.titletext:Hide() end
        end
        col:SetLayout("List")
        -- 3 columns per row; Flow will wrap the remaining groups to row 2.
        col:SetRelativeWidth(0.325)
        col:SetHeight(SLOT_GROUP_H)
        SkinInlineGroup(col, { border = false, alpha = 0.28 })
        if colIndex <= 3 then
            gridRow1:AddChild(col)
        else
            gridRow2:AddChild(col)
        end

        self.UI.groupSlots[colIndex] = self.UI.groupSlots[colIndex] or {}

        local groupLabel = AceGUI:Create("Label")
        groupLabel:SetText("Group " .. tostring(colIndex))
        groupLabel:SetFullWidth(true)
        groupLabel:SetHeight(GROUP_LABEL_H)
        if groupLabel.label then
            if groupLabel.label.SetTextColor then
                groupLabel.label:SetTextColor(0.85, 0.85, 0.85, 1)
            end
            if groupLabel.label.SetJustifyH then
                groupLabel.label:SetJustifyH("CENTER")
            end
            SetEchoesFont(groupLabel.label, 10, ECHOES_FONT_FLAGS)
        end
        col:AddChild(groupLabel)

        local groupLabelPad = AceGUI:Create("SimpleGroup")
        groupLabelPad:SetFullWidth(true)
        groupLabelPad:SetLayout("Fill")
        if groupLabelPad.SetAutoAdjustHeight then groupLabelPad:SetAutoAdjustHeight(false) end
        groupLabelPad:SetHeight(4)
        col:AddChild(groupLabelPad)

        for rowIndex = 1, cfg.rows do
            local rowGroup = AceGUI:Create("SimpleGroup")
            rowGroup:SetFullWidth(true)
            rowGroup:SetLayout("None")
            if rowGroup.SetAutoAdjustHeight then rowGroup:SetAutoAdjustHeight(false) end
            rowGroup:SetHeight(ROW_H)
            col:AddChild(rowGroup)

            local cycleBtn
            local function EnsureAltbotCycleValues(slot)
                if not slot or not slot.classDrop or not slot.cycleBtn then return end
                local dd = slot.classDrop
                local value = dd._EchoesSelectedValue or dd.value
                local isAltbot = (value == ALTBOT_INDEX) or (dd._EchoesAltbotName and dd._EchoesAltbotName ~= "")
                Echoes_Log("GroupTab: EnsureAltbotCycleValues value=" .. tostring(value) .. " isAltbot=" .. tostring(isAltbot))
                if not isAltbot then return end

                local classText
                if dd.dropdown and dd.dropdown._EchoesFilledClassFile and CLASSFILE_TO_DISPLAY then
                    classText = CLASSFILE_TO_DISPLAY[dd.dropdown._EchoesFilledClassFile]
                end
                if (not classText or classText == "") and dd._EchoesAltbotClassText then
                    classText = NormalizeAltbotClassText and NormalizeAltbotClassText(dd._EchoesAltbotClassText) or dd._EchoesAltbotClassText
                end
                if (not classText or classText == "") and ResolveAltbotClassText then
                    classText = ResolveAltbotClassText(dd._EchoesAltbotName, dd._EchoesAltbotClassText)
                end
                if not classText or classText == "" then return end

                Echoes_Log("GroupTab: EnsureAltbotCycleValues classText=" .. tostring(classText))

                -- Only rebuild cycle values when class actually changes or values are missing.
                local lastClassText = slot.cycleBtn._EchoesCycleClassText
                if lastClassText == classText and slot.cycleBtn.values and #slot.cycleBtn.values > 1 then
                    return
                end

                dd._EchoesAltbotClassText = classText
                local vals = GetCycleValuesForRightText(classText)
                if slot.cycleBtn then
                    local prevLabel = slot.cycleBtn._EchoesSpecLabel
                    slot.cycleBtn.values = { t_unpack(vals) }
                    slot.cycleBtn._EchoesCycleClassText = classText

                    local newIndex = 1
                    if prevLabel and prevLabel ~= "" then
                        for i, it in ipairs(slot.cycleBtn.values) do
                            if type(it) == "table" and it.label == prevLabel then
                                newIndex = i
                                break
                            end
                        end
                    end
                    slot.cycleBtn.index = newIndex
                    if slot.cycleBtn._EchoesCycleUpdate then slot.cycleBtn._EchoesCycleUpdate(slot.cycleBtn) end
                end
            end
            local function CycleUpdate(btn)
                local n = #btn.values
                if n == 0 then
                    btn:SetText("")
                    if btn._EchoesIconTex then btn._EchoesIconTex:Hide() end
                    return
                end
                if btn.index < 1 or btn.index > n then
                    btn.index = 1
                end

                local item = btn.values[btn.index]
                local icon = (type(item) == "table") and item.icon or nil
                local label = (type(item) == "table") and item.label or tostring(item or "")

                Echoes_Log("GroupTab: CycleUpdate label=" .. tostring(label) .. " index=" .. tostring(btn.index) .. "/" .. tostring(n))

                btn._EchoesSpecLabel = label
                btn:SetText("")

                if btn.frame and not btn._EchoesIconTex then
                    local t = btn.frame:CreateTexture(nil, "ARTWORK")
                    t._EchoesNoStrip = true
                    if t.SetDrawLayer then
                        t:SetDrawLayer("OVERLAY")
                    end
                    t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                    t:SetPoint("CENTER", btn.frame, "CENTER", 0, 0)
                    btn._EchoesIconTex = t

                    if btn.frame.HookScript then
                        btn.frame:HookScript("OnEnter", function(self)
                            if rawget(_G, "GameTooltip") and btn._EchoesSpecLabel and btn._EchoesSpecLabel ~= "" then
                                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                                GameTooltip:SetText(btn._EchoesSpecLabel, 1, 1, 1)
                                GameTooltip:Show()
                            end
                        end)
                        btn.frame:HookScript("OnLeave", function()
                            if rawget(_G, "GameTooltip") then GameTooltip:Hide() end
                        end)
                    end
                end

                if btn._EchoesIconTex then
                    local h = (btn.frame and btn.frame.GetHeight and btn.frame:GetHeight()) or INPUT_HEIGHT
                    local size = math.max(8, (h or INPUT_HEIGHT) - 6)
                    if btn._EchoesIconTex.SetSize then
                        btn._EchoesIconTex:SetSize(size, size)
                    else
                        if btn._EchoesIconTex.SetWidth then btn._EchoesIconTex:SetWidth(size) end
                        if btn._EchoesIconTex.SetHeight then btn._EchoesIconTex:SetHeight(size) end
                    end

                    if icon and btn._EchoesIconTex.SetTexture then
                        btn._EchoesIconTex:SetTexture(icon)
                        btn._EchoesIconTex:Show()
                    else
                        btn._EchoesIconTex:Hide()
                    end
                end
            end

            cycleBtn = AceGUI:Create("Button")
            cycleBtn:SetWidth(ROW_H)
            cycleBtn:SetHeight(ROW_H)
            cycleBtn.values = { t_unpack(DEFAULT_CYCLE_VALUES) }
            cycleBtn.index  = 1
            cycleBtn._EchoesCycleUpdate = CycleUpdate

            if cycleBtn.frame and cycleBtn.frame.RegisterForClicks then
                cycleBtn.frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            end

            cycleBtn:SetCallback("OnClick", function(widget, event, button)
                local btn = widget
                if btn._EchoesLocked then return end
                if not btn.values or #btn.values == 0 then return end
                if btn._EchoesSlot then
                    EnsureAltbotCycleValues(btn._EchoesSlot)
                end
                Echoes_Log("GroupTab: cycle click button=" .. tostring(button) .. " count=" .. tostring(#(btn.values or {})))
                if button == "RightButton" then
                    btn.index = btn.index - 1
                    if btn.index < 1 then btn.index = #btn.values end
                else
                    btn.index = btn.index + 1
                    if btn.index > #btn.values then btn.index = 1 end
                end
                CycleUpdate(btn)
            end)

            CycleUpdate(cycleBtn)
            rowGroup:AddChild(cycleBtn)
            SkinButton(cycleBtn)

            if cycleBtn.frame and rowGroup.frame then
                cycleBtn.frame:ClearAllPoints()
                cycleBtn.frame:SetPoint("TOPLEFT", rowGroup.frame, "TOPLEFT", 0, 0)
                cycleBtn.frame:SetPoint("BOTTOMLEFT", rowGroup.frame, "BOTTOMLEFT", 0, 0)
            end

            local nameBtn
            local dd = AceGUI:Create("Dropdown")
            dd:SetList(slotValues)
            dd:SetValue(1)
            dd:SetHeight(ROW_H)

            local function UpdateNameButtonVisibility(selectedValue)
                local value = selectedValue or dd._EchoesSelectedValue or dd.value
                if value == 1 then
                    dd._EchoesAltbotName = nil
                    dd._EchoesAltbotClassText = nil
                end
                local showName = (value ~= 1) and ((value == ALTBOT_INDEX) or (dd._EchoesAltbotName and dd._EchoesAltbotName ~= ""))
                Echoes_Log("GroupTab: UpdateNameButtonVisibility value=" .. tostring(value) .. " showName=" .. tostring(showName))
                if nameBtn and nameBtn.frame then
                    if showName then
                        if nameBtn.frame.SetAlpha then nameBtn.frame:SetAlpha(1) end
                        nameBtn.frame:Show()
                        nameBtn.frame:EnableMouse(true)
                    else
                        if nameBtn.frame.SetAlpha then nameBtn.frame:SetAlpha(0) end
                        nameBtn.frame:Hide()
                        nameBtn.frame:EnableMouse(false)
                    end
                end

                if dd and dd.frame and rowGroup and rowGroup.frame and cycleBtn and cycleBtn.frame then
                    dd.frame:ClearAllPoints()
                    dd.frame:SetPoint("TOP", rowGroup.frame, "TOP", 0, 0)
                    dd.frame:SetPoint("BOTTOM", rowGroup.frame, "BOTTOM", 0, 0)
                    dd.frame:SetPoint("LEFT", cycleBtn.frame, "RIGHT", 8, 0)
                    if showName and nameBtn and nameBtn.frame then
                        dd.frame:SetPoint("RIGHT", nameBtn.frame, "LEFT", -6, 0)
                    else
                        dd.frame:SetPoint("RIGHT", rowGroup.frame, "RIGHT", 0, 0)
                    end
                end
            end

            dd._EchoesUpdateNameButtonVisibility = UpdateNameButtonVisibility

            if dd.dropdown then
                dd.dropdown._EchoesOwned = true
                dd.dropdown._EchoesDropdownKind = "groupSlot"
            end

            dd:SetCallback("OnValueChanged", function(widget, event, value)
                if widget._EchoesSuppress then return end
                widget._EchoesSelectedValue = value

                Echoes_Log("GroupTab: slot class changed value=" .. tostring(value))

                if value ~= ALTBOT_INDEX then
                    widget._EchoesAltbotName = nil
                    widget._EchoesAltbotClassText = nil
                end

                local text = slotValues[value]
                Echoes_Log("GroupTab: slot class changed text=" .. tostring(text))
                local classForCycle = text
                if value == ALTBOT_INDEX then
                    local resolved = ResolveAltbotClassText(widget._EchoesAltbotName, widget._EchoesAltbotClassText)
                    if resolved and resolved ~= "" then
                        widget._EchoesAltbotClassText = resolved
                        classForCycle = resolved
                    end
                end
                local vals = GetCycleValuesForRightText(classForCycle)
                if cycleBtn then
                    cycleBtn.values = { t_unpack(vals) }
                    cycleBtn.index  = 1
                    CycleUpdate(cycleBtn)
                end

                ApplyGroupSlotSelectedTextColor(widget, value)

                UpdateNameButtonVisibility(value)
            end)

            rowGroup:AddChild(dd)
            SkinDropdown(dd)

            if dd.frame and rowGroup.frame and cycleBtn.frame then
                dd.frame:ClearAllPoints()
                dd.frame:SetPoint("TOP", rowGroup.frame, "TOP", 0, 0)
                dd.frame:SetPoint("BOTTOM", rowGroup.frame, "BOTTOM", 0, 0)
                dd.frame:SetPoint("LEFT", cycleBtn.frame, "RIGHT", 8, 0)
                dd.frame:SetPoint("RIGHT", rowGroup.frame, "RIGHT", 0, 0)
            end

            ApplyGroupSlotSelectedTextColor(dd, 1)

            nameBtn = AceGUI:Create("Button")
            nameBtn:SetText("Name")
            nameBtn:SetWidth(65)
            nameBtn:SetHeight(ROW_H)
            local function OnNameButtonClick()
                if not ALTBOT_INDEX then return end
                local cur = dd and (dd._EchoesSelectedValue or dd.value)
                if cur ~= ALTBOT_INDEX then
                    return
                end

                Echoes_Log("GroupTab: altbot name button clicked")

                local initialText = (dd._EchoesAltbotName and tostring(dd._EchoesAltbotName)) or ""
                local ok, err = pcall(function()
                    Echoes:ShowNamePrompt({
                        title = "Custom Character",
                        initialText = initialText,
                        onAccept = function(text)
                            dd._EchoesAltbotName = NormalizeAltbotName(text)

                            dd._EchoesSuppress = true
                            dd:SetValue(ALTBOT_INDEX)
                            dd._EchoesSuppress = nil
                            ApplyGroupSlotSelectedTextColor(dd, ALTBOT_INDEX)
                            UpdatePrivateDropdownText(dd)

                            local classForCycle = ResolveAltbotClassText(dd._EchoesAltbotName, dd._EchoesAltbotClassText)
                            if classForCycle and classForCycle ~= "" then
                                dd._EchoesAltbotClassText = classForCycle
                            end
                            if cycleBtn then
                                local vals = GetCycleValuesForRightText(classForCycle)
                                cycleBtn.values = { t_unpack(vals) }
                                cycleBtn.index  = 1
                                CycleUpdate(cycleBtn)
                            end
                        end,
                    })
                end)

                if not ok then
                    Echoes_Print("Name popup error: " .. tostring(err))
                    Echoes_Log("GroupTab: name popup error: " .. tostring(err))
                end
            end

            nameBtn._EchoesDefaultOnClick = OnNameButtonClick
            nameBtn:SetCallback("OnClick", OnNameButtonClick)
            rowGroup:AddChild(nameBtn)
            SkinButton(nameBtn)

            if nameBtn.frame and rowGroup.frame then
                nameBtn.frame:ClearAllPoints()
                nameBtn.frame:SetPoint("TOPRIGHT", rowGroup.frame, "TOPRIGHT", 0, 0)
                nameBtn.frame:SetPoint("BOTTOMRIGHT", rowGroup.frame, "BOTTOMRIGHT", 0, 0)
            end

            if nameBtn.frame then
                nameBtn.frame:Hide()
                nameBtn.frame:EnableMouse(false)
            end

            UpdateNameButtonVisibility(dd._EchoesSelectedValue or dd.value)

            if nameBtn.text and nameBtn.text.GetFont and nameBtn.text.SetFont then
                local font, _, flags = nameBtn.text:GetFont()
                nameBtn.text:SetFont(font, 9, flags)
            end

            local slotObj = {
                cycleBtn = cycleBtn,
                classDrop = dd,
                nameBtn = nameBtn,
            }
            cycleBtn._EchoesSlot = slotObj
            self.UI.groupSlots[colIndex][rowIndex] = slotObj
        end
    end

    -- "Group 6" column: actions (Invite / Set Talents)
    local actionCol = AceGUI:Create("InlineGroup")
    actionCol:SetTitle("")
    if actionCol.titletext and actionCol.titletext.SetText then
        actionCol.titletext:SetText("")
        if actionCol.titletext.Hide then actionCol.titletext:Hide() end
    end
    actionCol:SetLayout("List")
    actionCol:SetWidth(240)
    actionCol:SetHeight((4 * INPUT_HEIGHT) + 10)
    SkinInlineGroup(actionCol, { border = false, alpha = 0.28 })
    if actionCol.frame and gridPanel.frame then
        actionCol.frame:SetParent(gridPanel.frame)
        actionCol.frame:ClearAllPoints()
        actionCol.frame:SetPoint("BOTTOMRIGHT", gridPanel.frame, "BOTTOMRIGHT", -8, 34)
        actionCol.frame:Show()
    end

    local inviteBtn = AceGUI:Create("Button")
    inviteBtn._EchoesLogId = "GroupTab.Invite"
    inviteBtn:SetText("Invite")
    inviteBtn:SetFullWidth(true)

    local function InviteClick()
        if not self.UI or not self.UI.groupSlots then return end

        Echoes_Log("GroupTab: invite click")

        local function IsInRaidNow()
            return (type(GetNumRaidMembers) == "function") and ((GetNumRaidMembers() or 0) > 0)
        end

        local function CanReorderRaid()
            if type(IsRaidLeader) == "function" and IsRaidLeader() then return true end
            if type(IsRaidOfficer) == "function" and IsRaidOfficer() then return true end
            return false
        end

        local function CompressRaidToFront()
            if not IsInRaidNow() then return false end
            if not CanReorderRaid() then return false end
            if type(GetRaidRosterInfo) ~= "function" or type(SetRaidSubgroup) ~= "function" then return false end

            local n = GetNumRaidMembers() or 0
            if n <= 0 then return false end

            local roster = {}
            for i = 1, n do
                local name, _, subgroup = GetRaidRosterInfo(i)
                name = Echoes_NormalizeName(name)
                subgroup = tonumber(subgroup) or 1
                if name and name ~= "" then
                    roster[#roster + 1] = { name = name, subgroup = subgroup, idx = i }
                end
            end

            table.sort(roster, function(a, b)
                if a.subgroup == b.subgroup then
                    return (a.idx or 0) < (b.idx or 0)
                end
                return (a.subgroup or 0) < (b.subgroup or 0)
            end)

            local needsMove = false
            for newIndex, m in ipairs(roster) do
                local newGroup = math.floor((newIndex - 1) / 5) + 1
                if m.subgroup ~= newGroup then
                    needsMove = true
                    pcall(SetRaidSubgroup, m.name, newGroup)
                end
            end

            return needsMove
        end

        if CompressRaidToFront() then
            if not self._EchoesInviteDeferredAfterCompress then
                self._EchoesInviteDeferredAfterCompress = true
                self:RunAfter(0.8, function()
                    self._EchoesInviteDeferredAfterCompress = false
                    if self.UpdateGroupCreationFromRoster then
                        self:UpdateGroupCreationFromRoster(true)
                    end
                    InviteClick()
                end)
            end
            return
        end

        local displayToCmd = {
            ["Paladin"] = "paladin",
            ["Death Knight"] = "dk",
            ["Warrior"] = "warrior",
            ["Shaman"] = "shaman",
            ["Hunter"] = "hunter",
            ["Druid"] = "druid",
            ["Rogue"] = "rogue",
            ["Priest"] = "priest",
            ["Warlock"] = "warlock",
            ["Mage"] = "mage",
        }

        local function NormalizeAltbotToAddClassCmd(name)
            name = tostring(name or "")
            name = name:gsub("^%s+", ""):gsub("%s+$", "")
            if name == "" then return nil end

            local key = name:lower()
            key = key:gsub("%s+", " ")

            if key == "deathknight" or key == "death knight" or key == "dk" then return "dk" end
            if key == "warrior" then return "warrior" end
            if key == "paladin" then return "paladin" end
            if key == "hunter" then return "hunter" end
            if key == "rogue" then return "rogue" end
            if key == "priest" then return "priest" end
            if key == "shaman" then return "shaman" end
            if key == "warlock" then return "warlock" end
            if key == "mage" then return "mage" end
            if key == "druid" then return "druid" end
            return nil
        end

        local function SlotHasConfiguredClass(slot)
            if not slot or not slot.classDrop then return false end
            if (slot._EchoesMember and slot._EchoesMember.isPlayer) or (slot.cycleBtn and slot.cycleBtn._EchoesLocked) then
                return false
            end
            local dd = slot.classDrop
            local value = dd._EchoesSelectedValue or dd.value or 1
            local classText = slotValues[value]
            return (classText ~= nil) and (classText ~= "None")
        end

        local function GroupHasMembers(g)
            for p = 1, 5 do
                local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                if slot and slot._EchoesMember then
                    return true
                end
            end
            return false
        end

        local function SetSlotConfig(slot, valueIndex, specLabel, altbotName, altbotClassText)
            if not slot or not slot.classDrop then return end
            if slot._EchoesMember then return end
            if (slot.cycleBtn and slot.cycleBtn._EchoesLocked) then return end

            local dd = slot.classDrop
            valueIndex = tonumber(valueIndex) or 1

            if valueIndex ~= ALTBOT_INDEX then
                dd._EchoesAltbotName = nil
                dd._EchoesAltbotClassText = nil
            else
                dd._EchoesAltbotName = NormalizeAltbotName(altbotName)
                dd._EchoesAltbotClassText = NormalizeAltbotClassText(altbotClassText)
            end

            dd:SetValue(valueIndex)
            dd._EchoesSelectedValue = valueIndex
            if dd._EchoesUpdateNameButtonVisibility then
                dd._EchoesUpdateNameButtonVisibility(valueIndex)
            end
            if self.UI and self.UI._GroupSlotApplyColor then
                self.UI._GroupSlotApplyColor(dd, valueIndex)
            end
            UpdatePrivateDropdownText(dd)

            if specLabel and specLabel ~= "" and slot.cycleBtn and slot.cycleBtn.values and slot.cycleBtn._EchoesCycleUpdate then
                local desired = tostring(specLabel)
                for i, item in ipairs(slot.cycleBtn.values) do
                    local label = (type(item) == "table") and item.label or tostring(item or "")
                    if label == desired then
                        slot.cycleBtn.index = i
                        slot.cycleBtn._EchoesCycleUpdate(slot.cycleBtn)
                        break
                    end
                end
            end
        end

        local function ReadSlotConfig(slot)
            if not slot or not slot.classDrop then
                return { valueIndex = 1, specLabel = "", altbotName = nil, altbotClassText = nil }
            end
            local dd = slot.classDrop
            local valueIndex = dd._EchoesSelectedValue or dd.value or 1
            local specLabel = (slot.cycleBtn and slot.cycleBtn._EchoesSpecLabel) or ""
            local altbotName = dd._EchoesAltbotName
            local altbotClassText = dd._EchoesAltbotClassText
            return { valueIndex = valueIndex, specLabel = specLabel, altbotName = altbotName, altbotClassText = altbotClassText }
        end

        local function SlotIsMovable(slot)
            if not slot or not slot.classDrop then return false end
            if slot._EchoesMember then return false end
            if (slot._EchoesMember and slot._EchoesMember.isPlayer) then return false end
            if (slot.cycleBtn and slot.cycleBtn._EchoesLocked) then return false end
            return true
        end

        local function CompactInvitePlanToFront()
            local sources = {}

            for g = 1, 5 do
                for p = 1, 5 do
                    local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                    if SlotIsMovable(slot) and SlotHasConfiguredClass(slot) then
                        sources[#sources + 1] = ReadSlotConfig(slot)
                    end
                end
            end

            if #sources == 0 then return end

            for g = 1, 5 do
                for p = 1, 5 do
                    local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                    if SlotIsMovable(slot) and SlotHasConfiguredClass(slot) then
                        SetSlotConfig(slot, 1, "", nil, nil)
                    end
                end
            end

            local i = 1
            for g = 1, 5 do
                for p = 1, 5 do
                    local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                    if SlotIsMovable(slot) then
                        local cfg = sources[i]
                        if not cfg then
                            return
                        end
                        SetSlotConfig(slot, cfg.valueIndex, cfg.specLabel, cfg.altbotName, cfg.altbotClassText)
                        i = i + 1
                    end
                end
            end
        end

        -- Preserve slot positions when inviting (do not auto-compact configured slots).

        local function GroupHasAnyConfigured(g)
            for p = 1, 5 do
                local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                if SlotHasConfiguredClass(slot) then
                    return true
                end
            end
            return false
        end

        local maxGroupToInvite = 0
        for g = 1, 5 do
            if GroupHasAnyConfigured(g) or GroupHasMembers(g) then
                maxGroupToInvite = g
            end
        end

        if maxGroupToInvite <= 0 then
            Echoes_Print("Nothing to invite.")
            Echoes_Log("GroupTab: invite aborted (nothing to invite)")
            return
        end

        self._EchoesInviteSessionActive = true
        self._EchoesInviteHelloFrom = {}
        self._EchoesInviteExpectedByName = {}

        local configuredCount = 0
        for g = 1, maxGroupToInvite do
            for p = 1, 5 do
                local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                if slot and slot.classDrop then
                    if not ((slot._EchoesMember and slot._EchoesMember.isPlayer) or (slot.cycleBtn and slot.cycleBtn._EchoesLocked)) then
                        local dd = slot.classDrop
                        local value = dd._EchoesSelectedValue or dd.value or 1
                        local classText = slotValues[value]
                        if classText and classText ~= "None" then
                            configuredCount = configuredCount + 1
                        end
                    end
                end
            end
        end
        self._EchoesInviteNeedsRaid = (configuredCount > 4)

        self._EchoesPlannedTalentByPos = self._EchoesPlannedTalentByPos or {}

        local actions = {}
        local seenAddByName = {}
        for g = 1, maxGroupToInvite do
            self._EchoesPlannedTalentByPos[g] = {}
            for p = 1, 5 do
                local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                if slot and slot.classDrop then
                    if (slot._EchoesMember and slot._EchoesMember.isPlayer) or (slot.cycleBtn and slot.cycleBtn._EchoesLocked) then
                        self._EchoesPlannedTalentByPos[g][p] = nil
                    else
                        local dd = slot.classDrop
                        local value = dd._EchoesSelectedValue or dd.value or 1
                        local classText = slotValues[value]

                        local specLabel = (slot.cycleBtn and slot.cycleBtn._EchoesSpecLabel) or ""
                        if classText and classText ~= "None" then
                            self._EchoesPlannedTalentByPos[g][p] = { classText = tostring(classText), specLabel = tostring(specLabel) }
                        else
                            self._EchoesPlannedTalentByPos[g][p] = nil
                        end

                        if not slot._EchoesMember then
                            if classText == "Altbot" then
                                local name = dd._EchoesAltbotName
                                name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
                                if name ~= "" then
                                    local addClassCmd = NormalizeAltbotToAddClassCmd(name)
                                    if addClassCmd then
                                        actions[#actions + 1] = {
                                            kind = "chat_wait_hello",
                                            msg = ".playerbots bot addclass " .. addClassCmd,
                                            channel = "GUILD",
                                            helloTimeout = 2.5,
                                            postInviteTimeout = 2.5,
                                            plan = { classText = tostring(classText or ""), specLabel = tostring(specLabel or ""), group = g, slot = p },
                                        }
                                    else
                                        local norm = Echoes_NormalizeName(name)
                                        if norm ~= "" then
                                            self._EchoesInviteExpectedByName[norm:lower()] = norm
                                        end
                                        if not seenAddByName[name:lower()] then
                                            seenAddByName[name:lower()] = true
                                            actions[#actions + 1] = {
                                                kind = "chat_wait_hello",
                                                msg = ".playerbots bot add " .. name,
                                                channel = "GUILD",
                                                helloTimeout = 2.5,
                                                postInviteTimeout = 2.5,
                                                plan = { classText = tostring(classText or ""), specLabel = tostring(specLabel or ""), group = g, slot = p },
                                            }
                                        end
                                    end
                                end
                            elseif classText and classText ~= "None" then
                                local cmd = displayToCmd[classText]
                                if cmd then
                                    actions[#actions + 1] = {
                                        kind = "chat_wait_hello",
                                        msg = ".playerbots bot addclass " .. cmd,
                                        channel = "GUILD",
                                        helloTimeout = 2.5,
                                        postInviteTimeout = 2.5,
                                        plan = { classText = tostring(classText or ""), specLabel = tostring(specLabel or ""), group = g, slot = p },
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end

        for g = maxGroupToInvite + 1, 5 do
            self._EchoesPlannedTalentByPos[g] = nil
        end

        if #actions == 0 then
            Echoes_Print("Nothing to invite.")
            return
        end

        local function IsInRaid()
            return (type(GetNumRaidMembers) == "function") and ((GetNumRaidMembers() or 0) > 0)
        end

        local function PartyMemberCount()
            return (type(GetNumPartyMembers) == "function") and (GetNumPartyMembers() or 0) or 0
        end

        local function CurrentGroupSize()
            if IsInRaid() then
                return (type(GetNumRaidMembers) == "function") and (GetNumRaidMembers() or 0) or 0
            end
            local nParty = PartyMemberCount()
            if nParty > 0 then
                return nParty + 1
            end
            return 1
        end

        local function EnsureRaidIfWouldExceed5(extraMembers)
            extraMembers = tonumber(extraMembers) or 0
            if extraMembers <= 0 then return false end
            if IsInRaid() then return false end

            if (CurrentGroupSize() + extraMembers) <= 5 then
                return false
            end

            local nParty = PartyMemberCount()
            if nParty <= 0 then
                self._EchoesInviteNeedsRaid = true
                return false
            end

            if type(ConvertToRaid) ~= "function" then return false end
            local now = (type(GetTime) == "function" and GetTime()) or 0
            if not self._EchoesLastConvertToRaid or (now - self._EchoesLastConvertToRaid) > 1.0 then
                self._EchoesLastConvertToRaid = now
                ConvertToRaid()
                return true
            end
            return false
        end

        local function StartInviteRun()
            Echoes_Print("Inviting...")
            Echoes_Log("GroupTab: inviting start actions=" .. tostring(#actions))
            self:RunActionQueue(actions, 0.70, function()
                self:RunAfter(1.2, function()
                    local missing = {}
                    local dedupe = {}

                    local function QueueInvite(name)
                        name = Echoes_NormalizeName(name)
                        if name == "" then return end
                        local k = name:lower()
                        if dedupe[k] then return end
                        if Echoes_IsNameInGroup(name) then return end
                        dedupe[k] = true
                        missing[#missing + 1] = { kind = "invite", name = name }
                    end

                    for nm, _ in pairs(self._EchoesInviteHelloFrom or {}) do
                        QueueInvite(nm)
                    end

                    for _, nm in pairs(self._EchoesInviteExpectedByName or {}) do
                        QueueInvite(nm)
                    end

                    if #missing > 0 then
                        local converted = EnsureRaidIfWouldExceed5(#missing)
                        Echoes_Print("Inviting missing bots...")
                        if converted then
                            self:RunAfter(0.8, function()
                                self:RunActionQueue(missing, 0.70)
                            end)
                        else
                            self:RunActionQueue(missing, 0.70)
                        end
                    end

                    self._EchoesInviteSessionActive = false
                    Echoes_Log("GroupTab: inviting complete missing=" .. tostring(#missing))
                end)
            end)
        end

        local converted = EnsureRaidIfWouldExceed5(#actions)
        if converted then
            self:RunAfter(0.8, StartInviteRun)
        else
            StartInviteRun()
        end
    end

    inviteBtn:SetCallback("OnClick", function()
        InviteClick()
    end)
    actionCol:AddChild(inviteBtn)
    SkinButton(inviteBtn)

    local talentsBtn = AceGUI:Create("Button")
    talentsBtn._EchoesLogId = "GroupTab.SetTalents"
    talentsBtn:SetText("Set Talents")
    talentsBtn:SetFullWidth(true)
    talentsBtn:SetCallback("OnClick", function()
        if not self.UI or not self.UI.groupSlots then return end

        Echoes_Log("GroupTab: set talents click")

        local function SpecLabelToTalentSpec(specLabel)
            local s = tostring(specLabel or "")
            s = s:gsub("^%s+", ""):gsub("%s+$", "")
            local key = s:lower()
            key = key:gsub("%s+", "")

            if key == "bear" then return "bear" end
            if key == "feral" then return "cat" end
            if key == "cat" then return "cat" end
            if key == "protection" then return "prot" end
            if key == "frostfire" then return "frostfire" end

            if key == "restoration" then return "resto" end
            if key == "discipline" then return "disc" end
            if key == "retribution" then return "ret" end
            if key == "enhancement" then return "enh" end
            if key == "elemental" then return "ele" end
            if key == "marksmanship" then return "mm" end
            if key == "survival" then return "sv" end
            if key == "beastmastery" then return "bm" end
            if key == "assassination" then return "as" end
            if key == "demonology" then return "demo" end
            if key == "destruction" then return "destro" end
            if key == "affliction" then return "affli" end

            return key
        end

        local actions = {}
        local seenTargets = {}

        local function NormalizeTargetName(name)
            name = tostring(name or "")
            name = name:gsub("^%s+", ""):gsub("%s+$", "")
            if name == "" then return nil end
            if Echoes_NormalizeName then
                name = Echoes_NormalizeName(name)
            elseif NormalizeAltbotName then
                name = NormalizeAltbotName(name) or name
            end
            return name
        end

        local function QueueSpecWhisper(name, specLabel)
            local normalized = NormalizeTargetName(name)
            if not normalized or normalized == "" then return end
            local key = normalized:lower()
            if seenTargets[key] then return end
            seenTargets[key] = true

            local spec = SpecLabelToTalentSpec(specLabel)
            if spec and spec ~= "" then
                local msg = "talents spec " .. spec .. " pve"
                actions[#actions + 1] = { kind = "chat", msg = msg, channel = "WHISPER", target = normalized }
            end
        end

        for g = 1, 5 do
            for p = 1, 5 do
                local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                local member = slot and slot._EchoesMember or nil
                if member and not member.isPlayer and member.name and member.name ~= "" then
                    local curLabel = (slot.cycleBtn and slot.cycleBtn._EchoesSpecLabel) or ""
                    curLabel = tostring(curLabel or "")
                    curLabel = curLabel:gsub("^%s+", ""):gsub("%s+$", "")
                    if curLabel ~= "" then
                        self._EchoesPlannedTalentByPos = self._EchoesPlannedTalentByPos or {}
                        self._EchoesPlannedTalentByPos[g] = self._EchoesPlannedTalentByPos[g] or {}
                        self._EchoesPlannedTalentByPos[g][p] = self._EchoesPlannedTalentByPos[g][p] or {}
                        self._EchoesPlannedTalentByPos[g][p].specLabel = curLabel

                        self._EchoesPlannedTalentByName = self._EchoesPlannedTalentByName or {}
                        local nk = Echoes_NormalizeName(member.name):lower()
                        self._EchoesPlannedTalentByName[nk] = self._EchoesPlannedTalentByName[nk] or {}
                        self._EchoesPlannedTalentByName[nk].specLabel = curLabel
                    end

                    local byName = nil
                    if self._EchoesPlannedTalentByName then
                        local nk = Echoes_NormalizeName(member.name):lower()
                        byName = self._EchoesPlannedTalentByName[nk]
                    end

                    local planned = self._EchoesPlannedTalentByPos and self._EchoesPlannedTalentByPos[g] and self._EchoesPlannedTalentByPos[g][p]
                    local specLabel = (byName and byName.specLabel) or (planned and planned.specLabel) or (slot.cycleBtn and slot.cycleBtn._EchoesSpecLabel) or ""
                    QueueSpecWhisper(member.name, specLabel)
                elseif slot and slot.classDrop then
                    local altbotName = slot.classDrop._EchoesAltbotName
                    if altbotName and tostring(altbotName) ~= "" then
                        local planned = self._EchoesPlannedTalentByPos and self._EchoesPlannedTalentByPos[g] and self._EchoesPlannedTalentByPos[g][p]
                        local specLabel = (slot.cycleBtn and slot.cycleBtn._EchoesSpecLabel) or (planned and planned.specLabel) or ""
                        specLabel = tostring(specLabel or "")
                        specLabel = specLabel:gsub("^%s+", ""):gsub("%s+$", "")

                        if specLabel ~= "" then
                            self._EchoesPlannedTalentByPos = self._EchoesPlannedTalentByPos or {}
                            self._EchoesPlannedTalentByPos[g] = self._EchoesPlannedTalentByPos[g] or {}
                            self._EchoesPlannedTalentByPos[g][p] = self._EchoesPlannedTalentByPos[g][p] or {}
                            self._EchoesPlannedTalentByPos[g][p].specLabel = specLabel

                            self._EchoesPlannedTalentByName = self._EchoesPlannedTalentByName or {}
                            local nn = NormalizeTargetName(altbotName)
                            if nn and nn ~= "" then
                                local nk = nn:lower()
                                self._EchoesPlannedTalentByName[nk] = self._EchoesPlannedTalentByName[nk] or {}
                                self._EchoesPlannedTalentByName[nk].specLabel = specLabel
                            end
                        end

                        QueueSpecWhisper(altbotName, specLabel)
                    end
                end
            end
        end

        if #actions == 0 then
            Echoes_Print("Set Talents: no bot members found in the roster slots.")
            Echoes_Log("GroupTab: set talents aborted (no members)")
            return
        end

        Echoes_Print("Sending talent commands...")
        Echoes_Log("GroupTab: set talents sending actions=" .. tostring(#actions))
        self:RunActionQueue(actions, 0.35)
    end)
    actionCol:AddChild(talentsBtn)
    SkinButton(talentsBtn)

    local maintBtn = AceGUI:Create("Button")
    maintBtn._EchoesLogId = "GroupTab.Autogear"
    maintBtn:SetText("Autogear")
    maintBtn:SetFullWidth(true)
    maintBtn:SetCallback("OnClick", function()
        Echoes_Log("GroupTab: autogear click")
        self:DoMaintenanceAutogear()
    end)
    actionCol:AddChild(maintBtn)
    SkinButton(maintBtn)

    local raidResetBtn = AceGUI:Create("Button")
    raidResetBtn._EchoesLogId = "GroupTab.RaidReset"
    raidResetBtn:SetText("Raid Reset")
    raidResetBtn:SetFullWidth(true)
    raidResetBtn:SetCallback("OnClick", function()
        local inRaid = (type(GetNumRaidMembers) == "function" and (GetNumRaidMembers() or 0) > 0)
        local inParty = (not inRaid) and (type(GetNumPartyMembers) == "function" and (GetNumPartyMembers() or 0) > 0)
        local ch = inRaid and "RAID" or (inParty and "PARTY" or nil)

        if not ch then
            Echoes_Print("Raid Reset: you are not in a party/raid.")
            Echoes_Log("GroupTab: raid reset aborted (not in group)")
            return
        end
        if type(SendChatMessage) ~= "function" then return end
        Echoes_Log("GroupTab: raid reset send channel=" .. tostring(ch))
        SendChatMessage("resetraids", ch)
    end)
    actionCol:AddChild(raidResetBtn)
    SkinButton(raidResetBtn)

    local function RefreshGroupView(force)
        local inRaid = (type(GetNumRaidMembers) == "function") and ((GetNumRaidMembers() or 0) > 0)
        local inParty = (not inRaid) and (type(GetNumPartyMembers) == "function") and ((GetNumPartyMembers() or 0) > 0)

        if inRaid or inParty then
            self:UpdateGroupCreationFromRoster(force == true)
        else
            LoadPreset(EchoesDB.groupTemplateIndex or 1)
        end

        if container and container.DoLayout then
            container:DoLayout()
        end
    end

    self._EchoesLoadGroupPreset = LoadPreset
    self._EchoesRefreshGroupView = RefreshGroupView

    -- Periodic refresh while the Group tab is active (helps on servers that miss roster events).
    if not self._EchoesGroupRosterTicker and self.ScheduleRepeatingTimer then
        self._EchoesGroupRosterTicker = self:ScheduleRepeatingTimer(function()
            if self.UI and self.UI.activeTab == "GROUP" then
                self:UpdateGroupCreationFromRoster(true)
            end
        end, 1.0)
    end

    RefreshGroupView(true)
end

local function Echoes_GetGroupSlotIndexForClassFile(classFile)
    if not classFile then return nil end
    if classFile == "PALADIN" then return 2 end
    if classFile == "DEATHKNIGHT" then return 3 end
    if classFile == "WARRIOR" then return 4 end
    if classFile == "SHAMAN" then return 5 end
    if classFile == "HUNTER" then return 6 end
    if classFile == "DRUID" then return 7 end
    if classFile == "ROGUE" then return 8 end
    if classFile == "PRIEST" then return 9 end
    if classFile == "WARLOCK" then return 10 end
    if classFile == "MAGE" then return 11 end
    return nil
end

function Echoes:UpdateGroupCreationFromRoster(force)
    if not self.UI or not self.UI.groupSlots then return end

    Echoes_Log("GroupTab: UpdateGroupCreationFromRoster force=" .. tostring(force))

    local applyColor = self.UI._GroupSlotApplyColor
    local colors = rawget(_G, "RAID_CLASS_COLORS")

    local function ClassColorRGB(c)
        if not c then return 1, 1, 1 end
        return c.r or 1, c.g or 1, c.b or 1
    end

    local function SetEnabledForWidget(widget, enabled)
        if not widget then return end
        if widget.SetDisabled then widget:SetDisabled(not enabled) end
        if widget.frame and widget.frame.EnableMouse then widget.frame:EnableMouse(enabled) end
    end

    local function SetEnabledForDropdown(dd, enabled)
        if not dd then return end
        if dd.SetDisabled then dd:SetDisabled(not enabled) end
        if dd.dropdown and dd.dropdown.EnableMouse then dd.dropdown:EnableMouse(enabled) end
        if dd.button then
            if enabled and dd.button.Enable then dd.button:Enable() end
            if (not enabled) and dd.button.Disable then dd.button:Disable() end
        end
    end

    local function SetNameButtonVisible(slot, visible)
        if not slot or not slot.nameBtn then return end
        local f = slot.nameBtn.frame
        if not f then return end

        if visible then
            if f.SetAlpha then f:SetAlpha(1) end
            if f.Show then f:Show() end
            if f.EnableMouse then f:EnableMouse(true) end
        else
            if f.EnableMouse then f:EnableMouse(false) end
            if f.SetAlpha then f:SetAlpha(0) end
            if f.Hide then f:Hide() end
        end
    end

    local function SetNameButtonMode(slot, mode, member)
        if not slot or not slot.nameBtn then return end

        if mode == "kick" and member and member.name and member.name ~= "" then
            slot.nameBtn:SetText("Kick")
            if slot.nameBtn.text and slot.nameBtn.text.SetTextColor then
                slot.nameBtn.text:SetTextColor(1.0, 0.35, 0.35, 1)
            end
            slot.nameBtn._EchoesTextColor = { 1.0, 0.35, 0.35, 1 }
            if slot.nameBtn.frame then
                slot.nameBtn.frame._EchoesTextColor = slot.nameBtn._EchoesTextColor
            end
            slot.nameBtn:SetCallback("OnClick", function()
                if type(SendChatMessage) == "function" then
                    SendChatMessage("logout", "WHISPER", nil, member.name)
                end

                if type(UninviteUnit) == "function" then
                    UninviteUnit(member.name)
                end
            end)
        else
            slot.nameBtn:SetText("Name")
            if slot.nameBtn.text and slot.nameBtn.text.SetTextColor then
                slot.nameBtn.text:SetTextColor(0.90, 0.85, 0.70, 1)
            end
            slot.nameBtn._EchoesTextColor = nil
            if slot.nameBtn.frame then
                slot.nameBtn.frame._EchoesTextColor = nil
            end
            if slot.nameBtn._EchoesDefaultOnClick then
                slot.nameBtn:SetCallback("OnClick", slot.nameBtn._EchoesDefaultOnClick)
            end
        end
    end

    local function SetInviteOnNameClick(slot, name)
        if not slot or not slot.classDrop then return end
        local dd = slot.classDrop
        local host = dd.frame
        if not host or type(CreateFrame) ~= "function" then return end

        name = Echoes_NormalizeName(name)
        slot._EchoesInviteClickName = (name ~= "" and name) or nil
        Echoes_Log("GroupTab: SetInviteOnNameClick name=" .. tostring(name))

        if not slot._EchoesInviteOverlay then
            local overlay = CreateFrame("Button", nil, host)
            overlay:SetAllPoints(host)
            if host.GetFrameLevel and overlay.SetFrameLevel then
                overlay:SetFrameLevel((host:GetFrameLevel() or 0) + 10)
            end
            overlay:RegisterForClicks("LeftButtonUp")
            overlay:SetScript("OnClick", function()
                local nm = slot and slot._EchoesInviteClickName
                nm = Echoes_NormalizeName(nm)
                Echoes_Log("GroupTab: invite name click nm=" .. tostring(nm))
                if nm == "" then return end
                if Echoes_IsNameInGroup and Echoes_IsNameInGroup(nm) then
                    Echoes_Log("GroupTab: invite click ignored (already in group) nm=" .. tostring(nm))
                    return
                end
                if type(InviteUnit) == "function" then
                    InviteUnit(nm)
                    Echoes_Log("GroupTab: InviteUnit called nm=" .. tostring(nm))
                end
            end)
            slot._EchoesInviteOverlay = overlay
            Echoes_Log("GroupTab: invite overlay created")
        end

        if slot._EchoesInviteOverlay then
            if slot._EchoesInviteClickName then
                slot._EchoesInviteOverlay:Show()
                slot._EchoesInviteOverlay:EnableMouse(true)
                Echoes_Log("GroupTab: invite overlay enabled")
            else
                slot._EchoesInviteOverlay:Hide()
                slot._EchoesInviteOverlay:EnableMouse(false)
                Echoes_Log("GroupTab: invite overlay disabled")
            end
        end
    end

    local function AnchorSlotDropdown(slot, showRightButton)
        if not slot or not slot.classDrop or not slot.classDrop.frame then return end
        if not slot.cycleBtn or not slot.cycleBtn.frame then return end

        local ddFrame = slot.classDrop.frame
        local cycleFrame = slot.cycleBtn.frame
        local rowFrame = cycleFrame.GetParent and cycleFrame:GetParent() or nil
        if not rowFrame then return end

        ddFrame:ClearAllPoints()
        ddFrame:SetPoint("TOP", rowFrame, "TOP", 0, 0)
        ddFrame:SetPoint("BOTTOM", rowFrame, "BOTTOM", 0, 0)
        ddFrame:SetPoint("LEFT", cycleFrame, "RIGHT", 8, 0)
        if showRightButton and slot.nameBtn and slot.nameBtn.frame then
            ddFrame:SetPoint("RIGHT", slot.nameBtn.frame, "LEFT", -6, 0)
        else
            ddFrame:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)
        end
    end

    local function ResetSlot(slot)
        if not slot then return end
        Echoes_Log("GroupTab: ResetSlot")
        SetEnabledForWidget(slot.cycleBtn, true)
        SetEnabledForDropdown(slot.classDrop, true)
        SetEnabledForWidget(slot.nameBtn, true)

        if slot.cycleBtn and slot.cycleBtn.frame then
            if slot.cycleBtn.frame.Show then slot.cycleBtn.frame:Show() end
            if slot.cycleBtn.frame.EnableMouse then slot.cycleBtn.frame:EnableMouse(true) end
        end

        if slot.classDrop and slot.classDrop.button and slot.classDrop.button.EnableMouse then
            slot.classDrop.button:EnableMouse(true)
        end

        local altIndex = self.UI and self.UI._AltbotIndex
        local cur = slot.classDrop and (slot.classDrop._EchoesSelectedValue or slot.classDrop.value)
        local showName = (altIndex and cur == altIndex) or (slot.classDrop and slot.classDrop._EchoesAltbotName and slot.classDrop._EchoesAltbotName ~= "")
        SetNameButtonVisible(slot, showName and true or false)
        AnchorSlotDropdown(slot, showName and true or false)

        slot._EchoesMember = nil
        SetNameButtonMode(slot, "name")
        SetInviteOnNameClick(slot, nil)

        if slot.classDrop and slot.classDrop.SetList and slot.classDrop.SetValue then
            if slot.classDrop.dropdown then
                slot.classDrop.dropdown._EchoesFilledClassFile = nil
            end
            local baseList = self.UI and self.UI._GroupSlotSlotValues
            slot.classDrop._EchoesSuppress = true
            if baseList then
                slot.classDrop:SetList(baseList)
            end
            slot.classDrop:SetValue(1) -- None
            slot.classDrop._EchoesSelectedValue = 1
            slot.classDrop._EchoesAltbotName = nil
            slot.classDrop._EchoesAltbotClassText = nil
            slot.classDrop._EchoesSuppress = nil
            if applyColor then applyColor(slot.classDrop, 1) end
            if slot.classDrop._EchoesUpdateNameButtonVisibility then
                slot.classDrop._EchoesUpdateNameButtonVisibility(1)
            else
                SetNameButtonVisible(slot, false)
                AnchorSlotDropdown(slot, false)
            end
            UpdatePrivateDropdownText(slot.classDrop)
        end

        if slot.cycleBtn then
            slot.cycleBtn.values = { t_unpack(DEFAULT_CYCLE_VALUES) }
            slot.cycleBtn.index = 1
            slot.cycleBtn._EchoesLocked = false
            if slot.cycleBtn._EchoesCycleUpdate then slot.cycleBtn._EchoesCycleUpdate(slot.cycleBtn) end
        end
    end

    local function FillSlot(slot, member)
        if not slot or not member then return end
        Echoes_Log("GroupTab: FillSlot member=" .. tostring(member.name or "") .. " isPlayer=" .. tostring(member.isPlayer))

        slot._EchoesMember = member

        if (not member.classFile or member.classFile == "") and member.unit and type(UnitClass) == "function" then
            member.classFile = select(2, UnitClass(member.unit))
        end

        if (not member.classFile or member.classFile == "") and member.unit and type(UnitClass) == "function" then
            member.classFile = select(2, UnitClass(member.unit))
        end

        local c = member.classFile and colors and colors[member.classFile]
        if slot.classDrop and slot.classDrop.SetList and slot.classDrop.SetValue then
            if slot.classDrop.dropdown then
                slot.classDrop.dropdown._EchoesFilledClassFile = member.classFile
            end
            slot.classDrop._EchoesSuppress = true
            slot.classDrop:SetList({ [1] = member.name or "" })
            slot.classDrop:SetValue(1)
            slot.classDrop._EchoesSuppress = nil

            if slot.classDrop.text and slot.classDrop.text.SetTextColor then
                if c then
                    local r, g, b = ClassColorRGB(c)
                    slot.classDrop.text:SetTextColor(r, g, b, 1)
                else
                    slot.classDrop.text:SetTextColor(1, 1, 1, 1)
                end
            end
        end
        SetEnabledForDropdown(slot.classDrop, false)

        if slot.classDrop and slot.classDrop.text and slot.classDrop.text.SetTextColor then
            if c then
                local r, g, b = ClassColorRGB(c)
                slot.classDrop.text:SetTextColor(r, g, b, 1)
            else
                slot.classDrop.text:SetTextColor(1, 1, 1, 1)
            end
        end

        SetEnabledForWidget(slot.nameBtn, true)
        SetNameButtonVisible(slot, not member.isPlayer)
        AnchorSlotDropdown(slot, not member.isPlayer)
        if not member.isPlayer then
            SetNameButtonMode(slot, "kick", member)
            SetInviteOnNameClick(slot, member.name)
        else
            SetNameButtonMode(slot, "name")
            SetInviteOnNameClick(slot, nil)
        end

        if slot.cycleBtn then
            local byName = nil
            if member.name and self._EchoesPlannedTalentByName then
                local nk = Echoes_NormalizeName(member.name):lower()
                byName = self._EchoesPlannedTalentByName[nk]
            end

            local planned = self._EchoesPlannedTalentByPos and self._EchoesPlannedTalentByPos[member.subgroup or 0] and self._EchoesPlannedTalentByPos[member.subgroup or 0][member.pos or 0]
            local keepLabel = (member._EchoesTemplateSpecLabel and tostring(member._EchoesTemplateSpecLabel) ~= "") and tostring(member._EchoesTemplateSpecLabel)
                or ((byName and byName.specLabel and tostring(byName.specLabel) ~= "") and tostring(byName.specLabel))
                or ((planned and planned.specLabel and tostring(planned.specLabel) ~= "") and tostring(planned.specLabel))
                or slot.cycleBtn._EchoesSpecLabel
            local classIndex = Echoes_GetGroupSlotIndexForClassFile(member.classFile)
            local display = (classIndex and self.UI._GroupSlotSlotValues and self.UI._GroupSlotSlotValues[classIndex]) or nil
            local vals = GetCycleValuesForRightText(display)

            slot.cycleBtn._EchoesLastClassFile = slot.cycleBtn._EchoesLastClassFile or member.classFile
            slot.cycleBtn._EchoesLastClassFile = member.classFile

            slot.cycleBtn.values = { t_unpack(vals) }

            if member.isPlayer then
                local wantLabel = Echoes_GetPlayerSpecLabel(member.classFile)
                if wantLabel then
                    for i, it in ipairs(slot.cycleBtn.values) do
                        if type(it) == "table" and it.label == wantLabel then
                            slot.cycleBtn.index = i
                            break
                        end
                    end
                end
            end

            if not member.isPlayer then
                if keepLabel and keepLabel ~= "" then
                    for i, it in ipairs(slot.cycleBtn.values) do
                        if type(it) == "table" and it.label == keepLabel then
                            slot.cycleBtn.index = i
                            break
                        end
                    end
                end
            end

            if not slot.cycleBtn.index or slot.cycleBtn.index < 1 or slot.cycleBtn.index > #slot.cycleBtn.values then
                slot.cycleBtn.index = 1
            end
            if slot.cycleBtn._EchoesCycleUpdate then slot.cycleBtn._EchoesCycleUpdate(slot.cycleBtn) end
        end

        if slot.cycleBtn then
            slot.cycleBtn._EchoesLocked = member.isPlayer and true or false
        end

        if member.isPlayer and slot.cycleBtn and slot.cycleBtn.frame then
            if slot.cycleBtn.frame.Hide then slot.cycleBtn.frame:Hide() end
            if slot.cycleBtn.frame.EnableMouse then slot.cycleBtn.frame:EnableMouse(false) end
        elseif slot.cycleBtn and slot.cycleBtn.frame then
            if slot.cycleBtn.frame.Show then slot.cycleBtn.frame:Show() end
            if slot.cycleBtn.frame.EnableMouse then slot.cycleBtn.frame:EnableMouse(true) end
        end
    end

    local membersByGroup = {}
    local n = (type(GetNumRaidMembers) == "function" and GetNumRaidMembers()) or 0
    local inRaid = ((n and n > 0) and true) or (UnitInRaid and UnitInRaid("player") and UnitInRaid("player") ~= 0) or false

    local nParty = (type(GetNumPartyMembers) == "function" and GetNumPartyMembers()) or 0
    local inParty = (not inRaid) and (nParty and nParty > 0)
    local forceReset = (force == true)
    if not inRaid and not inParty then
        forceReset = true
    end

    local function IsUnknownName(name)
        name = tostring(name or "")
        local k = name:lower()
        return (k == "unknown" or k == "unkown")
    end

    local function NormalizeAltbotNameSafe(name)
        name = tostring(name or "")
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then return nil end
        if Echoes_NormalizeName then
            name = Echoes_NormalizeName(name)
        end
        return string.upper(name:sub(1, 1)) .. string.lower(name:sub(2))
    end

    local function NormalizeMemberKey(name)
        local n = NormalizeAltbotNameSafe(name)
        if not n or n == "" then return nil end
        return n:lower()
    end

    local function GetTemplateSlotsForIndex(idx)
        if not EchoesDB or not EchoesDB.groupTemplates then return nil end
        local tpl = EchoesDB.groupTemplates[idx]
        if type(tpl) ~= "table" then return nil end
        if type(tpl.slots) == "table" then return tpl.slots end
        if type(tpl.groups) == "table" then return tpl.groups end
        if type(tpl[1]) == "table" then return tpl end
        return nil
    end

    local function ApplyTemplateEntryToSlot(slot, entry)
        if not slot or not slot.classDrop or not entry then return false end

        Echoes_Log("GroupTab: ApplyTemplateEntryToSlot class=" .. tostring(entry.class) .. " altName=" .. tostring(entry.altName))

        slot._EchoesMember = nil
        SetEnabledForWidget(slot.cycleBtn, true)
        SetEnabledForDropdown(slot.classDrop, true)
        SetEnabledForWidget(slot.nameBtn, true)

        local classText = tostring(entry.class or "None")
        local desiredIndex = 1
        local slotValuesList = (self.UI and self.UI._GroupSlotSlotValues) or slotValues or GROUP_SLOT_OPTIONS or {}
        local altbotIndex = ALTBOT_INDEX
        if not altbotIndex then
            for i, v in ipairs(slotValuesList) do
                if v == "Altbot" then
                    altbotIndex = i
                    break
                end
            end
        end
        local resolvedAltbotIndex = altbotIndex or ALTBOT_INDEX
        for i, v in ipairs(slotValuesList) do
            if v == classText then
                desiredIndex = i
                break
            end
        end
        if classText == "Altbot" and resolvedAltbotIndex and desiredIndex == 1 then
            desiredIndex = resolvedAltbotIndex
        end

        local altbotName = (resolvedAltbotIndex and desiredIndex == resolvedAltbotIndex) and NormalizeAltbotNameSafe(entry.altName) or nil
        local altbotClassText = nil
        if resolvedAltbotIndex and desiredIndex == resolvedAltbotIndex then
            local resolver = (self and self.ResolveAltbotClassText) or ResolveAltbotClassText
            if resolver then
                altbotClassText = resolver(altbotName, entry.altClassText)
            else
                altbotClassText = NormalizeAltbotClassText and NormalizeAltbotClassText(entry.altClassText) or nil
            end
        end
        local specLabel = entry.specLabel and tostring(entry.specLabel) or nil

        slot.classDrop._EchoesSuppress = true
        slot.classDrop:SetList(slotValuesList)
        slot.classDrop:SetValue(desiredIndex)
        slot.classDrop._EchoesSelectedValue = desiredIndex
        if resolvedAltbotIndex and desiredIndex == resolvedAltbotIndex then
            slot.classDrop._EchoesAltbotName = altbotName
            slot.classDrop._EchoesAltbotClassText = altbotClassText
        else
            slot.classDrop._EchoesAltbotName = nil
            slot.classDrop._EchoesAltbotClassText = nil
        end
        if slot.classDrop.dropdown then
            slot.classDrop.dropdown._EchoesFilledClassFile = nil
        end
        slot.classDrop._EchoesSuppress = nil

        if applyColor then
            applyColor(slot.classDrop, desiredIndex)
        end
        if slot.classDrop._EchoesUpdateNameButtonVisibility then
            slot.classDrop._EchoesUpdateNameButtonVisibility(desiredIndex)
        end
        SetNameButtonMode(slot, "name")
        local showName = (classText == "Altbot") or (resolvedAltbotIndex and desiredIndex == resolvedAltbotIndex) or (slot.classDrop._EchoesAltbotName and slot.classDrop._EchoesAltbotName ~= "")
        SetNameButtonVisible(slot, showName and true or false)
        AnchorSlotDropdown(slot, showName and true or false)
        if showName and altbotName and altbotName ~= "" then
            SetInviteOnNameClick(slot, altbotName)
        else
            SetInviteOnNameClick(slot, nil)
        end
        if slot.cycleBtn then
            local classForCycle = classText
            if classText == "Altbot" and altbotClassText and altbotClassText ~= "" then
                classForCycle = altbotClassText
            elseif classText == "Altbot" and slot.classDrop and slot.classDrop.dropdown and slot.classDrop.dropdown._EchoesFilledClassFile then
                local cf = slot.classDrop.dropdown._EchoesFilledClassFile
                local display = CLASSFILE_TO_DISPLAY and CLASSFILE_TO_DISPLAY[cf] or nil
                if display and display ~= "" then
                    classForCycle = display
                end
            end
            local vals = GetCycleValuesForRightText(classForCycle)
            slot.cycleBtn.values = { t_unpack(vals) }
            local want = specLabel
            local chosen = 1
            if want and want ~= "" then
                for i, it in ipairs(slot.cycleBtn.values) do
                    if type(it) == "table" and it.label == want then
                        chosen = i
                        break
                    end
                end
            end
            slot.cycleBtn.index = chosen
            if slot.cycleBtn._EchoesCycleUpdate then slot.cycleBtn._EchoesCycleUpdate(slot.cycleBtn) end
        end

        if slot.cycleBtn then
            slot.cycleBtn._EchoesLocked = false
        end

        return true
    end

    local function GetRosterName(unit, rosterName)
        local name = rosterName
        if type(UnitName) == "function" and unit then
            local unitName = UnitName(unit)
            if unitName and unitName ~= "" and not IsUnknownName(unitName) then
                name = unitName
            end
        end
        if not name or name == "" or IsUnknownName(name) then
            return nil
        end
        if Echoes_NormalizeName then
            name = Echoes_NormalizeName(name)
        end
        return name
    end

    local function GetRosterClassFile(unit, rosterClassFile)
        local classFile = rosterClassFile
        if (not classFile or classFile == "") and type(UnitClass) == "function" and unit then
            classFile = select(2, UnitClass(unit))
        end
        if not classFile or classFile == "" then
            return nil
        end
        return classFile
    end

    local function UpdateAltbotDataFromRoster(members)
        EchoesDB = _G.EchoesDB or EchoesDB or {}
        EchoesDB.altbotData = EchoesDB.altbotData or {}
        local db = EchoesDB.altbotData

        for _, groupMembers in pairs(members) do
            for _, m in ipairs(groupMembers) do
                if m and not m.isPlayer and m.name and m.classFile and not IsUnknownName(m.name) then
                    local baseName = Echoes_NormalizeName and Echoes_NormalizeName(m.name) or tostring(m.name)
                    local norm = NormalizeAltbotNameSafe(baseName)
                    if norm and norm ~= "" then
                        local key = norm:lower()
                        local existing = db[key]
                        if not existing or existing.classFile ~= m.classFile or existing.name ~= norm then
                            db[key] = { name = norm, classFile = m.classFile }
                            Echoes_Log("Altbot data updated: " .. tostring(norm) .. " class=" .. tostring(m.classFile))
                        end
                    end
                end
            end
        end
    end

    local needsRetry = false

    if inRaid then
        for i = 1, n do
            local name, _, subgroup, _, _, classFile = GetRaidRosterInfo(i)
            subgroup = tonumber(subgroup)
            if subgroup and subgroup >= 1 and subgroup <= 5 then
                membersByGroup[subgroup] = membersByGroup[subgroup] or {}
                local unit = "raid" .. i
                local fixedName = GetRosterName(unit, name)
                local fixedClass = GetRosterClassFile(unit, classFile)
                if fixedName then
                    membersByGroup[subgroup][#membersByGroup[subgroup] + 1] = {
                        unit = unit,
                        name = fixedName,
                        classFile = fixedClass,
                        isPlayer = (UnitIsUnit and UnitIsUnit(unit, "player")) or false,
                    }
                else
                    if type(UnitExists) == "function" and UnitExists(unit) then
                        needsRetry = true
                    end
                end
            end
        end
    elseif inParty then
        local playerName = GetRosterName("player", UnitName("player"))
        membersByGroup[1] = {
            {
                unit = "player",
                name = playerName,
                classFile = GetRosterClassFile("player", select(2, UnitClass("player"))),
                isPlayer = true,
            },
        }

        for i = 1, math.min(4, nParty) do
            local unit = "party" .. i
            local fixedName = GetRosterName(unit, UnitName(unit))
            local fixedClass = GetRosterClassFile(unit, select(2, UnitClass(unit)))
            local isPlayerUnit = (UnitIsUnit and UnitIsUnit(unit, "player")) or false
            if fixedName and (not isPlayerUnit) and (not (playerName and fixedName == playerName)) then
                membersByGroup[1][#membersByGroup[1] + 1] = {
                    unit = unit,
                    name = fixedName,
                    classFile = fixedClass,
                    isPlayer = false,
                }
            else
                if type(UnitExists) == "function" and UnitExists(unit) then
                    needsRetry = true
                end
            end
        end
    else
        membersByGroup[1] = {
            {
                unit = "player",
                name = GetRosterName("player", UnitName("player")),
                classFile = GetRosterClassFile("player", select(2, UnitClass("player"))),
                isPlayer = true,
            },
        }
    end

    UpdateAltbotDataFromRoster(membersByGroup)

    -- Core rule: never place the player in any roster slot (only Group 1 Slot 5 later).
    for g = 1, 5 do
        local list = membersByGroup[g]
        if list then
            for i = #list, 1, -1 do
                local m = list[i]
                if m and m.isPlayer then
                    table.remove(list, i)
                end
            end
        end
    end

    -- Remap members into their profile group when the name matches.
    do
        local tplSlots = GetTemplateSlotsForIndex(EchoesDB.groupTemplateIndex or 1)
        if tplSlots then
            local nameToSlot = {}
            for g = 1, 5 do
                for p = 1, 5 do
                    local entry = tplSlots[g] and tplSlots[g][p]
                    if entry and type(entry) == "table" and entry.altName then
                        local key = NormalizeMemberKey(entry.altName)
                        if key then
                            nameToSlot[key] = { group = g, pos = p, entry = entry }
                        end
                    end
                end
            end

            local function SlotHasTemplateEntry(group, pos)
                local entry = tplSlots and tplSlots[group] and tplSlots[group][pos] or nil
                return entry ~= nil
            end

            -- Also honor current UI-configured name slots (even if not saved to the template yet).
            if self.UI and self.UI.groupSlots then
                for g = 1, 5 do
                    for p = 1, 5 do
                        if not (g == 1 and p == 5) then
                            local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                            local dd = slot and slot.classDrop
                            local name = dd and dd._EchoesAltbotName
                            if name and name ~= "" then
                                local key = NormalizeMemberKey(name)
                                if key and not nameToSlot[key] then
                                    local specLabel = (slot.cycleBtn and slot.cycleBtn._EchoesSpecLabel) or nil
                                    nameToSlot[key] = { group = g, pos = p, entry = { specLabel = specLabel } }
                                end
                            end
                        end
                    end
                end
            end

            local function FindOpenSlot(remap, group, allowTemplate)
                for p = 1, 5 do
                    if not remap[group][p] and (allowTemplate or not SlotHasTemplateEntry(group, p)) then
                        return p
                    end
                end
                if not allowTemplate then
                    for p = 1, 5 do
                        if not remap[group][p] then return p end
                    end
                end
                return nil
            end

            local rosterGroups = membersByGroup
            local remapped = { [1] = {}, [2] = {}, [3] = {}, [4] = {}, [5] = {} }
            local placed = {}

            -- Place named members into their configured group/slot first.
            for g = 1, 5 do
                for _, m in ipairs(membersByGroup[g] or {}) do
                    if m and m.name then
                        local key = NormalizeMemberKey(m.name)
                        local target = key and nameToSlot[key]
                        if target then
                            local destPos = target.pos
                            if remapped[target.group][destPos] then
                                destPos = FindOpenSlot(remapped, target.group, true)
                            end
                            if destPos then
                                remapped[target.group][destPos] = m
                                placed[key] = true
                                m._EchoesTemplateSpecLabel = target.entry and target.entry.specLabel or nil
                            end
                        end
                    end
                end
            end

            -- Fill remaining members into their current group order.
            for g = 1, 5 do
                for _, m in ipairs(membersByGroup[g] or {}) do
                    if m and m.name then
                        local key = NormalizeMemberKey(m.name)
                        if not (key and placed[key]) then
                            local destPos = FindOpenSlot(remapped, g, false)
                            if destPos then
                                remapped[g][destPos] = m
                                if key then placed[key] = true end
                            end
                        end
                    end
                end
            end

            -- If we're in a raid, nudge named members into their configured group.
            if inRaid and type(SetRaidSubgroup) == "function" then
                local function CanReorderRaid()
                    if type(IsRaidLeader) == "function" and IsRaidLeader() then return true end
                    if type(IsRaidOfficer) == "function" and IsRaidOfficer() then return true end
                    return false
                end

                if CanReorderRaid() then
                    local now = (type(GetTime) == "function") and GetTime() or 0
                    local last = tonumber(self._EchoesRosterAssignCooldownAt) or 0
                    if (now - last) > 0.5 then
                        self._EchoesRosterAssignCooldownAt = now
                        for g = 1, 5 do
                            for _, m in ipairs(rosterGroups[g] or {}) do
                                if m and not m.isPlayer and m.name then
                                    local key = NormalizeMemberKey(m.name)
                                    local target = key and nameToSlot[key]
                                    if target and target.group and target.group ~= g then
                                        pcall(SetRaidSubgroup, m.name, target.group)
                                    end
                                end
                            end
                        end
                    end
                end
            end

            membersByGroup = remapped
        end
    end

    if needsRetry and not self._EchoesRosterRetryPending then
        self._EchoesRosterRetryPending = true
        self:RunAfter(0.6, function()
            self._EchoesRosterRetryPending = false
            if self.UpdateGroupCreationFromRoster then
                self:UpdateGroupCreationFromRoster(true)
            end
        end)
    end

    -- Always show the player in Group 1, Slot 5 for UI purposes.
    do
        local playerMember
        local playerGroup
        local playerPos

        for g, groupMembers in pairs(membersByGroup) do
            for p, m in ipairs(groupMembers) do
                if m and m.isPlayer then
                    playerMember = m
                    playerGroup = g
                    playerPos = p
                    break
                end
            end
            if playerMember then break end
        end

        if not playerMember then
            playerMember = {
                unit = "player",
                name = UnitName("player"),
                classFile = select(2, UnitClass("player")),
                isPlayer = true,
            }
        end

        membersByGroup[1] = membersByGroup[1] or {}
        local occupant = membersByGroup[1][5]
        membersByGroup[1][5] = playerMember

        if playerMember and playerGroup and playerPos and (playerGroup ~= 1 or playerPos ~= 5) then
            membersByGroup[playerGroup] = membersByGroup[playerGroup] or {}
            if occupant then
                membersByGroup[playerGroup][playerPos] = occupant
            else
                membersByGroup[playerGroup][playerPos] = nil
            end
        end
    end


    local function IsKickMode(slot)
        if not slot or not slot.nameBtn or not slot.nameBtn.text or not slot.nameBtn.text.GetText then
            return false
        end
        return slot.nameBtn.text:GetText() == "Kick"
    end

    local occupiedNames = {}
    for g = 1, 5 do
        for _, m in ipairs(membersByGroup[g] or {}) do
            if m and m.name then
                local key = NormalizeMemberKey(m.name)
                if key then
                    occupiedNames[key] = true
                end
            end
        end
    end

    for group = 1, 5 do
        for pos = 1, 5 do
            local slot = self.UI.groupSlots[group] and self.UI.groupSlots[group][pos] or nil
            if slot then
                local member = membersByGroup[group] and membersByGroup[group][pos] or nil
                if member then
                    member.subgroup = group
                    member.pos = pos
                    FillSlot(slot, member)
                else
                    local tplSlots = GetTemplateSlotsForIndex(EchoesDB.groupTemplateIndex or 1)
                    local entry = tplSlots and tplSlots[group] and tplSlots[group][pos] or nil
                    if entry and (not (entry.altName and occupiedNames[NormalizeMemberKey(entry.altName)])) then
                        ApplyTemplateEntryToSlot(slot, entry)
                    else
                        if forceReset or slot._EchoesMember or IsKickMode(slot) then
                            ResetSlot(slot)
                        end
                    end
                end
            end
        end

        -- Always force the player into Group 1, Slot 5 (no spec cycle button).
        do
            local slot = self.UI.groupSlots[1] and self.UI.groupSlots[1][5]
            local classFile = (type(UnitClass) == "function") and select(2, UnitClass("player")) or nil
            local playerName = (type(UnitName) == "function") and UnitName("player") or nil
            local slotValuesList = (self.UI and self.UI._GroupSlotSlotValues) or slotValues or {}
            local map = {
                PALADIN = "Paladin",
                DEATHKNIGHT = "Death Knight",
                WARRIOR = "Warrior",
                SHAMAN = "Shaman",
                HUNTER = "Hunter",
                DRUID = "Druid",
                ROUGE = "Rogue",
                ROGUE = "Rogue",
                PRIEST = "Priest",
                WARLOCK = "Warlock",
                MAGE = "Mage",
            }
            local classText = classFile and map[classFile] or nil

            if slot and slot.classDrop and classText then
                local desiredIndex = 1
                for i, v in ipairs(slotValuesList) do
                    if v == classText then
                        desiredIndex = i
                        break
                    end
                end

                slot._EchoesMember = { isPlayer = true, name = playerName or "", classFile = classFile }

                slot.classDrop._EchoesSuppress = true
                slot.classDrop:SetList({ [1] = playerName or classText })
                slot.classDrop:SetValue(1)
                slot.classDrop._EchoesSelectedValue = 1
                slot.classDrop._EchoesAltbotName = nil
                slot.classDrop._EchoesAltbotClassText = nil
                if slot.classDrop.dropdown then
                    slot.classDrop.dropdown._EchoesFilledClassFile = classFile
                end
                slot.classDrop._EchoesSuppress = nil

                if slot.classDrop.SetDisabled then slot.classDrop:SetDisabled(true) end
                if slot.classDrop.dropdown and slot.classDrop.dropdown.EnableMouse then
                    slot.classDrop.dropdown:EnableMouse(false)
                end
                if slot.classDrop.button then
                    if slot.classDrop.button.Disable then slot.classDrop.button:Disable() end
                end

                if slot.cycleBtn and slot.cycleBtn.frame then
                    if slot.cycleBtn.frame.Hide then slot.cycleBtn.frame:Hide() end
                    if slot.cycleBtn.frame.EnableMouse then slot.cycleBtn.frame:EnableMouse(false) end
                end
            end
        end
    end
end

function Echoes:DoMaintenanceAutogear()
    local inRaid = (type(GetNumRaidMembers) == "function" and (GetNumRaidMembers() or 0) > 0)
    local inParty = (not inRaid) and (type(GetNumPartyMembers) == "function" and (GetNumPartyMembers() or 0) > 0)
    local ch = inRaid and "RAID" or (inParty and "PARTY" or nil)

    if not ch then
        Echoes_Print("Maintenance: you are not in a party/raid.")
        return
    end

    if type(SendChatMessage) ~= "function" then return end

    SendChatMessage("maintenance", ch)

    self:RunAfter(0.5, function()
        if type(SendChatMessage) ~= "function" then return end
        local sent = {}

        if type(UnitName) == "function" then
            local me = Echoes_NormalizeName(UnitName("player"))
            if me ~= "" then sent[me:lower()] = true end
        end

        if type(GetNumRaidMembers) == "function" and type(GetRaidRosterInfo) == "function" then
            local n = GetNumRaidMembers() or 0
            if n > 0 then
                for i = 1, n do
                    local rn = GetRaidRosterInfo(i)
                    rn = Echoes_NormalizeName(rn)
                    local key = rn:lower()
                    if rn ~= "" and not sent[key] then
                        sent[key] = true
                        SendChatMessage("summon", "WHISPER", nil, rn)
                    end
                end
                return
            end
        end

        if type(GetNumPartyMembers) == "function" and type(UnitName) == "function" then
            local nParty = GetNumPartyMembers() or 0
            for i = 1, math.min(4, nParty) do
                local pn = UnitName("party" .. i)
                pn = Echoes_NormalizeName(pn)
                local key = pn:lower()
                if pn ~= "" and not sent[key] then
                    sent[key] = true
                    SendChatMessage("summon", "WHISPER", nil, pn)
                end
            end
        end
    end)

    self:RunAfter(1.0, function()
        if type(SendChatMessage) ~= "function" then return end
        SendChatMessage("autogear", ch)
    end)
end

function Echoes:UpdateGroupCreationPlayerSlot(force)
    self:UpdateGroupCreationFromRoster(force)
end
