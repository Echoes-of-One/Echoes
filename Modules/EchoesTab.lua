local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")
local AceGUI = LibStub("AceGUI-3.0")

-- Pull shared helpers from the core file.
local Clamp = Echoes.Clamp
local SkinHeading = Echoes.SkinHeading
local SkinLabel = Echoes.SkinLabel

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
    end)
    scaleSlider:SetCallback("OnMouseUp", function(widget, event, value)
        local v = tonumber(value) or Echoes._EchoesPendingUiScale or (EchoesDB.uiScale or 1.0)
        v = Clamp(v, 0.5, 2.0)
        EchoesDB.uiScale = v
        EchoesDB.uiScaleUserSet = true
        Echoes._EchoesPendingUiScale = nil

        Echoes:ApplyScale()
    end)
    container:AddChild(scaleSlider)

    -- X / Y / Scale edit boxes (all on one row)
    local row = AceGUI:Create("SimpleGroup")
    row:SetFullWidth(true)
    row:SetLayout("Flow")
    container:AddChild(row)

    local function CreateLabel(text)
        local lbl = AceGUI:Create("Label")
        lbl:SetText(text)
        lbl:SetWidth(20)
        return lbl
    end

    local function CreateEdit(defaultText)
        local eb = AceGUI:Create("EditBox")
        eb:SetText(defaultText or "")
        eb:SetWidth(90)
        return eb
    end

    local xEd, yEd, scaleEd

    local function UpdatePositionEdits()
        local x, y = Echoes_GetMainWindowTopLeftOffsetsInUIParent()
        if xEd and xEd.SetText then xEd:SetText(string.format("%.1f", x or 0)) end
        if yEd and yEd.SetText then yEd:SetText(string.format("%.1f", y or 0)) end
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

    row:AddChild(CreateLabel("X"))
    xEd = CreateEdit("0")
    xEd:SetCallback("OnEnterPressed", function(widget, event, value)
        local x = tonumber(value)
        if not x then return end
        local _, y = Echoes_GetMainWindowTopLeftOffsetsInUIParent()
        y = y or 0
        Echoes_SetMainWindowTopLeftOffsetsInUIParent(x, y)
        UpdatePositionEdits()
    end)
    row:AddChild(xEd)

    row:AddChild(CreateLabel("Y"))
    yEd = CreateEdit("0")
    yEd:SetCallback("OnEnterPressed", function(widget, event, value)
        local y = tonumber(value)
        if not y then return end
        local x, _ = Echoes_GetMainWindowTopLeftOffsetsInUIParent()
        x = x or 0
        Echoes_SetMainWindowTopLeftOffsetsInUIParent(x, y)
        UpdatePositionEdits()
    end)
    row:AddChild(yEd)

    row:AddChild(CreateLabel("Scale"))
    scaleEd = CreateEdit("1.00")
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
    end)
    row:AddChild(scaleEd)

    UpdatePositionEdits()
    UpdateScaleEdit()

    self.UI = self.UI or {}
    self.UI.scaleSlider = scaleSlider
end
