-- Core\SpecPanel.lua
-- Target Spec Whisper frame (toggleable + movable)

local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")

local SkinBackdrop = Echoes.SkinBackdrop
local SetEchoesFont = Echoes.SetEchoesFont
local ECHOES_FONT_FLAGS = Echoes.ECHOES_FONT_FLAGS
local ForceFontFaceOnFrame = Echoes.ForceFontFaceOnFrame

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
        width = math.max(width, 160)
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
        ForceFontFaceOnFrame(self)
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

    f:ClearAllPoints()
    if anchorFrame and anchorFrame.GetPoint then
        f:SetPoint("TOPRIGHT", anchorFrame, "TOPLEFT", -8, 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

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
