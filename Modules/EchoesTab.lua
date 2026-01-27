local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")
local AceGUI = LibStub("AceGUI-3.0")

-- Pull shared helpers from the core file.
local Clamp = Echoes.Clamp
local SkinHeading = Echoes.SkinHeading
local SkinLabel = Echoes.SkinLabel
local SkinEditBox = Echoes.SkinEditBox

local function Echoes_Log(msg)
    if Echoes and Echoes.Log then
        Echoes:Log("INFO", msg)
    end
end

local function Echoes_GetMainWindowTopLeftOffsetsInUIParent()
    local widget = Echoes.UI and Echoes.UI.frame
    local f = widget and widget.frame
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
        if point == "TOPLEFT" and rel == UIParent and rPoint == "TOPLEFT" then
            return tonumber(xOfs) or 0, tonumber(yOfs) or 0
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

    if f.GetCenter and f.GetWidth and f.GetHeight and f.GetEffectiveScale and UIParent.GetEffectiveScale then
        local cx, cy = f:GetCenter()
        if cx and cy then
            local scale = f:GetEffectiveScale() or 1
            local parentScale = UIParent:GetEffectiveScale() or 1
            if scale <= 0 then scale = 1 end
            if parentScale <= 0 then parentScale = 1 end
            local w = (f:GetWidth() or 0) * (scale / parentScale)
            local h = (f:GetHeight() or 0) * (scale / parentScale)
            local x = cx - (w * 0.5)
            local y = (cy + (h * 0.5)) - parentTop
            return x, y
        end
    end

    return nil, nil
end

local function Echoes_SetMainWindowTopLeftOffsetsInUIParent(x, y)
    local widget = Echoes.UI and Echoes.UI.frame
    local f = widget and widget.frame
    if not (f and UIParent and x and y and f.ClearAllPoints and f.SetPoint) then return end
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
end

------------------------------------------------------------
-- Echoes tab (now includes UI scale slider)
------------------------------------------------------------
function Echoes:BuildEchoesTab(container)
    local EchoesDB = _G.EchoesDB
    container:SetLayout("List")

    Echoes_Log("EchoesTab: build")

    local sliderTopPad = AceGUI:Create("SimpleGroup")
    sliderTopPad:SetFullWidth(true)
    sliderTopPad:SetLayout("Fill")
    if sliderTopPad.SetAutoAdjustHeight then sliderTopPad:SetAutoAdjustHeight(false) end
    sliderTopPad:SetHeight(15)
    container:AddChild(sliderTopPad)

    local scaleSlider = AceGUI:Create("Slider")
    scaleSlider:SetLabel("UI Scale")
    scaleSlider:SetSliderValues(0.5, 2.0, 0.05)
    scaleSlider:SetValue(EchoesDB.uiScale or 1.0)
    scaleSlider:SetFullWidth(true)

    -- Remove the manual type-in box.
    if scaleSlider.editbox then
        scaleSlider.editbox:Hide()
        if scaleSlider.editbox.EnableMouse then
            scaleSlider.editbox:EnableMouse(false)
        end
    end
    -- Reduce the empty reserved height left by the hidden editbox.
    if scaleSlider.SetHeight then
        scaleSlider:SetHeight(30)
    end

    -- IMPORTANT: applying scale while dragging the slider resizes the slider itself,
    -- which can make AceGUI's Slider jump to the minimum due to the changing mouse/value mapping.
    -- We only apply the scale after the user releases the mouse.
    scaleSlider:SetCallback("OnValueChanged", function(widget, event, value)
        local v = tonumber(value) or (EchoesDB.uiScale or 1.0)
        v = Clamp(v, 0.5, 2.0)
        Echoes._EchoesPendingUiScale = v
        Echoes_Log("EchoesTab: scale slider change=" .. string.format("%.2f", v))
    end)
    scaleSlider:SetCallback("OnMouseUp", function(widget, event, value)
        local v = tonumber(value) or Echoes._EchoesPendingUiScale or (EchoesDB.uiScale or 1.0)
        v = Clamp(v, 0.5, 2.0)
        EchoesDB.uiScale = v
        EchoesDB.uiScaleUserSet = true
        Echoes._EchoesPendingUiScale = nil

        Echoes:ApplyScale()
        Echoes_Log("EchoesTab: scale applied=" .. string.format("%.2f", v))
    end)
    container:AddChild(scaleSlider)

    local sliderPad = AceGUI:Create("SimpleGroup")
    sliderPad:SetFullWidth(true)
    sliderPad:SetLayout("Fill")
    if sliderPad.SetAutoAdjustHeight then sliderPad:SetAutoAdjustHeight(false) end
    sliderPad:SetHeight(10)
    container:AddChild(sliderPad)

    -- X / Y / Scale edit boxes (all on one row)
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("None")
    if row.SetAutoAdjustHeight then row:SetAutoAdjustHeight(false) end
    row:SetHeight(28)
    container:AddChild(row)

    local host = row.content or row.frame

    local function CreateLabel(text, width)
        local lbl = AceGUI:Create("Label")
        lbl:SetText(text)
        lbl:SetWidth(width or 20)
        return lbl
    end

    local function CreateEdit(defaultText, width)
        local eb = AceGUI:Create("EditBox")
        eb:SetText(defaultText or "")
        eb:SetWidth(width or 90)
        if eb.DisableButton then
            eb:DisableButton(true)
        end
        if eb.button and eb.button.Hide then
            eb.button:Hide()
        end
        if eb.editbox and eb.editbox.SetTextInsets then
            eb.editbox:SetTextInsets(0, 0, 3, 3)
        end
        if SkinEditBox then
            SkinEditBox(eb)
        end
        return eb
    end

    local xEd, yEd, scaleEd

    local function UpdatePositionEdits()
        local x, y = Echoes_GetMainWindowTopLeftOffsetsInUIParent()
        if xEd and xEd.SetText then xEd:SetText(string.format("%.0f", x or 0)) end
        if yEd and yEd.SetText then yEd:SetText(string.format("%.0f", y or 0)) end
    end

    function Echoes:UpdatePositionEdits()
        UpdatePositionEdits()
    end

    local function UpdateScaleEdit()
        local v = EchoesDB.uiScale or 1.0
        if scaleEd and scaleEd.SetText then scaleEd:SetText(string.format("%.2f", v)) end
    end

    function Echoes:UpdateScaleEdit()
        UpdateScaleEdit()
    end

    local lblX = CreateLabel("X", 14)
    row:AddChild(lblX)
    xEd = CreateEdit("0", 56)
    xEd:SetCallback("OnEnterPressed", function(widget, event, value)
        local x = tonumber(value)
        if not x then return end
        local _, y = Echoes_GetMainWindowTopLeftOffsetsInUIParent()
        y = y or 0
        Echoes_SetMainWindowTopLeftOffsetsInUIParent(x, y)
        UpdatePositionEdits()
        Echoes_Log("EchoesTab: position set x=" .. tostring(x) .. " y=" .. tostring(y))
        if widget and widget.editbox and widget.editbox.ClearFocus then
            widget.editbox:ClearFocus()
        end
    end)
    row:AddChild(xEd)

    local lblY = CreateLabel("Y", 14)
    row:AddChild(lblY)
    yEd = CreateEdit("0", 56)
    yEd:SetCallback("OnEnterPressed", function(widget, event, value)
        local y = tonumber(value)
        if not y then return end
        local x, _ = Echoes_GetMainWindowTopLeftOffsetsInUIParent()
        x = x or 0
        Echoes_SetMainWindowTopLeftOffsetsInUIParent(x, y)
        UpdatePositionEdits()
        Echoes_Log("EchoesTab: position set x=" .. tostring(x) .. " y=" .. tostring(y))
        if widget and widget.editbox and widget.editbox.ClearFocus then
            widget.editbox:ClearFocus()
        end
    end)
    row:AddChild(yEd)

    local lblScale = CreateLabel("Scale", 34)
    row:AddChild(lblScale)
    scaleEd = CreateEdit("1.00", 49)
    scaleEd:SetCallback("OnEnterPressed", function(widget, event, value)
        local v = tonumber(value)
        if not v then return end
        v = Clamp(v, 0.5, 2.0)
        EchoesDB.uiScale = v
        EchoesDB.uiScaleUserSet = true
        Echoes:ApplyScale()
        if scaleSlider and scaleSlider.SetValue then
            scaleSlider:SetValue(v)
        end
        UpdateScaleEdit()
        Echoes_Log("EchoesTab: scale set via edit=" .. string.format("%.2f", v))
        if widget and widget.editbox and widget.editbox.ClearFocus then
            widget.editbox:ClearFocus()
        end
    end)
    row:AddChild(scaleEd)

    if host and host.SetPoint then
        local function LayoutRow()
            local w = host.GetWidth and host:GetWidth() or 0
            if w <= 0 then return end

            local total = lblX.frame:GetWidth() + 3
                + xEd.frame:GetWidth() + 10
                + lblY.frame:GetWidth() + 3
                + yEd.frame:GetWidth() + 10
                + lblScale.frame:GetWidth() + 3
                + scaleEd.frame:GetWidth()

            local x = math.floor((w - total) * 0.5 + 0.5)
            if x < 0 then x = 0 end

            lblX.frame:ClearAllPoints()
            lblX.frame:SetPoint("LEFT", host, "LEFT", x, 0)
            x = x + lblX.frame:GetWidth() + 3

            xEd.frame:ClearAllPoints()
            xEd.frame:SetPoint("LEFT", host, "LEFT", x, 0)
            x = x + xEd.frame:GetWidth() + 10

            lblY.frame:ClearAllPoints()
            lblY.frame:SetPoint("LEFT", host, "LEFT", x, 0)
            x = x + lblY.frame:GetWidth() + 3

            yEd.frame:ClearAllPoints()
            yEd.frame:SetPoint("LEFT", host, "LEFT", x, 0)
            x = x + yEd.frame:GetWidth() + 10

            lblScale.frame:ClearAllPoints()
            lblScale.frame:SetPoint("LEFT", host, "LEFT", x, 0)
            x = x + lblScale.frame:GetWidth() + 3

            scaleEd.frame:ClearAllPoints()
            scaleEd.frame:SetPoint("LEFT", host, "LEFT", x, 0)
        end

        LayoutRow()
        if host.HookScript and not host._EchoesRowCenteredHooked then
            host._EchoesRowCenteredHooked = true
            host:HookScript("OnShow", LayoutRow)
            host:HookScript("OnSizeChanged", LayoutRow)
        end
    end

    UpdatePositionEdits()
    UpdateScaleEdit()

    local tradeToggle = AceGUI:Create("CheckBox")
    tradeToggle:SetLabel("Trade Features")
    tradeToggle:SetValue(EchoesDB.tradeFeaturesEnabled ~= false)
    tradeToggle:SetFullWidth(true)
    tradeToggle:SetCallback("OnValueChanged", function(widget, event, value)
        EchoesDB.tradeFeaturesEnabled = (value == true)
        Echoes_Log("EchoesTab: trade features=" .. tostring(EchoesDB.tradeFeaturesEnabled))
        if not EchoesDB.tradeFeaturesEnabled then
            if Echoes and Echoes.Trade_OnClosed then
                Echoes:Trade_OnClosed()
            end
        elseif Echoes and Echoes.Trade_OnShow then
            if _G.TradeFrame and _G.TradeFrame.IsShown and _G.TradeFrame:IsShown() then
                Echoes:Trade_OnShow()
            end
        end
    end)
    container:AddChild(tradeToggle)

    local spamToggle = AceGUI:Create("CheckBox")
    spamToggle:SetLabel("Bot Spam Filter")
    spamToggle:SetValue(EchoesDB.botSpamFilterEnabled == true)
    spamToggle:SetFullWidth(true)
    spamToggle:SetCallback("OnValueChanged", function(widget, event, value)
        EchoesDB.botSpamFilterEnabled = (value == true)
        Echoes_Log("EchoesTab: bot spam filter=" .. tostring(EchoesDB.botSpamFilterEnabled))
    end)
    container:AddChild(spamToggle)

    self.UI = self.UI or {}
    self.UI.scaleSlider = scaleSlider
end
