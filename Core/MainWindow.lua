-- Core\MainWindow.lua
-- Main window creation, tabs, sizing/scale, and slash command handling.

local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")
local AceGUI = LibStub("AceGUI-3.0")

local Clamp = Echoes.Clamp
local Echoes_Print = Echoes.Print

local SkinMainFrame = Echoes.SkinMainFrame
local SkinSimpleGroup = Echoes.SkinSimpleGroup
local SkinTabButton = Echoes.SkinTabButton

------------------------------------------------------------
-- UI state
------------------------------------------------------------
Echoes.UI = Echoes.UI or {}
Echoes.UI.frame = Echoes.UI.frame or nil
Echoes.UI.content = Echoes.UI.content or nil
Echoes.UI.tabs = Echoes.UI.tabs or {}
Echoes.UI.pages = Echoes.UI.pages or {}

local TAB_DEFS = {
    { key = "BOT",    label = "Bot Control" },
    { key = "GROUP",  label = "Group Creation" },
    { key = "ECHOES", label = "Echoes" },
}

local TOP_TAB_H = 26

local function Echoes_LayoutTopTabs(tabBar, buttons)
    if not tabBar or not buttons or #buttons == 0 then return end

    local host = tabBar.content or tabBar.frame
    if not host or not (host.GetWidth and host.GetHeight) then return end

    local w = host:GetWidth() or 0
    if w <= 0 then return end

    local n = #buttons
    local overlap = 1

    local total = w + (n - 1) * overlap
    local base = math.floor(total / n)
    local remainder = total - (base * n)

    local x = 0
    for i = 1, n do
        local btn = buttons[i]
        local f = btn and btn.frame
        if btn and f and btn.SetWidth and btn.SetHeight and f.ClearAllPoints and f.SetPoint then
            local wi = base
            if remainder > 0 then
                wi = wi + 1
                remainder = remainder - 1
            end

            btn:SetWidth(wi)
            btn:SetHeight(TOP_TAB_H)

            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", host, "TOPLEFT", x, 0)

            x = x + wi - overlap
        end
    end
end

------------------------------------------------------------
-- Frame size & scale helpers
------------------------------------------------------------
local function Echoes_GetTopLeftOffsetsInUIParent(f)
    if not f or not UIParent then return nil, nil end

    local parentLeft = (UIParent.GetLeft and UIParent:GetLeft())
    local parentTop = (UIParent.GetTop and UIParent:GetTop())
    if parentLeft == nil then
        parentLeft = 0
    end
    if parentTop == nil then
        parentTop = (UIParent.GetHeight and UIParent:GetHeight()) or 0
    end

    if f.GetPoint then
        local point, relTo, relPoint, xOfs, yOfs = f:GetPoint(1)
        local rel = relTo or UIParent
        local rPoint = relPoint or point
        if point == "TOPLEFT" and rel == UIParent then
            if rPoint == "TOPLEFT" then
                return tonumber(xOfs) or 0, tonumber(yOfs) or 0
            end
            if rPoint == "BOTTOMLEFT" then
                return tonumber(xOfs) or 0, (tonumber(yOfs) or 0) - parentTop
            end
        end

        if point == "CENTER" and rel == UIParent and rPoint == "CENTER" and xOfs and yOfs and f.GetWidth and f.GetHeight then
            local scale = f:GetEffectiveScale() or 1
            local parentScale = UIParent:GetEffectiveScale() or 1
            if scale <= 0 then scale = 1 end
            if parentScale <= 0 then parentScale = 1 end
            local w = (f:GetWidth() or 0) * (scale / parentScale)
            local h = (f:GetHeight() or 0) * (scale / parentScale)
            return tonumber(xOfs) - (w * 0.5), tonumber(yOfs) - parentTop + (h * 0.5)
        end

        -- Support AceGUI-style anchors (TOP to BOTTOM, LEFT to LEFT).
        local topOfs, leftOfs
        if point == "TOP" and rel == UIParent and rPoint == "BOTTOM" then
            topOfs = tonumber(yOfs) or 0
        elseif point == "LEFT" and rel == UIParent and rPoint == "LEFT" then
            leftOfs = tonumber(xOfs) or 0
        end

        local point2, relTo2, relPoint2, xOfs2, yOfs2 = f:GetPoint(2)
        if point2 then
            local rel2 = relTo2 or UIParent
            local rPoint2 = relPoint2 or point2
            if point2 == "TOP" and rel2 == UIParent and rPoint2 == "BOTTOM" then
                topOfs = tonumber(yOfs2) or 0
            elseif point2 == "LEFT" and rel2 == UIParent and rPoint2 == "LEFT" then
                leftOfs = tonumber(xOfs2) or 0
            end
        end

        if topOfs and leftOfs then
            return leftOfs, topOfs - parentTop
        end
    end

    if f.GetLeft and f.GetTop then
        local left = f:GetLeft()
        local top = f:GetTop()
        if left and top then
            return left - parentLeft, top - parentTop
        end
    end

    if not (f.GetCenter and f.GetWidth and f.GetHeight and f.GetEffectiveScale and UIParent.GetEffectiveScale and UIParent.GetHeight) then
        return nil, nil
    end

    local cx, cy = f:GetCenter()
    if not cx or not cy then return nil, nil end

    local scale = f:GetEffectiveScale() or 1
    local parentScale = UIParent:GetEffectiveScale() or 1
    if scale <= 0 then scale = 1 end
    if parentScale <= 0 then parentScale = 1 end

    local parentH = UIParent:GetHeight() or 0
    local w = (f:GetWidth() or 0) * (scale / parentScale)
    local h = (f:GetHeight() or 0) * (scale / parentScale)

    local x = cx - (w * 0.5)
    local y = (cy + (h * 0.5)) - parentH
    return x, y
end

local function Echoes_SetTopLeftOffsetsInUIParent(f, x, y)
    if not (f and UIParent and x and y and f.ClearAllPoints and f.SetPoint) then return end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
end

function Echoes:ApplyFrameSizeForTab(key)
    local frame = self.UI.frame
    if not frame then return end

    local FRAME_SIZES = self.FRAME_SIZES or {}
    local s = FRAME_SIZES[key] or FRAME_SIZES["BOT"]
    if not s then return end

    local native = frame.frame

    local EchoesDB = _G.EchoesDB
    local scale = EchoesDB.uiScale or 1.0
    if scale < 0.01 then scale = 1.0 end

    local screenW = (GetScreenWidth and GetScreenWidth()) or (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or s.w
    local screenH = (GetScreenHeight and GetScreenHeight()) or (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or s.h

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

    if self.UpdatePositionEdits then
        self:UpdatePositionEdits()
    end
end

function Echoes:ApplyScale()
    local EchoesDB = _G.EchoesDB
    local widget = self.UI.frame
    local f = widget and widget.frame

    if f and f.SetScale then
        f:SetScale(EchoesDB.uiScale or 1.0)
    end

    -- After any scale change, recenter like /echoes reset.
    self:ResetMainWindowPosition()
end

------------------------------------------------------------
-- Manual tab management
------------------------------------------------------------
function Echoes:SetActiveTab(key)
    local EchoesDB = _G.EchoesDB
    EchoesDB.lastPanel = key or "BOT"

    for tabKey, btn in pairs(self.UI.tabs) do
        if btn and btn.text then
            if tabKey == key then
                btn.text:SetText("|cffffffff" .. btn.origText .. "|r")
            else
                btn.text:SetText("|cffcccccc" .. btn.origText .. "|r")
            end
        end
    end

    local container = self.UI.content
    if not container then return end

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

    for _, p in pairs(self.UI.pages) do
        if p and p.frame then
            p.frame:Hide()
        end
    end
    if page and page.frame then
        page.frame:Show()
    end

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

    local FRAME_SIZES = self.FRAME_SIZES or {}

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Echoes v0.12")
    frame:SetLayout("List")
    frame:SetWidth(FRAME_SIZES.BOT and FRAME_SIZES.BOT.w or 320)
    frame:SetHeight(FRAME_SIZES.BOT and FRAME_SIZES.BOT.h or 480)
    frame:Hide()

    frame:SetCallback("OnClose", function(widget)
        widget:Hide()
    end)

    local EchoesDB = _G.EchoesDB
    frame.frame:SetScale(EchoesDB.uiScale or 1.0)
    SkinMainFrame(frame)

    -- Prevent AceGUI status handling from re-positioning the frame.
    -- We manage position ourselves (drag stop + scale adjustments).
    if frame.ApplyStatus and not frame._EchoesApplyStatusOverridden then
        frame._EchoesApplyStatusOverridden = true
        frame.ApplyStatus = function(self)
            local status = self.status or self.localstatus
            local curW = self.frame and self.frame.GetWidth and self.frame:GetWidth()
            local curH = self.frame and self.frame.GetHeight and self.frame:GetHeight()
            self:SetWidth(status.width or curW or 700)
            self:SetHeight(status.height or curH or 500)
            -- Intentionally do not change anchors here.
        end
    end

    local tabBar = AceGUI:Create("SimpleGroup")
    tabBar:SetFullWidth(true)
    tabBar:SetLayout("Fill")
    tabBar:SetHeight(TOP_TAB_H)
    if tabBar.SetAutoAdjustHeight then
        tabBar:SetAutoAdjustHeight(false)
    end
    frame:AddChild(tabBar)
    SkinSimpleGroup(tabBar)

    local topTabs = {}
    for _, def in ipairs(TAB_DEFS) do
        local btn = AceGUI:Create("Button")
        btn.origText = def.label
        btn:SetText(def.label)
        -- Width will be set by our layout function; this is just a harmless default.
        btn:SetWidth(90)
        btn:SetHeight(TOP_TAB_H)
        btn:SetCallback("OnClick", function()
            Echoes:SetActiveTab(def.key)
        end)
        -- Do NOT AddChild() (it would invoke AceGUI layouts and add padding).
        -- Instead, parent it and position manually so it fills the whole row.
        if btn.SetParent then
            btn:SetParent(tabBar)
        end
        if btn.frame and btn.frame.Show then
            btn.frame:Show()
        end
        SkinTabButton(btn)
        self.UI.tabs[def.key] = btn
        topTabs[#topTabs + 1] = btn
    end

    if not tabBar._EchoesTopTabsHooked then
        tabBar._EchoesTopTabsHooked = true
        local host = tabBar.content or tabBar.frame
        if host and host.HookScript then
            host:HookScript("OnSizeChanged", function()
                Echoes_LayoutTopTabs(tabBar, topTabs)
            end)
        end
    end

    Echoes_LayoutTopTabs(tabBar, topTabs)

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

local function Echoes_Trim(s)
    s = tostring(s or "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Echoes:ResetMainWindowPosition()
    self:CreateMainWindow()

    local widget = self.UI.frame
    local f = widget and widget.frame
    if not f or not f.SetPoint then return end

    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    if f.SetClampedToScreen then
        f:SetClampedToScreen(false)
    end

    widget:Show()

    local EchoesDB = _G.EchoesDB
    self:ApplyFrameSizeForTab(EchoesDB.lastPanel or "BOT")
    if self.UpdatePositionEdits then
        self:UpdatePositionEdits()
    end
    if self.UpdateScaleEdit then
        self:UpdateScaleEdit()
    end
    Echoes_Print("Window reset to center.")
end

function Echoes:ChatCommand(input)
    local EchoesDB = _G.EchoesDB

    input = Echoes_Trim(input)
    local cmd = input:match("^(%S+)")
    cmd = cmd and cmd:lower() or ""

    if cmd == "help" or cmd == "?" then
        Echoes_Print("Echoes commands:")
        Echoes_Print("  /echoes                 - Toggle the main window")
        Echoes_Print("  /echoes help            - Show this help")
        Echoes_Print("  /echoes scale <0.5-2.0> - Set UI scale")
        Echoes_Print("  /echoes reset           - Reset window position")
        Echoes_Print("  /echoes spec            - Toggle spec whisper panel")
        Echoes_Print("  /echoes inv             - Run inventory scan")
        return
    end

    if cmd == "scale" then
        local arg = input:match("^%S+%s+(.+)$")
        local v = tonumber(arg)
        if not v then
            Echoes_Print("Usage: /echoes scale <0.5-2.0>")
            return
        end
        v = Clamp(v, 0.5, 2.0)
        EchoesDB.uiScale = v
        EchoesDB.uiScaleUserSet = true
        self:CreateMainWindow()

        self:ApplyScale()

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
        self:CreateMainWindow()
        local anchor
        local w = self.UI and self.UI.frame
        if w and w.frame and w.IsShown and w:IsShown() then
            anchor = w.frame
        end
        self:ToggleSpecWhisperFrame(anchor)
        return
    end

    if cmd == "inv" then
        if self.RunInventoryScan then
            self:RunInventoryScan()
        else
            Echoes_Print("inv: feature not loaded")
        end
        return
    end

    self:ToggleMainWindow()
end
