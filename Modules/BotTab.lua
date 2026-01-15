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

------------------------------------------------------------
-- Bot Control tab
------------------------------------------------------------
function Echoes:BuildBotTab(container)
    local EchoesDB = _G.EchoesDB
    -- Use Flow instead of List to avoid oversized vertical gaps between rows in some AceGUI builds
    -- (List layout can over-allocate spacing depending on widget heights and fontstring metrics on 3.3.5)
    container:SetLayout("Flow")

    local ROW_H = 26
    local LABEL_H = 14
    -- Keep gaps very small so nothing spills outside the frame (WoW doesn't clip children).
    local GAP_H = 0
    -- Role matrix is the lowest section; keep it slightly more compact.
    local ROLE_ROW_H = 24
    local ROLE_HDR_H = 18

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
        classLabel.frame:SetPoint("LEFT", classGroup.frame, "LEFT", 10, 0)
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
        else
            classDrop.text:SetTextColor(0.90, 0.85, 0.70, 1)
        end
    end

    classDrop:SetCallback("OnValueChanged", function(widget, event, value)
        EchoesDB.classIndex = value
        ApplyBotClassDropdownColor(value)
    end)

    -- Ensure initial color matches selected class.
    ApplyBotClassDropdownColor(EchoesDB.classIndex or 1)


    local function SetClassIndex(idx)
        if not idx then
            idx = 1
        elseif idx < 1 then
            idx = #CLASSES
        elseif idx > #CLASSES then
            idx = 1
        end
        EchoesDB.classIndex = idx
        classDrop:SetValue(idx)
        ApplyBotClassDropdownColor(idx)
    end

    local prevBtn = AceGUI:Create("Button")
    prevBtn:SetText("<")
    prevBtn:SetWidth(42)
    prevBtn:SetHeight(ROW_H)
    prevBtn:SetCallback("OnClick", function()
        SetClassIndex((EchoesDB.classIndex or 1) - 1)
    end)
    classGroup:AddChild(prevBtn)
    SkinButton(prevBtn)

    local nextBtn = AceGUI:Create("Button")
    nextBtn:SetText(">")
    nextBtn:SetWidth(42)
    nextBtn:SetHeight(ROW_H)
    nextBtn:SetCallback("OnClick", function()
        SetClassIndex((EchoesDB.classIndex or 1) + 1)
    end)
    classGroup:AddChild(nextBtn)
    SkinButton(nextBtn)

    if nextBtn.frame and classGroup.frame then
        nextBtn.frame:ClearAllPoints()
        nextBtn.frame:SetPoint("RIGHT", classGroup.frame, "RIGHT", -10, 0)
        nextBtn.frame:SetPoint("TOP", classGroup.frame, "TOP", 0, 0)
        nextBtn.frame:SetPoint("BOTTOM", classGroup.frame, "BOTTOM", 0, 0)
    end
    if prevBtn.frame and nextBtn.frame then
        prevBtn.frame:ClearAllPoints()
        prevBtn.frame:SetPoint("RIGHT", nextBtn.frame, "LEFT", -6, 0)
        prevBtn.frame:SetPoint("TOP", classGroup.frame, "TOP", 0, 0)
        prevBtn.frame:SetPoint("BOTTOM", classGroup.frame, "BOTTOM", 0, 0)
    end
    if classDrop.frame and classGroup.frame and classLabel.frame and prevBtn.frame then
        classDrop.frame:ClearAllPoints()
        classDrop.frame:SetPoint("LEFT", classLabel.frame, "RIGHT", 10, 0)
        classDrop.frame:SetPoint("TOP", classGroup.frame, "TOP", 0, 0)
        classDrop.frame:SetPoint("BOTTOM", classGroup.frame, "BOTTOM", 0, 0)
        classDrop.frame:SetPoint("RIGHT", prevBtn.frame, "LEFT", -10, 0)
    end

    ------------------------------------------------
    -- 2) Add / Remove row (centered)
    ------------------------------------------------
    local addRemGroup = AceGUI:Create("SimpleGroup")
    addRemGroup:SetFullWidth(true)
    addRemGroup:SetLayout("Flow")
    container:AddChild(addRemGroup)

    local spacerL = AceGUI:Create("SimpleGroup")
    spacerL:SetRelativeWidth(0.05)
    spacerL:SetLayout("Flow")
    addRemGroup:AddChild(spacerL)

    local addBtn = AceGUI:Create("Button")
    addBtn:SetText("Add")
    addBtn:SetRelativeWidth(0.45)
    addBtn:SetHeight(ROW_H)
    addBtn:SetCallback("OnClick", function()
        local c = GetSelectedClass()

        -- Track bots that whisper "Hello!" after we add them.
        self._EchoesBotAddSessionActive = true
        self._EchoesBotAddHelloFrom = {}
        self._EchoesBotAddSessionId = (tonumber(self._EchoesBotAddSessionId) or 0) + 1
        local sessionId = self._EchoesBotAddSessionId

        SendChatMessage(".playerbots bot addclass " .. c.cmd, "GUILD")

        -- If "Hello" bots aren't in group after 10s, re-attempt invites.
        self:RunAfter(10.0, function()
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
        end)
    end)
    addRemGroup:AddChild(addBtn)
    SkinButton(addBtn)

    local remBtn = AceGUI:Create("Button")
    remBtn:SetText("Remove All")
    remBtn:SetRelativeWidth(0.45)
    remBtn:SetHeight(ROW_H)
    remBtn:SetCallback("OnClick", function()
        SendCmdKey("REMOVE_ALL")
    end)
    addRemGroup:AddChild(remBtn)
    SkinButton(remBtn)

    local spacerR = AceGUI:Create("SimpleGroup")
    spacerR:SetRelativeWidth(0.05)
    spacerR:SetLayout("Flow")
    addRemGroup:AddChild(spacerR)

    addRemGroup:SetHeight(ROW_H + 2)

    ------------------------------------------------
    -- 3) Utilities rows: Summon/Release, LevelUp/Drink
    ------------------------------------------------
    local function MakeUtilRow(text1, key1, text2, key2)
        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")
        container:AddChild(row)

        local rSpacerL = AceGUI:Create("SimpleGroup")
        rSpacerL:SetRelativeWidth(0.05)
        rSpacerL:SetLayout("Flow")
        row:AddChild(rSpacerL)

        local b1 = AceGUI:Create("Button")
        b1:SetText(text1)
        b1:SetRelativeWidth(0.45)
        b1:SetHeight(ROW_H)
        b1:SetCallback("OnClick", function() SendCmdKey(key1) end)
        row:AddChild(b1)
        SkinButton(b1)

        local b2 = AceGUI:Create("Button")
        b2:SetText(text2)
        b2:SetRelativeWidth(0.45)
        b2:SetHeight(ROW_H)
        b2:SetCallback("OnClick", function() SendCmdKey(key2) end)
        row:AddChild(b2)
        SkinButton(b2)

        local rSpacerR = AceGUI:Create("SimpleGroup")
        rSpacerR:SetRelativeWidth(0.05)
        rSpacerR:SetLayout("Flow")
        row:AddChild(rSpacerR)

        row:SetHeight(ROW_H + 2)
    end

    MakeUtilRow("Summon",  "SUMMON",   "Release",  "RELEASE")
    MakeUtilRow("Level Up","LEVEL_UP", "Drink",    "DRINK")

    ------------------------------------------------
    -- 4) Movement: Follow / Stay / Flee (centered)
    ------------------------------------------------
    local moveGroup = AceGUI:Create("SimpleGroup")
    moveGroup:SetFullWidth(true)
    moveGroup:SetLayout("Flow")
    container:AddChild(moveGroup)

    local mSpacerL = AceGUI:Create("SimpleGroup")
    mSpacerL:SetRelativeWidth(0.05)
    mSpacerL:SetLayout("Flow")
    moveGroup:AddChild(mSpacerL)

    local followBtn = AceGUI:Create("Button")
    followBtn:SetText("Follow")
    followBtn:SetRelativeWidth(0.30)
    followBtn:SetHeight(ROW_H)
    followBtn:SetCallback("OnClick", function() SendCmdKey("FOLLOW") end)
    moveGroup:AddChild(followBtn)
    SkinButton(followBtn)

    local stayBtn = AceGUI:Create("Button")
    stayBtn:SetText("Stay")
    stayBtn:SetRelativeWidth(0.30)
    stayBtn:SetHeight(ROW_H)
    stayBtn:SetCallback("OnClick", function() SendCmdKey("STAY") end)
    moveGroup:AddChild(stayBtn)
    SkinButton(stayBtn)

    local fleeBtn = AceGUI:Create("Button")
    fleeBtn:SetText("Flee")
    fleeBtn:SetRelativeWidth(0.30)
    fleeBtn:SetHeight(ROW_H)
    fleeBtn:SetCallback("OnClick", function() SendCmdKey("FLEE") end)
    moveGroup:AddChild(fleeBtn)
    SkinButton(fleeBtn)

    local mSpacerR = AceGUI:Create("SimpleGroup")
    mSpacerR:SetRelativeWidth(0.05)
    mSpacerR:SetLayout("Flow")
    moveGroup:AddChild(mSpacerR)

    moveGroup:SetHeight(ROW_H + 2)

    -- Extra vertical spacing between global movement buttons and the role matrix
    -- (Empty SimpleGroups can collapse in AceGUI Flow layout; use a Label spacer instead.)
    local moveRoleGap = AceGUI:Create("Label")
    moveRoleGap:SetText(" ")
    moveRoleGap:SetFullWidth(true)
    moveRoleGap:SetHeight(GAP_H)
    container:AddChild(moveRoleGap)

    ------------------------------------------------
    -- 5) Role Matrix: label + 4 buttons filling the row
    ------------------------------------------------
    local rows = {
        { label = "Tank",   su = "TANK_SUMMON",   a="TANK_ATTACK", s="TANK_STAY",   f="TANK_FOLLOW",   fl="TANK_FLEE"   },
        { label = "Melee",  su = "MELEE_SUMMON",  a="MELEE_ATK",   s="MELEE_STAY",  f="MELEE_FOLLOW",  fl="MELEE_FLEE"  },
        { label = "Ranged", su = "RANGED_SUMMON", a="RANGED_ATK",  s="RANGED_STAY", f="RANGED_FOLLOW", fl="RANGED_FLEE" },
        { label = "Healer", su = "HEAL_SUMMON",   a="HEAL_ATTACK", s="HEAL_STAY",   f="HEAL_FOLLOW",   fl="HEAL_FLEE"   },
    }

    for i, row in ipairs(rows) do
        -- Role header: keep the label and Summon button close together and inside the frame.
        local header = AceGUI:Create("SimpleGroup")
        header:SetFullWidth(true)
        header:SetLayout("None")
        if header.SetAutoAdjustHeight then header:SetAutoAdjustHeight(false) end
        header:SetHeight(ROLE_HDR_H)
        container:AddChild(header)
        SkinSimpleGroup(header)
        if header.frame and header.frame.SetBackdropBorderColor then
            header.frame:SetBackdropBorderColor(0, 0, 0, 0)
        end

        local summonBtn = AceGUI:Create("Button")
        summonBtn:SetText("Summon")
        summonBtn:SetWidth(90)
        summonBtn:SetHeight(ROLE_HDR_H)
        summonBtn:SetCallback("OnClick", function() SendCmdKey(row.su) end)
        header:AddChild(summonBtn)
        SkinButton(summonBtn)

        if summonBtn.frame and header.frame then
            summonBtn.frame:ClearAllPoints()
            -- Keep summon X position consistent across rows and split the row at center.
            summonBtn.frame:SetPoint("LEFT", header.frame, "CENTER", 10, 0)
            summonBtn.frame:SetPoint("TOP", header.frame, "TOP", 0, 0)
            summonBtn.frame:SetPoint("BOTTOM", header.frame, "BOTTOM", 0, 0)
        end

        if header.frame and header.frame.CreateFontString then
            local fs = header.frame:CreateFontString(nil, "OVERLAY")
            -- WoW 3.3.5 throws "Font not set" if SetText runs before SetFont.
            SetEchoesFont(fs, 12, ECHOES_FONT_FLAGS)
            fs:SetText(row.label)
            -- Center within the left half of the header.
            fs:SetJustifyH("CENTER")
            fs:SetJustifyV("MIDDLE")
            fs:SetPoint("LEFT", header.frame, "LEFT", 10, 0)
            fs:SetPoint("RIGHT", header.frame, "CENTER", -10, 0)
            if fs.SetTextColor then fs:SetTextColor(0.85, 0.85, 0.85, 1) end
            header._EchoesRoleHeaderFS = fs
        end

        local rowGroup = AceGUI:Create("SimpleGroup")
        rowGroup:SetFullWidth(true)
        rowGroup:SetLayout("Flow")
        container:AddChild(rowGroup)

        local rowSpacerL = AceGUI:Create("SimpleGroup")
        rowSpacerL:SetRelativeWidth(0.06)
        rowSpacerL:SetLayout("Flow")
        rowGroup:AddChild(rowSpacerL)

        local function AddRoleButton(text, key)
            local b = AceGUI:Create("Button")
            b:SetText(text)
            b:SetRelativeWidth(0.22) -- 2*0.06 + 4*0.22 = 1.0
            b:SetHeight(ROLE_ROW_H)
            -- Slightly smaller so labels don't truncate.
            b._EchoesFontSize = 9
            b:SetCallback("OnClick", function() SendCmdKey(key) end)
            rowGroup:AddChild(b)
            SkinButton(b)
        end

        AddRoleButton("Attack", row.a)
        AddRoleButton("Stay",   row.s)
        AddRoleButton("Follow", row.f)
        AddRoleButton("Flee",   row.fl)

        local rowSpacerR = AceGUI:Create("SimpleGroup")
        rowSpacerR:SetRelativeWidth(0.06)
        rowSpacerR:SetLayout("Flow")
        rowGroup:AddChild(rowSpacerR)

        rowGroup:SetHeight(ROLE_ROW_H + 2)
    end
end
