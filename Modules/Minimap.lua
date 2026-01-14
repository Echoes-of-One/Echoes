local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")

-- Pull shared helpers from the core file.
local SetEchoesFont = Echoes.SetEchoesFont
local ECHOES_FONT_FLAGS = Echoes.ECHOES_FONT_FLAGS

------------------------------------------------------------
-- Minimap button
------------------------------------------------------------
local MinimapBtn

local function MinimapButton_UpdatePosition()
    if not MinimapBtn then return end

    local EchoesDB = _G.EchoesDB
    if not EchoesDB then return end

    local angle  = tonumber(EchoesDB.minimapAngle) or 220
    local radius = 80
    local bx = radius * math.cos(math.rad(angle))
    local by = radius * math.sin(math.rad(angle))

    MinimapBtn:ClearAllPoints()
    MinimapBtn:SetPoint("CENTER", Minimap, "CENTER", bx, by)
end

local function MinimapButton_OnDragUpdate()
    local EchoesDB = _G.EchoesDB
    if not EchoesDB then return end

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

    local b = CreateFrame("Button", nil, Minimap)
    MinimapBtn = b
    b:SetSize(32, 32)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton", "RightButton")
    b:SetHighlightTexture(nil)

    -- Circular minimap-style button with a visible background color.
    -- We use Blizzard's tracking background as the alpha shape, tinted dark blue.
    local fill = b:CreateTexture(nil, "BACKGROUND")
    fill:SetTexture("Interface\\Minimap\\MiniMap-TrackingBackground")
    fill:SetSize(54, 54)
    fill:SetPoint("CENTER", b, "CENTER", 10, -12)
    fill:SetVertexColor(0.06, 0.10, 0.26, 1.0)
    b._EchoesFill = fill

    -- Optional subtle texture layer (same circular shape, low alpha)
    local bg = b:CreateTexture(nil, "BORDER")
    bg:SetTexture("Interface\\Minimap\\MiniMap-TrackingBackground")
    bg:SetSize(54, 54)
    bg:SetPoint("CENTER", b, "CENTER", 10, -12)
    bg:SetVertexColor(0.18, 0.22, 0.35, 0.20)
    b._EchoesBG = bg

    local border = b:CreateTexture(nil, "ARTWORK")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("CENTER", b, "CENTER", 10, -12)
    b._EchoesBorder = border

    local label = b:CreateFontString(nil, "OVERLAY")
    label:SetPoint("CENTER", b, "CENTER", 0, 0)
    label:SetTextColor(0.95, 0.82, 0.25, 1)
    SetEchoesFont(label, 16, ECHOES_FONT_FLAGS)
    label:SetText("E")

    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Echoes\n|cffAAAAAALeft-click: Toggle window\nRight-drag: Move\nCtrl+Click to reset position.|r")
        GameTooltip:Show()
    end)

    b:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    b:SetScript("OnClick", function(self, button)
        if type(IsControlKeyDown) == "function" and IsControlKeyDown() then
            Echoes:ResetMainWindowPosition()
            return
        end
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
