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
    GROUP  = { w = 480, h = 520 },
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
        tb:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -1)
        tb:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -1)
        tb:SetHeight(22)
        SkinBackdrop(tb, 0.98)
        f.EchoesTitleBar = tb
    end

    if widget.titletext then
        widget.titletext:ClearAllPoints()
        widget.titletext:SetPoint("CENTER", f.EchoesTitleBar, "CENTER", 0, -1)
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
    SkinBackdrop(widget.frame, 0.25)
end

local function SkinInlineGroup(widget)
    if not widget or not widget.frame then return end
    SkinBackdrop(widget.frame, 0.5)
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

    -- Skin the box
    SkinBackdrop(box, 0.95)
    box:SetBackdropColor(0.11, 0.11, 0.11, 0.98)
    box:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)

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
            b:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
            b:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)

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
            widget.text:SetTextColor(0.92, 0.92, 0.92, 1)
        end
    end

    -- Label styling (if a label is used)
    if widget.label and widget.label.SetTextColor then
        widget.label:SetTextColor(0.9, 0.9, 0.9, 1)
    end
end

local function SkinEditBox(widget)
    if not widget or not widget.editbox then return end
    SkinBackdrop(widget.editbox, 0.6)

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
    "none",
    "pally",
    "dk",
    "war",
    "sham",
    "hunt",
    "druid",
    "rogue",
    "priest",
    "lock",
    "mage",
}

local DEFAULT_CYCLE_VALUES = { "none" }

local CYCLE_VALUES_BY_RIGHT_TEXT = {
    ["Paladin"]      = { "Prot", "Holy", "Ret" },
    ["Death Knight"] = { "Blood", "Frost", "Unholy" },
    ["Warrior"]      = { "Prot", "Arms", "Fury" },
    ["Shaman"]       = { "Resto", "Enhance", "Ele" },
    ["Hunter"]       = { "BM", "Surv", "MM" },
    ["Druid"]        = { "Bear", "Resto", "Cat", "Boomy" },
    ["Rogue"]        = { "Combat", "Assa", "Sub" },
    ["Priest"]       = { "Disc", "Holy", "Shadow" },
    ["Warlock"]      = { "Affl", "Demo", "Destro" },
    ["Mage"]         = { "Fire", "Arcane", "Frost" },
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
    frame:SetWidth(s.w)
    frame:SetHeight(s.h)
end

function Echoes:ApplyScale()
    local widget = self.UI.frame
    if widget and widget.frame and widget.frame.SetScale then
        widget.frame:SetScale(EchoesDB.uiScale or 1.0)
    end
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
        lab:SetJustifyH("CENTER")
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

    local topGroup = AceGUI:Create("SimpleGroup")
    topGroup:SetFullWidth(true)
    topGroup:SetLayout("Flow")
    SkinSimpleGroup(topGroup)
    container:AddChild(topGroup)

    local nameEdit = AceGUI:Create("EditBox")
    nameEdit:SetLabel("Template Name")
    nameEdit:SetText("Text Box")
    nameEdit:SetWidth(150)
    nameEdit:SetCallback("OnEnterPressed", function(widget, event, text)
        if text == "" then
            widget:SetText("Text Box")
        end
    end)
    topGroup:AddChild(nameEdit)
    SkinEditBox(nameEdit)

    local templateValues = {}
    for i, v in ipairs(GROUP_TEMPLATES) do
        templateValues[i] = v
    end

    local templateDrop = AceGUI:Create("Dropdown")
    templateDrop:SetLabel("Template")
    templateDrop:SetList(templateValues)
    templateDrop:SetValue(EchoesDB.groupTemplateIndex or 1)
    templateDrop:SetWidth(140)
    templateDrop:SetCallback("OnValueChanged", function(widget, event, value)
        EchoesDB.groupTemplateIndex = value
    end)
    topGroup:AddChild(templateDrop)
    SkinDropdown(templateDrop)

    local saveBtn = AceGUI:Create("Button")
    saveBtn:SetText("Save")
    saveBtn:SetWidth(80)
    saveBtn:SetCallback("OnClick", function()
        Echoes_Print("Group setup saved (stub).")
    end)
    container:AddChild(saveBtn)
    SkinButton(saveBtn)

    local gridGroup = AceGUI:Create("InlineGroup")
    gridGroup:SetTitle("Group Slots")
    gridGroup:SetFullWidth(true)
    gridGroup:SetLayout("Flow")
    SkinInlineGroup(gridGroup)
    container:AddChild(gridGroup)

    local COLUMN_CONFIG = {
        { rows = 5 }, { rows = 5 }, { rows = 5 }, { rows = 5 },
        { rows = 5 }, { rows = 5 }, { rows = 5 }, { rows = 4 },
    }

    local slotValues = {}
    for i, v in ipairs(GROUP_SLOT_OPTIONS) do
        slotValues[i] = v
    end

    for _, cfg in ipairs(COLUMN_CONFIG) do
        local col = AceGUI:Create("InlineGroup")
        col:SetTitle("")
        col:SetLayout("List")
        col:SetWidth(140)
        SkinInlineGroup(col)
        gridGroup:AddChild(col)

        for rowIndex = 1, cfg.rows do
            local rowGroup = AceGUI:Create("SimpleGroup")
            rowGroup:SetFullWidth(true)
            rowGroup:SetLayout("Flow")
            col:AddChild(rowGroup)

            local cycleBtn = AceGUI:Create("Button")
            cycleBtn:SetWidth(40)
            cycleBtn.values = { unpack(DEFAULT_CYCLE_VALUES) }
            cycleBtn.index  = 1

            local function CycleUpdate(btn)
                local n = #btn.values
                if n == 0 then
                    btn:SetText("")
                    return
                end
                if btn.index < 1 or btn.index > n then
                    btn.index = 1
                end
                btn:SetText(btn.values[btn.index])
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
            dd:SetWidth(70)
            dd:SetCallback("OnValueChanged", function(widget, event, value)
                local text = slotValues[value]
                local vals = GetCycleValuesForRightText(text)
                cycleBtn.values = { unpack(vals) }
                cycleBtn.index  = 1
                CycleUpdate(cycleBtn)
            end)
            rowGroup:AddChild(dd)
            SkinDropdown(dd)
        end
    end

    local bottomGroup = AceGUI:Create("SimpleGroup")
    bottomGroup:SetFullWidth(true)
    bottomGroup:SetLayout("Flow")
    SkinSimpleGroup(bottomGroup)
    container:AddChild(bottomGroup)

    local inviteBtn = AceGUI:Create("Button")
    inviteBtn:SetText("Invite")
    inviteBtn:SetWidth(120)
    inviteBtn:SetCallback("OnClick", function()
        Echoes_Print("Invite clicked (stub).")
    end)
    bottomGroup:AddChild(inviteBtn)
    SkinButton(inviteBtn)

    local talentsBtn = AceGUI:Create("Button")
    talentsBtn:SetText("Set Talents")
    talentsBtn:SetWidth(120)
    talentsBtn:SetCallback("OnClick", function()
        Echoes_Print("Set Talents clicked (stub).")
    end)
    bottomGroup:AddChild(talentsBtn)
    SkinButton(talentsBtn)
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
end

function Echoes:OnDisable()
end
