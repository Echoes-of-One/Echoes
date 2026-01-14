local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")
local AceGUI = LibStub("AceGUI-3.0")

-- Pull shared helpers from the core file.
local Clamp = Echoes.Clamp
local SkinHeading = Echoes.SkinHeading
local SkinLabel = Echoes.SkinLabel

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
        Echoes._EchoesPendingUiScale = nil
        Echoes:ApplyScale()
    end)
    container:AddChild(scaleSlider)

    self.UI = self.UI or {}
    self.UI.scaleSlider = scaleSlider
end
