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

    -- Group Creation templates
    EchoesDB.groupTemplates     = EchoesDB.groupTemplates     or {}
    EchoesDB.groupTemplateNames = EchoesDB.groupTemplateNames or {}

    -- Default built-in presets (only if user hasn't saved one already)
    -- 10 Man: leave Group 1 Slot 1 open for the player.
    if not EchoesDB.groupTemplates[1] then
        EchoesDB.groupTemplates[1] = {
            name = "10 Man",
            slots = {
                [1] = {
                    [1] = nil,
                    [2] = { class = "Paladin", specLabel = "Protection" },
                    [3] = { class = "Warrior", specLabel = "Protection" },
                    [4] = { class = "Priest",  specLabel = "Discipline" },
                    [5] = { class = "Druid",   specLabel = "Restoration" },
                },
                [2] = {
                    [1] = { class = "Rogue",  specLabel = "Combat" },
                    [2] = { class = "Paladin", specLabel = "Retribution" },
                    [3] = { class = "Shaman", specLabel = "Elemental" },
                    [4] = { class = "Mage",   specLabel = "Arcane" },
                    [5] = { class = "Druid",  specLabel = "Balance" },
                },
            },
        }
    end

    -- 25 Man: leave Group 1 Slot 1 open for the player.
    if not EchoesDB.groupTemplates[2] then
        EchoesDB.groupTemplates[2] = {
            name = "25 Man",
            slots = {
                [1] = {
                    [1] = nil,
                    [2] = { class = "Druid",   specLabel = "Bear" },
                    [3] = { class = "Paladin", specLabel = "Protection" },
                    [4] = { class = "Warrior", specLabel = "Protection" },
                    [5] = { class = "Paladin", specLabel = "Holy" },
                },
                [2] = {
                    [1] = { class = "Priest",  specLabel = "Discipline" },
                    [2] = { class = "Shaman",  specLabel = "Restoration" },
                    [3] = { class = "Druid",   specLabel = "Restoration" },
                    [4] = { class = "Priest",  specLabel = "Holy" },
                    [5] = { class = "Warlock", specLabel = "Affliction" },
                },
                [3] = {
                    [1] = { class = "Warrior", specLabel = "Fury" },
                    [2] = { class = "Rogue",   specLabel = "Assassination" },
                    [3] = { class = "Rogue",   specLabel = "Combat" },
                    [4] = { class = "Druid",   specLabel = "Feral" },
                    [5] = { class = "Shaman",  specLabel = "Enhancement" },
                },
                [4] = {
                    [1] = { class = "Paladin", specLabel = "Retribution" },
                    [2] = { class = "Hunter",  specLabel = "Marksmanship" },
                    [3] = { class = "Hunter",  specLabel = "Survival" },
                    [4] = { class = "Druid",   specLabel = "Balance" },
                    [5] = { class = "Shaman",  specLabel = "Elemental" },
                },
                [5] = {
                    [1] = { class = "Shaman",  specLabel = "Elemental" },
                    [2] = { class = "Shaman",  specLabel = "Elemental" },
                    [3] = { class = "Warlock", specLabel = "Demonology" },
                    [4] = { class = "Mage",    specLabel = "Arcane" },
                    [5] = { class = "Mage",    specLabel = "Fire" },
                },
            },
        }
    else
        -- Migration: older default used "Feral" for the bear tank slot.
        local t2 = EchoesDB.groupTemplates[2]
        local e = t2 and t2.slots and t2.slots[1] and t2.slots[1][2]
        if t2 and t2.name == "25 Man" and e and e.class == "Druid" and e.specLabel == "Feral" and not e.altName then
            e.specLabel = "Bear"
        end
    end

    -- Optional server-specific command template for setting talents/specs.
    -- Tokens: {name} {class} {spec} {group} {slot}
    EchoesDB.talentCommandTemplate = EchoesDB.talentCommandTemplate or ""
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

-- Forward declaration: ShowNamePrompt uses SkinEditBox, which is defined later.
local SkinEditBox

local function SkinPopupFrame(widget)
    if not widget or not widget.frame then return end
    local f = widget.frame

    -- Hide any AceGUI resize grips and bottom-bar widgets for this popup.
    -- We provide our own Save/Cancel buttons, and we never want a resizer.
    if widget.sizer_se then widget.sizer_se:Hide(); widget.sizer_se:EnableMouse(false) end
    if widget.sizer_s  then widget.sizer_s:Hide();  widget.sizer_s:EnableMouse(false)  end
    if widget.sizer_e  then widget.sizer_e:Hide();  widget.sizer_e:EnableMouse(false)  end
    if f.sizer_se then f.sizer_se:Hide(); if f.sizer_se.EnableMouse then f.sizer_se:EnableMouse(false) end end
    if f.sizer_s  then f.sizer_s:Hide();  if f.sizer_s.EnableMouse  then f.sizer_s:EnableMouse(false)  end end
    if f.sizer_e  then f.sizer_e:Hide();  if f.sizer_e.EnableMouse  then f.sizer_e:EnableMouse(false)  end end

    if widget.closebutton then
        widget.closebutton:Hide()
        widget.closebutton:EnableMouse(false)
    end
    if widget.statusbg then
        widget.statusbg:Hide()
        if widget.statusbg.SetBackdrop then widget.statusbg:SetBackdrop(nil) end
        if widget.statusbg.SetAlpha then widget.statusbg:SetAlpha(0) end
        if widget.statusbg.EnableMouse then widget.statusbg:EnableMouse(false) end
        if widget.statusbg.SetWidth then widget.statusbg:SetWidth(1) end
        if widget.statusbg.SetHeight then widget.statusbg:SetHeight(1) end
        if widget.statusbg.ClearAllPoints and widget.statusbg.SetPoint then
            widget.statusbg:ClearAllPoints()
            widget.statusbg:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 0)
        end
    end
    if widget.statustext then
        widget.statustext:Hide()
        if widget.statustext.SetText then widget.statustext:SetText("") end
    end

    -- Some Ace3 builds attach the status background/text directly to the frame.
    if f.statusbg then
        f.statusbg:Hide()
        if f.statusbg.SetBackdrop then f.statusbg:SetBackdrop(nil) end
        if f.statusbg.SetAlpha then f.statusbg:SetAlpha(0) end
        if f.statusbg.SetWidth then f.statusbg:SetWidth(1) end
        if f.statusbg.SetHeight then f.statusbg:SetHeight(1) end
        if f.statusbg.ClearAllPoints and f.statusbg.SetPoint then
            f.statusbg:ClearAllPoints()
            f.statusbg:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 0)
        end
    end
    if f.statustext then
        f.statustext:Hide()
        if f.statustext.SetText then f.statustext:SetText("") end
    end

    -- Strip default AceGUI/Blizzard textures where possible
    if f.GetRegions then
        local regs = { f:GetRegions() }
        for _, r in ipairs(regs) do
            if r and r.IsObjectType and r:IsObjectType("Texture") then
                r:SetTexture(nil)
            end
        end
    end

    SkinBackdrop(f, 0.95)
    if f.SetBackdropBorderColor then
        f:SetBackdropBorderColor(0, 0, 0, 0.85)
    end
end

function Echoes:ShowNamePrompt(opts)
    opts = opts or {}
    local title = opts.title or "Custom Character"
    local initialText = tostring(opts.initialText or "")
    local onAccept = opts.onAccept
    local onCancel = opts.onCancel

    -- Close any existing prompt
    if self.UI and self.UI.namePrompt and self.UI.namePrompt.Release then
        self.UI.namePrompt:Release()
        self.UI.namePrompt = nil
    end

    local INPUT_HEIGHT = 24
    local w = AceGUI:Create("Frame")
    w:SetTitle(title)
    w:SetLayout("List")
    w:SetWidth(280)
    w:SetHeight(160)

    if w.frame and w.frame.SetFrameStrata then
        w.frame:SetFrameStrata("DIALOG")
    end

    -- Popup should not be movable/resizable in 3.3.5
    if w.frame then
        -- AceGUI's title bar calls :StartMoving() unconditionally; if the frame
        -- is not movable, WoW throws "Frame is not movable". Keep movable enabled
        -- and instead disable the title mover child frame (see below).
        if w.frame.SetMovable then w.frame:SetMovable(true) end
        -- AceGUI's sizer scripts call :StartSizing() unconditionally; if the frame
        -- is not resizable, WoW throws "Frame is not resizable". Keep resizable
        -- enabled but lock min/max to the same size.
        if w.frame.SetResizable then w.frame:SetResizable(true) end
        if w.frame.SetMinResize and w.frame.SetMaxResize and w.frame.GetWidth and w.frame.GetHeight then
            local fw = w.frame:GetWidth() or 260
            local fh = w.frame:GetHeight() or 140
            w.frame:SetMinResize(fw, fh)
            w.frame:SetMaxResize(fw, fh)
        end
    end

    SkinPopupFrame(w)

    -- Remove any reserved bottom status-bar space and avoid overlap with our buttons.
    if w.frame and w.content and w.content.ClearAllPoints and w.content.SetPoint then
        w.content:ClearAllPoints()
        w.content:SetPoint("TOPLEFT", w.frame, "TOPLEFT", 10, -36)
        w.content:SetPoint("BOTTOMRIGHT", w.frame, "BOTTOMRIGHT", -10, 46)
    end

    local function DisableAceGUIChrome(frame)
        if not frame or not frame.GetChildren then return end
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            if child and child.IsObjectType then
                if child:IsObjectType("Button") then
                    local point, relTo = child.GetPoint and child:GetPoint(1)
                    local w2 = child.GetWidth and child:GetWidth() or 0
                    local h2 = child.GetHeight and child:GetHeight() or 0

                    -- Hide the default bottom-right Close button and the bottom-left status bar.
                    if (relTo == frame or relTo == nil) and point == "BOTTOMRIGHT" and w2 >= 90 and h2 <= 22 then
                        child:Hide()
                        child:EnableMouse(false)
                    elseif (relTo == frame or relTo == nil) and point == "BOTTOMLEFT" and h2 == 24 then
                        child:Hide()
                        child:EnableMouse(false)
                    end
                elseif child:IsObjectType("Frame") then
                    local md = child.GetScript and child:GetScript("OnMouseDown")
                    local mu = child.GetScript and child:GetScript("OnMouseUp")
                    local point, relTo = child.GetPoint and child:GetPoint(1)
                    local cw = child.GetWidth and child:GetWidth() or 0
                    local ch = child.GetHeight and child:GetHeight() or 0

                    -- Hide status-bar background frames (common: 24px tall, bottom-anchored)
                    if (relTo == frame or relTo == nil) and point and point:find("BOTTOM") and ch >= 18 and ch <= 30 and cw >= 80 then
                        child:Hide()
                        child:SetAlpha(0)
                        if child.SetBackdrop then child:SetBackdrop(nil) end
                        if child.EnableMouse then child:EnableMouse(false) end
                    end

                    -- Hide resize grips (sizers): small frames anchored on bottom/right.
                    if md and mu and (relTo == frame or relTo == nil) and (point == "BOTTOMRIGHT" or point == "BOTTOM" or point == "RIGHT") and cw <= 30 and ch <= 30 then
                        child:Hide()
                        if child.EnableMouse then child:EnableMouse(false) end
                        if child.SetScript then
                            child:SetScript("OnMouseDown", nil)
                            child:SetScript("OnMouseUp", nil)
                        end
                    end

                    -- Disable the title mover: a mouse-enabled frame with mouse down/up scripts.
                    if md and mu and (point == "TOP" or point == "TOPLEFT" or point == "TOPRIGHT" or point == nil) and ch >= 20 and ch <= 50 then
                        if child.EnableMouse then child:EnableMouse(false) end
                        if child.SetScript then
                            child:SetScript("OnMouseDown", nil)
                            child:SetScript("OnMouseUp", nil)
                        end
                    end
                end
            end
        end
    end

    if w.frame then
        DisableAceGUIChrome(w.frame)
    end

    local function ClosePrompt()
        if self.UI and self.UI.namePrompt == w then
            self.UI.namePrompt = nil
        end
        if w and w.Release then
            w:Release()
        end
    end

    local function DoAccept()
        local text = initialText
        -- AceGUI EditBox stores the real EditBox as widget.editbox
        if w._EchoesNameEdit and w._EchoesNameEdit.editbox and w._EchoesNameEdit.editbox.GetText then
            text = w._EchoesNameEdit.editbox:GetText() or ""
        end

        if type(onAccept) == "function" then
            onAccept(text)
        end
        ClosePrompt()
    end

    local function DoCancel()
        if type(onCancel) == "function" then
            onCancel()
        end
        ClosePrompt()
    end

    w:SetCallback("OnClose", function()
        DoCancel()
    end)

    -- Upper-center on screen
    if w.frame and w.frame.ClearAllPoints and w.frame.SetPoint then
        w.frame:ClearAllPoints()
        w.frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
    end

    local padTop = AceGUI:Create("SimpleGroup")
    padTop:SetFullWidth(true)
    padTop:SetLayout("Flow")
    padTop:SetHeight(6)
    w:AddChild(padTop)

    local edit = AceGUI:Create("EditBox")
    edit:SetLabel("")
    edit:SetText(initialText)
    edit:SetFullWidth(true)
    edit:SetHeight(INPUT_HEIGHT)
    w:AddChild(edit)
    SkinEditBox(edit)
    if edit.DisableButton then
        edit:DisableButton(true)
    end
    -- AceGUI EditBox's internal OKAY button can still be visible depending on focus/text;
    -- force-hide it when we want a clean popup.
    if edit.button then
        if edit.button.Hide then edit.button:Hide() end
        if edit.button.EnableMouse then edit.button:EnableMouse(false) end
        -- Some Ace3 builds will re-show this button on focus; prevent it.
        if edit.button.Hide then
            edit.button.Show = edit.button.Hide
        end
    end
    if edit.editbox and edit.editbox.SetTextInsets then
        edit.editbox:SetTextInsets(0, 0, 3, 3)
    end
    w._EchoesNameEdit = edit

    edit:SetCallback("OnEnterPressed", function(widget, event, text)
        DoAccept()
    end)

    -- Escape should cancel/close, and focus the editbox when shown.
    if edit and edit.editbox then
        if edit.editbox.SetFocus then
            edit.editbox:SetFocus()
        end
        if edit.editbox.HighlightText then
            edit.editbox:HighlightText()
        end

        -- Wire keys directly on the real EditBox for reliability across Ace3 builds.
        if edit.editbox.SetScript then
            edit.editbox:SetScript("OnEnterPressed", function()
                DoAccept()
            end)
            edit.editbox:SetScript("OnEscapePressed", function()
                DoCancel()
            end)
        end
    end


    -- Provide explicit Save/Cancel buttons (do not rely on AceGUI's bottom bar).
    if w.frame then
        local f = w.frame
        local function EnsurePopupButton(key, label, anchorOffsetX, onClick)
            local btn = f[key]
            if not btn then
                btn = CreateFrame("Button", nil, f)
                btn:SetSize(90, 22)
                SkinBackdrop(btn, 0.9)

                local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                fs:SetPoint("CENTER")
                fs:SetTextColor(0.9, 0.8, 0.5, 1)
                local font, size, flags = fs:GetFont()
                fs:SetFont(font, math.max(10, (size or 12)), "OUTLINE")
                btn._EchoesLabel = fs

                btn:HookScript("OnEnter", function(self)
                    self:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
                end)
                btn:HookScript("OnLeave", function(self)
                    self:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
                end)

                f[key] = btn
            end

            if btn._EchoesLabel and btn._EchoesLabel.SetText then
                btn._EchoesLabel:SetText(label)
            end
            if btn.ClearAllPoints then
                btn:ClearAllPoints()
                btn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", anchorOffsetX, 10)
            end
            if btn.SetFrameLevel and f.GetFrameLevel then
                btn:SetFrameLevel((f:GetFrameLevel() or 0) + 10)
            end
            if btn.EnableMouse then btn:EnableMouse(true) end
            if btn.SetScript then btn:SetScript("OnClick", onClick) end
            if btn.Show then btn:Show() end
        end

        EnsurePopupButton("EchoesPopupCancel", "Close", -10, function() DoCancel() end)
        EnsurePopupButton("EchoesPopupSave", "Save", -110, function() DoAccept() end)

        -- Last-resort: hide any remaining bottom-left status-bar panels.
        if f.GetChildren then
            local kids = { f:GetChildren() }
            for _, child in ipairs(kids) do
                if child and child.IsObjectType and child.GetPoint and child.GetHeight then
                    local point, relTo = child:GetPoint(1)
                    local h = child:GetHeight() or 0

                    local isOurButton = (child == f.EchoesPopupSave) or (child == f.EchoesPopupCancel)
                    if not isOurButton and (relTo == f or relTo == nil) and point and point:find("BOTTOM") and h >= 18 and h <= 30 then
                        if child.Hide then child:Hide() end
                        if child.SetAlpha then child:SetAlpha(0) end
                        if child.EnableMouse then child:EnableMouse(false) end
                        if child.SetBackdrop then child:SetBackdrop(nil) end

                        -- Clear any textures on the offending frame.
                        if child.GetRegions then
                            local regs = { child:GetRegions() }
                            for _, r in ipairs(regs) do
                                if r and r.IsObjectType and r:IsObjectType("Texture") and r.SetTexture then
                                    r:SetTexture(nil)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    self.UI = self.UI or {}
    self.UI.namePrompt = w
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

        -- Filled roster slots store an explicit classFile so we can keep the name
        -- class-colored even while disabled.
        if widget.dropdown._EchoesFilledClassFile then
            local colors = rawget(_G, "RAID_CLASS_COLORS")
            local c = colors and colors[widget.dropdown._EchoesFilledClassFile]
            if c and widget.text and widget.text.SetTextColor then
                widget.text:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)
                return
            end
        end

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

SkinEditBox = function(widget)
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

    -- Make text selection highlight obvious (default highlight can be too dark on our theme).
    if widget.editbox.SetHighlightColor then
        widget.editbox:SetHighlightColor(0.92, 0.92, 0.92, 0.45)
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

local function Echoes_GetPlayerSpecLabel(classFile)
    if not classFile or type(GetTalentTabInfo) ~= "function" then return nil end

    local talentGroup = 1
    if type(GetActiveTalentGroup) == "function" then
        talentGroup = GetActiveTalentGroup() or 1
    end

    local bestName
    local bestPoints = -1
    for tab = 1, 3 do
        local name, _, pointsSpent = GetTalentTabInfo(tab, false, false, talentGroup)
        pointsSpent = tonumber(pointsSpent) or 0
        if name and pointsSpent > bestPoints then
            bestPoints = pointsSpent
            bestName = name
        end
    end
    if not bestName then return nil end

    local s = tostring(bestName)
    local norm = s:lower():gsub("%s+", "")

    -- Normalize names that don't match our labels exactly.
    if classFile == "DRUID" and norm == "feralcombat" then
        return "Feral"
    end

    -- Most classes: talent tab names already match our labels.
    if classFile == "PALADIN" then
        if s == "Holy" or s == "Protection" or s == "Retribution" then return s end
    elseif classFile == "DEATHKNIGHT" then
        if s == "Blood" or s == "Frost" or s == "Unholy" then return s end
    elseif classFile == "WARRIOR" then
        if s == "Arms" or s == "Fury" or s == "Protection" then return s end
    elseif classFile == "SHAMAN" then
        if s == "Elemental" or s == "Enhancement" or s == "Restoration" then return s end
    elseif classFile == "HUNTER" then
        if s == "Beast Mastery" or s == "Marksmanship" or s == "Survival" then return s end
    elseif classFile == "ROGUE" then
        if s == "Assassination" or s == "Combat" or s == "Subtlety" then return s end
    elseif classFile == "PRIEST" then
        if s == "Discipline" or s == "Holy" or s == "Shadow" then return s end
    elseif classFile == "WARLOCK" then
        if s == "Affliction" or s == "Demonology" or s == "Destruction" then return s end
    elseif classFile == "MAGE" then
        if s == "Arcane" or s == "Fire" or s == "Frost" then return s end
    elseif classFile == "DRUID" then
        if s == "Balance" or s == "Feral" or s == "Restoration" then return s end
    end

    return nil
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

-- Small action queue to avoid spamming chat / invite too fast.
-- actions: { { kind = "chat", msg = "...", channel = "PARTY", target = nil }, { kind = "invite", name = "..." }, ... }
local function Echoes_NormalizeName(name)
    name = tostring(name or "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    name = name:gsub("%-.+$", "") -- strip realm (Name-Realm)
    return name
end

function Echoes:RunAfter(delaySeconds, fn)
    delaySeconds = tonumber(delaySeconds) or 0
    if delaySeconds < 0 then delaySeconds = 0 end

    if type(fn) ~= "function" then return end

    if not self._EchoesAfterFrame then
        local f = CreateFrame("Frame", nil, UIParent)
        f:Hide()
        f:SetScript("OnUpdate", function(_, elapsed)
            if not Echoes._EchoesAfterQueue or #Echoes._EchoesAfterQueue == 0 then
                f:Hide()
                return
            end

            for i = #Echoes._EchoesAfterQueue, 1, -1 do
                local item = Echoes._EchoesAfterQueue[i]
                item.t = (item.t or 0) - (elapsed or 0)
                if item.t <= 0 then
                    table.remove(Echoes._EchoesAfterQueue, i)
                    local ok, err = pcall(item.fn)
                    if not ok then
                        Echoes_Print("Timer error: " .. tostring(err))
                    end
                end
            end
        end)
        self._EchoesAfterFrame = f
    end

    self._EchoesAfterQueue = self._EchoesAfterQueue or {}
    self._EchoesAfterQueue[#self._EchoesAfterQueue + 1] = { t = delaySeconds, fn = fn }
    self._EchoesAfterFrame:Show()
end

local function Echoes_IsNameInGroup(name)
    name = Echoes_NormalizeName(name)
    if name == "" then return false end
    local needle = name:lower()

    if type(GetNumRaidMembers) == "function" and type(GetRaidRosterInfo) == "function" then
        local n = GetNumRaidMembers() or 0
        if n > 0 then
            for i = 1, n do
                local rn = GetRaidRosterInfo(i)
                rn = Echoes_NormalizeName(rn)
                if rn ~= "" and rn:lower() == needle then
                    return true
                end
            end
        end
    end

    if UnitName and UnitName("player") then
        local pn = Echoes_NormalizeName(UnitName("player"))
        if pn ~= "" and pn:lower() == needle then
            return true
        end
    end

    if type(GetNumPartyMembers) == "function" then
        local nParty = GetNumPartyMembers() or 0
        for i = 1, math.min(4, nParty) do
            local unit = "party" .. i
            local un = UnitName and UnitName(unit)
            un = Echoes_NormalizeName(un)
            if un ~= "" and un:lower() == needle then
                return true
            end
        end
    end

    return false
end

function Echoes:RunActionQueue(actions, interval, onDone)
    if not actions or #actions == 0 then return end
    interval = tonumber(interval) or 0.25
    if interval < 0.05 then interval = 0.05 end

    self._EchoesActionQueue = actions
    self._EchoesActionInterval = interval
    self._EchoesActionElapsed = 0
    self._EchoesActionOnDone = onDone
    self._EchoesActionOnDoneFired = false

    if not self._EchoesActionFrame then
        local f = CreateFrame("Frame", nil, UIParent)
        f:Hide()
        f:SetScript("OnUpdate", function(_, elapsed)
            -- If we're in a "wait for Hello" handshake, don't advance the queue until
            -- we either see a Hello sender and they join, or we time out.
            if Echoes._EchoesWaitHelloActive then
                local now = (type(GetTime) == "function" and GetTime()) or 0
                local deadline = Echoes._EchoesWaitHelloDeadline or 0
                local name = Echoes._EchoesWaitHelloName

                if name and name ~= "" then
                    if Echoes_IsNameInGroup(name) then
                        Echoes._EchoesWaitHelloActive = false
                        Echoes._EchoesWaitHelloName = nil
                        Echoes._EchoesWaitHelloInvited = false
                        Echoes._EchoesWaitHelloDeadline = nil
                        return
                    end

                    if not Echoes._EchoesWaitHelloInvited then
                        Echoes._EchoesWaitHelloInvited = true
                        if type(InviteUnit) == "function" then
                            InviteUnit(name)
                        end
                        local post = Echoes._EchoesWaitHelloPostInviteTimeout or 2.0
                        Echoes._EchoesWaitHelloDeadline = now + post
                        return
                    end

                    if now >= deadline then
                        Echoes._EchoesWaitHelloActive = false
                        Echoes._EchoesWaitHelloName = nil
                        Echoes._EchoesWaitHelloInvited = false
                        Echoes._EchoesWaitHelloDeadline = nil
                        return
                    end

                    return
                end

                if now >= deadline then
                    Echoes._EchoesWaitHelloActive = false
                    Echoes._EchoesWaitHelloName = nil
                    Echoes._EchoesWaitHelloInvited = false
                    Echoes._EchoesWaitHelloDeadline = nil
                    return
                end

                return
            end

            if not Echoes._EchoesActionQueue or #Echoes._EchoesActionQueue == 0 then
                if Echoes._EchoesActionOnDone and not Echoes._EchoesActionOnDoneFired then
                    Echoes._EchoesActionOnDoneFired = true
                    local cb = Echoes._EchoesActionOnDone
                    Echoes._EchoesActionOnDone = nil
                    local ok, err = pcall(cb)
                    if not ok then
                        Echoes_Print("ActionQueue onDone error: " .. tostring(err))
                    end
                end
                f:Hide()
                return
            end

            Echoes._EchoesActionElapsed = (Echoes._EchoesActionElapsed or 0) + (elapsed or 0)
            if Echoes._EchoesActionElapsed < (Echoes._EchoesActionInterval or 0.25) then
                return
            end
            Echoes._EchoesActionElapsed = 0

            -- Peek so we can convert-to-raid before consuming the action that would invite beyond party size.
            local a = Echoes._EchoesActionQueue[1]
            if not a then return end

            -- If this invite run needs >5 and party is full, convert to raid before issuing the next add/invite.
            if Echoes._EchoesInviteSessionActive and Echoes._EchoesInviteNeedsRaid and type(ConvertToRaid) == "function" then
                local nRaid = (type(GetNumRaidMembers) == "function" and GetNumRaidMembers()) or 0
                local inRaid = (nRaid and nRaid > 0)
                if not inRaid and type(GetNumPartyMembers) == "function" then
                    local nParty = GetNumPartyMembers() or 0
                    -- Party is full when GetNumPartyMembers() returns 4 (player + 4).
                    if nParty >= 4 then
                        local now = (type(GetTime) == "function" and GetTime()) or 0
                        if not Echoes._EchoesLastConvertToRaid or (now - Echoes._EchoesLastConvertToRaid) > 1.0 then
                            Echoes._EchoesLastConvertToRaid = now
                            ConvertToRaid()
                        end
                        return
                    end
                end
            end

            a = table.remove(Echoes._EchoesActionQueue, 1)
            if not a then return end

            if a.kind == "invite" then
                if type(InviteUnit) == "function" and a.name and a.name ~= "" then
                    InviteUnit(a.name)
                end
            elseif a.kind == "chat" then
                if type(SendChatMessage) == "function" and a.msg and a.msg ~= "" then
                    SendChatMessage(a.msg, a.channel or "PARTY", nil, a.target)
                end
            elseif a.kind == "chat_wait_hello" then
                if type(SendChatMessage) == "function" and a.msg and a.msg ~= "" then
                    SendChatMessage(a.msg, a.channel or "PARTY", nil, a.target)

                    local now = (type(GetTime) == "function" and GetTime()) or 0
                    local timeout = tonumber(a.helloTimeout) or 2.0
                    if timeout < 0.5 then timeout = 0.5 end
                    Echoes._EchoesWaitHelloActive = true
                    Echoes._EchoesWaitHelloName = nil
                    Echoes._EchoesWaitHelloInvited = false
                    Echoes._EchoesWaitHelloPlan = (type(a.plan) == "table") and a.plan or nil
                    Echoes._EchoesWaitHelloPostInviteTimeout = tonumber(a.postInviteTimeout) or 2.0
                    Echoes._EchoesWaitHelloDeadline = now + timeout
                end
            end
        end)
        self._EchoesActionFrame = f
    end

    self._EchoesActionFrame:Show()
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
    "10 Man",
    "25 Man",
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
    "Altbot",
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
    nameEdit:SetText("")
    nameEdit:SetRelativeWidth(0.35)
    nameEdit:SetHeight(INPUT_HEIGHT)
    topGroup:AddChild(nameEdit)
    SkinEditBox(nameEdit)
    if nameEdit.DisableButton then nameEdit:DisableButton(true) end

    local topSpacer = AceGUI:Create("SimpleGroup")
    topSpacer:SetRelativeWidth(0.02)
    topSpacer:SetLayout("Flow")
    topGroup:AddChild(topSpacer)

    local function GetTemplateDisplayName(i)
        i = tonumber(i)
        if not i then return "" end
        if i <= PRESET_COUNT then
            return GROUP_TEMPLATES[i] or ("Template " .. tostring(i))
        end
        if EchoesDB.groupTemplateNames and EchoesDB.groupTemplateNames[i] and EchoesDB.groupTemplateNames[i] ~= "" then
            return tostring(EchoesDB.groupTemplateNames[i])
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
    templateDrop:SetRelativeWidth(0.35)
    templateDrop:SetHeight(INPUT_HEIGHT)
    self.UI.groupTemplateNameEdit = nameEdit
    self.UI.groupTemplateDrop = templateDrop

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

        local allowRename = (idx and idx > PRESET_COUNT) and true or false
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

        -- Disable Save/Delete for built-in presets.
        local allowSaveDelete = (idx and idx > PRESET_COUNT) and true or false
        SetButtonEnabled(saveBtn, allowSaveDelete)
        SetButtonEnabled(deleteBtn, allowSaveDelete)
    end

    -- Forward declarations (used by template helpers below, populated later).
    local slotValues = {}
    local ALTBOT_INDEX

    local function ClearEmptySlot(slot)
        if not slot or slot._EchoesMember then return end

        if slot.classDrop and slot.classDrop.SetList and slot.classDrop.SetValue then
            slot.classDrop._EchoesSuppress = true
            slot.classDrop:SetList(slotValues)
            slot.classDrop:SetValue(1) -- None
            slot.classDrop._EchoesSelectedValue = 1
            slot.classDrop._EchoesAltbotName = nil
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
            slot.cycleBtn.values = { unpack(DEFAULT_CYCLE_VALUES) }
            slot.cycleBtn.index = 1
            slot.cycleBtn._EchoesLocked = false
            if slot.cycleBtn._EchoesCycleUpdate then slot.cycleBtn._EchoesCycleUpdate(slot.cycleBtn) end
        end
    end

    local function LoadPreset(templateIndex)
        local idx = tonumber(templateIndex) or 1

        -- Always clear empty slots first so loading is deterministic.
        if self.UI and self.UI.groupSlots then
            for g = 1, 5 do
                for p = 1, 5 do
                    local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                    if slot then
                        ClearEmptySlot(slot)
                    end
                end
            end
        end

        local tpl = EchoesDB.groupTemplates and EchoesDB.groupTemplates[idx]
        local slots = tpl and tpl.slots
        if not slots or not self.UI or not self.UI.groupSlots then return end

        -- Build a stable per-position plan for specs (used both for icon persistence and Set Talents later).
        self._EchoesPlannedTalentByPos = {}
        for g = 1, 5 do
            self._EchoesPlannedTalentByPos[g] = {}
            for p = 1, 5 do
                local entry = slots[g] and slots[g][p]
                if entry and type(entry) == "table" then
                    self._EchoesPlannedTalentByPos[g][p] = {
                        classText = tostring(entry.class or ""),
                        specLabel = tostring(entry.specLabel or ""),
                    }
                else
                    self._EchoesPlannedTalentByPos[g][p] = nil
                end
            end
        end

        for g = 1, 5 do
            for p = 1, 5 do
                local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                if slot and not slot._EchoesMember and slot.classDrop and slot.classDrop.SetValue then
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

                        slot.classDrop._EchoesSuppress = true
                        slot.classDrop:SetList(slotValues)
                        slot.classDrop:SetValue(desiredIndex)
                        slot.classDrop._EchoesSelectedValue = desiredIndex
                        if desiredIndex == ALTBOT_INDEX then
                            slot.classDrop._EchoesAltbotName = (entry.altName and tostring(entry.altName)) or nil
                        else
                            slot.classDrop._EchoesAltbotName = nil
                        end
                        if slot.classDrop.dropdown then
                            slot.classDrop.dropdown._EchoesFilledClassFile = nil
                        end
                        slot.classDrop._EchoesSuppress = nil

                        if slot.cycleBtn then
                            local vals = GetCycleValuesForRightText(classText)
                            slot.cycleBtn.values = { unpack(vals) }
                            local want = entry.specLabel and tostring(entry.specLabel) or nil
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

    local function SavePreset(templateIndex)
        local idx = tonumber(templateIndex) or 1
        if idx <= PRESET_COUNT then return false end
        if not self.UI or not self.UI.groupSlots then return false end

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
        for g = 1, 5 do
            tpl.slots[g] = {}
            for p = 1, 5 do
                local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                local entry = nil
                if slot then
                    if slot._EchoesMember and slot._EchoesMember.name and not slot._EchoesMember.isPlayer then
                        -- If you're currently grouped, treat roster members as Altbot-by-name.
                        entry = {
                            class = "Altbot",
                            altName = tostring(slot._EchoesMember.name),
                            specLabel = slot.cycleBtn and slot.cycleBtn._EchoesSpecLabel or nil,
                        }
                    elseif (not slot._EchoesMember) and slot.classDrop then
                        local dd = slot.classDrop
                        local value = dd._EchoesSelectedValue or dd.value or 1
                        local classText = slotValues[value] or "None"
                        if classText ~= "None" then
                            local altName = dd._EchoesAltbotName
                            if altName then
                                altName = tostring(altName or "")
                                altName = altName:gsub("^%s+", ""):gsub("%s+$", "")
                                if altName == "" then altName = nil end
                            end

                            local specLabel = slot.cycleBtn and slot.cycleBtn._EchoesSpecLabel or nil
                            if specLabel == "None" then specLabel = nil end

                            entry = { class = classText, altName = altName, specLabel = specLabel }
                        end
                    end
                end
                tpl.slots[g][p] = entry
            end
        end

        EchoesDB.groupTemplates[idx] = tpl
        return true
    end

    templateDrop:SetCallback("OnValueChanged", function(widget, event, value)
        if templateDrop._EchoesSuppress then return end

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
                    LoadPreset(newIndex)
                end,
            })
            return
        end

        EchoesDB.groupTemplateIndex = value
        RefreshTemplateHeader(value)
        LoadPreset(value)
    end)
    topGroup:AddChild(templateDrop)
    SkinDropdown(templateDrop)

    RefreshTemplateHeader(EchoesDB.groupTemplateIndex or 1)

    local topSpacer2 = AceGUI:Create("SimpleGroup")
    topSpacer2:SetRelativeWidth(0.02)
    topSpacer2:SetLayout("Flow")
    topGroup:AddChild(topSpacer2)

    saveBtn = AceGUI:Create("Button")
    saveBtn:SetText("Save")
    saveBtn:SetRelativeWidth(0.12)
    saveBtn:SetHeight(INPUT_HEIGHT)
    saveBtn:SetCallback("OnClick", function()
        local idx = tonumber(EchoesDB.groupTemplateIndex) or 1
        if idx <= PRESET_COUNT then return end
        if not SavePreset(idx) then return end

        local vals = BuildTemplateValues()
        if templateDrop and templateDrop.SetList then
            templateDrop:SetList(vals)
        end
        RefreshTemplateHeader(idx)

        Echoes_Print("Group setup saved.")
    end)
    topGroup:AddChild(saveBtn)
    SkinButton(saveBtn)

    deleteBtn = AceGUI:Create("Button")
    deleteBtn:SetText("Delete")
    deleteBtn:SetRelativeWidth(0.12)
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
    end)
    topGroup:AddChild(deleteBtn)
    SkinButton(deleteBtn)

    -- Apply initial disabled state
    RefreshTemplateHeader(EchoesDB.groupTemplateIndex or 1)

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

        if display == "Altbot" then
            dropdownWidget.text:SetTextColor(0.90, 0.85, 0.70, 1)
            if dropdownWidget._EchoesAltbotName and dropdownWidget._EchoesAltbotName ~= "" and dropdownWidget.text.SetText then
                dropdownWidget.text:SetText(dropdownWidget._EchoesAltbotName)
            end
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
                if btn._EchoesLocked then return end
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

            local nameBtn
            local dd = AceGUI:Create("Dropdown")
            dd:SetList(slotValues)
            dd:SetValue(1)
            dd:SetRelativeWidth(0.54)

            local function UpdateNameButtonVisibility(selectedValue)
                local value = selectedValue or dd._EchoesSelectedValue or dd.value
                local showName = (value == ALTBOT_INDEX) or (dd._EchoesAltbotName and dd._EchoesAltbotName ~= "")
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
            end

            -- Expose for template apply.
            dd._EchoesUpdateNameButtonVisibility = UpdateNameButtonVisibility

            -- Mark these dropdowns so our dropdown popup theming can color class names
            -- and the selected value can be class-colored/disabled-grey.
            if dd.dropdown then
                dd.dropdown._EchoesOwned = true
                dd.dropdown._EchoesDropdownKind = "groupSlot"
            end

            dd:SetCallback("OnValueChanged", function(widget, event, value)
                if widget._EchoesSuppress then return end
                widget._EchoesSelectedValue = value

                if value ~= ALTBOT_INDEX then
                    widget._EchoesAltbotName = nil
                end

                local text = slotValues[value]
                local vals = GetCycleValuesForRightText(text)
                if cycleBtn then
                    cycleBtn.values = { unpack(vals) }
                    cycleBtn.index  = 1
                    CycleUpdate(cycleBtn)
                end

                ApplyGroupSlotSelectedTextColor(widget, value)

                UpdateNameButtonVisibility(value)
            end)

            rowGroup:AddChild(dd)
            SkinDropdown(dd)

            ApplyGroupSlotSelectedTextColor(dd, 1)

            nameBtn = AceGUI:Create("Button")
            nameBtn:SetText("Name")
            nameBtn:SetRelativeWidth(0.32)
            nameBtn:SetHeight(INPUT_HEIGHT)
            local function OnNameButtonClick()
                if not ALTBOT_INDEX then return end
                local cur = dd and (dd._EchoesSelectedValue or dd.value)
                if cur ~= ALTBOT_INDEX then
                    return
                end

                local initialText = (dd._EchoesAltbotName and tostring(dd._EchoesAltbotName)) or ""
                local ok, err = pcall(function()
                    Echoes:ShowNamePrompt({
                        title = "Custom Character",
                        initialText = initialText,
                        onAccept = function(text)
                            text = tostring(text or "")
                            text = text:gsub("^%s+", ""):gsub("%s+$", "")
                            if text == "" then
                                dd._EchoesAltbotName = nil
                            else
                                dd._EchoesAltbotName = text
                            end

                            dd._EchoesSuppress = true
                            dd:SetValue(ALTBOT_INDEX)
                            dd._EchoesSuppress = nil
                            ApplyGroupSlotSelectedTextColor(dd, ALTBOT_INDEX)
                        end,
                    })
                end)

                if not ok then
                    Echoes_Print("Name popup error: " .. tostring(err))
                end
            end

            nameBtn._EchoesDefaultOnClick = OnNameButtonClick
            nameBtn:SetCallback("OnClick", OnNameButtonClick)
            rowGroup:AddChild(nameBtn)
            SkinButton(nameBtn)

            -- Hide by default until Altbot is selected.
            if nameBtn.frame then
                nameBtn.frame:Hide()
                nameBtn.frame:EnableMouse(false)
            end

            -- Ensure correct visibility if state was set before Name existed.
            UpdateNameButtonVisibility(dd._EchoesSelectedValue or dd.value)

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
        if not self.UI or not self.UI.groupSlots then return end

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

        -- Invite session: track bot "Hello!" whispers and named bots we asked for.
        self._EchoesInviteSessionActive = true
        self._EchoesInviteHelloFrom = {}
        self._EchoesInviteExpectedByName = {}

        -- Decide whether this preset is bigger than a 5-man and needs raid conversion.
        local configuredCount = 0
        for g = 1, 5 do
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
        -- Party limit is player + 4; if we have more configured than that, we must convert once party is full.
        self._EchoesInviteNeedsRaid = (configuredCount > 4)

        -- Remember intended specs per slot (so Set Talents can be run after invites without relying on roster timing).
        self._EchoesPlannedTalentByPos = self._EchoesPlannedTalentByPos or {}

        local actions = {}
        local seenAddByName = {}
        for g = 1, 5 do
            self._EchoesPlannedTalentByPos[g] = {}
            for p = 1, 5 do
                local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                if slot and slot.classDrop then
                    -- Skip the player slot (we never invite ourselves).
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

                    -- Only invite empty (not currently occupied) slots.
                    if slot._EchoesMember then
                        -- Keep planned spec, but don't re-invite.
                    else

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

        if #actions == 0 then
            Echoes_Print("Nothing to invite.")
            return
        end

        Echoes_Print("Inviting...")
        -- Requirement: never run invite commands faster than every 0.7s.
        self:RunActionQueue(actions, 0.70, function()
            -- Give whispers/roster a moment to land, then invite any missing bots by name.
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

                -- 1) Bots that whispered "Hello!"
                for nm, _ in pairs(self._EchoesInviteHelloFrom or {}) do
                    QueueInvite(nm)
                end

                -- 2) Named altbots we explicitly requested
                for _, nm in pairs(self._EchoesInviteExpectedByName or {}) do
                    QueueInvite(nm)
                end

                if #missing > 0 then
                    Echoes_Print("Inviting missing bots...")
                    self:RunActionQueue(missing, 0.70)
                end

                self._EchoesInviteSessionActive = false
            end)
        end)
    end)
    actionCol:AddChild(inviteBtn)
    SkinButton(inviteBtn)

    local talentsBtn = AceGUI:Create("Button")
    talentsBtn:SetText("Set Talents")
    talentsBtn:SetFullWidth(true)
    talentsBtn:SetCallback("OnClick", function()
        local tpl = tostring(EchoesDB.talentCommandTemplate or "")
        tpl = tpl:gsub("^%s+", ""):gsub("%s+$", "")
        if tpl == "" then
            Echoes_Print("Set Talents: configure a Talent Command in the Echoes tab.")
            return
        end

        if not self.UI or not self.UI.groupSlots then return end

        local actions = {}
        for g = 1, 5 do
            for p = 1, 5 do
                local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                local member = slot and slot._EchoesMember or nil
                if member and not member.isPlayer and member.name and member.name ~= "" then
                    local byName = nil
                    if self._EchoesPlannedTalentByName then
                        local nk = Echoes_NormalizeName(member.name):lower()
                        byName = self._EchoesPlannedTalentByName[nk]
                    end

                    local planned = self._EchoesPlannedTalentByPos and self._EchoesPlannedTalentByPos[g] and self._EchoesPlannedTalentByPos[g][p]
                    local spec = (byName and byName.specLabel) or (planned and planned.specLabel) or (slot.cycleBtn and slot.cycleBtn._EchoesSpecLabel) or ""
                    local classText = nil
                    if member.classFile then
                        for disp, classFile in pairs(DISPLAY_TO_CLASSFILE) do
                            if classFile == member.classFile then
                                classText = disp
                                break
                            end
                        end
                    end

                    local msg = tpl
                    msg = msg:gsub("{name}", tostring(member.name))
                    msg = msg:gsub("{class}", tostring(classText or ""))
                    msg = msg:gsub("{spec}", tostring(spec or ""))
                    msg = msg:gsub("{group}", tostring(g))
                    msg = msg:gsub("{slot}", tostring(p))

                    local ch = (EchoesDB.sendAsChat and EchoesDB.chatChannel) or "PARTY"
                    actions[#actions + 1] = { kind = "chat", msg = msg, channel = ch }
                end
            end
        end

        if #actions == 0 then
            Echoes_Print("Set Talents: no bot members found in the roster slots.")
            return
        end

        Echoes_Print("Sending talent commands...")
        self:RunActionQueue(actions, 0.35)
    end)
    actionCol:AddChild(talentsBtn)
    SkinButton(talentsBtn)

    -- Initialize from roster once the page is built.
    self:UpdateGroupCreationFromRoster(true)
    LoadPreset(EchoesDB.groupTemplateIndex or 1)
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
            if slot.nameBtn._EchoesDefaultOnClick then
                slot.nameBtn:SetCallback("OnClick", slot.nameBtn._EchoesDefaultOnClick)
            end
        end
    end

    local function ResetSlot(slot)
        if not slot then return end
        SetEnabledForWidget(slot.cycleBtn, true)
        SetEnabledForDropdown(slot.classDrop, true)
        SetEnabledForWidget(slot.nameBtn, true)
        -- Only show Name for Altbot selection (or if an Altbot name exists)
        local altIndex = self.UI and self.UI._AltbotIndex
        local cur = slot.classDrop and (slot.classDrop._EchoesSelectedValue or slot.classDrop.value)
        local showName = (altIndex and cur == altIndex) or (slot.classDrop and slot.classDrop._EchoesAltbotName and slot.classDrop._EchoesAltbotName ~= "")
        SetNameButtonVisible(slot, showName and true or false)

        slot._EchoesMember = nil
        SetNameButtonMode(slot, "name")

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
            slot.classDrop._EchoesSuppress = nil
            if applyColor then applyColor(slot.classDrop, 1) end
        end

        if slot.cycleBtn then
            slot.cycleBtn.values = { unpack(DEFAULT_CYCLE_VALUES) }
            slot.cycleBtn.index = 1
            slot.cycleBtn._EchoesLocked = false
            if slot.cycleBtn._EchoesCycleUpdate then slot.cycleBtn._EchoesCycleUpdate(slot.cycleBtn) end
        end
    end

    local function FillSlot(slot, member)
        if not slot or not member then return end

        slot._EchoesMember = member

        -- Occupied slots: show the member name in the dropdown display.
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

        -- AceGUI disabled state can override our text color; re-apply after disabling.
        if slot.classDrop and slot.classDrop.text and slot.classDrop.text.SetTextColor then
            if c then
                local r, g, b = ClassColorRGB(c)
                slot.classDrop.text:SetTextColor(r, g, b, 1)
            else
                slot.classDrop.text:SetTextColor(1, 1, 1, 1)
            end
        end

        -- Name button: Kick for filled non-player slots; hidden for player slot.
        SetEnabledForWidget(slot.nameBtn, true)
        SetNameButtonVisible(slot, not member.isPlayer)
        if not member.isPlayer then
            SetNameButtonMode(slot, "kick", member)
        else
            SetNameButtonMode(slot, "name")
        end

        if slot.cycleBtn then
            local byName = nil
            if member.name and self._EchoesPlannedTalentByName then
                local nk = Echoes_NormalizeName(member.name):lower()
                byName = self._EchoesPlannedTalentByName[nk]
            end

            local planned = self._EchoesPlannedTalentByPos and self._EchoesPlannedTalentByPos[member.subgroup or 0] and self._EchoesPlannedTalentByPos[member.subgroup or 0][member.pos or 0]
            local keepLabel = (byName and byName.specLabel and tostring(byName.specLabel) ~= "") and tostring(byName.specLabel)
                or ((planned and planned.specLabel and tostring(planned.specLabel) ~= "") and tostring(planned.specLabel))
                or slot.cycleBtn._EchoesSpecLabel
            local classIndex = Echoes_GetGroupSlotIndexForClassFile(member.classFile)
            local display = (classIndex and self.UI._GroupSlotSlotValues and self.UI._GroupSlotSlotValues[classIndex]) or nil
            local vals = GetCycleValuesForRightText(display)

            -- Do not auto-reset the chosen spec icon when a member fills a slot.
            -- If class changes, try to keep the same label; otherwise keep the same index.
            slot.cycleBtn._EchoesLastClassFile = slot.cycleBtn._EchoesLastClassFile or member.classFile
            slot.cycleBtn._EchoesLastClassFile = member.classFile

            slot.cycleBtn.values = { unpack(vals) }

            -- For the player slot, auto-select the icon matching the player's actual spec.
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

        -- Allow changing spec icons for bots, but not for the player's own slot.
        if slot.cycleBtn then
            slot.cycleBtn._EchoesLocked = member.isPlayer and true or false
        end
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
                    member.subgroup = group
                    member.pos = pos
                    FillSlot(slot, member)
                else
                    -- Preserve user-selected template values for empty slots, unless the slot
                    -- was previously filled or we are forcing an initial build.
                    if force or slot._EchoesMember then
                        ResetSlot(slot)
                    end
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

    local spacer = AceGUI:Create("Label")
    spacer:SetText(" ")
    spacer:SetFullWidth(true)
    spacer:SetHeight(10)
    container:AddChild(spacer)

    local chatHeading = AceGUI:Create("Heading")
    chatHeading:SetText("Command Sending")
    chatHeading:SetFullWidth(true)
    SkinHeading(chatHeading)
    container:AddChild(chatHeading)

    local sendAs = AceGUI:Create("CheckBox")
    sendAs:SetLabel("Send commands to a chat channel")
    sendAs:SetValue(EchoesDB.sendAsChat and true or false)
    sendAs:SetFullWidth(true)
    sendAs:SetCallback("OnValueChanged", function(widget, event, value)
        EchoesDB.sendAsChat = value and true or false
    end)
    container:AddChild(sendAs)

    local channelList = { "SAY", "PARTY", "RAID", "GUILD" }
    local channelValues = {}
    for i, v in ipairs(channelList) do channelValues[i] = v end

    local channelDrop = AceGUI:Create("Dropdown")
    channelDrop:SetLabel("Channel")
    channelDrop:SetList(channelValues)
    local cur = tostring(EchoesDB.chatChannel or "SAY")
    local curIdx = 1
    for i, v in ipairs(channelList) do
        if v == cur then curIdx = i break end
    end
    channelDrop:SetValue(curIdx)
    channelDrop:SetFullWidth(true)
    channelDrop:SetCallback("OnValueChanged", function(widget, event, value)
        local v = channelList[value] or "SAY"
        EchoesDB.chatChannel = v
    end)
    container:AddChild(channelDrop)
    SkinDropdown(channelDrop)

    local talentsHeading = AceGUI:Create("Heading")
    talentsHeading:SetText("Group Creation")
    talentsHeading:SetFullWidth(true)
    SkinHeading(talentsHeading)
    container:AddChild(talentsHeading)

    local tplDesc = AceGUI:Create("Label")
    tplDesc:SetText("Talent Command template used by 'Set Talents'. Tokens: {name} {class} {spec} {group} {slot}")
    tplDesc:SetFullWidth(true)
    SkinLabel(tplDesc)
    container:AddChild(tplDesc)

    local talentCmd = AceGUI:Create("EditBox")
    talentCmd:SetLabel("Talent Command")
    talentCmd:SetText(EchoesDB.talentCommandTemplate or "")
    talentCmd:SetFullWidth(true)
    talentCmd:SetCallback("OnEnterPressed", function(widget, event, text)
        EchoesDB.talentCommandTemplate = tostring(text or "")
    end)
    container:AddChild(talentCmd)
    SkinEditBox(talentCmd)
    if talentCmd.DisableButton then talentCmd:DisableButton(true) end
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

    -- Bot "Hello!" whisper detection for invite verification.
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnEchoesChatMsgWhisper")
end

function Echoes:OnEchoesChatMsgWhisper(event, msg, author)
    if not self._EchoesInviteSessionActive then return end

    msg = tostring(msg or "")
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
    if msg ~= "Hello!" then return end

    author = Echoes_NormalizeName(author)
    if author == "" then return end

    self._EchoesInviteHelloFrom = self._EchoesInviteHelloFrom or {}
    self._EchoesInviteHelloFrom[author] = true

    -- If the invite queue is waiting for a Hello handshake, bind this sender to the current step.
    if self._EchoesWaitHelloActive and (not self._EchoesWaitHelloName or self._EchoesWaitHelloName == "") then
        self._EchoesWaitHelloName = author

        -- Lock in the planned spec/class for this bot name so party->raid reordering doesn't lose it.
        if self._EchoesWaitHelloPlan and type(self._EchoesWaitHelloPlan) == "table" then
            self._EchoesPlannedTalentByName = self._EchoesPlannedTalentByName or {}
            local k = author:lower()
            self._EchoesPlannedTalentByName[k] = {
                classText = tostring(self._EchoesWaitHelloPlan.classText or ""),
                specLabel = tostring(self._EchoesWaitHelloPlan.specLabel or ""),
                group = tonumber(self._EchoesWaitHelloPlan.group) or nil,
                slot = tonumber(self._EchoesWaitHelloPlan.slot) or nil,
            }
        end
    end
end

function Echoes:OnEchoesRosterOrSpecChanged()
    self:UpdateGroupCreationFromRoster(false)
end

function Echoes:OnDisable()
end
