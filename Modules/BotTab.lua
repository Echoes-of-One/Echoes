local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")
local AceGUI = LibStub("AceGUI-3.0")

-- Pull shared helpers from the core file.
local CLASSES = Echoes.CLASSES
local SkinSimpleGroup = Echoes.SkinSimpleGroup
local SkinDropdown = Echoes.SkinDropdown
local SkinButton = Echoes.SkinButton
local SetEchoesFont = Echoes.SetEchoesFont
local ECHOES_FONT_FLAGS = Echoes.ECHOES_FONT_FLAGS
local Echoes_Print = Echoes.Print
local Echoes_IsNameInGroup = Echoes.IsNameInGroup
local SendCmdKey = Echoes.SendCmdKey
local GetSelectedClass = Echoes.GetSelectedClass
local NormalizeName = Echoes.NormalizeName

------------------------------------------------------------
-- Bot Control tab
------------------------------------------------------------
function Echoes:BuildBotTab(container)
    local EchoesDB = _G.EchoesDB
    -- Use Flow instead of List to avoid oversized vertical gaps between rows in some AceGUI builds
    -- (List layout can over-allocate spacing depending on widget heights and fontstring metrics on 3.3.5)
    container:SetLayout("Flow")

    -- Build the tab on a single full-width page so the midline between columns
    -- is the true frame center (Flow "spacer" centering always leaves leftover slack).
    do
        local outer = container

        local page = AceGUI:Create("SimpleGroup")
        page:SetFullWidth(true)
        -- Use List so we don't get Flow's built-in 3px vertical spacing between rows.
        page:SetLayout("List")
        outer:AddChild(page)

        container = page
    end

    local ROW_H = 26
    local LABEL_H = 14
    -- Keep gaps very small so nothing spills outside the frame (WoW doesn't clip children).
    local GAP_H = 0
    -- Role matrix is the lowest section; keep it slightly more compact.
    local ROLE_ROW_H = 22
    local ROLE_HDR_H = 16
    local ROLE_TITLE_GAP = 5

    local H_INSET = 8
    local BTN_FONT = 11
    local ROLE_BTN_FONT = 10

    ------------------------------------------------
    -- 1) Class row: dropdown (40%) + spacer + < >
    ------------------------------------------------
    local classGroup = AceGUI:Create("SimpleGroup")
    classGroup:SetFullWidth(true)
    classGroup:SetLayout("None")
    if classGroup.SetAutoAdjustHeight then classGroup:SetAutoAdjustHeight(false) end
    classGroup:SetHeight(ROW_H)
    container:AddChild(classGroup)

    -- Inline "Class" label
    -- NOTE: AceGUI "Label" anchors its FontString to TOPLEFT (justifyV=TOP),
    -- so it appears vertically misaligned next to a full-height Dropdown.
    -- Use a SimpleGroup + manually centered FontString instead.
    local classLabel = AceGUI:Create("SimpleGroup")
    classLabel:SetWidth(50)
    classLabel:SetHeight(ROW_H)
    classLabel:SetLayout("Fill")
    classGroup:AddChild(classLabel)
    SkinSimpleGroup(classLabel)
    if classLabel.frame and classLabel.frame.SetBackdrop then
        -- Match other inline rows: label should be visually "flat".
        classLabel.frame:SetBackdropBorderColor(0, 0, 0, 0)
    end
    if classLabel.frame and classLabel.frame.CreateFontString then
        local fs = classLabel.frame:CreateFontString(nil, "OVERLAY")
        -- WoW 3.3.5 throws "Font not set" if SetText runs before SetFont.
        SetEchoesFont(fs, 11, ECHOES_FONT_FLAGS)
        fs:SetText("Class")
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("MIDDLE")
        fs:SetPoint("LEFT", classLabel.frame, "LEFT", 0, 0)
        fs:SetPoint("RIGHT", classLabel.frame, "RIGHT", 0, 0)
        fs:SetPoint("TOP", classLabel.frame, "TOP", 0, 0)
        fs:SetPoint("BOTTOM", classLabel.frame, "BOTTOM", 0, 0)
        if fs.SetTextColor then fs:SetTextColor(0.85, 0.85, 0.85, 1) end
        classLabel._EchoesFontString = fs
    end

    if classLabel.frame and classGroup.frame then
        classLabel.frame:ClearAllPoints()
        classLabel.frame:SetPoint("LEFT", classGroup.frame, "LEFT", H_INSET, 0)
        classLabel.frame:SetPoint("TOP", classGroup.frame, "TOP", 0, 0)
        classLabel.frame:SetPoint("BOTTOM", classGroup.frame, "BOTTOM", 0, 0)
    end


    local classValues = {}
    for i, c in ipairs(CLASSES) do
        classValues[i] = c.label
    end

    local classDrop = AceGUI:Create("Dropdown")
    classDrop:SetLabel("")
    classDrop:SetList(classValues)
    classDrop:SetValue(EchoesDB.classIndex or 1)
    classDrop:SetHeight(ROW_H)
    classGroup:AddChild(classDrop)
    SkinDropdown(classDrop)

    -- This dropdown's text color is controlled externally (class-color).
    -- Prevent SkinDropdown from resetting it back to the default gold.
    classDrop._EchoesPreserveTextColor = true
    if classDrop.dropdown then
        classDrop.dropdown._EchoesPreserveTextColor = true
    end

    local function ApplyBotClassDropdownColor(idx)
        if not classDrop or not classDrop.text or not classDrop.text.SetTextColor then return end
        idx = tonumber(idx) or (EchoesDB.classIndex or 1)

        local colors = rawget(_G, "RAID_CLASS_COLORS")
        local classFileByIndex = {
            [1]  = "PALADIN",
            [2]  = "DEATHKNIGHT",
            [3]  = "WARRIOR",
            [4]  = "SHAMAN",
            [5]  = "HUNTER",
            [6]  = "DRUID",
            [7]  = "ROGUE",
            [8]  = "PRIEST",
            [9]  = "WARLOCK",
            [10] = "MAGE",
        }
        local cf = classFileByIndex[idx]
        local c = cf and colors and colors[cf]
        if c then
            classDrop.text:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)
            if classDrop.dropdown and classDrop.dropdown._EchoesPrivateText and classDrop.dropdown._EchoesPrivateText.SetTextColor then
                classDrop.dropdown._EchoesPrivateText:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)
            end
        else
            classDrop.text:SetTextColor(0.90, 0.85, 0.70, 1)
            if classDrop.dropdown and classDrop.dropdown._EchoesPrivateText and classDrop.dropdown._EchoesPrivateText.SetTextColor then
                classDrop.dropdown._EchoesPrivateText:SetTextColor(0.90, 0.85, 0.70, 1)
            end
        end
    end

    classDrop:SetCallback("OnValueChanged", function(widget, event, value)
        EchoesDB.classIndex = value
        ApplyBotClassDropdownColor(value)
    end)

    -- Ensure initial color matches selected class.
    ApplyBotClassDropdownColor(EchoesDB.classIndex or 1)


    -- Replace the class cycle arrows with a global Summon button (all roles).
    local summonAllBtn = AceGUI:Create("Button")
    summonAllBtn:SetText("Summon")
    summonAllBtn:SetWidth(90)
    summonAllBtn:SetHeight(ROW_H)
    summonAllBtn._EchoesFontSize = BTN_FONT
    summonAllBtn:SetCallback("OnClick", function()
        SendCmdKey("SUMMON")
    end)
    classGroup:AddChild(summonAllBtn)
    SkinButton(summonAllBtn)

    if summonAllBtn.frame and classGroup.frame then
        summonAllBtn.frame:ClearAllPoints()
        summonAllBtn.frame:SetPoint("RIGHT", classGroup.frame, "RIGHT", -H_INSET, 0)
        summonAllBtn.frame:SetPoint("TOP", classGroup.frame, "TOP", 0, 0)
        summonAllBtn.frame:SetPoint("BOTTOM", classGroup.frame, "BOTTOM", 0, 0)
    end
    if classDrop.frame and classGroup.frame and classLabel.frame and summonAllBtn.frame then
        classDrop.frame:ClearAllPoints()
        classDrop.frame:SetPoint("LEFT", classLabel.frame, "RIGHT", 10, 0)
        classDrop.frame:SetPoint("TOP", classGroup.frame, "TOP", 0, 0)
        classDrop.frame:SetPoint("BOTTOM", classGroup.frame, "BOTTOM", 0, 0)
        classDrop.frame:SetPoint("RIGHT", summonAllBtn.frame, "LEFT", -10, 0)
    end

    ------------------------------------------------
    -- 2) Add / Remove row (centered)
    ------------------------------------------------

    -- Pack the next rows into one tight block (no vertical gaps between rows).
    local topBlock = AceGUI:Create("SimpleGroup")
    topBlock:SetFullWidth(true)
    topBlock:SetLayout("None")
    if topBlock.SetAutoAdjustHeight then topBlock:SetAutoAdjustHeight(false) end
    topBlock:SetHeight(ROW_H * 4)
    container:AddChild(topBlock)
    SkinSimpleGroup(topBlock)
    if topBlock.frame and topBlock.frame.SetBackdropBorderColor then
        topBlock.frame:SetBackdropBorderColor(0, 0, 0, 0)
    end

    local function AnchorTightRow(rowWidget, y)
        if not (rowWidget and rowWidget.frame and topBlock.frame) then return end
        rowWidget.frame:ClearAllPoints()
        rowWidget.frame:SetPoint("TOPLEFT", topBlock.frame, "TOPLEFT", H_INSET, y)
        rowWidget.frame:SetPoint("TOPRIGHT", topBlock.frame, "TOPRIGHT", -H_INSET, y)
    end

    local function LayoutEqualColumns(hostFrame, btnFrames)
        if not (hostFrame and btnFrames and #btnFrames >= 2) then return end

        -- IMPORTANT: In AceGUI SimpleGroup, children are parented to `widget.content`.
        -- Anchoring/splitting to the outer `widget.frame` can include border/backdrop
        -- pixels, which makes the last column look clipped/unequal.
        if hostFrame._EchoesEqualColsHooked then
            return
        end
        hostFrame._EchoesEqualColsHooked = true

        local function apply()
            local w = hostFrame:GetWidth() or 0
            if w <= 0 then return false end

            -- Compute split points in *physical pixels* (effective scale), then
            -- convert back to UI units. This avoids half-pixel splits that can
            -- visually shift the divider and make one column look narrower.
            local scale = 1
            if hostFrame.GetEffectiveScale then
                scale = hostFrame:GetEffectiveScale() or 1
            elseif _G.UIParent and _G.UIParent.GetEffectiveScale then
                scale = _G.UIParent:GetEffectiveScale() or 1
            end
            if not scale or scale <= 0 then scale = 1 end

            -- Prefer actual rendered bounds when available.
            local wPx
            if hostFrame.GetLeft and hostFrame.GetRight then
                local l = hostFrame:GetLeft()
                local r = hostFrame:GetRight()
                if l and r and r > l then
                    wPx = math.floor(((r - l) * scale) + 0.5)
                end
            end
            if not wPx or wPx <= 0 then
                -- Fall back to width; avoid rounding up.
                wPx = math.floor((w * scale) + 1e-6)
            end
            if wPx <= 0 then return false end

            local cols = #btnFrames
            if cols == 2 then
                -- Give any remainder pixel to the right button.
                local leftPx = math.floor(wPx / 2)
                local rightPx = wPx - leftPx
                local leftW = leftPx / scale
                local rightW = rightPx / scale
                local x1 = leftW

                local b1, b2 = btnFrames[1], btnFrames[2]
                b1:ClearAllPoints()
                b1:SetPoint("TOPLEFT", hostFrame, "TOPLEFT", 0, 0)
                b1:SetPoint("BOTTOMLEFT", hostFrame, "BOTTOMLEFT", 0, 0)
                if b1.SetWidth then b1:SetWidth(leftW) end

                b2:ClearAllPoints()
                b2:SetPoint("TOPLEFT", hostFrame, "TOPLEFT", x1, 0)
                b2:SetPoint("BOTTOMLEFT", hostFrame, "BOTTOMLEFT", x1, 0)
                if b2.SetWidth then b2:SetWidth(rightW) end
                return true
            end

            if cols == 3 then
                -- Split into 3 integer widths; give remainder pixels to the right,
                -- then the middle (so the right-most never ends up smaller).
                local base = math.floor(wPx / 3)
                local rem = wPx - (base * 3)
                local w1 = base
                local w2 = base
                local w3 = base + rem

                local w1u = w1 / scale
                local w2u = w2 / scale
                local w3u = w3 / scale
                local x1 = w1u
                local x2 = (w1 + w2) / scale

                local b1, b2, b3 = btnFrames[1], btnFrames[2], btnFrames[3]
                b1:ClearAllPoints()
                b1:SetPoint("TOPLEFT", hostFrame, "TOPLEFT", 0, 0)
                b1:SetPoint("BOTTOMLEFT", hostFrame, "BOTTOMLEFT", 0, 0)
                if b1.SetWidth then b1:SetWidth(w1u) end

                b2:ClearAllPoints()
                b2:SetPoint("TOPLEFT", hostFrame, "TOPLEFT", x1, 0)
                b2:SetPoint("BOTTOMLEFT", hostFrame, "BOTTOMLEFT", x1, 0)
                if b2.SetWidth then b2:SetWidth(w2u) end

                b3:ClearAllPoints()
                b3:SetPoint("TOPLEFT", hostFrame, "TOPLEFT", x2, 0)
                b3:SetPoint("BOTTOMLEFT", hostFrame, "BOTTOMLEFT", x2, 0)
                if b3.SetWidth then b3:SetWidth(w3u) end
            end

            return true
        end

        local function applyWhenReady()
            if apply() then
                if hostFrame._EchoesEqualColsOnUpdate then
                    hostFrame:SetScript("OnUpdate", nil)
                    hostFrame._EchoesEqualColsOnUpdate = nil
                end
                return
            end

            if hostFrame._EchoesEqualColsOnUpdate then return end
            hostFrame._EchoesEqualColsOnUpdate = true
            hostFrame:SetScript("OnUpdate", function(self)
                if apply() then
                    self:SetScript("OnUpdate", nil)
                    self._EchoesEqualColsOnUpdate = nil
                end
            end)
        end

        if hostFrame.HookScript then
            hostFrame:HookScript("OnShow", applyWhenReady)
            hostFrame:HookScript("OnSizeChanged", applyWhenReady)
        else
            hostFrame:SetScript("OnShow", applyWhenReady)
            hostFrame:SetScript("OnSizeChanged", applyWhenReady)
        end

        applyWhenReady()
    end

    local function MakeButton(text, height, fontSize, onClick)
        local b = AceGUI:Create("Button")
        b:SetText(text)
        b:SetHeight(height)
        b._EchoesFontSize = fontSize
        b:SetCallback("OnClick", onClick)
        SkinButton(b)
        return b
    end

    local function MakeTwoButtonRow(parent, height, fontSize, leftText, leftAction, rightText, rightAction)
        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("None")
        if row.SetAutoAdjustHeight then row:SetAutoAdjustHeight(false) end
        row:SetHeight(height)
        parent:AddChild(row)
        SkinSimpleGroup(row)
        if row.frame and row.frame.SetBackdropBorderColor then
            row.frame:SetBackdropBorderColor(0, 0, 0, 0)
        end

        local function ClickFor(action)
            return function()
                if type(action) == "function" then
                    action()
                else
                    SendCmdKey(action)
                end
            end
        end

        local leftBtn = MakeButton(leftText, height, fontSize, ClickFor(leftAction))
        local rightBtn = MakeButton(rightText, height, fontSize, ClickFor(rightAction))
        row:AddChild(leftBtn)
        row:AddChild(rightBtn)

        if (row.content or row.frame) and leftBtn.frame and rightBtn.frame then
            LayoutEqualColumns(row.content or row.frame, { leftBtn.frame, rightBtn.frame })
        end

        return row
    end

    local function MakeThreeButtonRow(parent, height, fontSize, leftText, leftAction, midText, midAction, rightText, rightAction)
        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("None")
        if row.SetAutoAdjustHeight then row:SetAutoAdjustHeight(false) end
        row:SetHeight(height)
        parent:AddChild(row)
        SkinSimpleGroup(row)
        if row.frame and row.frame.SetBackdropBorderColor then
            row.frame:SetBackdropBorderColor(0, 0, 0, 0)
        end

        local function ClickFor(action)
            return function()
                if type(action) == "function" then
                    action()
                else
                    SendCmdKey(action)
                end
            end
        end

        local leftBtn = MakeButton(leftText, height, fontSize, ClickFor(leftAction))
        local midBtn = MakeButton(midText, height, fontSize, ClickFor(midAction))
        local rightBtn = MakeButton(rightText, height, fontSize, ClickFor(rightAction))
        row:AddChild(leftBtn)
        row:AddChild(midBtn)
        row:AddChild(rightBtn)

        if (row.content or row.frame) and leftBtn.frame and midBtn.frame and rightBtn.frame then
            LayoutEqualColumns(row.content or row.frame, { leftBtn.frame, midBtn.frame, rightBtn.frame })
        end

        return row
    end

    local function DoAddClass()
        local c = GetSelectedClass()

        -- Track bots that whisper "Hello!" after we add them.
        self._EchoesBotAddSessionActive = true
        self._EchoesBotAddHelloFrom = {}
        self._EchoesBotAddSessionId = (tonumber(self._EchoesBotAddSessionId) or 0) + 1
        local sessionId = self._EchoesBotAddSessionId

        SendChatMessage(".playerbots bot addclass " .. c.cmd, "GUILD")

        -- If "Hello" bots aren't in group after 10s, re-attempt invites.
        local function ReinviteMissingHello()
            if sessionId ~= self._EchoesBotAddSessionId then return end
            self._EchoesBotAddSessionActive = false

            local helloFrom = self._EchoesBotAddHelloFrom or {}
            local missing = {}
            for name, _ in pairs(helloFrom) do
                if name and name ~= "" and (not Echoes_IsNameInGroup(name)) then
                    missing[#missing + 1] = { kind = "invite", name = name }
                end
            end

            if #missing > 0 then
                Echoes_Print("Re-inviting missing Hello bots...")
                self:RunActionQueue(missing, 0.70)
            end
        end

        if self.ScheduleTimer then
            if self._EchoesBotAddReinviteTimer and self.CancelTimer then
                self:CancelTimer(self._EchoesBotAddReinviteTimer, true)
            end
            self._EchoesBotAddReinviteTimer = self:ScheduleTimer(ReinviteMissingHello, 10.0)
        else
            self:RunAfter(10.0, ReinviteMissingHello)
        end
    end

    local function GetKickTargets()
        local names = {}
        local seen = {}

        local me = ""
        if type(UnitName) == "function" then
            me = NormalizeName(UnitName("player"))
        end

        local function add(name)
            local norm = NormalizeName(name)
            if norm == "" or norm == me or seen[norm] then return end
            seen[norm] = true
            names[#names + 1] = norm
        end

        if type(GetNumRaidMembers) == "function" and type(GetRaidRosterInfo) == "function" then
            local nRaid = GetNumRaidMembers() or 0
            if nRaid > 0 then
                for i = 1, nRaid do
                    local rn = GetRaidRosterInfo(i)
                    add(rn)
                end
                return names
            end
        end

        if type(GetNumPartyMembers) == "function" then
            local nParty = GetNumPartyMembers() or 0
            if nParty > 0 and type(UnitName) == "function" then
                for i = 1, math.min(4, nParty) do
                    local unit = "party" .. i
                    add(UnitName(unit))
                end
            end
        end

        return names
    end

    local function DoRemoveAll()
        local targets = GetKickTargets()
        if #targets == 0 then
            Echoes_Print("Echoes: not in a party or raid")
            return
        end

        local actions = {}
        for _, name in ipairs(targets) do
            actions[#actions + 1] = { kind = "kick", name = name }
        end
        self:RunActionQueue(actions, 0.35)
    end

    local addRemGroup = MakeTwoButtonRow(topBlock, ROW_H, BTN_FONT, "Add", DoAddClass, "Remove All", DoRemoveAll)
    AnchorTightRow(addRemGroup, 0)

    ------------------------------------------------
    -- 3) Utilities rows: Attack/Release, LevelUp/Drink
    ------------------------------------------------
    local function MakeUtilRow(parent, text1, action1, text2, action2)
        return MakeTwoButtonRow(parent, ROW_H, BTN_FONT, text1, action1, text2, action2)
    end

    local function BroadcastAttack()
        local chan
        if type(IsInRaid) == "function" and IsInRaid() then
            chan = "RAID"
        elseif type(GetNumRaidMembers) == "function" and (GetNumRaidMembers() or 0) > 0 then
            chan = "RAID"
        elseif type(GetNumPartyMembers) == "function" and (GetNumPartyMembers() or 0) > 0 then
            chan = "PARTY"
        end

        if not chan then
            Echoes_Print("Echoes: not in a party or raid")
            return
        end

        if type(SendChatMessage) == "function" then
            SendChatMessage("attack", chan)
        end
    end

    local utilRow1 = MakeUtilRow(topBlock, "Attack",  BroadcastAttack, "Release",  "RELEASE")
    AnchorTightRow(utilRow1, -ROW_H)

    local utilRow2 = MakeUtilRow(topBlock, "Level Up","LEVEL_UP", "Drink",    "DRINK")
    AnchorTightRow(utilRow2, -ROW_H * 2)

    ------------------------------------------------
    -- 4) Movement: Follow / Stay / Flee (centered)
    ------------------------------------------------
    local moveGroup = MakeThreeButtonRow(topBlock, ROW_H, BTN_FONT, "Follow", "FOLLOW", "Stay", "STAY", "Flee", "FLEE")
    AnchorTightRow(moveGroup, -ROW_H * 3)

    -- Breathing room between the top control block and the role sections.
    local topRoleGap = AceGUI:Create("Label")
    topRoleGap:SetText(" ")
    topRoleGap:SetFullWidth(true)
    topRoleGap:SetHeight(10)
    container:AddChild(topRoleGap)

    ------------------------------------------------
    -- 5) Role Matrix (compact)
    --    Row 1: Role title (centered)
    --    Row 2: Summon / Stay / Follow
    --    Row 3: Attack / Flee
    ------------------------------------------------
    local rows = {
        { label = "Tank",   su = "TANK_SUMMON",   a="TANK_ATTACK", s="TANK_STAY",   f="TANK_FOLLOW",   fl="TANK_FLEE"   },
        { label = "Melee",  su = "MELEE_SUMMON",  a="MELEE_ATK",   s="MELEE_STAY",  f="MELEE_FOLLOW",  fl="MELEE_FLEE"  },
        { label = "Ranged", su = "RANGED_SUMMON", a="RANGED_ATK",  s="RANGED_STAY", f="RANGED_FOLLOW", fl="RANGED_FLEE" },
        { label = "Healer", su = "HEAL_SUMMON",   a="HEAL_ATTACK", s="HEAL_STAY",   f="HEAL_FOLLOW",   fl="HEAL_FLEE"   },
    }

    local function AddRoleTitle(text)
        local header = AceGUI:Create("SimpleGroup")
        header:SetFullWidth(true)
        header:SetLayout("None")
        if header.SetAutoAdjustHeight then header:SetAutoAdjustHeight(false) end
        header:SetHeight(ROLE_HDR_H)
        return header
    end

    local function EnsureRoleTitle(header, text)
        if not header then return end
        SkinSimpleGroup(header)
        if header.frame and header.frame.SetBackdropBorderColor then
            header.frame:SetBackdropBorderColor(0, 0, 0, 0)
        end

        if header.frame and header.frame.CreateFontString then
            local fs = header.frame:CreateFontString(nil, "OVERLAY")
            SetEchoesFont(fs, 13, ECHOES_FONT_FLAGS)
            fs:SetText(tostring(text or ""))
            fs:SetJustifyH("CENTER")
            fs:SetJustifyV("MIDDLE")
            fs:SetPoint("LEFT", header.frame, "LEFT", 10, 0)
            fs:SetPoint("RIGHT", header.frame, "RIGHT", -10, 0)
            if fs.SetTextColor then fs:SetTextColor(0.95, 0.95, 0.95, 1) end
            header._EchoesRoleHeaderFS = fs
        end
    end

    local function AddRoleRow3(text1, key1, text2, key2, text3, key3)
        -- Equal widths, touching, aligned on the frame centerline.
        local rowGroup = AceGUI:Create("SimpleGroup")
        rowGroup:SetFullWidth(true)
        rowGroup:SetLayout("None")
        if rowGroup.SetAutoAdjustHeight then rowGroup:SetAutoAdjustHeight(false) end
        rowGroup:SetHeight(ROLE_ROW_H)
        SkinSimpleGroup(rowGroup)
        if rowGroup.frame and rowGroup.frame.SetBackdropBorderColor then
            rowGroup.frame:SetBackdropBorderColor(0, 0, 0, 0)
        end

        local leftBtn = MakeButton(text1, ROLE_ROW_H, ROLE_BTN_FONT, function() SendCmdKey(key1) end)
        local midBtn = MakeButton(text2, ROLE_ROW_H, ROLE_BTN_FONT, function() SendCmdKey(key2) end)
        local rightBtn = MakeButton(text3, ROLE_ROW_H, ROLE_BTN_FONT, function() SendCmdKey(key3) end)
        rowGroup:AddChild(leftBtn)
        rowGroup:AddChild(midBtn)
        rowGroup:AddChild(rightBtn)

        if (rowGroup.content or rowGroup.frame) and leftBtn.frame and midBtn.frame and rightBtn.frame then
            LayoutEqualColumns(rowGroup.content or rowGroup.frame, { leftBtn.frame, midBtn.frame, rightBtn.frame })
        end

        return rowGroup
    end

    local function AddRoleRow2(text1, key1, text2, key2)
        -- Equal widths, touching, split exactly on the frame centerline.
        local rowGroup = AceGUI:Create("SimpleGroup")
        rowGroup:SetFullWidth(true)
        rowGroup:SetLayout("None")
        if rowGroup.SetAutoAdjustHeight then rowGroup:SetAutoAdjustHeight(false) end
        rowGroup:SetHeight(ROLE_ROW_H)
        SkinSimpleGroup(rowGroup)
        if rowGroup.frame and rowGroup.frame.SetBackdropBorderColor then
            rowGroup.frame:SetBackdropBorderColor(0, 0, 0, 0)
        end

        local leftBtn = MakeButton(text1, ROLE_ROW_H, ROLE_BTN_FONT, function() SendCmdKey(key1) end)
        local rightBtn = MakeButton(text2, ROLE_ROW_H, ROLE_BTN_FONT, function() SendCmdKey(key2) end)
        rowGroup:AddChild(leftBtn)
        rowGroup:AddChild(rightBtn)

        if (rowGroup.content or rowGroup.frame) and leftBtn.frame and rightBtn.frame then
            LayoutEqualColumns(rowGroup.content or rowGroup.frame, { leftBtn.frame, rightBtn.frame })
        end

        return rowGroup
    end

    for i, row in ipairs(rows) do
        local block = AceGUI:Create("SimpleGroup")
        block:SetFullWidth(true)
        block:SetLayout("None")
        if block.SetAutoAdjustHeight then block:SetAutoAdjustHeight(false) end
        block:SetHeight(ROLE_HDR_H + ROLE_TITLE_GAP + (ROLE_ROW_H * 2))
        container:AddChild(block)
        SkinSimpleGroup(block)
        if block.frame and block.frame.SetBackdropBorderColor then
            block.frame:SetBackdropBorderColor(0, 0, 0, 0)
        end

        local header = AddRoleTitle(row.label)
        block:AddChild(header)
        EnsureRoleTitle(header, row.label)

        local r1 = AddRoleRow3("Summon", row.su, "Stay", row.s, "Follow", row.f)
        block:AddChild(r1)

        local r2 = AddRoleRow2("Attack", row.a, "Flee", row.fl)
        block:AddChild(r2)

        if header.frame and block.frame then
            header.frame:ClearAllPoints()
            header.frame:SetPoint("TOPLEFT", block.frame, "TOPLEFT", H_INSET, 0)
            header.frame:SetPoint("TOPRIGHT", block.frame, "TOPRIGHT", -H_INSET, 0)
        end
        if r1.frame and block.frame then
            r1.frame:ClearAllPoints()
            r1.frame:SetPoint("TOPLEFT", block.frame, "TOPLEFT", H_INSET, -ROLE_HDR_H - ROLE_TITLE_GAP)
            r1.frame:SetPoint("TOPRIGHT", block.frame, "TOPRIGHT", -H_INSET, -ROLE_HDR_H - ROLE_TITLE_GAP)
        end
        if r2.frame and block.frame then
            r2.frame:ClearAllPoints()
            r2.frame:SetPoint("TOPLEFT", block.frame, "TOPLEFT", H_INSET, -ROLE_HDR_H - ROLE_TITLE_GAP - ROLE_ROW_H)
            r2.frame:SetPoint("TOPRIGHT", block.frame, "TOPRIGHT", -H_INSET, -ROLE_HDR_H - ROLE_TITLE_GAP - ROLE_ROW_H)
        end

        local roleGap = AceGUI:Create("Label")
        roleGap:SetText(" ")
        roleGap:SetFullWidth(true)
        roleGap:SetHeight(10)
        container:AddChild(roleGap)
    end
end
