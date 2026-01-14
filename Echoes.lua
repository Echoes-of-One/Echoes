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

    -- Main window movement lock (false = movable)
    EchoesDB.frameLocked        = (EchoesDB.frameLocked ~= nil) and EchoesDB.frameLocked or false

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

end

-- Per-tab sizes (frame stays a fixed size, grows right/down)
local FRAME_SIZES = {
    BOT    = { w = 320, h = 480 },
    -- Wide enough for the 3-column grid + Name button, but not overly tall.
    GROUP  = { w = 740, h = 440 },
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

-- Keep Echoes font rendering consistent and isolated from other addons that
-- modify Blizzard's shared FontObjects (GameFontNormal, etc.).
local ECHOES_FONT_PATH = "Fonts\\FRIZQT__.TTF"
local ECHOES_FONT_FLAGS = "OUTLINE"

-- Private FontObjects (unique names) so we never depend on Blizzard shared FontObjects.
-- This prevents many skin packs from "hijacking" our fonts by swapping GameFontNormal, etc.
local ECHOES_FONT_OBJECTS = {}

local function Echoes_SanitizeFontFlags(flags)
    flags = tostring(flags or "")
    flags = flags:gsub("%s+", " ")
    flags = flags:gsub("^%s+", "")
    flags = flags:gsub("%s+$", "")
    if flags == "" then
        flags = ECHOES_FONT_FLAGS
    end
    return flags
end

local function Echoes_GetFontObject(size, flags)
    local s = tonumber(size) or 12
    local f = Echoes_SanitizeFontFlags(flags)
    local key = tostring(s) .. "|" .. f
    local fo = ECHOES_FONT_OBJECTS[key]
    if fo then return fo end

    if type(CreateFont) ~= "function" then
        return nil
    end

    -- Build a stable unique global name. (CreateFont registers globally by name.)
    local name = ("EchoesFont_%d_%s"):format(s, f:gsub("[^%w]", "_"))
    fo = CreateFont(name)
    if fo and fo.SetFont then
        fo:SetFont(ECHOES_FONT_PATH, s, f)
    end
    ECHOES_FONT_OBJECTS[key] = fo
    return fo
end

local function SetEchoesFont(fontString, size, flags)
    if not fontString then return end
    local s = tonumber(size) or 12
    local f = Echoes_SanitizeFontFlags(flags)

    -- Prefer FontObjects for isolation (most hijacks target shared FontObjects).
    if fontString.SetFontObject then
        local fo = Echoes_GetFontObject(s, f)
        if fo then
            fontString:SetFontObject(fo)
            return
        end
    end

    -- Fallback for objects that don't support SetFontObject.
    if fontString.SetFont then
        fontString:SetFont(ECHOES_FONT_PATH, s, f)
    end
end

-- Re-assert Echoes font via a private FontObject on a single FontString.
-- Preserves size/flags; only ensures it uses our face/object.
local function Echoes_ForceFontOnFontString(fs)
    if not fs or not fs.GetFont then return end
    local _, curSize, curFlags = fs:GetFont()
    SetEchoesFont(fs, tonumber(curSize) or 12, curFlags or ECHOES_FONT_FLAGS)
end

-- Global dropdown menu guard (scoped): only affects menus opened by Echoes-owned dropdowns.
-- This protects BOTH the selected-value text and the popup list item text from late skin passes.
local function Echoes_InstallDropdownFontGuards()
    if _G._EchoesDropdownFontGuardsInstalled then return end
    _G._EchoesDropdownFontGuardsInstalled = true

    -- Reapply the font face to popup menu buttons as they are added.
    if type(hooksecurefunc) == "function" and type(UIDropDownMenu_AddButton) == "function" then
        hooksecurefunc("UIDropDownMenu_AddButton", function(info, level)
            local openMenu = rawget(_G, "UIDROPDOWNMENU_OPEN_MENU")
            if not openMenu or not openMenu._EchoesOwned then return end

            local lvl = tonumber(level) or rawget(_G, "UIDROPDOWNMENU_MENU_LEVEL") or 1
            local listFrame = rawget(_G, "DropDownList" .. tostring(lvl))
            if not listFrame or not listFrame.numButtons then return end

            local idx = tonumber(listFrame.numButtons)
            if not idx or idx < 1 then return end

            local btn = rawget(_G, "DropDownList" .. tostring(lvl) .. "Button" .. tostring(idx))
            if not btn then return end

            local fs = (btn.GetFontString and btn:GetFontString()) or rawget(_G, btn:GetName() .. "NormalText")
            Echoes_ForceFontOnFontString(fs)
        end)
    end

    -- Also reassert when a dropdown list frame shows (covers cases where another addon
    -- changes fonts after button creation).
    for lvl = 1, 3 do
        local listFrame = rawget(_G, "DropDownList" .. tostring(lvl))
        if listFrame and listFrame.HookScript and not listFrame._EchoesFontGuardHooked then
            listFrame._EchoesFontGuardHooked = true
            listFrame:HookScript("OnShow", function(self)
                local openMenu = rawget(_G, "UIDROPDOWNMENU_OPEN_MENU")
                if not openMenu or not openMenu._EchoesOwned then return end
                local n = tonumber(self.numButtons) or 0
                for i = 1, n do
                    local btn = rawget(_G, self:GetName() .. "Button" .. tostring(i))
                    if btn then
                        local fs = (btn.GetFontString and btn:GetFontString()) or rawget(_G, btn:GetName() .. "NormalText")
                        Echoes_ForceFontOnFontString(fs)
                    end
                end
            end)
        end
    end
end

-- Re-assert Echoes font face on any FontStrings under a given frame.
-- This keeps Echoes text independent from other addons that modify Blizzard FontObjects.
-- We only swap the font *face* and preserve size/flags to avoid layout surprises.
local function Echoes_ForceFontFaceOnFrame(rootFrame)
    if not rootFrame or type(rootFrame) ~= "table" or not rootFrame.GetRegions then return end

    local visited = {}

    local function ApplyFontString(fs)
        if not fs or not fs.GetFont then return end
        -- Use private FontObjects; preserve size/flags.
        local _, curSize, curFlags = fs:GetFont()
        SetEchoesFont(fs, tonumber(curSize) or 12, curFlags or ECHOES_FONT_FLAGS)
    end

    local function Walk(frame)
        if not frame or visited[frame] then return end
        visited[frame] = true

        local okRegions, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 = pcall(frame.GetRegions, frame)
        if okRegions then
            local regs = { r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 }
            -- If there are more than 10 regions, fall back to table packing.
            if frame.GetNumRegions and frame:GetNumRegions() and frame:GetNumRegions() > 10 then
                regs = { frame:GetRegions() }
            end
            for _, r in ipairs(regs) do
                if r and r.IsObjectType and r:IsObjectType("FontString") then
                    ApplyFontString(r)
                end
            end
        end

        if frame.GetChildren then
            local kids = { frame:GetChildren() }
            for _, child in ipairs(kids) do
                Walk(child)
            end
        end
    end

    Walk(rootFrame)
end

local function StripFrameTextures(frame)
    if not frame then return end
    if frame.SetNormalTexture then frame:SetNormalTexture(nil) end
    if frame.SetPushedTexture then frame:SetPushedTexture(nil) end
    if frame.SetHighlightTexture then frame:SetHighlightTexture(nil) end
    if frame.SetDisabledTexture then frame:SetDisabledTexture(nil) end

    if frame.GetNormalTexture then
        local t = frame:GetNormalTexture()
        if t and t.SetTexture then t:SetTexture(nil) end
    end
    if frame.GetPushedTexture then
        local t = frame:GetPushedTexture()
        if t and t.SetTexture then t:SetTexture(nil) end
    end
    if frame.GetHighlightTexture then
        local t = frame:GetHighlightTexture()
        if t and t.SetTexture then t:SetTexture(nil) end
    end
    if frame.GetDisabledTexture then
        local t = frame:GetDisabledTexture()
        if t and t.SetTexture then t:SetTexture(nil) end
    end

    if frame.GetRegions then
        local regs = { frame:GetRegions() }
        for _, r in ipairs(regs) do
            if r and r._EchoesNoStrip then
                -- Preserve custom textures we add (e.g., spec cycle icons)
            elseif r and r.IsObjectType and r:IsObjectType("Texture") and r.SetTexture then
                r:SetTexture(nil)
            end
        end
    end
end

local function SkinBackdrop(frame, alpha)
    if not frame or not frame.SetBackdrop then return end
    frame:SetBackdrop(ECHOES_BACKDROP)
    frame:SetBackdropColor(0.06, 0.06, 0.06, alpha or 0.9)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
end

local function SkinMainFrame(widget)
    if not widget or not widget.frame then return end
    local f = widget.frame

    local function Echoes_UISpecialFrames_Add(frame)
        if not frame or type(frame.GetName) ~= "function" then return end
        if type(UISpecialFrames) ~= "table" then return end
        local name = frame:GetName()
        if not name or name == "" then return end
        for i = 1, #UISpecialFrames do
            if UISpecialFrames[i] == name then
                return
            end
        end
        table.insert(UISpecialFrames, name)
    end

    local function Echoes_UISpecialFrames_Remove(frame)
        if not frame or type(frame.GetName) ~= "function" then return end
        if type(UISpecialFrames) ~= "table" then return end
        local name = frame:GetName()
        if not name or name == "" then return end
        for i = #UISpecialFrames, 1, -1 do
            if UISpecialFrames[i] == name then
                table.remove(UISpecialFrames, i)
            end
        end
    end

    local function Echoes_SetLockButtonVisual(btn, locked)
        if not btn then return end

        -- These are Blizzard UI texture paths (3.3.5-compatible in most clients).
        -- If a client is missing them, the text fallback still shows state.
        local lockedTex = {
            normal    = "Interface\\Buttons\\UI-LockButton-LockedUp",
            pushed    = "Interface\\Buttons\\UI-LockButton-LockedDown",
            highlight = "Interface\\Buttons\\UI-LockButton-LockedHighlight",
        }
        local unlockedTex = {
            normal    = "Interface\\Buttons\\UI-LockButton-UnlockedUp",
            pushed    = "Interface\\Buttons\\UI-LockButton-UnlockedDown",
            highlight = "Interface\\Buttons\\UI-LockButton-UnlockedHighlight",
        }

        local t = locked and lockedTex or unlockedTex
        if btn.SetNormalTexture then btn:SetNormalTexture(t.normal) end
        if btn.SetPushedTexture then btn:SetPushedTexture(t.pushed) end
        if btn.SetHighlightTexture then
            btn:SetHighlightTexture(t.highlight)
            local ht = btn.GetHighlightTexture and btn:GetHighlightTexture()
            if ht and ht.SetBlendMode then ht:SetBlendMode("ADD") end
        end

        do
            local nt = btn.GetNormalTexture and btn:GetNormalTexture()
            if nt then nt._EchoesNoStrip = true end
            local pt = btn.GetPushedTexture and btn:GetPushedTexture()
            if pt then pt._EchoesNoStrip = true end
            local ht = btn.GetHighlightTexture and btn:GetHighlightTexture()
            if ht then ht._EchoesNoStrip = true end
        end

        if btn._EchoesTextFallback then
            btn._EchoesTextFallback:SetText(locked and "L" or "U")
        end
    end

    local function Echoes_IsFrameLocked()
        return EchoesDB and EchoesDB.frameLocked and true or false
    end

    -- Anchor once to TOPLEFT so size changes grow right/down
    if not f._EchoesAnchored then
        f._EchoesAnchored = true
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -200)
    end

    -- Keep Echoes underneath default Blizzard UI panels (bags, game menu).
    -- AceGUI frames often default to "DIALOG"; drop to a lower strata.
    if f.SetFrameStrata then
        f:SetFrameStrata("LOW")
    end
    if f.SetFrameLevel then
        f:SetFrameLevel(10)
    end

    -- Allow Escape to close/minimize Echoes when it's the topmost active panel.
    -- We manage this dynamically so we don't pollute UISpecialFrames when hidden.
    if not f._EchoesUISpecialManaged and f.HookScript then
        f._EchoesUISpecialManaged = true
        f:HookScript("OnShow", function(self)
            Echoes_UISpecialFrames_Add(self)
        end)
        f:HookScript("OnHide", function(self)
            Echoes_UISpecialFrames_Remove(self)
        end)
        if f.IsShown and f:IsShown() then
            Echoes_UISpecialFrames_Add(f)
        end
    end

    -- Movable, NO sizing
    f:SetMovable(true)
    f:EnableMouse(true)
    -- Allow the window to extend beyond the screen when resized (tab size changes).
    -- Clamping forces WoW to push the frame inward as it grows.
    f:SetClampedToScreen(false)
    f:SetResizable(true)
    local w, h = f:GetWidth(), f:GetHeight()
    f:SetMinResize(w, h)
    f:SetMaxResize(w, h)
    -- Restrict dragging to the title text area (see EchoesDragRegion below).
    f:SetScript("OnMouseDown", nil)
    f:SetScript("OnMouseUp", nil)

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

    -- Drag region: only this area moves the window ("Echoes" label zone).
    if f.EchoesTitleBar and not f.EchoesDragRegion then
        local dr = CreateFrame("Button", nil, f.EchoesTitleBar)
        dr:SetFrameLevel((f.EchoesTitleBar:GetFrameLevel() or 0) + 1)
        dr:SetPoint("LEFT", f.EchoesTitleBar, "LEFT", 6, 0)
        -- Leave space for the lock button on the right.
        dr:SetPoint("RIGHT", f.EchoesTitleBar, "RIGHT", -30, 0)
        dr:SetPoint("TOP", f.EchoesTitleBar, "TOP", 0, 0)
        dr:SetPoint("BOTTOM", f.EchoesTitleBar, "BOTTOM", 0, 0)
        dr:EnableMouse(true)
        dr:RegisterForDrag("LeftButton")

        dr:SetScript("OnDragStart", function()
            if Echoes_IsFrameLocked() then return end
            if f.StartMoving then f:StartMoving() end
        end)

        dr:SetScript("OnDragStop", function()
            if Echoes_IsFrameLocked() then return end
            if f.StopMovingOrSizing then f:StopMovingOrSizing() end

            -- Normalize anchor to TOPLEFT after moving so resizing (tab switches)
            -- doesn't shift the top bar.
            if f.GetLeft and f.GetTop and UIParent and f.SetPoint then
                local left = f:GetLeft()
                local top = f:GetTop()
                if left and top then
                    local scale = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
                    local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
                    if scale <= 0 then scale = 1 end
                    if parentScale <= 0 then parentScale = 1 end
                    local x = left * scale / parentScale
                    local y = top * scale / parentScale
                    f:ClearAllPoints()
                    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
                end
            end

            -- Prevent the window from being dropped fully off-screen.
            if Echoes and Echoes.NormalizeAndClampMainWindowToScreen then
                Echoes:NormalizeAndClampMainWindowToScreen()
            end
        end)

        f.EchoesDragRegion = dr
    end

    -- Title-bar Lock button (toggles frameLocked)
    if f.EchoesTitleBar and not f.EchoesLockButton then
        local lb = CreateFrame("Button", nil, f.EchoesTitleBar)
        lb:SetSize(18, 18)
        lb:SetPoint("RIGHT", f.EchoesTitleBar, "RIGHT", -6, 0)
        lb:SetFrameLevel((f.EchoesTitleBar:GetFrameLevel() or 0) + 10)
        if lb.RegisterForClicks then lb:RegisterForClicks("AnyUp") end

        -- Make it clickable even if another skin tries to strip textures.
        lb._EchoesNoStrip = true

        local fallback = lb:CreateFontString(nil, "OVERLAY")
        fallback:SetPoint("CENTER", lb, "CENTER", 0, 0)
        fallback:SetTextColor(0.95, 0.95, 0.95, 0.9)
        SetEchoesFont(fallback, 11, ECHOES_FONT_FLAGS)
        lb._EchoesTextFallback = fallback

        lb:SetScript("OnEnter", function(self)
            if GameTooltip and GameTooltip.SetOwner then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(Echoes_IsFrameLocked() and "Unlock window" or "Lock window")
                GameTooltip:Show()
            end
        end)
        lb:SetScript("OnLeave", function()
            if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
        end)
        lb:SetScript("OnClick", function()
            EchoesDB.frameLocked = not Echoes_IsFrameLocked()
            Echoes_SetLockButtonVisual(lb, Echoes_IsFrameLocked())
            if GameTooltip and GameTooltip.SetText then
                GameTooltip:SetText(Echoes_IsFrameLocked() and "Unlock window" or "Lock window")
            end
        end)

        f.EchoesLockButton = lb
        Echoes_SetLockButtonVisual(lb, Echoes_IsFrameLocked())
    elseif f.EchoesLockButton then
        Echoes_SetLockButtonVisual(f.EchoesLockButton, Echoes_IsFrameLocked())
    end

    if widget.titletext then
        widget.titletext:ClearAllPoints()
        widget.titletext:SetPoint("CENTER", f.EchoesTitleBar, "CENTER", 0, 0)
        widget.titletext:SetTextColor(0.95, 0.95, 0.95, 1)
        SetEchoesFont(widget.titletext, 15, ECHOES_FONT_FLAGS)
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
        cb:SetFrameStrata(f:GetFrameStrata() or "MEDIUM")
        cb:SetFrameLevel((f:GetFrameLevel() or 0) + 500)
        if cb.SetToplevel then cb:SetToplevel(true) end
        if cb.RegisterForClicks then cb:RegisterForClicks("AnyUp") end
        SkinBackdrop(cb, 0.9)

        local fs = cb:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER")
        fs:SetTextColor(0.9, 0.8, 0.5, 1)
        SetEchoesFont(fs, 12, ECHOES_FONT_FLAGS)
        fs:SetText("Close")
        cb._EchoesLabel = fs

        cb:HookScript("OnEnter", function(self)
            self:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
        end)
        cb:HookScript("OnLeave", function(self)
            self:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
        end)
        cb:SetScript("OnClick", function() f:Hide() end)

        f.EchoesCloseButton = cb
    end

    -- Custom bottom-right Spec button (toggles spec picker for current target)
    if not f.EchoesSpecButton then
        local sb = CreateFrame("Button", nil, f)
        sb._EchoesIsCustomSpec = true
        sb:SetSize(160, 22)
        sb:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
        sb:SetFrameStrata(f:GetFrameStrata() or "MEDIUM")
        sb:SetFrameLevel((f:GetFrameLevel() or 0) + 500)
        if sb.SetToplevel then sb:SetToplevel(true) end
        if sb.RegisterForClicks then sb:RegisterForClicks("AnyUp") end
        SkinBackdrop(sb, 0.9)

        local fs = sb:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER")
        fs:SetJustifyH("CENTER")
        fs:SetTextColor(0.9, 0.8, 0.5, 1)
        SetEchoesFont(fs, 12, ECHOES_FONT_FLAGS)
        fs:SetText("Toggle Spec Panel")
        sb._EchoesLabel = fs

        sb:HookScript("OnEnter", function(self)
            self:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
        end)
        sb:HookScript("OnLeave", function(self)
            self:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
        end)
        sb:SetScript("OnClick", function()
            if type(IsShiftKeyDown) == "function" and IsShiftKeyDown() then
                if rawget(_G, "DEFAULT_CHAT_FRAME") and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage("Echoes: Toggle Spec Panel clicked")
                end
            end

            local ok, err = pcall(function()
                Echoes:ToggleSpecWhisperFrame(f)
            end)
            if not ok and rawget(_G, "DEFAULT_CHAT_FRAME") and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("Echoes: Spec Panel error: " .. tostring(err))
            end
        end)

        f.EchoesSpecButton = sb
    end

    -- Re-assert button draw order in case AceGUI changes frame levels later.
    do
        local baseLevel = (f.GetFrameLevel and f:GetFrameLevel()) or 0
        local baseStrata = (f.GetFrameStrata and f:GetFrameStrata()) or "MEDIUM"
        if f.EchoesCloseButton then
            if f.EchoesCloseButton.GetParent and f.EchoesCloseButton:GetParent() ~= f and f.EchoesCloseButton.SetParent then
                f.EchoesCloseButton:SetParent(f)
                f.EchoesCloseButton:ClearAllPoints()
                f.EchoesCloseButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
            end
            if f.EchoesCloseButton.SetFrameStrata then f.EchoesCloseButton:SetFrameStrata(baseStrata) end
            if f.EchoesCloseButton.SetFrameLevel then f.EchoesCloseButton:SetFrameLevel(baseLevel + 500) end
            if f.EchoesCloseButton.SetToplevel then f.EchoesCloseButton:SetToplevel(true) end
            if f.EchoesCloseButton.EnableMouse then f.EchoesCloseButton:EnableMouse(true) end
        end
        if f.EchoesSpecButton then
            if f.EchoesSpecButton.GetParent and f.EchoesSpecButton:GetParent() ~= f and f.EchoesSpecButton.SetParent then
                f.EchoesSpecButton:SetParent(f)
                f.EchoesSpecButton:ClearAllPoints()
                f.EchoesSpecButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
            end
            if f.EchoesSpecButton.SetFrameStrata then f.EchoesSpecButton:SetFrameStrata(baseStrata) end
            if f.EchoesSpecButton.SetFrameLevel then f.EchoesSpecButton:SetFrameLevel(baseLevel + 500) end
            if f.EchoesSpecButton.SetToplevel then f.EchoesSpecButton:SetToplevel(true) end
            if f.EchoesSpecButton.EnableMouse then f.EchoesSpecButton:EnableMouse(true) end
        end
    end

    ------------------------------------------------
    -- Kill any remaining bottom-left "status"/resize artifacts
    ------------------------------------------------
    if f.GetChildren then
        local children = { f:GetChildren() }
        for _, child in ipairs(children) do
            if child and child.IsObjectType and child:IsObjectType("Frame") and child ~= f.EchoesTitleBar and child ~= f.EchoesCloseButton and child ~= f.EchoesSpecButton then
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

    -- Re-assert our theme on show (Echoes-only frame) in case another addon
    -- applies a generic skin pass after creation.
    if not f._EchoesSkinOnShowHooked then
        f._EchoesSkinOnShowHooked = true
        f:HookScript("OnShow", function(self)
            SkinBackdrop(self, 0.95)
            if self.SetBackdropBorderColor then
                self:SetBackdropBorderColor(0, 0, 0, 0.85)
            end
            if self.content then
                SkinBackdrop(self.content, 0.6)
                if self.content.SetBackdropBorderColor then
                    self.content:SetBackdropBorderColor(0, 0, 0, 0)
                end
            end
            if self.EchoesTitleBar then
                SkinBackdrop(self.EchoesTitleBar, 0.98)
                if self.EchoesTitleBar.SetBackdropBorderColor then
                    self.EchoesTitleBar:SetBackdropBorderColor(0, 0, 0, 0)
                end
            end
            if self.EchoesCloseButton and self.EchoesCloseButton._EchoesLabel then
                SetEchoesFont(self.EchoesCloseButton._EchoesLabel, 12, ECHOES_FONT_FLAGS)
            end
            if self.EchoesSpecButton and self.EchoesSpecButton._EchoesLabel then
                SetEchoesFont(self.EchoesSpecButton._EchoesLabel, 12, ECHOES_FONT_FLAGS)
            end

            if self.EchoesLockButton then
                Echoes_SetLockButtonVisual(self.EchoesLockButton, Echoes_IsFrameLocked())
            end

            -- Re-assert Echoes font face on any FontStrings within this window.
            Echoes_ForceFontFaceOnFrame(self)
        end)
    end
end

------------------------------------------------------------
-- Target Spec Whisper frame (toggleable + movable)
------------------------------------------------------------

local ECHOES_TARGET_SPEC_OPTIONS = {
    WARRIOR = {
        { spec = "prot", icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance" },
        { spec = "arms", icon = "Interface\\Icons\\Ability_Warrior_SavageBlow" },
        { spec = "fury", icon = "Interface\\Icons\\Ability_Warrior_BattleShout" },
    },
    PALADIN = {
        { spec = "prot", icon = "Interface\\Icons\\Spell_Holy_DevotionAura" },
        { spec = "holy", icon = "Interface\\Icons\\Spell_Holy_HolyBolt" },
        { spec = "ret",  icon = "Interface\\Icons\\Spell_Holy_AuraOfLight" },
    },
    DEATHKNIGHT = {
        { spec = "blood",  icon = "Interface\\Icons\\Spell_Deathknight_BloodPresence" },
        { spec = "frost",  icon = "Interface\\Icons\\Spell_Deathknight_FrostPresence" },
        { spec = "unholy", icon = "Interface\\Icons\\Spell_Deathknight_UnholyPresence" },
    },
    HUNTER = {
        { spec = "bm", icon = "Interface\\Icons\\Ability_Hunter_BeastTaming" },
        { spec = "mm", icon = "Interface\\Icons\\Ability_Marksmanship" },
        { spec = "surv", icon = "Interface\\Icons\\Ability_Hunter_SwiftStrike" },
    },
    ROGUE = {
        { spec = "as",    icon = "Interface\\Icons\\Ability_Rogue_Eviscerate" },
        { spec = "combat", icon = "Interface\\Icons\\Ability_BackStab" },
        { spec = "subtlety",    icon = "Interface\\Icons\\Ability_Stealth" },
    },
    PRIEST = {
        { spec = "disc",   icon = "Interface\\Icons\\Spell_Holy_PowerWordShield" },
        { spec = "holy",   icon = "Interface\\Icons\\Spell_Holy_GuardianSpirit" },
        { spec = "shadow", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain" },
    },
    SHAMAN = {
        { spec = "ele",   icon = "Interface\\Icons\\Spell_Nature_Lightning" },
        { spec = "enh",   icon = "Interface\\Icons\\Spell_Nature_LightningShield" },
        { spec = "resto", icon = "Interface\\Icons\\Spell_Nature_HealingWaveGreater" },
    },
    MAGE = {
        { spec = "arcane", icon = "Interface\\Icons\\Spell_Nature_StarFall" },
        { spec = "fire",   icon = "Interface\\Icons\\Spell_Fire_FlameBolt" },
        { spec = "frost",  icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
        { spec = "frostfire", icon = "Interface\\Icons\\Ability_Mage_FrostFireBolt" },
    },
    WARLOCK = {
        { spec = "affli",    icon = "Interface\\Icons\\Spell_Shadow_DeathCoil" },
        { spec = "demo",   icon = "Interface\\Icons\\Spell_Shadow_Metamorphosis" },
        { spec = "destro", icon = "Interface\\Icons\\Spell_Shadow_RainOfFire" },
    },
    DRUID = {
        { spec = "bear",    icon = "Interface\\Icons\\Ability_Racial_BearForm" },
        { spec = "cat",     icon = "Interface\\Icons\\Ability_Druid_CatForm" },
        { spec = "balance", icon = "Interface\\Icons\\Spell_Nature_StarFall" },
        { spec = "resto",   icon = "Interface\\Icons\\Spell_Nature_HealingTouch" },
    },
}

function Echoes:EnsureSpecWhisperFrame(anchorFrame)
    self.UI = self.UI or {}
    if self.UI.specWhisperFrame and self.UI.specWhisperFrame._EchoesIsSpecFrame then
        return self.UI.specWhisperFrame
    end

    local f = CreateFrame("Frame", nil, UIParent)
    f._EchoesIsSpecFrame = true
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function(self)
        if self.StartMoving then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        if self.StopMovingOrSizing then self:StopMovingOrSizing() end
    end)

    SkinBackdrop(f, 0.92)

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", f, "TOP", 0, -6)
    title:SetTextColor(0.9, 0.8, 0.5, 1)
    SetEchoesFont(title, 12, ECHOES_FONT_FLAGS)
    title:SetText("Spec Panel")
    f._EchoesTitle = title

    local noTargetLabel = f:CreateFontString(nil, "OVERLAY")
    noTargetLabel:SetPoint("CENTER", f, "CENTER", 0, -2)
    noTargetLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    SetEchoesFont(noTargetLabel, 12, ECHOES_FONT_FLAGS)
    noTargetLabel:SetText("<no target>")
    f._EchoesNoTargetLabel = noTargetLabel

    local buttons = {}
    local BTN = 30
    local GAP = 6
    local AUTO_H = 18
    local AUTO_W = 120

    local autoBtn = CreateFrame("Button", nil, f)
    autoBtn:SetSize(AUTO_W, AUTO_H)
    SkinBackdrop(autoBtn, 0.85)
    autoBtn:Hide()
    local autoText = autoBtn:CreateFontString(nil, "OVERLAY")
    autoText:SetPoint("CENTER", autoBtn, "CENTER", 0, 0)
    autoText:SetTextColor(0.90, 0.85, 0.70, 1)
    SetEchoesFont(autoText, 10, ECHOES_FONT_FLAGS)
    autoText:SetText("Autogear")
    autoBtn._EchoesLabel = autoText
    autoBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
    end)
    autoBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.06, 0.06, 0.06, 0.85)
    end)
    autoBtn:SetScript("OnClick", function()
        if Echoes and Echoes.DoMaintenanceAutogear then
            Echoes:DoMaintenanceAutogear()
        end
    end)
    f._EchoesAutoGearButton = autoBtn

    local function MakeIconButton(i)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(BTN, BTN)
        SkinBackdrop(b, 0.85)

        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetPoint("CENTER")
        t:SetSize(BTN - 6, BTN - 6)
        t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        b._EchoesIcon = t

        b:SetScript("OnEnter", function(self)
            if rawget(_G, "GameTooltip") and self._EchoesSpecKey and self._EchoesSpecKey ~= "" then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Spec: " .. tostring(self._EchoesSpecKey), 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function()
            if rawget(_G, "GameTooltip") then GameTooltip:Hide() end
        end)

        b:SetScript("OnClick", function(self)
            local spec = self._EchoesSpecKey
            if not spec or spec == "" then return end
            if type(UnitName) ~= "function" then return end
            local targetName = UnitName("target")
            if not targetName or targetName == "" then
                if rawget(_G, "DEFAULT_CHAT_FRAME") and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage("Echoes: Spec: no target selected.")
                end
                return
            end
            if type(SendChatMessage) ~= "function" then return end
            local msg = "talents spec " .. tostring(spec) .. " pve"
            SendChatMessage(msg, "WHISPER", nil, targetName)
        end)

        buttons[i] = b
        return b
    end

    for i = 1, 4 do
        MakeIconButton(i):Hide()
    end

    local function PositionButtons(count)
        count = tonumber(count) or 0
        if count < 1 then
            f:SetSize(160, 52)
            for i = 1, 4 do
                buttons[i]:Hide()
            end
            if f._EchoesAutoGearButton then
                f._EchoesAutoGearButton:Hide()
            end
            return
        end

        local iconRowWidth = (count * BTN) + ((count - 1) * GAP)
        local width = 12 + iconRowWidth + 12
        -- Ensure the panel is wide enough to fit the Autogear button.
        width = math.max(width, 160)
        -- Slightly tighter vertical padding (keep everything inside the frame).
        local height = 10 + 18 + 6 + BTN + 6 + AUTO_H + 8
        f:SetSize(width, height)

        local startX = (width - iconRowWidth) / 2
        for i = 1, 4 do
            local b = buttons[i]
            b:ClearAllPoints()
            if i <= count then
                b:SetPoint("TOPLEFT", f, "TOPLEFT", startX + ((i - 1) * (BTN + GAP)), -26)
                b:Show()
            else
                b:Hide()
            end
        end

        if f._EchoesAutoGearButton then
            local bw = math.min(AUTO_W, width - 24)
            f._EchoesAutoGearButton:SetWidth(bw)
            f._EchoesAutoGearButton:ClearAllPoints()
            f._EchoesAutoGearButton:SetPoint("TOPLEFT", f, "TOPLEFT", (width - bw) / 2, -26 - BTN - 6)
            f._EchoesAutoGearButton:Show()
        end
    end

    function f:_EchoesUpdateForTarget()
        local unit = "target"
        local targetName = (type(UnitName) == "function") and UnitName(unit) or nil
        local classFile
        if type(UnitClass) == "function" then
            local _, cf = UnitClass(unit)
            classFile = cf
        end

        if not targetName or targetName == "" or not classFile or classFile == "" then
            if f._EchoesNoTargetLabel then
                f._EchoesNoTargetLabel:SetText("<no target>")
                f._EchoesNoTargetLabel:Show()
            end
            PositionButtons(0)
            return
        end

        if f._EchoesNoTargetLabel then
            f._EchoesNoTargetLabel:Hide()
        end

        local opts = ECHOES_TARGET_SPEC_OPTIONS[classFile]
        if not opts then
            if f._EchoesNoTargetLabel then
                f._EchoesNoTargetLabel:SetText("<no specs>")
                f._EchoesNoTargetLabel:Show()
            end
            PositionButtons(0)
            return
        end

        local count = math.min(4, #opts)
        PositionButtons(count)

        for i = 1, count do
            local opt = opts[i]
            local b = buttons[i]
            b._EchoesSpecKey = opt.spec
            if b._EchoesIcon and b._EchoesIcon.SetTexture then
                b._EchoesIcon:SetTexture(opt.icon)
            end
        end
    end

    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    f:SetScript("OnEvent", function(self)
        self:_EchoesUpdateForTarget()
    end)
    f:SetScript("OnShow", function(self)
        SkinBackdrop(self, 0.92)
        Echoes_ForceFontFaceOnFrame(self)
        if self._EchoesTitle then
            SetEchoesFont(self._EchoesTitle, 12, ECHOES_FONT_FLAGS)
        end
        if self._EchoesNoTargetLabel then
            SetEchoesFont(self._EchoesNoTargetLabel, 12, ECHOES_FONT_FLAGS)
        end
        if self._EchoesAutoGearButton and self._EchoesAutoGearButton._EchoesLabel then
            SetEchoesFont(self._EchoesAutoGearButton._EchoesLabel, 10, ECHOES_FONT_FLAGS)
        end
        self:_EchoesUpdateForTarget()
    end)

    -- Initial position: outside TOPLEFT of the main frame.
    f:ClearAllPoints()
    if anchorFrame and anchorFrame.GetPoint then
        -- Place the panel just to the left of the main frame, aligned at the top.
        f:SetPoint("TOPRIGHT", anchorFrame, "TOPLEFT", -8, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    -- IMPORTANT: CreateFrame defaults to "shown". If we leave it shown here,
    -- the first toggle click after /reload will hide it, requiring a second click.
    -- Start hidden so the first click always opens it.
    f:Hide()

    self.UI.specWhisperFrame = f
    return f
end

function Echoes:ToggleSpecWhisperFrame(anchorFrame)
    local f = self:EnsureSpecWhisperFrame(anchorFrame)
    if not f then return end
    if f.IsShown and f:IsShown() then
        f:Hide()
    else
        -- Re-anchor outside TOPLEFT of the main frame each time so it doesn't "disappear".
        if anchorFrame and anchorFrame.GetPoint then
            f:ClearAllPoints()
            f:SetPoint("TOPRIGHT", anchorFrame, "TOPLEFT", -8, 0)
        end
        f:Show()
        if f._EchoesUpdateForTarget then
            f:_EchoesUpdateForTarget()
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

    -- IMPORTANT: In AceGUI-3.0 (WotLK 3.3.5), InlineGroup draws its visible box on a
    -- private "border" frame that is the parent of widget.content. Skinning widget.frame
    -- alone will not remove the boxes.
    local borderFrame = (widget.content and widget.content.GetParent and widget.content:GetParent()) or widget.frame

    if opts.border == false then
        -- Borderless panel: keep subtle background, remove edge texture.
        if borderFrame and borderFrame.SetBackdrop then
            borderFrame:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = nil,
                tile = false,
                tileSize = 0,
                edgeSize = 0,
                insets = { left = 0, right = 0, top = 0, bottom = 0 },
            })
            borderFrame:SetBackdropColor(0.06, 0.06, 0.06, alpha)
            if borderFrame.SetBackdropBorderColor then
                borderFrame:SetBackdropBorderColor(0, 0, 0, 0)
            end
        end
    else
        -- Bordered panel: apply our standard ElvUI-ish backdrop.
        if borderFrame then
            SkinBackdrop(borderFrame, alpha)
            if borderFrame.SetBackdropBorderColor then
                borderFrame:SetBackdropBorderColor(0, 0, 0, 0.85)
            end
        end
    end
end

local function SkinButton(widget)
    if not widget or not widget.frame then return end
    local f = widget.frame
    local fontSize = (tonumber(widget._EchoesFontSize) or tonumber(f._EchoesFontSize) or 10)

    -- AceGUI often uses Blizzard templates with multiple texture regions; strip all of them.
    StripFrameTextures(f)

    -- Re-assert stripping if another addon or the template scripts re-apply textures
    -- when the button is shown/enabled/disabled.
    if not f._EchoesSkinHooks then
        f._EchoesSkinHooks = true
        f:HookScript("OnShow", function(self)
            StripFrameTextures(self)
            SkinBackdrop(self, self._EchoesSkinAlpha or 0.7)
            local fs = self.GetFontString and self:GetFontString()
            if fs then
                fs:SetTextColor(0.90, 0.85, 0.70, 1)
                SetEchoesFont(fs, tonumber(self._EchoesFontSize) or 10, ECHOES_FONT_FLAGS)
            end
        end)
        f:HookScript("OnMouseDown", function(self)
            StripFrameTextures(self)
            SkinBackdrop(self, self._EchoesSkinAlpha or 0.7)
            self:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
        end)
        f:HookScript("OnMouseUp", function(self)
            StripFrameTextures(self)
            SkinBackdrop(self, self._EchoesSkinAlpha or 0.7)
        end)
        f:HookScript("OnClick", function(self)
            StripFrameTextures(self)
            SkinBackdrop(self, self._EchoesSkinAlpha or 0.7)
        end)
        f:HookScript("OnEnable", function(self)
            StripFrameTextures(self)
            SkinBackdrop(self, self._EchoesSkinAlpha or 0.7)
        end)
        f:HookScript("OnDisable", function(self)
            StripFrameTextures(self)
            SkinBackdrop(self, self._EchoesSkinAlpha or 0.7)
        end)
    end
    f._EchoesSkinAlpha = 0.7
    f._EchoesFontSize = fontSize

    SkinBackdrop(f, 0.7)

    f:HookScript("OnEnter", function(self)
        self:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
    end)
    f:HookScript("OnLeave", function(self)
        self:SetBackdropColor(0.06, 0.06, 0.06, 0.7)
    end)

    if widget.text and widget.text.SetTextColor then
        widget.text:SetTextColor(0.90, 0.85, 0.70, 1) -- gold-ish
        SetEchoesFont(widget.text, fontSize, ECHOES_FONT_FLAGS)
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

                local fs = btn:CreateFontString(nil, "OVERLAY")
                fs:SetPoint("CENTER")
                fs:SetTextColor(0.9, 0.8, 0.5, 1)
                SetEchoesFont(fs, 12, ECHOES_FONT_FLAGS)
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

    -- Ensure global (scoped) dropdown menu font guards are installed.
    Echoes_InstallDropdownFontGuards()

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
    -- widget.dropdown, which AceGUI offsets (-15/+17) to account for Blizzard art- We remove that art, anchor the dropdown to the frame, and skin the dropdown
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

            StripFrameTextures(b)

            b:ClearAllPoints()
            b:SetPoint("RIGHT", box, "RIGHT", -3, 0)
            b:SetSize(18, 18)

            SkinBackdrop(b, 0.95)
            b:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
            b:SetBackdropBorderColor(0, 0, 0, 1)

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

    local function ReapplyEchoesDropdownFont()
        if widget.text and widget.text.SetTextColor then
            widget.text:SetTextColor(0.90, 0.85, 0.70, 1) -- match buttons
        end
        if widget.text then
            SetEchoesFont(widget.text, 10, ECHOES_FONT_FLAGS)
        end
        ApplyEchoesGroupSlotSelectedColor()
    end

    -- Reassert after value changes (selection from popup). This is the main point
    -- where other skins can swap FontObjects after we set them.
    if not widget._EchoesSetValueHooked and type(widget.SetValue) == "function" then
        widget._EchoesSetValueHooked = true
        if type(hooksecurefunc) == "function" then
            hooksecurefunc(widget, "SetValue", function()
                ReapplyEchoesDropdownFont()
            end)
        else
            local orig = widget.SetValue
            widget.SetValue = function(self, ...)
                local r = orig(self, ...)
                ReapplyEchoesDropdownFont()
                return r
            end
        end
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
        ReapplyEchoesDropdownFont()
    end

    -- Some UI packs re-apply shared FontObjects after we skin the dropdown, which
    -- can "hijack" the visible selected-value font. Reassert on show and on click.
    if box and box.HookScript and not box._EchoesFontReassertHooked then
        box._EchoesFontReassertHooked = true
        box:HookScript("OnShow", function()
            ReapplyEchoesDropdownFont()
        end)
        box:HookScript("OnMouseDown", function()
            ReapplyEchoesDropdownFont()
        end)
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

    if widget.editbox.SetFont then
        widget.editbox:SetFont(ECHOES_FONT_PATH, 11, "")
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
    if widget and widget.label then
        SetEchoesFont(widget.label, 12, ECHOES_FONT_FLAGS)
    end
end

local function SkinLabel(widget)
    if widget and widget.label and widget.label.SetTextColor then
        widget.label:SetTextColor(0.85, 0.85, 0.85, 1)
    end
    if widget and widget.label then
        SetEchoesFont(widget.label, 11, ECHOES_FONT_FLAGS)
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

-- Normalize the main window anchor to TOPLEFT and keep it on-screen.
-- WoW frames don't clip children and can be dragged off-screen; scaling can also
-- push the window out of view. This helper prevents the addon from becoming
-- unreachable without requiring /echoes reset.
function Echoes:NormalizeAndClampMainWindowToScreen()
    local widget = self.UI and self.UI.frame
    local f = widget and widget.frame
    if not f or not UIParent then return end

    -- Clamp to screen bounds (in UIParent coordinate space) WITHOUT constantly re-anchoring.
    -- This prevents annoying "repositioning" during tab resizes, but still guarantees the
    -- window can always be recovered if it ends up off-screen.
    if not (f.GetLeft and f.GetTop and f.GetWidth and f.GetHeight and f.SetPoint and f.ClearAllPoints) then
        return
    end

    local parentW = (UIParent.GetWidth and UIParent:GetWidth()) or (GetScreenWidth and GetScreenWidth())
    local parentH = (UIParent.GetHeight and UIParent:GetHeight()) or (GetScreenHeight and GetScreenHeight())
    if not parentW or not parentH then return end

    local left = f:GetLeft()
    local top = f:GetTop()
    if not left or not top then return end

    local scale = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
    local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if scale <= 0 then scale = 1 end
    if parentScale <= 0 then parentScale = 1 end

    -- Convert current position into UIParent coordinate space.
    local x = left * scale / parentScale
    local y = top * scale / parentScale

    -- Convert current size into UIParent coordinate space.
    local w = (f:GetWidth() or 0) * (scale / parentScale)
    local h = (f:GetHeight() or 0) * (scale / parentScale)

    -- Keep a margin so the title bar (TOPLEFT) remains reachable.
    local margin = 24

    if w <= 0 or h <= 0 then
        -- Fall back to a sane default.
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        return
    end

    local right = x + w
    local bottom = y - h

    -- Only move the window if it's actually off-screen (or nearly so).
    local offscreen = false
    if x < margin or y > (parentH - margin) or right < margin or bottom > (parentH - margin) then
        offscreen = true
    end
    if x > (parentW - margin) or y < margin or right > (parentW + w - margin) or bottom < (-h + margin) then
        offscreen = true
    end

    if not offscreen then
        return
    end

    -- Clamp the TOPLEFT corner into the visible screen bounds. This guarantees recovery
    -- even if the window is larger than the screen.
    x = Clamp(x, margin, parentW - margin)
    y = Clamp(y, margin, parentH - margin)

    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
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
    REMOVE_ALL  = "leave",

    TANK_ATTACK = "@tank attack",
    ATTACK      = "@attack",
    DPS_ATTACK  = ".bot dps attack",

    SUMMON      = "summon",
    TANK_SUMMON   = "@tank summon",
    MELEE_SUMMON  = "@melee summon",
    RANGED_SUMMON = "@ranged summon",
    HEAL_SUMMON   = "@heal summon",
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
            -- we see a Hello sender (or we time out). We do NOT /invite immediately here;
            -- the server-side .playerbots command typically issues the invite itself.
            -- Any stragglers are handled by the end-of-invite missing check.
            if Echoes._EchoesWaitHelloActive then
                local now = (type(GetTime) == "function" and GetTime()) or 0
                local deadline = Echoes._EchoesWaitHelloDeadline or 0
                local name = Echoes._EchoesWaitHelloName

                if name and name ~= "" then
                    Echoes._EchoesWaitHelloActive = false
                    Echoes._EchoesWaitHelloName = nil
                    Echoes._EchoesWaitHelloInvited = false
                    Echoes._EchoesWaitHelloPlan = nil
                    Echoes._EchoesWaitHelloPostInviteTimeout = nil
                    Echoes._EchoesWaitHelloDeadline = nil
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
    -- GROUP tends to need more vertical room; allow a slightly smaller margin.
    local marginX, marginY = 120, 160
    if key == "GROUP" then
        marginY = 80
    end
    local maxW = (screenW - marginX) / scale
    local maxH = (screenH - marginY) / scale

    local w = s.w
    local h = s.h
    if maxW and maxW > 0 then w = math.min(w, maxW) end
    if maxH and maxH > 0 then h = math.min(h, maxH) end

    frame:SetWidth(math.floor(w + 0.5))
    frame:SetHeight(math.floor(h + 0.5))

    -- If the new size would push the window off-screen, gently clamp it back.
    self:NormalizeAndClampMainWindowToScreen()
end

function Echoes:ApplyScale()
    local widget = self.UI.frame
    if widget and widget.frame and widget.frame.SetScale then
        widget.frame:SetScale(EchoesDB.uiScale or 1.0)
    end

    -- Re-apply sizing after scale changes so the current tab still fits.
    self:ApplyFrameSizeForTab(EchoesDB.lastPanel or "BOT")

    -- Scaling can move the window off-screen; keep it reachable.
    self:NormalizeAndClampMainWindowToScreen()
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
    frame:SetTitle("Echoes v0.11")
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
        self:NormalizeAndClampMainWindowToScreen()
    end
end

local function Echoes_Trim(s)
    s = tostring(s or "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Echoes:ResetMainWindowPosition()
    self:CreateMainWindow()

    local widget = self.UI.frame
    local f = widget and widget.frame
    if not f or not f.SetPoint then return end

    widget:Show()

    -- Apply current scale + tab size first so we can accurately center.
    self:ApplyScale()
    self:ApplyFrameSizeForTab(EchoesDB.lastPanel or "BOT")

    -- Center the window, then clamp as a safety net.
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self:NormalizeAndClampMainWindowToScreen()
    Echoes_Print("Window reset to center.")
end

function Echoes:ChatCommand(input)
    input = Echoes_Trim(input)
    local cmd = input:match("^(%S+)")
    cmd = cmd and cmd:lower() or ""

    if cmd == "scale" then
        local arg = input:match("^%S+%s+(.+)$")
        local v = tonumber(arg)
        if not v then
            Echoes_Print("Usage: /echoes scale <0.5-2.0>")
            return
        end
        v = Clamp(v, 0.5, 2.0)
        EchoesDB.uiScale = v
        self:CreateMainWindow()
        self:ApplyScale()
        -- If the slider exists (Echoes tab has been opened), keep it in sync.
        if self.UI and self.UI.scaleSlider and self.UI.scaleSlider.SetValue then
            self.UI.scaleSlider:SetValue(v)
        end
        Echoes_Print("UI scale set to " .. string.format("%.2f", v))
        return
    end

    if cmd == "reset" then
        self:ResetMainWindowPosition()
        return
    end

    if cmd == "spec" then
        -- Toggle the Spec Panel. Anchor to the main window only when it's visible;
        -- otherwise center the panel so it can't appear off-screen.
        self:CreateMainWindow()
        local anchor
        local w = self.UI and self.UI.frame
        if w and w.frame and w.IsShown and w:IsShown() then
            anchor = w.frame
        end
        self:ToggleSpecWhisperFrame(anchor)
        return
    end

    -- Default behavior: toggle window
    self:ToggleMainWindow()
end

-- Expose commonly-used helpers for tab modules (loaded via .toc after this file).
-- This allows splitting the addon into multiple files without relying on cross-file locals.
Echoes.t_unpack = t_unpack
Echoes.Clamp = Clamp
Echoes.Print = Echoes_Print
Echoes.SetEchoesFont = SetEchoesFont
Echoes.ECHOES_FONT_FLAGS = ECHOES_FONT_FLAGS
Echoes.SkinMainFrame = SkinMainFrame
Echoes.SkinSimpleGroup = SkinSimpleGroup
Echoes.SkinButton = SkinButton
Echoes.SkinDropdown = SkinDropdown
Echoes.SkinEditBox = SkinEditBox
Echoes.SkinHeading = SkinHeading
Echoes.SkinLabel = SkinLabel
Echoes.SkinTabButton = SkinTabButton
Echoes.SendCmdKey = SendCmdKey
Echoes.GetSelectedClass = GetSelectedClass
Echoes.IsNameInGroup = Echoes_IsNameInGroup
Echoes.CLASSES = CLASSES
Echoes.GROUP_TEMPLATES = GROUP_TEMPLATES
Echoes.GetCycleValuesForRightText = GetCycleValuesForRightText

-- Bot Control tab is implemented in Modules\BotTab.lua

------------------------------------------------------------
-- Group Creation tab (unchanged layout)
------------------------------------------------------------
function Echoes:BuildGroupTab(container)
    -- Flat pane (no scrolling). The GROUP frame size is designed to fit the full grid.
    container:SetLayout("List")

    -- Row height for slot rows. Keep everything on one line (icon + dropdown + optional Name button).
    -- Slightly taller for readability, but not so tall that the 5x2 grid wastes space.
    local INPUT_HEIGHT = 22
    local ROW_H = INPUT_HEIGHT
    -- Compact, consistent height for the group slot grid. Without explicit heights,
    -- AceGUI containers default to a fairly tall value which looks like a huge empty panel.
    local SLOT_GROUP_H = (5 * ROW_H) + 26

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
    -- Keep the top tight so the Group Slots grid sits higher.
    headerPadTop:SetHeight(0)
    container:AddChild(headerPadTop)

    local topGroup = AceGUI:Create("SimpleGroup")
    topGroup:SetFullWidth(true)
    -- Anchor header widgets manually so the EditBox and Dropdown line up perfectly.
    topGroup:SetLayout("None")
    if topGroup.SetAutoAdjustHeight then topGroup:SetAutoAdjustHeight(false) end
    topGroup:SetHeight(INPUT_HEIGHT)
    SkinSimpleGroup(topGroup)
    container:AddChild(topGroup)

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

    local function NormalizeAltbotName(name)
        name = tostring(name or "")
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then return nil end
        return string.upper(name:sub(1, 1)) .. name:sub(2)
    end

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
            slot.cycleBtn.values = { t_unpack(DEFAULT_CYCLE_VALUES) }
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
                            slot.classDrop._EchoesAltbotName = NormalizeAltbotName(entry.altName)
                        else
                            slot.classDrop._EchoesAltbotName = nil
                        end
                        if slot.classDrop.dropdown then
                            slot.classDrop.dropdown._EchoesFilledClassFile = nil
                        end
                        slot.classDrop._EchoesSuppress = nil

                        if slot.cycleBtn then
                            local vals = GetCycleValuesForRightText(classText)
                            slot.cycleBtn.values = { t_unpack(vals) }
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
                            altName = NormalizeAltbotName(altName)

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

    if templateDrop.frame and topGroup.frame and nameEdit.frame then
        templateDrop.frame:ClearAllPoints()
        templateDrop.frame:SetPoint("TOP", topGroup.frame, "TOP", 0, 0)
        templateDrop.frame:SetPoint("BOTTOM", topGroup.frame, "BOTTOM", 0, 0)
        templateDrop.frame:SetPoint("LEFT", nameEdit.frame, "RIGHT", 10, 0)
        if templateDrop.frame.SetWidth then templateDrop.frame:SetWidth(240) end
    end

    RefreshTemplateHeader(EchoesDB.groupTemplateIndex or 1)

    saveBtn = AceGUI:Create("Button")
    saveBtn:SetText("Save")
    saveBtn:SetHeight(INPUT_HEIGHT)
    saveBtn:SetCallback("OnClick", function()
        local idx = tonumber(EchoesDB.groupTemplateIndex) or 1
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

    if saveBtn.frame and topGroup.frame and templateDrop.frame then
        saveBtn.frame:ClearAllPoints()
        saveBtn.frame:SetPoint("TOP", topGroup.frame, "TOP", 0, 0)
        saveBtn.frame:SetPoint("BOTTOM", topGroup.frame, "BOTTOM", 0, 0)
        saveBtn.frame:SetPoint("LEFT", templateDrop.frame, "RIGHT", 10, 0)
        if saveBtn.frame.SetWidth then saveBtn.frame:SetWidth(88) end
    end

    deleteBtn = AceGUI:Create("Button")
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
    end)
    topGroup:AddChild(deleteBtn)
    SkinButton(deleteBtn)

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

    local gridTitle = AceGUI:Create("Label")
    gridTitle:SetText("Group Slots")
    gridTitle:SetFullWidth(true)
    gridTitle:SetHeight(16)
    if gridTitle.label then
        if gridTitle.label.SetTextColor then
            gridTitle.label:SetTextColor(1.0, 0.82, 0.0, 1)
        end
        SetEchoesFont(gridTitle.label, 12, ECHOES_FONT_FLAGS)
    end
    gridPanel:AddChild(gridTitle)

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
        -- Leave plenty of headroom for Flow spacing so columns don't wrap.
        -- Slightly wider so the per-row widgets (especially Altbot Name) don't feel cramped.
        col:SetRelativeWidth(0.325)
        col:SetHeight(SLOT_GROUP_H)
        SkinInlineGroup(col, { border = false, alpha = 0.28 })
        if colIndex <= 3 then
            gridRow1:AddChild(col)
        else
            gridRow2:AddChild(col)
        end

        self.UI.groupSlots[colIndex] = self.UI.groupSlots[colIndex] or {}

        for rowIndex = 1, cfg.rows do
            local rowGroup = AceGUI:Create("SimpleGroup")
            rowGroup:SetFullWidth(true)
            -- IMPORTANT: avoid AceGUI "Flow" here. Mixing a fixed-width icon button with
            -- relative-width dropdowns causes wrapping in some AceGUI/WotLK builds, which
            -- makes the icon appear on a different line (looks misaligned).
            -- We anchor children manually instead.
            rowGroup:SetLayout("None")
            if rowGroup.SetAutoAdjustHeight then rowGroup:SetAutoAdjustHeight(false) end
            rowGroup:SetHeight(ROW_H)
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
            cycleBtn:SetWidth(ROW_H)
            cycleBtn:SetHeight(ROW_H)
            cycleBtn.values = { t_unpack(DEFAULT_CYCLE_VALUES) }
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

                -- Re-anchor dropdown to either the Name button (when visible) or the row right edge.
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
                    cycleBtn.values = { t_unpack(vals) }
                    cycleBtn.index  = 1
                    CycleUpdate(cycleBtn)
                end

                ApplyGroupSlotSelectedTextColor(widget, value)

                UpdateNameButtonVisibility(value)
            end)

            rowGroup:AddChild(dd)
            SkinDropdown(dd)

            -- Initial anchor (no Name button shown yet)
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
            nameBtn:SetWidth(80)
            nameBtn:SetHeight(ROW_H)
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
                            dd._EchoesAltbotName = NormalizeAltbotName(text)

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

            if nameBtn.frame and rowGroup.frame then
                nameBtn.frame:ClearAllPoints()
                nameBtn.frame:SetPoint("TOPRIGHT", rowGroup.frame, "TOPRIGHT", 0, 0)
                nameBtn.frame:SetPoint("BOTTOMRIGHT", rowGroup.frame, "BOTTOMRIGHT", 0, 0)
            end

            -- Hide by default until Altbot is selected.
            if nameBtn.frame then
                nameBtn.frame:Hide()
                nameBtn.frame:EnableMouse(false)
            end

            -- Ensure correct visibility if state was set before Name existed.
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
    -- Leave plenty of headroom for Flow spacing so this doesn't wrap into a new row.
    actionCol:SetRelativeWidth(0.325)
    actionCol:SetHeight(SLOT_GROUP_H)
    SkinInlineGroup(actionCol, { border = false, alpha = 0.28 })
    gridRow2:AddChild(actionCol)

    local inviteBtn = AceGUI:Create("Button")
    inviteBtn:SetText("Invite")
    inviteBtn:SetFullWidth(true)
    local function InviteClick()
        if not self.UI or not self.UI.groupSlots then return end

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

        -- Always compress raid subgroups before inviting so we minimize used groups.
        -- This avoids gaps (e.g., Group 3 occupied while Group 2 empty) causing over-invites.
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

        -- When inviting, we want Groups 1..5 to be filled in order.
        -- If the user configured Group 3/4/5 while a prior group is empty, shift those groups left.
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

        local function GroupIsEmptyConfig(g)
            for p = 1, 5 do
                local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                if SlotHasConfiguredClass(slot) then
                    return false
                end
            end
            return true
        end

        local function SetSlotConfig(slot, valueIndex, specLabel, altbotName)
            if not slot or not slot.classDrop then return end
            if slot._EchoesMember then return end
            if (slot.cycleBtn and slot.cycleBtn._EchoesLocked) then return end

            local dd = slot.classDrop
            valueIndex = tonumber(valueIndex) or 1

            if valueIndex ~= ALTBOT_INDEX then
                dd._EchoesAltbotName = nil
            else
                dd._EchoesAltbotName = NormalizeAltbotName(altbotName)
            end

            dd:SetValue(valueIndex)
            dd._EchoesSelectedValue = valueIndex
            if dd._EchoesUpdateNameButtonVisibility then
                dd._EchoesUpdateNameButtonVisibility(valueIndex)
            end
            if self.UI and self.UI._GroupSlotApplyColor then
                self.UI._GroupSlotApplyColor(dd, valueIndex)
            end

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
                return { valueIndex = 1, specLabel = "", altbotName = nil }
            end
            local dd = slot.classDrop
            local valueIndex = dd._EchoesSelectedValue or dd.value or 1
            local specLabel = (slot.cycleBtn and slot.cycleBtn._EchoesSpecLabel) or ""
            local altbotName = dd._EchoesAltbotName
            return { valueIndex = valueIndex, specLabel = specLabel, altbotName = altbotName }
        end

        local function SlotIsMovable(slot)
            if not slot or not slot.classDrop then return false end
            if slot._EchoesMember then return false end
            if (slot._EchoesMember and slot._EchoesMember.isPlayer) then return false end
            if (slot.cycleBtn and slot.cycleBtn._EchoesLocked) then return false end
            return true
        end

        local function CompactInvitePlanToFront()
            -- Pack configured slots into the earliest available movable slots (including Group 1),
            -- so gaps like Group 1 + Group 3 collapse into Group 1 + Group 2, and partial Group 1 fills first.
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

            -- Clear all movable configured slots first.
            for g = 1, 5 do
                for p = 1, 5 do
                    local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                    if SlotIsMovable(slot) and SlotHasConfiguredClass(slot) then
                        SetSlotConfig(slot, 1, "", nil)
                    end
                end
            end

            -- Refill into earliest movable slots.
            local i = 1
            for g = 1, 5 do
                for p = 1, 5 do
                    local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                    if SlotIsMovable(slot) then
                        local cfg = sources[i]
                        if not cfg then
                            return
                        end
                        SetSlotConfig(slot, cfg.valueIndex, cfg.specLabel, cfg.altbotName)
                        i = i + 1
                    end
                end
            end
        end

        CompactInvitePlanToFront()

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
            return
        end

        -- Invite session: track bot "Hello!" whispers and named bots we asked for.
        self._EchoesInviteSessionActive = true
        self._EchoesInviteHelloFrom = {}
        self._EchoesInviteExpectedByName = {}

        -- Decide whether this preset is bigger than a 5-man and needs raid conversion.
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
        -- Party limit is player + 4; if we have more configured than that, we must convert once party is full.
        self._EchoesInviteNeedsRaid = (configuredCount > 4)

        -- Remember intended specs per slot (so Set Talents can be run after invites without relying on roster timing).
        self._EchoesPlannedTalentByPos = self._EchoesPlannedTalentByPos or {}

        local actions = {}
        local seenAddByName = {}
        for g = 1, maxGroupToInvite do
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

        -- Clear any planned data beyond the contiguous invite range to avoid stale plans.
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

            -- We can only ConvertToRaid once we're actually in a party.
            local nParty = PartyMemberCount()
            if nParty <= 0 then
                -- Best-effort: remember we need a raid as soon as we have a party member.
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
                    -- If the remaining missing members would push us past 5, ensure we're a raid BEFORE inviting.
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
            end)
        end)
        end

        -- If this invite run would exceed party size, convert to raid up front (when possible).
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
    talentsBtn:SetText("Set Talents")
    talentsBtn:SetFullWidth(true)
    talentsBtn:SetCallback("OnClick", function()
        if not self.UI or not self.UI.groupSlots then return end

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
        for g = 1, 5 do
            for p = 1, 5 do
                local slot = self.UI.groupSlots[g] and self.UI.groupSlots[g][p]
                local member = slot and slot._EchoesMember or nil
                if member and not member.isPlayer and member.name and member.name ~= "" then
                    -- Snapshot the *current* icon selection into our plan tables.
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
                    local spec = SpecLabelToTalentSpec(specLabel)
                    if spec and spec ~= "" then
                        local msg = "talents spec " .. spec .. " pve"
                        actions[#actions + 1] = { kind = "chat", msg = msg, channel = "WHISPER", target = member.name }
                    end
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

    local maintBtn = AceGUI:Create("Button")
    maintBtn:SetText("Autogear")
    maintBtn:SetFullWidth(true)
    maintBtn:SetCallback("OnClick", function()
        self:DoMaintenanceAutogear()
    end)
    actionCol:AddChild(maintBtn)
    SkinButton(maintBtn)

    local raidResetBtn = AceGUI:Create("Button")
    raidResetBtn:SetText("Raid Reset")
    raidResetBtn:SetFullWidth(true)
    raidResetBtn:SetCallback("OnClick", function()
        local inRaid = (type(GetNumRaidMembers) == "function" and (GetNumRaidMembers() or 0) > 0)
        local inParty = (not inRaid) and (type(GetNumPartyMembers) == "function" and (GetNumPartyMembers() or 0) > 0)
        local ch = inRaid and "RAID" or (inParty and "PARTY" or nil)

        if not ch then
            Echoes_Print("Raid Reset: you are not in a party/raid.")
            return
        end
        if type(SendChatMessage) ~= "function" then return end
        SendChatMessage("resetraids", ch)
    end)
    actionCol:AddChild(raidResetBtn)
    SkinButton(raidResetBtn)

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
        SetEnabledForWidget(slot.cycleBtn, true)
        SetEnabledForDropdown(slot.classDrop, true)
        SetEnabledForWidget(slot.nameBtn, true)

        if slot.classDrop and slot.classDrop.button and slot.classDrop.button.EnableMouse then
            slot.classDrop.button:EnableMouse(true)
        end

        -- Only show Name for Altbot selection (or if an Altbot name exists)
        local altIndex = self.UI and self.UI._AltbotIndex
        local cur = slot.classDrop and (slot.classDrop._EchoesSelectedValue or slot.classDrop.value)
        local showName = (altIndex and cur == altIndex) or (slot.classDrop and slot.classDrop._EchoesAltbotName and slot.classDrop._EchoesAltbotName ~= "")
        SetNameButtonVisible(slot, showName and true or false)
        AnchorSlotDropdown(slot, showName and true or false)

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
            slot.cycleBtn.values = { t_unpack(DEFAULT_CYCLE_VALUES) }
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
        AnchorSlotDropdown(slot, not member.isPlayer)
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

            slot.cycleBtn.values = { t_unpack(vals) }

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

    -- After 0.5s, whisper "summon" to each party/raid member.
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

    -- After another 0.5s, send autogear.
    self:RunAfter(1.0, function()
        if type(SendChatMessage) ~= "function" then return end
        SendChatMessage("autogear", ch)
    end)
end

-- Backwards compat: keep the old name but drive from full roster now.
function Echoes:UpdateGroupCreationPlayerSlot(force)
    self:UpdateGroupCreationFromRoster(force)
end

-- Echoes tab is implemented in Modules\EchoesTab.lua

------------------------------------------------------------
-- Minimap button
------------------------------------------------------------
-- Minimap button is implemented in Modules\Minimap.lua

------------------------------------------------------------
-- AceAddon lifecycle
------------------------------------------------------------
function Echoes:OnInitialize()
    EnsureDefaults()
    self:RegisterChatCommand("echoes", "ChatCommand")
    self:RegisterChatCommand("ech",    "ChatCommand")
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
    msg = tostring(msg or "")
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
    if msg ~= "Hello!" then return end

    author = Echoes_NormalizeName(author)
    if author == "" then return end

    -- 1) Group Creation invite verification.
    if self._EchoesInviteSessionActive then
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

    -- 2) Bot Control "Add" verification.
    if self._EchoesBotAddSessionActive then
        self._EchoesBotAddHelloFrom = self._EchoesBotAddHelloFrom or {}
        self._EchoesBotAddHelloFrom[author] = true
    end
end

function Echoes:OnEchoesRosterOrSpecChanged()
    self:UpdateGroupCreationFromRoster(false)
end

function Echoes:OnDisable()
end
