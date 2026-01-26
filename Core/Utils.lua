-- Core\Utils.lua
-- Generic helpers, command mapping, timers/action queue, and shared data lists.

if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100Echoes:|r Utils.lua executing")
end

local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")

local function Echoes_Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100Echoes:|r " .. tostring(msg))
end

local function Clamp(v, minv, maxv)
    if v < minv then return minv end
    if v > maxv then return maxv end
    return v
end

local function Echoes_NormalizeName(name)
    name = tostring(name or "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    name = name:gsub("%-.+$", "")
    return name
end

function Echoes:NormalizeAndClampMainWindowToScreen()
    local widget = self.UI and self.UI.frame
    local f = widget and widget.frame
    if not f or not UIParent then return end

    if not (f.GetWidth and f.GetHeight and f.SetPoint and f.ClearAllPoints) then
        return
    end

    local parentW = (UIParent.GetWidth and UIParent:GetWidth()) or (GetScreenWidth and GetScreenWidth())
    local parentH = (UIParent.GetHeight and UIParent:GetHeight()) or (GetScreenHeight and GetScreenHeight())
    local parentTop = parentH
    if UIParent.GetRect then
        local _, pb, _, ph = UIParent:GetRect()
        if pb and ph then
            parentTop = pb + ph
        end
    end
    if not parentW or not parentH then return end

    -- Determine current TOPLEFT anchor offsets in UIParent coordinate space.
    -- IMPORTANT: Do not read or write SavedVariables here; this function should only clamp
    -- the *current* position (otherwise we can "snap back" after normal dragging).
    local x, y

    if f.GetPoint then
        local point, relTo, relPoint, xOfs, yOfs = f:GetPoint(1)
        local rel = relTo or UIParent
        local rPoint = relPoint or point
        if point == "TOPLEFT" and rel == UIParent and rPoint == "TOPLEFT" then
            x, y = tonumber(xOfs) or 0, tonumber(yOfs) or 0
        end

        if not x or not y then
            if point == "CENTER" and rel == UIParent and rPoint == "CENTER" and xOfs and yOfs and f.GetWidth and f.GetHeight then
                local scale = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
                local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
                if scale <= 0 then scale = 1 end
                if parentScale <= 0 then parentScale = 1 end
                local w = (f:GetWidth() or 0) * (scale / parentScale)
                local h = (f:GetHeight() or 0) * (scale / parentScale)
                x = tonumber(xOfs) - (w * 0.5)
                y = tonumber(yOfs) - parentTop + (h * 0.5)
            end
        end

        if not x or not y then
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

            if topOfs and leftOfs and UIParent.GetHeight then
                local parentH = UIParent:GetHeight() or 0
                x, y = leftOfs, topOfs - parentTop
            end
        end
    end

    -- Fallback: compute from center position (scale-aware).
    if (not x or not y) and f.GetCenter and f.GetWidth and f.GetHeight and f.GetEffectiveScale and UIParent.GetEffectiveScale then
        local cx, cy = f:GetCenter()
        if cx and cy then
            local scale = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
            local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
            if scale <= 0 then scale = 1 end
            if parentScale <= 0 then parentScale = 1 end
            local w = (f:GetWidth() or 0) * (scale / parentScale)
            local h = (f:GetHeight() or 0) * (scale / parentScale)
            x = cx - (w * 0.5)
            y = (cy + (h * 0.5)) - parentTop
        end
    end

    if not x or not y then return end

    local scale = (f.GetEffectiveScale and f:GetEffectiveScale()) or 1
    local parentScale = (UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if scale <= 0 then scale = 1 end
    if parentScale <= 0 then parentScale = 1 end

    local w = (f:GetWidth() or 0) * (scale / parentScale)
    local h = (f:GetHeight() or 0) * (scale / parentScale)

    local margin = 0

    if w <= 0 or h <= 0 or w > parentW or h > parentH then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        return
    end

    local minX = margin
    local maxX = parentW - margin - w
    -- With TOPLEFT->TOPLEFT anchoring, y is negative when the frame is moved downward.
    local minY = (-parentH) + margin + h
    local maxY = -margin

    x = Clamp(x, minX, maxX)
    y = Clamp(y, minY, maxY)

    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
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

    if classFile == "DRUID" and norm == "feralcombat" then
        return "Feral"
    end

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

    local EchoesDB = _G.EchoesDB

    if EchoesDB.sendAsChat then
        SendChatMessage(cmd, EchoesDB.chatChannel or "SAY")
    else
        SendChatMessage(cmd, "PARTY")
    end
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
            if Echoes._EchoesWaitHelloActive then
                local nextAction = Echoes._EchoesActionQueue and Echoes._EchoesActionQueue[1]
                if nextAction and nextAction.kind == "kick" then
                    -- Kicks don't need to wait for Hello responses.
                else
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

            local a = Echoes._EchoesActionQueue[1]
            if not a then return end

            if Echoes._EchoesInviteSessionActive and Echoes._EchoesInviteNeedsRaid and type(ConvertToRaid) == "function" then
                local nRaid = (type(GetNumRaidMembers) == "function" and GetNumRaidMembers()) or 0
                local inRaid = (nRaid and nRaid > 0)
                if not inRaid and type(GetNumPartyMembers) == "function" then
                    local nParty = GetNumPartyMembers() or 0
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
            elseif a.kind == "kick" then
                if a.name and a.name ~= "" then
                    if type(SendChatMessage) == "function" then
                        SendChatMessage("logout", "WHISPER", nil, a.name)
                    end
                    if type(UninviteUnit) == "function" then
                        UninviteUnit(a.name)
                    end
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
    local EchoesDB = _G.EchoesDB
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

-- Exports used by other files/modules
Echoes.Print = Echoes_Print
Echoes.Clamp = Clamp
Echoes.NormalizeName = Echoes_NormalizeName
Echoes.IsNameInGroup = Echoes_IsNameInGroup
Echoes.GetPlayerSpecLabel = Echoes_GetPlayerSpecLabel
Echoes.SendCmdKey = SendCmdKey
Echoes.GetSelectedClass = GetSelectedClass

Echoes.CLASSES = CLASSES
Echoes.GROUP_TEMPLATES = GROUP_TEMPLATES
Echoes.GROUP_SLOT_OPTIONS = GROUP_SLOT_OPTIONS
Echoes.DEFAULT_CYCLE_VALUES = DEFAULT_CYCLE_VALUES
Echoes.GetCycleValuesForRightText = GetCycleValuesForRightText
