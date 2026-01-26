-- Core\Defaults.lua
-- SavedVariables defaults and static config.

if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100Echoes:|r Defaults.lua executing")
end

local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")

_G.EchoesDB = _G.EchoesDB or {}

function Echoes:EnsureDefaults()
    local EchoesDB = _G.EchoesDB

    local DEFAULT_UI_SCALE = 0.92

    EchoesDB.sendAsChat         = (EchoesDB.sendAsChat ~= nil) and EchoesDB.sendAsChat or false
    EchoesDB.chatChannel        = EchoesDB.chatChannel        or "SAY"
    EchoesDB.groupTemplateIndex = EchoesDB.groupTemplateIndex or 1
    EchoesDB.classIndex         = EchoesDB.classIndex         or 1
    EchoesDB.lastPanel          = EchoesDB.lastPanel          or "BOT"
    EchoesDB.minimapAngle       = EchoesDB.minimapAngle       or 220

    -- UI scale (default slightly smaller)
    EchoesDB.uiScaleUserSet     = (EchoesDB.uiScaleUserSet ~= nil) and EchoesDB.uiScaleUserSet or false
    if EchoesDB.uiScale == nil then
        EchoesDB.uiScale = DEFAULT_UI_SCALE
    elseif (not EchoesDB.uiScaleUserSet) and tonumber(EchoesDB.uiScale) == 1.0 then
        -- Migration: older defaults were 1.0; treat as "not user-set".
        EchoesDB.uiScale = DEFAULT_UI_SCALE
    end

    -- Inventory scan
    EchoesDB.invHideKeys        = (EchoesDB.invHideKeys ~= nil) and EchoesDB.invHideKeys or false
    EchoesDB.invCrateItem       = EchoesDB.invCrateItem or nil

    -- Trade helpers
    EchoesDB.tradeFeaturesEnabled = (EchoesDB.tradeFeaturesEnabled ~= nil) and EchoesDB.tradeFeaturesEnabled or true

    -- Bot spam filter
    EchoesDB.botSpamFilterEnabled = (EchoesDB.botSpamFilterEnabled ~= nil) and EchoesDB.botSpamFilterEnabled or false

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
                    [1] = { class = "Druid",   specLabel = "Restoration" },
                    [2] = { class = "Paladin", specLabel = "Protection" },
                    [3] = { class = "Warrior", specLabel = "Protection" },
                    [4] = { class = "Priest",  specLabel = "Discipline" },
                    [5] = nil,
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
                    [1] = { class = "Paladin", specLabel = "Holy" },
                    [2] = { class = "Druid",   specLabel = "Bear" },
                    [3] = { class = "Paladin", specLabel = "Protection" },
                    [4] = { class = "Warrior", specLabel = "Protection" },
                    [5] = nil,
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

    -- Migration: move Group 1 Slot 5 to Slot 1 for 10/25 Man defaults.
    local function MoveGroup1Slot5ToSlot1(tplName)
        local t = EchoesDB.groupTemplates and EchoesDB.groupTemplates[tplName]
        if not t or not t.slots or not t.slots[1] then return end
        local g1 = t.slots[1]
        local s1 = g1[1]
        local s5 = g1[5]
        if s5 and (s1 == nil) then
            g1[1] = s5
            g1[5] = nil
        end
    end

    -- Apply to known defaults by index if they match names.
    if EchoesDB.groupTemplates[1] and EchoesDB.groupTemplates[1].name == "10 Man" then
        MoveGroup1Slot5ToSlot1(1)
    end
    if EchoesDB.groupTemplates[2] and EchoesDB.groupTemplates[2].name == "25 Man" then
        MoveGroup1Slot5ToSlot1(2)
    end
end

-- Per-tab sizes (frame stays a fixed size, grows right/down)
Echoes.FRAME_SIZES = {
    BOT    = { w = 320, h = 540 },
    -- Wide enough for the 3-column grid + Name button, but not overly tall.
    GROUP  = { w = 740, h = 440 },
    ECHOES = { w = 320, h = 360 },
}
