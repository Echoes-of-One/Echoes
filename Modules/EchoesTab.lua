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

    if f.GetPoint then
        local point, relTo, relPoint, xOfs, yOfs = f:GetPoint(1)
        if point == "TOPLEFT" and relTo == UIParent and relPoint == "TOPLEFT" and xOfs and yOfs then
            return tonumber(xOfs), tonumber(yOfs)
        end
    end

    if not (f.GetLeft and f.GetTop and f.GetEffectiveScale and UIParent.GetEffectiveScale and UIParent.GetHeight) then
        return nil, nil
    end

    local left = f:GetLeft()
    local top = f:GetTop()
    if not left or not top then return nil, nil end

    local scale = f:GetEffectiveScale() or 1
    local parentScale = UIParent:GetEffectiveScale() or 1
    if scale <= 0 then scale = 1 end
    if parentScale <= 0 then parentScale = 1 end

    local parentH = UIParent:GetHeight() or 0
    local x = (left * scale) / parentScale
    local y = ((top * scale) / parentScale) - parentH
    return x, y
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

    -- When the user starts dragging the slider, record the current TOPLEFT.
    local function RecordScaleDragAnchor()
        if Echoes._EchoesScaleDragX and Echoes._EchoesScaleDragY then return end
        local x, y = Echoes_GetMainWindowTopLeftOffsetsInUIParent()
        Echoes._EchoesScaleDragX = x
        Echoes._EchoesScaleDragY = y
    end

    if scaleSlider.frame and scaleSlider.frame.HookScript then
        scaleSlider.frame:HookScript("OnMouseDown", RecordScaleDragAnchor)
    end
    if scaleSlider.slider and scaleSlider.slider.HookScript then
        scaleSlider.slider:HookScript("OnMouseDown", RecordScaleDragAnchor)
    end

    -- IMPORTANT: applying scale while dragging the slider resizes the slider itself,
    -- which can make AceGUI's Slider jump to the minimum due to the changing mouse/value mapping.
    -- We only apply the scale after the user releases the mouse.
    scaleSlider:SetCallback("OnValueChanged", function(widget, event, value)
        RecordScaleDragAnchor()
        local v = tonumber(value) or (EchoesDB.uiScale or 1.0)
        v = Clamp(v, 0.5, 2.0)
        Echoes._EchoesPendingUiScale = v
    end)
    scaleSlider:SetCallback("OnMouseUp", function(widget, event, value)
        RecordScaleDragAnchor()
        local v = tonumber(value) or Echoes._EchoesPendingUiScale or (EchoesDB.uiScale or 1.0)
        v = Clamp(v, 0.5, 2.0)
        EchoesDB.uiScale = v
        EchoesDB.uiScaleUserSet = true
        Echoes._EchoesPendingUiScale = nil

        -- Lock the frame's anchor to TOPLEFT *before* scaling so it visually grows right/down
        -- instead of expanding from CENTER.
        local keepX, keepY = Echoes._EchoesScaleDragX, Echoes._EchoesScaleDragY
        if keepX and keepY then
            Echoes_SetMainWindowTopLeftOffsetsInUIParent(keepX, keepY)
        end

        Echoes:ApplyScale()
        Echoes._EchoesScaleDragX, Echoes._EchoesScaleDragY = nil, nil

        if keepX and keepY and Echoes.RunAfter then
            Echoes:RunAfter(0.05, function()
                Echoes_SetMainWindowTopLeftOffsetsInUIParent(keepX, keepY)
                if Echoes.NormalizeAndClampMainWindowToScreen then
                    Echoes:NormalizeAndClampMainWindowToScreen()
                end
            end)
        end
    end)
    container:AddChild(scaleSlider)

    self.UI = self.UI or {}
    self.UI.scaleSlider = scaleSlider
end
