-- Echoes.lua (Ace3 UI version, WoW 3.3.5)
-- ElvUI-ish skin, draggable frame, per-tab widths, cleaned Role Matrix & Group Slots,
-- global UI scale slider on Echoes tab.

------------------------------------------------------------
-- Ace3 setup
------------------------------------------------------------
local AceAddon   = LibStub("AceAddon-3.0")
local AceConsole = LibStub("AceConsole-3.0")
local AceEvent   = LibStub("AceEvent-3.0")
local AceGUI     = LibStub("AceGUI-3.0")

local Echoes = AceAddon:NewAddon("Echoes", "AceConsole-3.0", "AceEvent-3.0")

------------------------------------------------------------
-- SavedVariables defaults
------------------------------------------------------------
EchoesDB = EchoesDB or {}

local function EnsureDefaults()
    EchoesDB.sendAsChat         = (EchoesDB.sendAsChat ~= nil) and EchoesDB.sendAsChat or false
    EchoesDB.chatChannel        = EchoesDB.chatChannel        or "SAY"
    EchoesDB.groupTemplateIndex = EchoesDB.groupTemplateIndex or 1
    EchoesDB.classIndex         = EchoesDB.classIndex         or 1
    EchoesDB.lastPanel          = EchoesDB.lastPanel          or "BOT"
    EchoesDB.minimapAngle       = EchoesDB.minimapAngle       or 220
    EchoesDB.uiScale            = EchoesDB.uiScale            or 1.0
end

-- Per-tab sizes (frame stays a fixed size, grows right/down)
local FRAME_SIZES = {
    BOT    = { w = 320, h = 470 },
    GROUP  = { w = 650, h = 520 },
    ECHOES = { w = 320, h = 360 },
}

------------------------------------------------------------
-- Simple skin helpers (ElvUI-ish dark theme)
------------------------------------------------------------
local ECHOES_BACKDROP = {
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile     = false, tileSize = 0,
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function SkinBackdrop(frame, alpha)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop(ECHOES_BACKDROP)
    frame:SetBackdropColor(0.06, 0.06, 0.06, alpha or 0.9)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
end

local function SkinMainFrame(widget)
    if not widget or not widget.frame then return end
    local f = widget.frame

    -- Anchor once to TOPLEFT so size changes grow right/down
    if not f._EchoesAnchored then
        f._EchoesAnchored = true
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -200)
    end

    -- Movable, NO sizing
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetResizable(true)
    local w, h = f:GetWidth(), f:GetHeight()
    f:SetMinResize(w, h)
    f:SetMaxResize(w, h)
    f:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:StartMoving()
        end
    end)
    f:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            self:StopMovingOrSizing()
        end
    end)

    -- Hide AceGUI sizer widgets completely
    if widget.sizer_se then widget.sizer_se:Hide(); widget.sizer_se:EnableMouse(false) end
    if widget.sizer_s  then widget.sizer_s:Hide();  widget.sizer_s:EnableMouse(false)  end
    if widget.sizer_e  then widget.sizer_e:Hide();  widget.sizer_e:EnableMouse(false)  end

    -- Kill Blizzard frame art behind the AceGUI frame (stone borders etc.)
    local regions = { f:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region:IsObjectType("Texture") then
            local tex = region:GetTexture()
            if type(tex) == "string" and (
                tex:find("UI%-DialogBox") or
                tex:find("UI%-Panel") or
                tex:find("UI%-Frame") or
                tex:find("UI%-Background")
            ) then
                region:SetTexture(nil)
            end
        end
    end

    SkinBackdrop(f, 0.95)

    if widget.content and widget.content.SetBackdrop then
        SkinBackdrop(widget.content, 0.6)
    end

    ------------------------------------------------
    -- Custom Echoes title bar (ElvUI-ish)
    ------------------------------------------------
    if widget.titlebg then
        widget.titlebg:Hide()
    end

    if not f.EchoesTitleBar then
        local tb = CreateFrame("Frame", nil, f)
        tb:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -2)
        tb:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -2)
        tb:SetHeight(28)
        SkinBackdrop(tb, 0.98)
        tb:SetBackdropBorderColor(0, 0, 0, 0)
        f.EchoesTitleBar = tb
    end

    if widget.titletext then
        widget.titletext:ClearAllPoints()
        widget.titletext:SetPoint("CENTER", f.EchoesTitleBar, "CENTER", 0, 0)
        widget.titletext:SetTextColor(0.95, 0.95, 0.95, 1)
        local font, size, flags = widget.titletext:GetFont()
        widget.titletext:SetFont(font, (size or 14) + 1, "OUTLINE")
    end

    ------------------------------------------------
    -- Status bar gone (no bottom bar / stray boxes)
    ------------------------------------------------
    if widget.statusbg then
        widget.statusbg:Hide()
        if widget.statusbg.SetBackdrop then
            widget.statusbg:SetBackdrop(nil)
        end
        widget.statusbg:SetHeight(1)
    end
    if widget.statustext then
        widget.statustext:Hide()
        widget.statustext:SetText("")
    end

    ------------------------------------------------
    -- Remove AceGUI default close/status widgets and use our own bottom Close
    ------------------------------------------------
    -- Hide default top-right close (x)
    if widget.closebutton then
        widget.closebutton:Hide()
        widget.closebutton:EnableMouse(false)
    end

    -- Hide status bar/text (the empty panel area)
    if widget.statusbg then
        widget.statusbg:Hide()
        if widget.statusbg.SetBackdrop then widget.statusbg:SetBackdrop(nil) end
        widget.statusbg:SetAlpha(0)
        widget.statusbg:SetWidth(1)
        widget.statusbg:SetHeight(1)
        widget.statusbg:ClearAllPoints()
        widget.statusbg:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 0)
    end
    if widget.statustext then
        widget.statustext:Hide()
        widget.statustext:SetText("")
    end

    -- Some AceGUI versions store these on the frame directly
    if f.statusbg then
        f.statusbg:Hide()
        if f.statusbg.SetBackdrop then f.statusbg:SetBackdrop(nil) end
        f.statusbg:SetAlpha(0)
        f.statusbg:SetWidth(1)
        f.statusbg:SetHeight(1)
        if f.statusbg.ClearAllPoints then
            f.statusbg:ClearAllPoints()
            f.statusbg:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 0)
        end
    end
    if f.statustext then
        f.statustext:Hide()
        if f.statustext.SetText then f.statustext:SetText("") end
    end

    -- Hide ANY other "Close" button that might be created by templates
    if f.GetChildren then
        local children = { f:GetChildren() }
        for _, child in ipairs(children) do
            if child and child.IsObjectType and child:IsObjectType("Button") then
                local gt = child.GetText and child:GetText()
                if gt == "Close" and not child._EchoesIsCustomClose then
                    child:Hide()
                    child:EnableMouse(false)
                end
            end
        end
    end

    -- Custom bottom-right Close button (ElvUI-ish)
    if not f.EchoesCloseButton then
        local cb = CreateFrame("Button", nil, f)
        cb._EchoesIsCustomClose = true
        cb:SetSize(90, 22)
        cb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
        SkinBackdrop(cb, 0.9)

        local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("CENTER")
        fs:SetText("Close")
        fs:SetTextColor(0.9, 0.8, 0.5, 1)
        local font, size, flags = fs:GetFont()
        fs:SetFont(font, math.max(10, (size or 12)), "OUTLINE")

        cb:HookScript("OnEnter", function(self)
            self:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
        end)
        cb:HookScript("OnLeave", function(self)
            self:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
        end)
        cb:SetScript("OnClick", function() f:Hide() end)

        f.EchoesCloseButton = cb
    end

    ------------------------------------------------
    -- Kill any remaining bottom-left "status"/resize artifacts
    ------------------------------------------------
    if f.GetChildren then
        local children = { f:GetChildren() }
        for _, child in ipairs(children) do
            if child and child.IsObjectType and child:IsObjectType("Frame") and child ~= f.EchoesTitleBar and child ~= f.EchoesCloseButton then
                local p = child.GetPoint and child:GetPoint(1)
                if p then
                    local point, relTo = child:GetPoint(1)
                    if relTo == f and point and point:find("BOTTOM") then
                        -- Common offender: AceGUI status bar background (looks like a grey rounded box)
                        child:Hide()
                        child:SetAlpha(0)
                        if child.SetBackdrop then child:SetBackdrop(nil) end
                    end
                end
            end
        end
    end
end

local function SkinSimpleGroup(widget)
    if not widget or not widget.frame then return end
    -- Used mainly outside the Bot tab now; keep subtle backdrop
    SkinBackdrop(widget.frame, 0.18)
    if widget.frame.SetBackdropBorderColor then
        widget.frame:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

local function SkinInlineGroup(widget, opts)
    if not widget or not widget.frame then return end
    opts = opts or {}
    local alpha = (opts.alpha ~= nil) and opts.alpha or 0.35
    SkinBackdrop(widget.frame, alpha)
    if widget.frame.SetBackdropBorderColor then
        if opts.border == false then
            widget.frame:SetBackdropBorderColor(0, 0, 0, 0)
        else
            widget.frame:SetBackdropBorderColor(0, 0, 0, 0.85)
        end
    end
    if widget.border and widget.border.SetBackdrop then
        widget.border:SetBackdrop(nil)
    end
end

local function SkinButton(widget)
    if not widget or not widget.frame then return end
    local f = widget.frame

    if f.SetNormalTexture then f:SetNormalTexture(nil) end
    if f.SetHighlightTexture then f:SetHighlightTexture(nil) end
    if f.SetPushedTexture then f:SetPushedTexture(nil) end

    SkinBackdrop(f, 0.7)

    f:HookScript("OnEnter", function(self)
        self:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
    end)
    f:HookScript("OnLeave", function(self)
        self:SetBackdropColor(0.06, 0.06, 0.06, 0.7)
    end)

    if widget.text and widget.text.SetTextColor then
        widget.text:SetTextColor(0.90, 0.85, 0.70, 1) -- gold-ish
        local font, size, flags = widget.text:GetFont()
        widget.text:SetFont(font, math.max(8, (size or 12) - 2), flags)
    end
end

-- Tab buttons: same base style but always white text
local function SkinTabButton(widget)
    SkinButton(widget)
    if widget.text and widget.text.SetTextColor then
        widget.text:SetTextColor(1, 1, 1, 1)
    end
end

local function SkinDropdown(widget)
    if not widget or not widget.frame then return end
    local f = widget.frame

    local function StripColorCodes(s)
        if type(s) ~= "string" then return s end
        s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
        s = s:gsub("|r", "")
        return s
    end

    local function ClassFileFromDisplayName(text)
        if type(text) ~= "string" then return nil end
        local t = StripColorCodes(text)
        t = t:lower()
        t = t:gsub("%s+", " ")
        t = t:gsub("^%s+", "")
        t = t:gsub("%s+$", "")

        if t == "none" or t == "" then return nil end
        if t == "paladin" or t == "pally" then return "PALADIN" end
        if t == "death knight" or t == "deathknight" or t == "dk" then return "DEATHKNIGHT" end
        if t == "warrior" or t == "war" then return "WARRIOR" end
        if t == "shaman" or t == "sham" then return "SHAMAN" end
        if t == "hunter" or t == "hunt" then return "HUNTER" end
        if t == "druid" then return "DRUID" end
        if t == "rogue" then return "ROGUE" end
        if t == "priest" then return "PRIEST" end
        if t == "warlock" or t == "lock" then return "WARLOCK" end
        if t == "mage" then return "MAGE" end
        return nil
    end

    local function ApplyEchoesGroupSlotSelectedColor()
        if not widget.dropdown or widget.dropdown._EchoesDropdownKind ~= "groupSlot" then return end
        if widget.dropdown._EchoesForceDisabledGrey then
            if widget.text and widget.text.SetTextColor then
                widget.text:SetTextColor(0.55, 0.55, 0.55, 1)
            end
            return
        end

        if widget.text and widget.text.GetText and widget.text.SetTextColor then
            local classFile = ClassFileFromDisplayName(widget.text:GetText())
            local colors = rawget(_G, "RAID_CLASS_COLORS")
            local c = classFile and colors and colors[classFile]
            if c then
                widget.text:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)
            else
                widget.text:SetTextColor(0.90, 0.85, 0.70, 1)
            end
        end
    end

    -- AceGUI Dropdown uses UIDropDownMenuTemplate. The visible "box" is actually
    -- widget.dropdown, which AceGUI offsets (-15/+17) to account for Blizzard art.
    -- We remove that art, anchor the dropdown to the frame, and skin the dropdown
    -- itself so it reads as a real dropdown box.
    local box = widget.dropdown or f

    -- Remove Blizzard textures from the template pieces (left/middle/right/button art)
    if widget.dropdown and widget.dropdown.GetRegions then
        local regs = { widget.dropdown:GetRegions() }
        for _, r in ipairs(regs) do
            if r and r.IsObjectType and r:IsObjectType("Texture") then
                r:SetTexture(nil)
            end
        end
    end

    -- Anchor the internal dropdown to fill the widget frame (no template offsets)
    if widget.dropdown and not widget.dropdown._EchoesAnchored then
        widget.dropdown._EchoesAnchored = true
        widget.dropdown:ClearAllPoints()
        widget.dropdown:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        widget.dropdown:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    end

    -- Some AceGUI builds don't propagate height cleanly; force internal box to match.
    if widget.dropdown and f.GetHeight and widget.dropdown.SetHeight then
        local h = f:GetHeight()
        if h and h > 0 then
            widget.dropdown:SetHeight(h)
        end
    end

    -- Mark ownership so popup theming can be scoped to Echoes only
    if widget.dropdown then
        widget.dropdown._EchoesOwned = true
    end

    -- Skin the box (match Echoes dark theme)
    SkinBackdrop(box, 0.95)
    box:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    box:SetBackdropBorderColor(0, 0, 0, 1)

    -- Arrow button: make it a distinct square on the right
    local sepTex
    if widget.button then
        local b = widget.button
        if not b._EchoesStyled then
            b._EchoesStyled = true

            if b.SetNormalTexture then b:SetNormalTexture(nil) end
            if b.SetPushedTexture then b:SetPushedTexture(nil) end
            if b.SetHighlightTexture then b:SetHighlightTexture(nil) end

            b:ClearAllPoints()
            b:SetPoint("RIGHT", box, "RIGHT", -3, 0)
            b:SetSize(18, 18)

            SkinBackdrop(b, 0.95)
            b:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
            b:SetBackdropBorderColor(0, 0, 0, 1)

            if b.GetRegions then
                local regs = { b:GetRegions() }
                for _, r in ipairs(regs) do
                    if r and r.IsObjectType and r:IsObjectType("Texture") then
                        r:SetTexture(nil)
                    end
                end
            end

            local t = b:CreateTexture(nil, "ARTWORK")
            t:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
            t:SetSize(14, 14)
            t:SetPoint("CENTER", b, "CENTER", 0, 0)
            b._EchoesArrowTex = t

            b:HookScript("OnEnter", function(self)
                self:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
            end)
            b:HookScript("OnLeave", function(self)
                self:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
            end)
        end

        -- Separator between text area and arrow button
        if not box._EchoesDropSep then
            local sep = box:CreateTexture(nil, "BORDER")
            sep:SetTexture("Interface\\Buttons\\WHITE8x8")
            sep:SetVertexColor(0, 0, 0, 1)
            sep:SetWidth(1)
            sep:SetPoint("TOPRIGHT", b, "TOPLEFT", -3, -2)
            sep:SetPoint("BOTTOMRIGHT", b, "BOTTOMLEFT", -3, 2)
            box._EchoesDropSep = sep
        end
        sepTex = box._EchoesDropSep
    end

    -- Re-anchor the displayed value text inside the skinned box
    if widget.text and widget.text.ClearAllPoints and widget.text.SetPoint then
        widget.text:ClearAllPoints()
        widget.text:SetPoint("LEFT", box, "LEFT", 8, 0)
        if sepTex then
            widget.text:SetPoint("RIGHT", sepTex, "LEFT", -6, 0)
        elseif widget.button then
            widget.text:SetPoint("RIGHT", widget.button, "LEFT", -6, 0)
        else
            widget.text:SetPoint("RIGHT", box, "RIGHT", -8, 0)
        end
        if widget.text.SetJustifyH then
            widget.text:SetJustifyH("LEFT")
        end
        if widget.text.SetTextColor then
            widget.text:SetTextColor(0.90, 0.85, 0.70, 1) -- match buttons
        end
    end

    -- Apply class colors to group-slot dropdowns (Echoes-only)
    ApplyEchoesGroupSlotSelectedColor()

    -- Label styling (if a label is used)
    if widget.label and widget.label.SetTextColor then
        widget.label:SetTextColor(0.9, 0.9, 0.9, 1)
    end
end

-- NOTE: Echoes intentionally does not skin UIDropDownMenu popup list frames.
-- Those DropDownList* frames are global singletons shared with Blizzard UI and
-- other addons. Echoes styling is kept fully self-contained.

local function SkinEditBox(widget)
    if not widget or not widget.editbox then return end
    -- Remove template textures so the edit box matches Echoes theme
    if widget.editbox.GetRegions then
        local regs = { widget.editbox:GetRegions() }
        for _, r in ipairs(regs) do
            if r and r.IsObjectType and r:IsObjectType("Texture") then
                r:SetTexture(nil)
            end
        end
    end

    SkinBackdrop(widget.editbox, 0.95)
    widget.editbox:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    widget.editbox:SetBackdropBorderColor(0, 0, 0, 1)

    if widget.editbox.SetTextColor then
        widget.editbox:SetTextColor(0.90, 0.85, 0.70, 1)
    end

    if widget.label and widget.label.SetTextColor then
        widget.label:SetTextColor(0.9, 0.9, 0.9, 1)
    end
end

local function SkinHeading(widget)
    if widget and widget.label and widget.label.SetTextColor then
        widget.label:SetTextColor(0.95, 0.95, 0.95, 1)
    end
end

local function SkinLabel(widget)
    if widget and widget.label and widget.label.SetTextColor then
        widget.label:SetTextColor(0.85, 0.85, 0.85, 1)
    end
end

------------------------------------------------------------
-- Utilities & data
------------------------------------------------------------
local function Echoes_Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100Echoes:|r " .. tostring(msg))
end

local function Clamp(v, minv, maxv)
    if v < minv then return minv end
    if v > maxv then return maxv end
    return v
end

local CMD = {
    ADD_CLASS   = ".playerbots bot addclass",
    REMOVE_ALL  = "logout",

    TANK_ATTACK = "@tank attack",
    ATTACK      = "@attack",
    DPS_ATTACK  = ".bot dps attack",

    SUMMON      = "summon",
    RELEASE     = "release",
    LEVEL_UP    = ".playerbots bot init=epic",
    DRINK       = "drink",

    STAY        = "stay",
    FOLLOW      = "follow",
    FLEE        = "flee",

    HEAL_ATTACK = "@heal attack",
    MELEE_ATK   = "@melee attack",
    RANGED_ATK  = "@ranged attack",

    TANK_STAY   = "@tank stay",
    HEAL_STAY   = "@heal stay",
    MELEE_STAY  = "@melee stay",
    RANGED_STAY = "@ranged stay",

    HEAL_FOLLOW   = "@heal follow",
    RANGED_FOLLOW = "@ranged follow",
    MELEE_FOLLOW  = "@melee follow",
    TANK_FOLLOW   = "@tank follow",

    TANK_FLEE   = "@tank flee",
    MELEE_FLEE  = "@melee flee",
    RANGED_FLEE = "@ranged flee",
    HEAL_FLEE   = "@heal flee",
}

local function SendCmdKey(key)
    local cmd = CMD[key]
    if not cmd then
        Echoes_Print("No command mapped for: " .. tostring(key))
        return
    end

    if EchoesDB.sendAsChat then
        SendChatMessage(cmd, EchoesDB.chatChannel or "SAY")
    else
        SendChatMessage(cmd, "PARTY")
    end
end

local CLASSES = {
    { label = "Paladin",      cmd = "paladin" },
    { label = "Death Knight", cmd = "dk"      },
    { label = "Warrior",      cmd = "warrior" },
    { label = "Shaman",       cmd = "shaman"  },
    { label = "Hunter",       cmd = "hunter"  },
    { label = "Druid",        cmd = "druid"   },
    { label = "Rogue",        cmd = "rogue"   },
    { label = "Priest",       cmd = "priest"  },
    { label = "Warlock",      cmd = "warlock" },
    { label = "Mage",         cmd = "mage"    },
}

local function GetSelectedClass()
    local i = Clamp(tonumber(EchoesDB.classIndex) or 1, 1, #CLASSES)
    EchoesDB.classIndex = i
    return CLASSES[i]
end

local GROUP_TEMPLATES = {
    "naxx 10 man",
    "Custom 1",
    "Custom 2",
}

local GROUP_SLOT_OPTIONS = {
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
}

local DEFAULT_CYCLE_VALUES = {
    { label = "None", icon = "Interface\\Icons\\INV_Misc_QuestionMark" },
}

-- Spec icons in WotLK (3.3.5) talent-tab order.
-- Note: These are the icons shown on the talent tabs, not arbitrary spell icons.
local CYCLE_VALUES_BY_RIGHT_TEXT = {
    ["Paladin"] = {
        { label = "Holy",        icon = "Interface\\Icons\\Spell_Holy_HolyBolt" },
        { label = "Protection",  icon = "Interface\\Icons\\Spell_Holy_DevotionAura" },
        { label = "Retribution", icon = "Interface\\Icons\\Spell_Holy_AuraOfLight" },
    },
    ["Death Knight"] = {
        { label = "Blood",  icon = "Interface\\Icons\\Spell_Deathknight_BloodPresence" },
        { label = "Frost",  icon = "Interface\\Icons\\Spell_Deathknight_FrostPresence" },
        { label = "Unholy", icon = "Interface\\Icons\\Spell_Deathknight_UnholyPresence" },
    },
    ["Warrior"] = {
        { label = "Arms",       icon = "Interface\\Icons\\Ability_Warrior_SavageBlow" },
        { label = "Fury",       icon = "Interface\\Icons\\Ability_Warrior_Innerrage" },
        { label = "Protection", icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance" },
    },
    ["Shaman"] = {
        { label = "Elemental",    icon = "Interface\\Icons\\Spell_Nature_Lightning" },
        { label = "Enhancement",  icon = "Interface\\Icons\\Spell_Nature_LightningShield" },
        { label = "Restoration",  icon = "Interface\\Icons\\Spell_Nature_MagicImmunity" },
    },
    ["Hunter"] = {
        { label = "Beast Mastery", icon = "Interface\\Icons\\Ability_Hunter_BeastTaming" },
        { label = "Marksmanship",  icon = "Interface\\Icons\\Ability_Marksmanship" },
        { label = "Survival",      icon = "Interface\\Icons\\Ability_Hunter_SwiftStrike" },
    },
    ["Druid"] = {
        { label = "Balance",      icon = "Interface\\Icons\\Spell_Nature_StarFall" },
        { label = "Feral",        icon = "Interface\\Icons\\Ability_Druid_CatForm" },
        { label = "Bear",         icon = "Interface\\Icons\\Ability_Racial_BearForm" },
        { label = "Restoration",  icon = "Interface\\Icons\\Spell_Nature_HealingTouch" },
    },
    ["Rogue"] = {
        { label = "Assassination", icon = "Interface\\Icons\\Ability_Rogue_Eviscerate" },
        { label = "Combat",        icon = "Interface\\Icons\\Ability_BackStab" },
        { label = "Subtlety",      icon = "Interface\\Icons\\Ability_Stealth" },
    },
    ["Priest"] = {
        { label = "Discipline", icon = "Interface\\Icons\\Spell_Holy_WordFortitude" },
        { label = "Holy",       icon = "Interface\\Icons\\Spell_Holy_HolyBolt" },
        { label = "Shadow",     icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain" },
    },
    ["Warlock"] = {
        { label = "Affliction",  icon = "Interface\\Icons\\Spell_Shadow_DeathCoil" },
        { label = "Demonology",  icon = "Interface\\Icons\\Spell_Shadow_Metamorphosis" },
        { label = "Destruction", icon = "Interface\\Icons\\Spell_Shadow_RainOfFire" },
    },
    ["Mage"] = {
        { label = "Arcane", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
        { label = "Fire",   icon = "Interface\\Icons\\Spell_Fire_FireBolt02" },
        { label = "Frostfire", icon = "Interface\\Icons\\Ability_mage_frostfirebolt" },
        { label = "Frost",  icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
    },
}

local function GetCycleValuesForRightText(text)
    if not text or text == "" then
        return DEFAULT_CYCLE_VALUES
    end
    return CYCLE_VALUES_BY_RIGHT_TEXT[text] or DEFAULT_CYCLE_VALUES
end

------------------------------------------------------------
-- UI state
------------------------------------------------------------
Echoes.UI = {
    frame   = nil,
    content = nil,
    tabs    = {},
}

local TAB_DEFS = {
    { key = "BOT",    label = "Bot Control" },
    { key = "GROUP",  label = "Group Creation" },
    { key = "ECHOES", label = "Echoes" },
}

function Echoes:BuildBotTab(container)   end
function Echoes:BuildGroupTab(container) end
function Echoes:BuildEchoesTab(container)end

------------------------------------------------------------
-- Frame size & scale helpers
------------------------------------------------------------
function Echoes:ApplyFrameSizeForTab(key)
    local frame = self.UI.frame
    if not frame then return end
    local s = FRAME_SIZES[key] or FRAME_SIZES["BOT"]

    -- Constrain to available screen space, accounting for addon UI scale.
    -- This keeps the window usable across different resolutions.
    local scale = EchoesDB.uiScale or 1.0
    if scale < 0.01 then scale = 1.0 end

    local screenW = (GetScreenWidth and GetScreenWidth()) or (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or s.w
    local screenH = (GetScreenHeight and GetScreenHeight()) or (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or s.h

    -- Margins (in screen pixels) to avoid clipping the window against edges.
    local marginX, marginY = 120, 160
    local maxW = (screenW - marginX) / scale
    local maxH = (screenH - marginY) / scale

    local w = s.w
    local h = s.h
    if maxW and maxW > 0 then w = math.min(w, maxW) end
    if maxH and maxH > 0 then h = math.min(h, maxH) end

    frame:SetWidth(math.floor(w + 0.5))
    frame:SetHeight(math.floor(h + 0.5))
end

function Echoes:ApplyScale()
    local widget = self.UI.frame
    if widget and widget.frame and widget.frame.SetScale then
        widget.frame:SetScale(EchoesDB.uiScale or 1.0)
    end

    -- Re-apply sizing after scale changes so the current tab still fits.
    self:ApplyFrameSizeForTab(EchoesDB.lastPanel or "BOT")
end


------------------------------------------------------------
-- Manual tab management
------------------------------------------------------------
function Echoes:SetActiveTab(key)
    EchoesDB.lastPanel = key or "BOT"

    for tabKey, btn in pairs(self.UI.tabs) do
        if btn and btn.text then
            if tabKey == key then
                btn.text:SetText("|cffffffff" .. btn.origText .. "|r") -- selected white
            else
                btn.text:SetText("|cffcccccc" .. btn.origText .. "|r") -- unselected light gray
            end
        end
    end

    local container = self.UI.content
    if not container then return end

    -- Cache tab contents so switching tabs doesn't destroy/recreate widgets.
    -- IMPORTANT: the AceGUI "Fill" layout ONLY shows children[1], so we must
    -- keep the active page as the first child.
    self.UI.pages = self.UI.pages or {}

    if container.PauseLayout then
        container:PauseLayout()
    end

    local page = self.UI.pages[key]
    if not page then
        page = AceGUI:Create("SimpleGroup")
        page:SetFullWidth(true)
        page:SetFullHeight(true)
        self.UI.pages[key] = page

        container:AddChild(page)

        if key == "BOT" then
            self:BuildBotTab(page)
        elseif key == "GROUP" then
            self:BuildGroupTab(page)
        else
            self:BuildEchoesTab(page)
        end
    end

    -- Hide all pages, then show the selected one
    for _, p in pairs(self.UI.pages) do
        if p and p.frame then
            p.frame:Hide()
        end
    end
    if page and page.frame then
        page.frame:Show()
    end

    -- Ensure selected page is children[1] so Fill layout displays it.
    if container.children then
        local foundIndex
        for i = 1, #container.children do
            if container.children[i] == page then
                foundIndex = i
                break
            end
        end
        if foundIndex and foundIndex ~= 1 then
            table.remove(container.children, foundIndex)
            table.insert(container.children, 1, page)
        end
    end

    self:ApplyFrameSizeForTab(key)

    if container.ResumeLayout then
        container:ResumeLayout()
    end
    if container.DoLayout then
        container:DoLayout()
    end
end

function Echoes:CreateMainWindow()
    if self.UI.frame then
        return
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Echoes")
    frame:SetLayout("List")
    frame:SetWidth(FRAME_SIZES.BOT.w)
    frame:SetHeight(FRAME_SIZES.BOT.h)
    frame:Hide()

    frame:SetCallback("OnClose", function(widget)
        widget:Hide()
    end)

    frame.frame:SetScale(EchoesDB.uiScale or 1.0)
    SkinMainFrame(frame)


    -- Tab bar (Bot / Group / Echoes on one line)
    local tabBar = AceGUI:Create("SimpleGroup")
    tabBar:SetFullWidth(true)
    tabBar:SetLayout("Flow")
    frame:AddChild(tabBar)
    SkinSimpleGroup(tabBar)

    for _, def in ipairs(TAB_DEFS) do
        local btn = AceGUI:Create("Button")
        btn.origText = def.label
        btn:SetText(def.label)
        btn:SetWidth(90)
        btn:SetCallback("OnClick", function()
            Echoes:SetActiveTab(def.key)
        end)
        tabBar:AddChild(btn)
        SkinTabButton(btn)
        self.UI.tabs[def.key] = btn
    end

    -- Content area
    local content = AceGUI:Create("SimpleGroup")
    content:SetFullWidth(true)
    content:SetFullHeight(true)
    content:SetLayout("Fill")
    frame:AddChild(content)
    SkinSimpleGroup(content)

    self.UI.frame   = frame
    self.UI.content = content

    local last = EchoesDB.lastPanel
    if last ~= "BOT" and last ~= "GROUP" and last ~= "ECHOES" then
        last = "BOT"
    end
    self:SetActiveTab(last)
end

function Echoes:ToggleMainWindow()
    self:CreateMainWindow()
    local f = self.UI.frame
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

------------------------------------------------------------
-- Bot Control tab
------------------------------------------------------------
function Echoes:BuildBotTab(container)
    -- Use Flow instead of List to avoid oversized vertical gaps between rows in some AceGUI builds
    -- (List layout can over-allocate spacing depending on widget heights and fontstring metrics on 3.3.5)
    container:SetLayout("Flow")

    ------------------------------------------------
    -- 1) Class row: dropdown (40%) + spacer + < >
    ------------------------------------------------
    local classGroup = AceGUI:Create("SimpleGroup")
    classGroup:SetFullWidth(true)
    classGroup:SetLayout("Flow")
    container:AddChild(classGroup)

    local padL = AceGUI:Create("Label")
    padL:SetText("")
    padL:SetRelativeWidth(0.04)
    classGroup:AddChild(padL)

    -- Inline "Class" label
    local classLabel = AceGUI:Create("Label")
    classLabel:SetText("Class")
    classLabel:SetRelativeWidth(0.12)
    classGroup:AddChild(classLabel)
    SkinLabel(classLabel)


    local classValues = {}
    for i, c in ipairs(CLASSES) do
        classValues[i] = c.label
    end

    local classDrop = AceGUI:Create("Dropdown")
    classDrop:SetLabel("")
    classDrop:SetList(classValues)
    classDrop:SetValue(EchoesDB.classIndex or 1)
    classDrop:SetRelativeWidth(0.40)
    classDrop:SetCallback("OnValueChanged", function(widget, event, value)
        EchoesDB.classIndex = value
    end)
    classGroup:AddChild(classDrop)
    SkinDropdown(classDrop)


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
    end

    local classSpacer = AceGUI:Create("SimpleGroup")
    classSpacer:SetRelativeWidth(0.1)
    classSpacer:SetLayout("Flow")
    classGroup:AddChild(classSpacer)

    local prevBtn = AceGUI:Create("Button")
    prevBtn:SetText("<")
    prevBtn:SetRelativeWidth(0.15)
    prevBtn:SetCallback("OnClick", function()
        SetClassIndex((EchoesDB.classIndex or 1) - 1)
    end)
    classGroup:AddChild(prevBtn)
    SkinButton(prevBtn)

    local nextBtn = AceGUI:Create("Button")
    nextBtn:SetText(">")
    nextBtn:SetRelativeWidth(0.15)
    nextBtn:SetCallback("OnClick", function()
        SetClassIndex((EchoesDB.classIndex or 1) + 1)
    end)
    classGroup:AddChild(nextBtn)
    SkinButton(nextBtn)

    -- right padding (~15px)
    local padR = AceGUI:Create("Label")
    padR:SetText("")
    padR:SetRelativeWidth(0.04)
    classGroup:AddChild(padR)

    classGroup:SetHeight(32)

    ------------------------------------------------
    -- 2) Add / Remove row (centered)
    ------------------------------------------------
    local addRemGroup = AceGUI:Create("SimpleGroup")
    addRemGroup:SetFullWidth(true)
    addRemGroup:SetLayout("Flow")
    container:AddChild(addRemGroup)

    local spacerL = AceGUI:Create("SimpleGroup")
    spacerL:SetRelativeWidth(0.15)
    spacerL:SetLayout("Flow")
    addRemGroup:AddChild(spacerL)

    local addBtn = AceGUI:Create("Button")
    addBtn:SetText("Add")
    addBtn:SetRelativeWidth(0.35)
    addBtn:SetCallback("OnClick", function()
        local c = GetSelectedClass()
        SendChatMessage(".playerbots bot addclass " .. c.cmd, "GUILD")
    end)
    addRemGroup:AddChild(addBtn)
    SkinButton(addBtn)

    local remBtn = AceGUI:Create("Button")
    remBtn:SetText("Remove All")
    remBtn:SetRelativeWidth(0.35)
    remBtn:SetCallback("OnClick", function()
        SendCmdKey("REMOVE_ALL")
    end)
    addRemGroup:AddChild(remBtn)
    SkinButton(remBtn)

    local spacerR = AceGUI:Create("SimpleGroup")
    spacerR:SetRelativeWidth(0.15)
    spacerR:SetLayout("Flow")
    addRemGroup:AddChild(spacerR)

    addRemGroup:SetHeight(24)

    ------------------------------------------------
    -- 3) Utilities rows: Summon/Release, LevelUp/Drink
    ------------------------------------------------
    local function MakeUtilRow(text1, key1, text2, key2)
        local row = AceGUI:Create("SimpleGroup")
        row:SetFullWidth(true)
        row:SetLayout("Flow")
        container:AddChild(row)

        local rSpacerL = AceGUI:Create("SimpleGroup")
        rSpacerL:SetRelativeWidth(0.15)
        rSpacerL:SetLayout("Flow")
        row:AddChild(rSpacerL)

        local b1 = AceGUI:Create("Button")
        b1:SetText(text1)
        b1:SetRelativeWidth(0.35)
        b1:SetCallback("OnClick", function() SendCmdKey(key1) end)
        row:AddChild(b1)
        SkinButton(b1)

        local b2 = AceGUI:Create("Button")
        b2:SetText(text2)
        b2:SetRelativeWidth(0.35)
        b2:SetCallback("OnClick", function() SendCmdKey(key2) end)
        row:AddChild(b2)
        SkinButton(b2)

        local rSpacerR = AceGUI:Create("SimpleGroup")
        rSpacerR:SetRelativeWidth(0.15)
        rSpacerR:SetLayout("Flow")
        row:AddChild(rSpacerR)

        row:SetHeight(22)
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
    mSpacerL:SetRelativeWidth(0.125)
    mSpacerL:SetLayout("Flow")
    moveGroup:AddChild(mSpacerL)

    local followBtn = AceGUI:Create("Button")
    followBtn:SetText("Follow")
    followBtn:SetRelativeWidth(0.25)
    followBtn:SetCallback("OnClick", function() SendCmdKey("FOLLOW") end)
    moveGroup:AddChild(followBtn)
    SkinButton(followBtn)

    local stayBtn = AceGUI:Create("Button")
    stayBtn:SetText("Stay")
    stayBtn:SetRelativeWidth(0.25)
    stayBtn:SetCallback("OnClick", function() SendCmdKey("STAY") end)
    moveGroup:AddChild(stayBtn)
    SkinButton(stayBtn)

    local fleeBtn = AceGUI:Create("Button")
    fleeBtn:SetText("Flee")
    fleeBtn:SetRelativeWidth(0.25)
    fleeBtn:SetCallback("OnClick", function() SendCmdKey("FLEE") end)
    moveGroup:AddChild(fleeBtn)
    SkinButton(fleeBtn)

    local mSpacerR = AceGUI:Create("SimpleGroup")
    mSpacerR:SetRelativeWidth(0.125)
    mSpacerR:SetLayout("Flow")
    moveGroup:AddChild(mSpacerR)

    moveGroup:SetHeight(32)

    -- Extra vertical spacing between global movement buttons and the role matrix
    -- (Empty SimpleGroups can collapse in AceGUI Flow layout; use a Label spacer instead.)
    local moveRoleGap = AceGUI:Create("Label")
    moveRoleGap:SetText(" ")
    moveRoleGap:SetFullWidth(true)
    moveRoleGap:SetHeight(18)
    container:AddChild(moveRoleGap)

    ------------------------------------------------
    -- 5) Role Matrix: label + 4 buttons filling the row
    ------------------------------------------------
    local rows = {
        { label = "Tank",   a="TANK_ATTACK", s="TANK_STAY",   f="TANK_FOLLOW",   fl="TANK_FLEE"   },
        { label = "Melee",  a="MELEE_ATK",   s="MELEE_STAY",  f="MELEE_FOLLOW",  fl="MELEE_FLEE"  },
        { label = "Ranged", a="RANGED_ATK",  s="RANGED_STAY", f="RANGED_FOLLOW", fl="RANGED_FLEE" },
        { label = "Healer", a="HEAL_ATTACK", s="HEAL_STAY",   f="HEAL_FOLLOW",   fl="HEAL_FLEE"   },
    }

    for _, row in ipairs(rows) do
        local lab = AceGUI:Create("Label")
        lab:SetText(row.label)
        lab:SetFullWidth(true)
        if lab.label and lab.label.SetJustifyH then
            lab.label:SetJustifyH("CENTER")
        end
        container:AddChild(lab)
        SkinLabel(lab)
        lab:SetHeight(12)

        local rowGroup = AceGUI:Create("SimpleGroup")
        rowGroup:SetFullWidth(true)
        rowGroup:SetLayout("Flow")
        container:AddChild(rowGroup)

        local rowSpacerL = AceGUI:Create("SimpleGroup")
        rowSpacerL:SetRelativeWidth(0.03)
        rowSpacerL:SetLayout("Flow")
        rowGroup:AddChild(rowSpacerL)

        local function AddRoleButton(text, key)
            local b = AceGUI:Create("Button")
            b:SetText(text)
            b:SetRelativeWidth(0.235) -- 4 * 0.235 + 2*0.03 ≈ 1.0
            b:SetCallback("OnClick", function() SendCmdKey(key) end)
            rowGroup:AddChild(b)
            SkinButton(b)
        end

        AddRoleButton("Attack", row.a)
        AddRoleButton("Stay",   row.s)
        AddRoleButton("Follow", row.f)
        AddRoleButton("Flee",   row.fl)

        local rowSpacerR = AceGUI:Create("SimpleGroup")
        rowSpacerR:SetRelativeWidth(0.03)
        rowSpacerR:SetLayout("Flow")
        rowGroup:AddChild(rowSpacerR)

        rowGroup:SetHeight(22)
    end
end

------------------------------------------------------------
-- Group Creation tab (unchanged layout)
------------------------------------------------------------
function Echoes:BuildGroupTab(container)
    container:SetLayout("List")

    local INPUT_HEIGHT = 24

    local headerPadTop = AceGUI:Create("SimpleGroup")
    headerPadTop:SetFullWidth(true)
    headerPadTop:SetLayout("Flow")
    headerPadTop:SetHeight(8)
    container:AddChild(headerPadTop)

    local topGroup = AceGUI:Create("SimpleGroup")
    topGroup:SetFullWidth(true)
    topGroup:SetLayout("Flow")
    SkinSimpleGroup(topGroup)
    container:AddChild(topGroup)

    local headerPadL = AceGUI:Create("SimpleGroup")
    headerPadL:SetRelativeWidth(0.01)
    headerPadL:SetLayout("Flow")
    topGroup:AddChild(headerPadL)

    local nameEdit = AceGUI:Create("EditBox")
    nameEdit:SetLabel("")
    nameEdit:SetText("Text Box")
    nameEdit:SetRelativeWidth(0.35)
    nameEdit:SetHeight(INPUT_HEIGHT)
    nameEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        if text == "" then
            widget:SetText("Text Box")
        end
    end)
    topGroup:AddChild(nameEdit)
    SkinEditBox(nameEdit)

    local topSpacer = AceGUI:Create("SimpleGroup")
    topSpacer:SetRelativeWidth(0.02)
    topSpacer:SetLayout("Flow")
    topGroup:AddChild(topSpacer)

    local templateValues = {}
    for i, v in ipairs(GROUP_TEMPLATES) do
        templateValues[i] = v
    end

    local templateDrop = AceGUI:Create("Dropdown")
    templateDrop:SetLabel("")
    templateDrop:SetList(templateValues)
    templateDrop:SetValue(EchoesDB.groupTemplateIndex or 1)
    templateDrop:SetRelativeWidth(0.35)
    templateDrop:SetHeight(INPUT_HEIGHT)
    templateDrop:SetCallback("OnValueChanged", function(widget, event, value)
        EchoesDB.groupTemplateIndex = value
    end)
    topGroup:AddChild(templateDrop)
    SkinDropdown(templateDrop)

    local topSpacer2 = AceGUI:Create("SimpleGroup")
    topSpacer2:SetRelativeWidth(0.02)
    topSpacer2:SetLayout("Flow")
    topGroup:AddChild(topSpacer2)

    local saveBtn = AceGUI:Create("Button")
    saveBtn:SetText("Save")
    saveBtn:SetRelativeWidth(0.12)
    saveBtn:SetHeight(INPUT_HEIGHT)
    saveBtn:SetCallback("OnClick", function()
        Echoes_Print("Group setup saved (stub).")
    end)
    topGroup:AddChild(saveBtn)
    SkinButton(saveBtn)

    local deleteBtn = AceGUI:Create("Button")
    deleteBtn:SetText("Delete")
    deleteBtn:SetRelativeWidth(0.12)
    deleteBtn:SetHeight(INPUT_HEIGHT)
    deleteBtn:SetCallback("OnClick", function()
        Echoes_Print("Group setup deleted (stub).")
    end)
    topGroup:AddChild(deleteBtn)
    SkinButton(deleteBtn)

    local headerPadR = AceGUI:Create("SimpleGroup")
    headerPadR:SetRelativeWidth(0.01)
    headerPadR:SetLayout("Flow")
    topGroup:AddChild(headerPadR)

    local headerPadBottom = AceGUI:Create("SimpleGroup")
    headerPadBottom:SetFullWidth(true)
    headerPadBottom:SetLayout("Flow")
    headerPadBottom:SetHeight(8)
    container:AddChild(headerPadBottom)

    local gridGroup = AceGUI:Create("InlineGroup")
    gridGroup:SetTitle("Group Slots")
    gridGroup:SetFullWidth(true)
    gridGroup:SetLayout("Flow")
    SkinInlineGroup(gridGroup, { border = true, alpha = 0.30 })
    container:AddChild(gridGroup)

    -- Layout groups in a 3x2 grid (3 on first row, 2 on second row)
    local COLUMN_CONFIG = {
        { rows = 5 }, { rows = 5 }, { rows = 5 }, { rows = 5 }, { rows = 5 },
    }

    local slotValues = {}
    for i, v in ipairs(GROUP_SLOT_OPTIONS) do
        slotValues[i] = v
    end

    local DISPLAY_TO_CLASSFILE = {
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

    local function ApplyGroupSlotSelectedTextColor(dropdownWidget, value)
        if not dropdownWidget or not dropdownWidget.text or not dropdownWidget.text.SetTextColor then return end
        if dropdownWidget.dropdown and dropdownWidget.dropdown._EchoesForceDisabledGrey then
            dropdownWidget.text:SetTextColor(0.55, 0.55, 0.55, 1)
            return
        end

        local display = slotValues[value]
        if display == "None" or not display then
            dropdownWidget.text:SetTextColor(0.60, 0.60, 0.60, 1)
            return
        end

        local classFile = DISPLAY_TO_CLASSFILE[display]
        local colors = rawget(_G, "RAID_CLASS_COLORS")
        local c = classFile and colors and colors[classFile]
        if c then
            dropdownWidget.text:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)
        else
            dropdownWidget.text:SetTextColor(0.90, 0.85, 0.70, 1)
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
        -- Slightly wider columns so the right-side button text doesn't clip.
        col:SetRelativeWidth(0.325)
        SkinInlineGroup(col, { border = false, alpha = 0.28 })
        gridGroup:AddChild(col)

        self.UI.groupSlots[colIndex] = self.UI.groupSlots[colIndex] or {}

        for rowIndex = 1, cfg.rows do
            local rowGroup = AceGUI:Create("SimpleGroup")
            rowGroup:SetFullWidth(true)
            rowGroup:SetLayout("Flow")
            col:AddChild(rowGroup)

            local isPlayerSlot = false

            local cycleBtn
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

                btn._EchoesSpecLabel = label
                btn:SetText("")

                if btn.frame and not btn._EchoesIconTex then
                    local t = btn.frame:CreateTexture(nil, "ARTWORK")
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
                    -- Keep the icon square and as tall as the dropdown row.
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
            -- Keep this button perfectly square.
            cycleBtn:SetWidth(INPUT_HEIGHT)
            cycleBtn:SetHeight(INPUT_HEIGHT)
            cycleBtn.values = { unpack(DEFAULT_CYCLE_VALUES) }
            cycleBtn.index  = 1
            cycleBtn._EchoesCycleUpdate = CycleUpdate

            -- AceGUI's Button widget will pass the WoW mouse button name (e.g. "RightButton")
            -- to the OnClick callback, but only if the frame is registered for right-clicks.
            if cycleBtn.frame and cycleBtn.frame.RegisterForClicks then
                cycleBtn.frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            end

            cycleBtn:SetCallback("OnClick", function(widget, event, button)
                local btn = widget
                if not btn.values or #btn.values == 0 then return end
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

            local dd = AceGUI:Create("Dropdown")
            dd:SetList(slotValues)
            dd:SetValue(1)
            dd:SetRelativeWidth(0.54)

            -- Mark these dropdowns so our dropdown popup theming can color class names
            -- and the selected value can be class-colored/disabled-grey.
            if dd.dropdown then
                dd.dropdown._EchoesOwned = true
                dd.dropdown._EchoesDropdownKind = "groupSlot"
            end

            dd:SetCallback("OnValueChanged", function(widget, event, value)
                if widget._EchoesSuppress then return end
                local text = slotValues[value]
                local vals = GetCycleValuesForRightText(text)
                if cycleBtn then
                    cycleBtn.values = { unpack(vals) }
                    cycleBtn.index  = 1
                    CycleUpdate(cycleBtn)
                end

                ApplyGroupSlotSelectedTextColor(widget, value)
            end)

            rowGroup:AddChild(dd)
            SkinDropdown(dd)

            ApplyGroupSlotSelectedTextColor(dd, 1)

            local nameBtn = AceGUI:Create("Button")
            nameBtn:SetText("Name")
            nameBtn:SetRelativeWidth(0.32)
            nameBtn:SetHeight(INPUT_HEIGHT)
            nameBtn:SetCallback("OnClick", function()
                Echoes_Print("Name clicked (stub).")
            end)
            rowGroup:AddChild(nameBtn)
            SkinButton(nameBtn)

            if nameBtn.text and nameBtn.text.GetFont and nameBtn.text.SetFont then
                local font, _, flags = nameBtn.text:GetFont()
                nameBtn.text:SetFont(font, 8, flags)
            end

            self.UI.groupSlots[colIndex][rowIndex] = {
                cycleBtn = cycleBtn,
                classDrop = dd,
                nameBtn = nameBtn,
            }
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
    actionCol:SetRelativeWidth(0.325)
    SkinInlineGroup(actionCol, { border = false, alpha = 0.28 })
    gridGroup:AddChild(actionCol)

    local inviteBtn = AceGUI:Create("Button")
    inviteBtn:SetText("Invite")
    inviteBtn:SetFullWidth(true)
    inviteBtn:SetCallback("OnClick", function()
        Echoes_Print("Invite clicked (stub).")
    end)
    actionCol:AddChild(inviteBtn)
    SkinButton(inviteBtn)

    local talentsBtn = AceGUI:Create("Button")
    talentsBtn:SetText("Set Talents")
    talentsBtn:SetFullWidth(true)
    talentsBtn:SetCallback("OnClick", function()
        Echoes_Print("Set Talents clicked (stub).")
    end)
    actionCol:AddChild(talentsBtn)
    SkinButton(talentsBtn)

    -- Initialize from roster once the page is built.
    self:UpdateGroupCreationFromRoster(true)
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

    local applyColor = self.UI._GroupSlotApplyColor
    local colors = rawget(_G, "RAID_CLASS_COLORS")

    local function GreyTintClassColor(c)
        if not c then return 1, 1, 1 end
        local grey = 0.65
        local mix = 0.25
        local r = (c.r or 1) * (1 - mix) + grey * mix
        local g = (c.g or 1) * (1 - mix) + grey * mix
        local b = (c.b or 1) * (1 - mix) + grey * mix
        return r, g, b
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
            slot.nameBtn:SetCallback("OnClick", function()
                -- 1) Whisper the player the text "logout"
                if type(SendChatMessage) == "function" then
                    SendChatMessage("logout", "WHISPER", nil, member.name)
                end

                -- 2) Remove them from the group (party or raid) if possible
                if type(UninviteUnit) == "function" then
                    UninviteUnit(member.name)
                end
            end)
        else
            slot.nameBtn:SetText("Name")
            if slot.nameBtn.text and slot.nameBtn.text.SetTextColor then
                slot.nameBtn.text:SetTextColor(0.90, 0.85, 0.70, 1)
            end
            slot.nameBtn:SetCallback("OnClick", function()
                Echoes_Print("Name clicked (stub).")
            end)
        end
    end

    local function ResetSlot(slot)
        if not slot then return end
        SetEnabledForWidget(slot.cycleBtn, true)
        SetEnabledForDropdown(slot.classDrop, true)
        SetEnabledForWidget(slot.nameBtn, true)
        SetNameButtonVisible(slot, true)

        slot._EchoesMember = nil
        SetNameButtonMode(slot, "name")

        if slot.classDrop and slot.classDrop.SetList and slot.classDrop.SetValue then
            local baseList = self.UI and self.UI._GroupSlotSlotValues
            slot.classDrop._EchoesSuppress = true
            if baseList then
                slot.classDrop:SetList(baseList)
            end
            slot.classDrop:SetValue(1) -- None
            slot.classDrop._EchoesSuppress = nil
            if applyColor then applyColor(slot.classDrop, 1) end
        end

        if slot.cycleBtn then
            slot.cycleBtn.values = { unpack(DEFAULT_CYCLE_VALUES) }
            slot.cycleBtn.index = 1
            if slot.cycleBtn._EchoesCycleUpdate then slot.cycleBtn._EchoesCycleUpdate(slot.cycleBtn) end
        end
    end

    local function FillSlot(slot, member)
        if not slot or not member then return end

        slot._EchoesMember = member

        -- Occupied slots: show the member name in the dropdown display.
        local c = member.classFile and colors and colors[member.classFile]
        if slot.classDrop and slot.classDrop.SetList and slot.classDrop.SetValue then
            slot.classDrop._EchoesSuppress = true
            slot.classDrop:SetList({ [1] = member.name or "" })
            slot.classDrop:SetValue(1)
            slot.classDrop._EchoesSuppress = nil

            if slot.classDrop.text and slot.classDrop.text.SetTextColor then
                if c then
                    local r, g, b = GreyTintClassColor(c)
                    slot.classDrop.text:SetTextColor(r, g, b, 1)
                else
                    slot.classDrop.text:SetTextColor(1, 1, 1, 1)
                end
            end
        end
        SetEnabledForDropdown(slot.classDrop, false)

        -- Name button: Kick for filled non-player slots; hidden for player slot.
        SetEnabledForWidget(slot.nameBtn, true)
        SetNameButtonVisible(slot, not member.isPlayer)
        if not member.isPlayer then
            SetNameButtonMode(slot, "kick", member)
        else
            SetNameButtonMode(slot, "name")
        end

        if slot.cycleBtn then
            local classIndex = Echoes_GetGroupSlotIndexForClassFile(member.classFile)
            local display = (classIndex and self.UI._GroupSlotSlotValues and self.UI._GroupSlotSlotValues[classIndex]) or nil
            local vals = GetCycleValuesForRightText(display)

            slot.cycleBtn._EchoesLastClassFile = slot.cycleBtn._EchoesLastClassFile or member.classFile
            if slot.cycleBtn._EchoesLastClassFile ~= member.classFile then
                slot.cycleBtn.index = 1
                slot.cycleBtn._EchoesLastClassFile = member.classFile
            end

            slot.cycleBtn.values = { unpack(vals) }
            if not slot.cycleBtn.index or slot.cycleBtn.index < 1 or slot.cycleBtn.index > #slot.cycleBtn.values then
                slot.cycleBtn.index = 1
            end
            if slot.cycleBtn._EchoesCycleUpdate then slot.cycleBtn._EchoesCycleUpdate(slot.cycleBtn) end
        end

        -- Spec box should always be changeable, even when the raid slot is filled.
        SetEnabledForWidget(slot.cycleBtn, true)
    end

    -- Build members by subgroup in roster order.
    local membersByGroup = {}
    local n = (type(GetNumRaidMembers) == "function" and GetNumRaidMembers()) or 0
    local inRaid = (UnitInRaid and UnitInRaid("player") and UnitInRaid("player") ~= 0 and n > 0)

    local nParty = (type(GetNumPartyMembers) == "function" and GetNumPartyMembers()) or 0
    local inParty = (not inRaid) and (nParty and nParty > 0)

    if inRaid then
        for i = 1, n do
            -- 3.3.5 GetRaidRosterInfo return order: name, rank, subgroup, level, class, classFile, ...
            local name, _, subgroup, _, _, classFile = GetRaidRosterInfo(i)
            subgroup = tonumber(subgroup)
            if subgroup and subgroup >= 1 and subgroup <= 5 then
                membersByGroup[subgroup] = membersByGroup[subgroup] or {}
                local unit = "raid" .. i

                membersByGroup[subgroup][#membersByGroup[subgroup] + 1] = {
                    unit = unit,
                    name = name,
                    classFile = classFile,
                    isPlayer = (UnitIsUnit and UnitIsUnit(unit, "player")) or false,
                }
            end
        end
    elseif inParty then
        -- Party layout: mirror player first, then party1..party4.
        membersByGroup[1] = {
            {
                unit = "player",
                name = UnitName("player"),
                classFile = select(2, UnitClass("player")),
                isPlayer = true,
            },
        }

        for i = 1, math.min(4, nParty) do
            local unit = "party" .. i
            membersByGroup[1][#membersByGroup[1] + 1] = {
                unit = unit,
                name = UnitName(unit),
                classFile = select(2, UnitClass(unit)),
                isPlayer = false,
            }
        end
    else
        membersByGroup[1] = {
            {
                unit = "player",
                name = UnitName("player"),
                classFile = select(2, UnitClass("player")),
                isPlayer = true,
            },
        }
    end

    for group = 1, 5 do
        for pos = 1, 5 do
            local slot = self.UI.groupSlots[group] and self.UI.groupSlots[group][pos] or nil
            if slot then
                local member = membersByGroup[group] and membersByGroup[group][pos] or nil
                if member then
                    FillSlot(slot, member)
                else
                    ResetSlot(slot)
                end
            end
        end
    end
end

-- Backwards compat: keep the old name but drive from full roster now.
function Echoes:UpdateGroupCreationPlayerSlot(force)
    self:UpdateGroupCreationFromRoster(force)
end

------------------------------------------------------------
-- Echoes tab (now includes UI scale slider)
------------------------------------------------------------
function Echoes:BuildEchoesTab(container)
    container:SetLayout("List")

    local heading = AceGUI:Create("Heading")
    heading:SetText("Echoes")
    heading:SetFullWidth(true)
    SkinHeading(heading)
    container:AddChild(heading)

    local desc = AceGUI:Create("Label")
    desc:SetText("Extra tools & settings for the Echoes control panel.")
    desc:SetFullWidth(true)
    SkinLabel(desc)
    container:AddChild(desc)

    local scaleSlider = AceGUI:Create("Slider")
    scaleSlider:SetLabel("UI Scale")
    scaleSlider:SetSliderValues(0.7, 1.3, 0.05)
    scaleSlider:SetValue(EchoesDB.uiScale or 1.0)
    scaleSlider:SetFullWidth(true)
    scaleSlider:SetCallback("OnValueChanged", function(widget, event, value)
        local v = tonumber(value) or 1.0
        v = Clamp(v, 0.7, 1.3)
        EchoesDB.uiScale = v
        Echoes:ApplyScale()
    end)
    container:AddChild(scaleSlider)
end

------------------------------------------------------------
-- Minimap button
------------------------------------------------------------
local MinimapBtn

local function MinimapButton_UpdatePosition()
    if not MinimapBtn then return end

    local angle  = tonumber(EchoesDB.minimapAngle) or 220
    local radius = 80

    local mx, my = Minimap:GetCenter()
    local bx = mx + radius * math.cos(math.rad(angle))
    local by = my + radius * math.sin(math.rad(angle))

    MinimapBtn:ClearAllPoints()
    MinimapBtn:SetPoint("CENTER", UIParent, "BOTTOMLEFT", bx, by)
end

local function MinimapButton_OnDragUpdate()
    local cx, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    cx, cy = cx / scale, cy / scale

    local mx, my = Minimap:GetCenter()
    local dx, dy = cx - mx, cy - my

    local angle = math.deg(math.atan2(dy, dx))
    EchoesDB.minimapAngle = angle
    MinimapButton_UpdatePosition()
end

function Echoes:BuildMinimapButton()
    if MinimapBtn then return end

    local b = CreateFrame("Button", "EchoesMinimapButton", Minimap)
    MinimapBtn = b
    b:SetSize(32, 32)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("RightButton")
    b:SetHighlightTexture(nil)

    local border = b:CreateTexture(nil, "ARTWORK")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("CENTER", b, "CENTER", 10, -12)

    local label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER", b, "CENTER", 0, 0)
    label:SetText("E")
    label:SetTextColor(0.95, 0.82, 0.25, 1)
    label:SetFont(label:GetFont(), 16, "OUTLINE")

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Echoes\n|cffAAAAAALeft-click: Toggle window\nRight-drag: Move|r")
        GameTooltip:Show()
    end)

    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    b:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            Echoes:ToggleMainWindow()
        end
    end)

    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", MinimapButton_OnDragUpdate)
    end)

    b:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        MinimapButton_UpdatePosition()
    end)

    MinimapButton_UpdatePosition()
end

------------------------------------------------------------
-- AceAddon lifecycle
------------------------------------------------------------
function Echoes:OnInitialize()
    EnsureDefaults()
    self:RegisterChatCommand("echoes", "ToggleMainWindow")
    self:RegisterChatCommand("ech",    "ToggleMainWindow")
end

function Echoes:OnEnable()
    self:BuildMinimapButton()

    -- Keep Group Creation "player slot" in sync with raid changes and spec changes.
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEchoesRosterOrSpecChanged")
    self:RegisterEvent("RAID_ROSTER_UPDATE", "OnEchoesRosterOrSpecChanged")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED", "OnEchoesRosterOrSpecChanged")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "OnEchoesRosterOrSpecChanged")
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "OnEchoesRosterOrSpecChanged")
end

function Echoes:OnEchoesRosterOrSpecChanged()
    self:UpdateGroupCreationFromRoster(false)
end

function Echoes:OnDisable()
end
