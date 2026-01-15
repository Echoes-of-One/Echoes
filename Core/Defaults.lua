-- Core\Defaults.lua
-- SavedVariables defaults and static config.

local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")

_G.EchoesDB = _G.EchoesDB or {}

function Echoes:EnsureDefaults()
    local EchoesDB = _G.EchoesDB

    EchoesDB.sendAsChat         = (EchoesDB.sendAsChat ~= nil) and EchoesDB.sendAsChat or false
    EchoesDB.chatChannel        = EchoesDB.chatChannel        or "SAY"
    EchoesDB.groupTemplateIndex = EchoesDB.groupTemplateIndex or 1
    EchoesDB.classIndex         = EchoesDB.classIndex         or 1
    EchoesDB.lastPanel          = EchoesDB.lastPanel          or "BOT"
    EchoesDB.minimapAngle       = EchoesDB.minimapAngle       or 220
    EchoesDB.uiScale            = EchoesDB.uiScale            or 1.0

    -- Inventory scan
    EchoesDB.invHideKeys        = (EchoesDB.invHideKeys ~= nil) and EchoesDB.invHideKeys or false
    EchoesDB.invCrateItem       = EchoesDB.invCrateItem or nil

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
                    [1] = nil,
                    [2] = { class = "Paladin", specLabel = "Protection" },
                    [3] = { class = "Warrior", specLabel = "Protection" },
                    [4] = { class = "Priest",  specLabel = "Discipline" },
                    [5] = { class = "Druid",   specLabel = "Restoration" },
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
                    [1] = nil,
                    [2] = { class = "Druid",   specLabel = "Bear" },
                    [3] = { class = "Paladin", specLabel = "Protection" },
                    [4] = { class = "Warrior", specLabel = "Protection" },
                    [5] = { class = "Paladin", specLabel = "Holy" },
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
end

-- Per-tab sizes (frame stays a fixed size, grows right/down)
Echoes.FRAME_SIZES = {
    BOT    = { w = 320, h = 480 },
    -- Wide enough for the 3-column grid + Name button, but not overly tall.
    GROUP  = { w = 740, h = 440 },
    ECHOES = { w = 320, h = 360 },
}
