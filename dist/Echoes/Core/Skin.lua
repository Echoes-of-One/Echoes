-- Core\Skin.lua
-- ElvUI-ish dark theme + font isolation helpers.

local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")
local AceGUI = LibStub("AceGUI-3.0")

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

local function Echoes_EnableSelectionHighlight(editbox)
    return
end

local function Echoes_ApplyDropdownItemColor(fs, info)
    if not (fs and fs.SetTextColor and fs.GetTextColor) then return end

    if info and info.colorCode and type(info.colorCode) == "string" then
        -- Respect explicit color codes; do not override.
        return
    end

    local _, _, _, a = fs:GetTextColor()
    if a and a > 0.2 then return end

    fs:SetTextColor(0.90, 0.85, 0.70, 1)
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
            Echoes_ApplyDropdownItemColor(fs, info)
        end)
    end

    -- Also reassert when a dropdown list frame shows.
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
                        Echoes_ApplyDropdownItemColor(fs, nil)
                    end
                end
            end)
        end
    end
end

-- Re-assert Echoes font face on any FontStrings under a given frame.
local function Echoes_ForceFontFaceOnFrame(rootFrame)
    if not rootFrame or type(rootFrame) ~= "table" or not rootFrame.GetRegions then return end

    local visited = {}

    local function ApplyFontString(fs)
        if not fs or not fs.GetFont then return end
        local _, curSize, curFlags = fs:GetFont()
        SetEchoesFont(fs, tonumber(curSize) or 12, curFlags or ECHOES_FONT_FLAGS)
    end

    local function Walk(frame)
        if not frame or visited[frame] then return end
        visited[frame] = true

        local okRegions, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 = pcall(frame.GetRegions, frame)
        if okRegions then
            local regs = { r1, r2, r3, r4, r5, r6, r7, r8, r9, r10 }
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
                -- Preserve custom textures we add.
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
        local EchoesDB = _G.EchoesDB
        return EchoesDB and EchoesDB.frameLocked and true or false
    end

    if not f._EchoesAnchored then
        f._EchoesAnchored = true
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -200)
    end


    if f.SetFrameStrata then
        f:SetFrameStrata("LOW")
    end
    if f.SetFrameLevel then
        f:SetFrameLevel(10)
    end

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

    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(false)
    f:SetResizable(true)
    local w, h = f:GetWidth(), f:GetHeight()
    f:SetMinResize(w, h)
    f:SetMaxResize(w, h)
    f:SetScript("OnMouseDown", nil)
    f:SetScript("OnMouseUp", nil)

    if widget.sizer_se then widget.sizer_se:Hide(); widget.sizer_se:EnableMouse(false) end
    if widget.sizer_s  then widget.sizer_s:Hide();  widget.sizer_s:EnableMouse(false)  end
    if widget.sizer_e  then widget.sizer_e:Hide();  widget.sizer_e:EnableMouse(false)  end

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

    -- Reserve space for our custom footer buttons.
    local FOOTER_BTN_H = 22
    local FOOTER_BOTTOM_PAD = 8
    local FOOTER_TOP_GAP = 8
    local CONTENT_INSET = 10
    -- Title bar is offset -2 and height 28 => bottom at -30.
    -- Use 30 so content starts flush under the title bar.
    local CONTENT_TOP_INSET = 30
    local CONTENT_BOTTOM_INSET = FOOTER_BTN_H + FOOTER_BOTTOM_PAD + FOOTER_TOP_GAP + 8

    do
        local contentFrame = widget.content or f.content
        if contentFrame and contentFrame.ClearAllPoints and contentFrame.SetPoint then
            contentFrame:ClearAllPoints()
            contentFrame:SetPoint("TOPLEFT", f, "TOPLEFT", CONTENT_INSET, -CONTENT_TOP_INSET)
            contentFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -CONTENT_INSET, CONTENT_BOTTOM_INSET)
        end
    end

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

    if f.EchoesTitleBar and not f.EchoesDragRegion then
        local dr = CreateFrame("Button", nil, f.EchoesTitleBar)
        dr:SetFrameLevel((f.EchoesTitleBar:GetFrameLevel() or 0) + 1)
        -- Leave space on the right for lock + close (X) buttons.
        dr:SetPoint("LEFT", f.EchoesTitleBar, "LEFT", 6, 0)
        dr:SetPoint("RIGHT", f.EchoesTitleBar, "RIGHT", -46, 0)
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
            if Echoes and Echoes.UpdatePositionEdits then
                Echoes:UpdatePositionEdits()
            end
        end)

        f.EchoesDragRegion = dr
    end

    if f.EchoesTitleBar and not f.EchoesLockButton then
        local lb = CreateFrame("Button", nil, f.EchoesTitleBar)
        lb:SetSize(18, 18)
        lb:SetPoint("RIGHT", f.EchoesTitleBar, "RIGHT", -28, 0)
        lb:SetFrameLevel((f.EchoesTitleBar:GetFrameLevel() or 0) + 10)
        if lb.RegisterForClicks then lb:RegisterForClicks("AnyUp") end

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
            local EchoesDB = _G.EchoesDB
            EchoesDB.frameLocked = not Echoes_IsFrameLocked()
            Echoes_SetLockButtonVisual(lb, Echoes_IsFrameLocked())
            if GameTooltip and GameTooltip.SetText then
                GameTooltip:SetText(Echoes_IsFrameLocked() and "Unlock window" or "Lock window")
            end
        end)

        f.EchoesLockButton = lb
        Echoes_SetLockButtonVisual(lb, Echoes_IsFrameLocked())
    elseif f.EchoesLockButton then
        if f.EchoesLockButton.ClearAllPoints and f.EchoesLockButton.SetPoint then
            f.EchoesLockButton:ClearAllPoints()
            f.EchoesLockButton:SetPoint("RIGHT", f.EchoesTitleBar, "RIGHT", -28, 0)
        end
        Echoes_SetLockButtonVisual(f.EchoesLockButton, Echoes_IsFrameLocked())
    end

    if f.EchoesTitleBar and not f.EchoesTitleCloseButton then
        local xb = CreateFrame("Button", nil, f.EchoesTitleBar)
        xb:SetSize(18, 18)
        xb:SetFrameLevel((f.EchoesTitleBar:GetFrameLevel() or 0) + 10)
        if xb.RegisterForClicks then xb:RegisterForClicks("AnyUp") end

        xb:SetPoint("RIGHT", f.EchoesTitleBar, "RIGHT", -6, 0)

        SkinBackdrop(xb, 0.9)

        local fs = xb:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER", xb, "CENTER", 0, 0)
        fs:SetTextColor(0.95, 0.95, 0.95, 0.95)
        SetEchoesFont(fs, 12, ECHOES_FONT_FLAGS)
        fs:SetText("X")
        xb._EchoesLabel = fs

        xb:HookScript("OnEnter", function(self)
            self:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
            if GameTooltip and GameTooltip.SetOwner then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Close")
                GameTooltip:Show()
            end
        end)
        xb:HookScript("OnLeave", function(self)
            self:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
            if GameTooltip and GameTooltip.Hide then GameTooltip:Hide() end
        end)
        xb:SetScript("OnClick", function()
            if f and f.Hide then f:Hide() end
        end)

        f.EchoesTitleCloseButton = xb
    elseif f.EchoesTitleCloseButton then
        if f.EchoesTitleCloseButton.ClearAllPoints and f.EchoesTitleCloseButton.SetPoint then
            f.EchoesTitleCloseButton:ClearAllPoints()
            f.EchoesTitleCloseButton:SetPoint("RIGHT", f.EchoesTitleBar, "RIGHT", -6, 0)
        end
    end

    -- If both exist, keep lock snug to the left of the X.
    if f.EchoesLockButton and f.EchoesTitleCloseButton and f.EchoesLockButton.SetPoint and f.EchoesLockButton.ClearAllPoints then
        f.EchoesLockButton:ClearAllPoints()
        f.EchoesLockButton:SetPoint("RIGHT", f.EchoesTitleCloseButton, "LEFT", -4, 0)
    end

    if widget.titletext then
        widget.titletext:ClearAllPoints()
        widget.titletext:SetPoint("CENTER", f.EchoesTitleBar, "CENTER", 0, 0)
        widget.titletext:SetTextColor(0.95, 0.95, 0.95, 1)
        SetEchoesFont(widget.titletext, 15, ECHOES_FONT_FLAGS)

        -- Disable AceGUI's default title drag handling so only our custom title bar
        -- can move the window (prevents hidden anchor/status changes).
        local titleFrame = widget.titletext.GetParent and widget.titletext:GetParent()
        if titleFrame then
            if titleFrame.EnableMouse then titleFrame:EnableMouse(false) end
            if titleFrame.SetScript then
                titleFrame:SetScript("OnMouseDown", nil)
                titleFrame:SetScript("OnMouseUp", nil)
            end
        end
    end

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

    if widget.closebutton then
        widget.closebutton:Hide()
        widget.closebutton:EnableMouse(false)
    end

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
        fs:SetText("Spec Panel")
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

    if not f.EchoesInventoriesButton then
        local ib = CreateFrame("Button", nil, f)
        ib._EchoesIsCustomInventories = true
        ib:SetSize(120, 22)
        if f.EchoesSpecButton then
            ib:SetPoint("BOTTOMLEFT", f.EchoesSpecButton, "BOTTOMRIGHT", 8, 0)
        else
            ib:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 178, 8)
        end
        ib:SetFrameStrata(f:GetFrameStrata() or "MEDIUM")
        ib:SetFrameLevel((f:GetFrameLevel() or 0) + 500)
        if ib.SetToplevel then ib:SetToplevel(true) end
        if ib.RegisterForClicks then ib:RegisterForClicks("AnyUp") end
        SkinBackdrop(ib, 0.9)

        local fs = ib:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER")
        fs:SetJustifyH("CENTER")
        fs:SetTextColor(0.9, 0.8, 0.5, 1)
        SetEchoesFont(fs, 12, ECHOES_FONT_FLAGS)
        fs:SetText("Inventories")
        ib._EchoesLabel = fs

        ib:HookScript("OnEnter", function(self)
            self:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
        end)
        ib:HookScript("OnLeave", function(self)
            self:SetBackdropColor(0.06, 0.06, 0.06, 0.9)
        end)
        ib:SetScript("OnClick", function()
            local ok, err = pcall(function()
                if Echoes and type(Echoes.Inv_ToggleBar) == "function" then
                    Echoes:Inv_ToggleBar()
                end
            end)
            if not ok and rawget(_G, "DEFAULT_CHAT_FRAME") and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("Echoes: Inventories error: " .. tostring(err))
            end
        end)

        f.EchoesInventoriesButton = ib
    end

    local function LayoutFooterButtons()
        local host = (f and f.content and f.content.GetWidth) and f.content or f
        local w = (host and host.GetWidth and host:GetWidth()) or 0
        if w <= 0 then return end

        local gap = 8
        local leftPad, rightPad
        if host == f then
            leftPad, rightPad = 10, 10
        else
            leftPad, rightPad = 0, 0
        end

        local usable = w - leftPad - rightPad - (gap * 2)
        if usable <= 0 then return end

        local btnW = math.floor(usable / 3)
        if btnW < 50 then btnW = 50 end

        local function PlaceTopAligned(btn)
            if not btn then return end
            btn:ClearAllPoints()
            if host ~= f and host and host.GetPoint then
                -- No upper margin: buttons sit flush to the top of the reserved footer space,
                -- i.e. directly under the AceGUI content frame.
                -- (AceGUI content bottom is already inset up from the frame bottom.)
                return "TOP", host, "BOTTOM"
            end
            return nil
        end

        if f.EchoesSpecButton then
            f.EchoesSpecButton:SetSize(btnW, 22)
            local point, rel, relPoint = PlaceTopAligned(f.EchoesSpecButton)
            if point then
                f.EchoesSpecButton:SetPoint("TOPLEFT", host, "BOTTOMLEFT", leftPad, -FOOTER_TOP_GAP)
            else
                f.EchoesSpecButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", leftPad, 8)
            end
        end

        if f.EchoesInventoriesButton then
            f.EchoesInventoriesButton:SetSize(btnW, 22)
            f.EchoesInventoriesButton:ClearAllPoints()
            if f.EchoesSpecButton then
                f.EchoesInventoriesButton:SetPoint("TOPLEFT", f.EchoesSpecButton, "TOPRIGHT", gap, 0)
            else
                local point = (host ~= f and host and host.GetPoint) and true or false
                if point then
                    f.EchoesInventoriesButton:SetPoint("TOPLEFT", host, "BOTTOMLEFT", leftPad + btnW + gap, -FOOTER_TOP_GAP)
                else
                    f.EchoesInventoriesButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", leftPad + btnW + gap, 8)
                end
            end
        end

        if f.EchoesCloseButton then
            f.EchoesCloseButton:SetSize(btnW, 22)
            f.EchoesCloseButton:ClearAllPoints()
            local point = (host ~= f and host and host.GetPoint) and true or false
            if point then
                f.EchoesCloseButton:SetPoint("TOPRIGHT", host, "BOTTOMRIGHT", -rightPad, -FOOTER_TOP_GAP)
            else
                f.EchoesCloseButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -rightPad, 8)
            end
        end
    end

    LayoutFooterButtons()

    do
        local baseLevel = (f.GetFrameLevel and f:GetFrameLevel()) or 0
        local baseStrata = (f.GetFrameStrata and f:GetFrameStrata()) or "MEDIUM"
        if f.EchoesCloseButton then
            if f.EchoesCloseButton.GetParent and f.EchoesCloseButton:GetParent() ~= f and f.EchoesCloseButton.SetParent then
                f.EchoesCloseButton:SetParent(f)
            end
            if f.EchoesCloseButton.SetFrameStrata then f.EchoesCloseButton:SetFrameStrata(baseStrata) end
            if f.EchoesCloseButton.SetFrameLevel then f.EchoesCloseButton:SetFrameLevel(baseLevel + 500) end
            if f.EchoesCloseButton.SetToplevel then f.EchoesCloseButton:SetToplevel(true) end
            if f.EchoesCloseButton.EnableMouse then f.EchoesCloseButton:EnableMouse(true) end
        end
        if f.EchoesSpecButton then
            if f.EchoesSpecButton.GetParent and f.EchoesSpecButton:GetParent() ~= f and f.EchoesSpecButton.SetParent then
                f.EchoesSpecButton:SetParent(f)
            end
            if f.EchoesSpecButton.SetFrameStrata then f.EchoesSpecButton:SetFrameStrata(baseStrata) end
            if f.EchoesSpecButton.SetFrameLevel then f.EchoesSpecButton:SetFrameLevel(baseLevel + 500) end
            if f.EchoesSpecButton.SetToplevel then f.EchoesSpecButton:SetToplevel(true) end
            if f.EchoesSpecButton.EnableMouse then f.EchoesSpecButton:EnableMouse(true) end
        end
        if f.EchoesInventoriesButton then
            if f.EchoesInventoriesButton.GetParent and f.EchoesInventoriesButton:GetParent() ~= f and f.EchoesInventoriesButton.SetParent then
                f.EchoesInventoriesButton:SetParent(f)
            end
            if f.EchoesInventoriesButton.SetFrameStrata then f.EchoesInventoriesButton:SetFrameStrata(baseStrata) end
            if f.EchoesInventoriesButton.SetFrameLevel then f.EchoesInventoriesButton:SetFrameLevel(baseLevel + 500) end
            if f.EchoesInventoriesButton.SetToplevel then f.EchoesInventoriesButton:SetToplevel(true) end
            if f.EchoesInventoriesButton.EnableMouse then f.EchoesInventoriesButton:EnableMouse(true) end
        end

        LayoutFooterButtons()
    end

    if f.GetChildren then
        local children = { f:GetChildren() }
        for _, child in ipairs(children) do
            if child and child.IsObjectType and child:IsObjectType("Frame") and child ~= f.EchoesTitleBar and child ~= f.EchoesCloseButton and child ~= f.EchoesSpecButton and child ~= f.EchoesInventoriesButton then
                local p = child.GetPoint and child:GetPoint(1)
                if p then
                    local point, relTo = child:GetPoint(1)
                    if relTo == f and point and point:find("BOTTOM") then
                        child:Hide()
                        child:SetAlpha(0)
                        if child.SetBackdrop then child:SetBackdrop(nil) end
                    end
                end
            end
        end
    end

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
            if self.EchoesInventoriesButton and self.EchoesInventoriesButton._EchoesLabel then
                SetEchoesFont(self.EchoesInventoriesButton._EchoesLabel, 12, ECHOES_FONT_FLAGS)
            end

            LayoutFooterButtons()

            if self.EchoesLockButton then
                Echoes_SetLockButtonVisual(self.EchoesLockButton, Echoes_IsFrameLocked())
            end

            Echoes_ForceFontFaceOnFrame(self)
        end)

        f:HookScript("OnSizeChanged", function()
            LayoutFooterButtons()
        end)
    end
end

local function SkinSimpleGroup(widget)
    if not widget or not widget.frame then return end
    SkinBackdrop(widget.frame, 0.18)
    if widget.frame.SetBackdropBorderColor then
        widget.frame:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

local function SkinInlineGroup(widget, opts)
    if not widget or not widget.frame then return end
    opts = opts or {}
    local alpha = (opts.alpha ~= nil) and opts.alpha or 0.35

    local borderFrame = (widget.content and widget.content.GetParent and widget.content:GetParent()) or widget.frame

    if opts.border == false then
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

    -- Cache FontObjects per size so hover/highlight can't swap to a different (larger) font.
    Echoes._EchoesButtonFontObjects = Echoes._EchoesButtonFontObjects or {}
    local function GetButtonFontObject(size)
        size = tonumber(size) or 10
        local fo = Echoes._EchoesButtonFontObjects[size]
        if fo then return fo end

        if type(CreateFont) == "function" then
            fo = CreateFont("EchoesButtonFont" .. tostring(size))
            if fo and fo.SetFont and type(ECHOES_FONT_PATH) == "string" then
                fo:SetFont(ECHOES_FONT_PATH, size, ECHOES_FONT_FLAGS or "")
            end
            Echoes._EchoesButtonFontObjects[size] = fo
            return fo
        end

        return nil
    end

    local function ReapplyButtonFont(self)
        local size = tonumber(self and self._EchoesFontSize) or fontSize

        -- Reapply to *all* FontString regions (some templates show a different FontString on hover).
        if self and self.GetRegions then
            local regs = { self:GetRegions() }
            for _, r in ipairs(regs) do
                if r and r.IsObjectType and r:IsObjectType("FontString") then
                    if r.SetTextColor then
                        r:SetTextColor(0.90, 0.85, 0.70, 1)
                    end
                    SetEchoesFont(r, size, ECHOES_FONT_FLAGS)
                end
            end
        end

        local fs = (self and self.GetFontString and self:GetFontString()) or nil
        if fs and fs.SetTextColor then
            fs:SetTextColor(0.90, 0.85, 0.70, 1)
        end
        if fs then
            SetEchoesFont(fs, size, ECHOES_FONT_FLAGS)
        end

        if widget.text then
            if widget.text.SetTextColor then
                widget.text:SetTextColor(0.90, 0.85, 0.70, 1)
            end
            SetEchoesFont(widget.text, size, ECHOES_FONT_FLAGS)
        end

        -- If the frame supports FontObjects, force all states to the same font.
        local fo = GetButtonFontObject(size)
        if fo and self then
            if self.SetNormalFontObject then self:SetNormalFontObject(fo) end
            if self.SetHighlightFontObject then self:SetHighlightFontObject(fo) end
            if self.SetDisabledFontObject then self:SetDisabledFontObject(fo) end
        end
    end

    StripFrameTextures(f)

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

            ReapplyButtonFont(self)
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

        -- Many UI packs / templates swap FontObjects on hover.
        -- Reassert our font to prevent the "growing text" effect.
        f:HookScript("OnEnter", function(self)
            self:SetBackdropColor(0.10, 0.10, 0.10, 0.95)
            ReapplyButtonFont(self)
        end)
        f:HookScript("OnLeave", function(self)
            self:SetBackdropColor(0.06, 0.06, 0.06, 0.7)
            ReapplyButtonFont(self)
        end)
    end
    f._EchoesSkinAlpha = 0.7
    f._EchoesFontSize = fontSize

    SkinBackdrop(f, 0.7)

    if widget.text and widget.text.SetTextColor then
        widget.text:SetTextColor(0.90, 0.85, 0.70, 1)
        SetEchoesFont(widget.text, fontSize, ECHOES_FONT_FLAGS)
    end

    -- Also update the internal button FontString if it differs from widget.text.
    ReapplyButtonFont(f)
end

-- Forward declaration: ShowNamePrompt uses SkinEditBox, which is defined later.
local SkinEditBox

local function SkinPopupFrame(widget)
    if not widget or not widget.frame then return end
    local f = widget.frame

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

    if w.frame then
        if w.frame.SetMovable then w.frame:SetMovable(true) end
        if w.frame.SetResizable then w.frame:SetResizable(true) end
        if w.frame.SetMinResize and w.frame.SetMaxResize and w.frame.GetWidth and w.frame.GetHeight then
            local fw = w.frame:GetWidth() or 260
            local fh = w.frame:GetHeight() or 140
            w.frame:SetMinResize(fw, fh)
            w.frame:SetMaxResize(fw, fh)
        end
    end

    SkinPopupFrame(w)

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

                    if (relTo == frame or relTo == nil) and point and point:find("BOTTOM") and ch >= 18 and ch <= 30 and cw >= 80 then
                        child:Hide()
                        child:SetAlpha(0)
                        if child.SetBackdrop then child:SetBackdrop(nil) end
                        if child.EnableMouse then child:EnableMouse(false) end
                    end

                    if md and mu and (relTo == frame or relTo == nil) and (point == "BOTTOMRIGHT" or point == "BOTTOM" or point == "RIGHT") and cw <= 30 and ch <= 30 then
                        child:Hide()
                        if child.EnableMouse then child:EnableMouse(false) end
                        if child.SetScript then
                            child:SetScript("OnMouseDown", nil)
                            child:SetScript("OnMouseUp", nil)
                        end
                    end

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
    if edit.button then
        if edit.button.Hide then edit.button:Hide() end
        if edit.button.EnableMouse then edit.button:EnableMouse(false) end
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

    if edit and edit.editbox then
        if edit.editbox.SetFocus then
            edit.editbox:SetFocus()
        end
        if edit.editbox.HighlightText then
            edit.editbox:HighlightText()
        end

        if edit.editbox.SetScript then
            edit.editbox:SetScript("OnEnterPressed", function()
                DoAccept()
            end)
            edit.editbox:SetScript("OnEscapePressed", function()
                DoCancel()
            end)
        end
    end

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

local function SkinTabButton(widget)
    SkinButton(widget)
    if widget.text and widget.text.SetTextColor then
        widget.text:SetTextColor(1, 1, 1, 1)
    end
end

local function SkinDropdown(widget)
    if not widget or not widget.frame then return end
    local f = widget.frame

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

    local function ApplyEchoesGroupSlotSelectedColor(targetText)
        local target = targetText or widget.text
        if not widget.dropdown or widget.dropdown._EchoesDropdownKind ~= "groupSlot" then return end

        if widget.dropdown._EchoesFilledClassFile then
            local colors = rawget(_G, "RAID_CLASS_COLORS")
            local c = colors and colors[widget.dropdown._EchoesFilledClassFile]
            if c and target and target.SetTextColor then
                target:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)
                return
            end
        end

        if widget.dropdown._EchoesForceDisabledGrey then
            if target and target.SetTextColor then
                target:SetTextColor(0.55, 0.55, 0.55, 1)
            end
            return
        end

        if target and target.GetText and target.SetTextColor then
            local rawText = target:GetText()
            local stripped = StripColorCodes(rawText)
            local t = tostring(stripped or "")
            t = t:lower():gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

            -- Group slot dropdown wants "None" to remain visibly grey.
            if t == "none" or t == "" then
                target:SetTextColor(0.60, 0.60, 0.60, 1)
                return
            end

            local classFile = ClassFileFromDisplayName(rawText)
            local colors = rawget(_G, "RAID_CLASS_COLORS")
            local c = classFile and colors and colors[classFile]
            if c then
                target:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)
            else
                target:SetTextColor(0.90, 0.85, 0.70, 1)
            end
        end
    end

    local box = widget.dropdown or f

    if widget.dropdown and widget.dropdown.GetRegions then
        local regs = { widget.dropdown:GetRegions() }
        for _, r in ipairs(regs) do
            if r and r.IsObjectType and r:IsObjectType("Texture") then
                r:SetTexture(nil)
            end
        end
    end

    if widget.dropdown and not widget.dropdown._EchoesAnchored then
        widget.dropdown._EchoesAnchored = true
        widget.dropdown:ClearAllPoints()
        widget.dropdown:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        widget.dropdown:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    end

    if widget.dropdown and f.GetHeight and widget.dropdown.SetHeight then
        local h = f:GetHeight()
        if h and h > 0 then
            widget.dropdown:SetHeight(h)
        end
    end

    if widget.dropdown then
        widget.dropdown._EchoesOwned = true
    end

    SkinBackdrop(box, 0.95)
    box:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    box:SetBackdropBorderColor(0, 0, 0, 1)

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

    local function EnsurePrivateDropdownText()
        if not box or not box.CreateFontString then return nil end
        if box._EchoesPrivateText then return box._EchoesPrivateText end

        local fs = box:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("MIDDLE")
        box._EchoesPrivateText = fs
        return fs
    end

    local function ReapplyEchoesDropdownFont()
        local preserveTextColor = (widget and widget._EchoesPreserveTextColor) or (widget.dropdown and widget.dropdown._EchoesPreserveTextColor)
        local rawText = widget.text and widget.text.GetText and widget.text:GetText() or ""

        local fs = EnsurePrivateDropdownText()
        if fs then
            SetEchoesFont(fs, 10, ECHOES_FONT_FLAGS)
            fs:SetText(tostring(rawText or ""))
            if not preserveTextColor then
                fs:SetTextColor(0.90, 0.85, 0.70, 1)
            elseif widget.text and widget.text.GetTextColor then
                local r, g, b, a = widget.text:GetTextColor()
                if r and g and b then
                    fs:SetTextColor(r, g, b, a or 1)
                end
            end
            ApplyEchoesGroupSlotSelectedColor(fs)
        end

        if not preserveTextColor and widget.text and widget.text.SetTextColor then
            widget.text:SetTextColor(0.90, 0.85, 0.70, 1)
        end
        if widget.text then
            SetEchoesFont(widget.text, 10, ECHOES_FONT_FLAGS)
        end
        ApplyEchoesGroupSlotSelectedColor()
    end

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
        if widget.text.SetAlpha then
            widget.text:SetAlpha(0)
        end
        local fs = EnsurePrivateDropdownText()
        if fs then
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", box, "LEFT", 8, 0)
            if sepTex then
                fs:SetPoint("RIGHT", sepTex, "LEFT", -6, 0)
            elseif widget.button then
                fs:SetPoint("RIGHT", widget.button, "LEFT", -6, 0)
            else
                fs:SetPoint("RIGHT", box, "RIGHT", -8, 0)
            end
        end
        ReapplyEchoesDropdownFont()
    end

    if box and box.HookScript and not box._EchoesFontReassertHooked then
        box._EchoesFontReassertHooked = true
        box:HookScript("OnShow", function()
            ReapplyEchoesDropdownFont()
        end)
        box:HookScript("OnMouseDown", function()
            ReapplyEchoesDropdownFont()
        end)
    end

    ApplyEchoesGroupSlotSelectedColor()

    if widget.label and widget.label.SetTextColor then
        widget.label:SetTextColor(0.9, 0.9, 0.9, 1)
    end
end

SkinEditBox = function(widget)
    if not widget or not widget.editbox then return end
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

-- Exports
Echoes.SetEchoesFont = SetEchoesFont
Echoes.ECHOES_FONT_FLAGS = ECHOES_FONT_FLAGS
Echoes.SkinBackdrop = SkinBackdrop
Echoes.SkinMainFrame = SkinMainFrame
Echoes.SkinSimpleGroup = SkinSimpleGroup
Echoes.SkinInlineGroup = SkinInlineGroup
Echoes.SkinButton = SkinButton
Echoes.SkinTabButton = SkinTabButton
Echoes.SkinDropdown = SkinDropdown
Echoes.SkinEditBox = SkinEditBox
Echoes.SkinHeading = SkinHeading
Echoes.SkinLabel = SkinLabel
Echoes.ForceFontFaceOnFrame = Echoes_ForceFontFaceOnFrame
Echoes.EnableSelectionHighlight = Echoes_EnableSelectionHighlight
