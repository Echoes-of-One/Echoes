-- Core\Lifecycle.lua
-- AceAddon lifecycle and event handlers.

local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")

local NormalizeName = Echoes.NormalizeName

function Echoes:OnInitialize()
    -- Ensure saved vars exist and defaults are present.
    if self.EnsureDefaults then
        self:EnsureDefaults()
    end

    self:RegisterChatCommand("echoes", "ChatCommand")
    self:RegisterChatCommand("ech",    "ChatCommand")

    -- Fallback slash registration (in case AceConsole registration fails).
    if not _G.SlashCmdList or not _G.SLASH_ECHOES1 then
        _G.SlashCmdList = _G.SlashCmdList or {}
        _G.SLASH_ECHOES1 = "/echoes"
        _G.SLASH_ECHOES2 = "/ech"
        _G.SlashCmdList["ECHOES"] = function(msg)
            if Echoes and Echoes.ChatCommand then
                Echoes:ChatCommand(msg)
            end
        end
    end
end

function Echoes:OnEnable()
    if self.BuildMinimapButton then
        self:BuildMinimapButton()
    end

    -- Keep Group Creation in sync with roster changes and player spec changes.
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEchoesRosterOrSpecChanged")
    self:RegisterEvent("RAID_ROSTER_UPDATE", "OnEchoesRosterOrSpecChanged")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED", "OnEchoesRosterOrSpecChanged")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "OnEchoesRosterOrSpecChanged")
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "OnEchoesRosterOrSpecChanged")

    -- Bot "Hello!" whisper detection for invite verification.
    self:RegisterEvent("CHAT_MSG_WHISPER", "OnEchoesChatMsgWhisper")
end

function Echoes:OnEchoesChatMsgWhisper(event, msg, author)
    msg = tostring(msg or "")
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")

    author = NormalizeName(author)
    if author == "" then return end

    -- 0) Inventory scan responses (opt-in: only consumes messages starting with "items").
    if self.Inv_OnWhisper then
        self:Inv_OnWhisper(msg, author)
    end

    if msg ~= "Hello!" then return end

    -- 1) Group Creation invite verification.
    if self._EchoesInviteSessionActive then
        self._EchoesInviteHelloFrom = self._EchoesInviteHelloFrom or {}
        self._EchoesInviteHelloFrom[author] = true

        -- If the invite queue is waiting for a Hello handshake, bind this sender to the current step.
        if self._EchoesWaitHelloActive and (not self._EchoesWaitHelloName or self._EchoesWaitHelloName == "") then
            self._EchoesWaitHelloName = author

            -- Lock in the planned spec/class for this bot name so party->raid reordering doesn't lose it.
            if self._EchoesWaitHelloPlan and type(self._EchoesWaitHelloPlan) == "table" then
                self._EchoesPlannedTalentByName = self._EchoesPlannedTalentByName or {}
                local k = author:lower()
                self._EchoesPlannedTalentByName[k] = {
                    classText = tostring(self._EchoesWaitHelloPlan.classText or ""),
                    specLabel = tostring(self._EchoesWaitHelloPlan.specLabel or ""),
                    group = tonumber(self._EchoesWaitHelloPlan.group) or nil,
                    slot = tonumber(self._EchoesWaitHelloPlan.slot) or nil,
                }
            end
        end
    end

    -- 2) Bot Control "Add" verification.
    if self._EchoesBotAddSessionActive then
        self._EchoesBotAddHelloFrom = self._EchoesBotAddHelloFrom or {}
        self._EchoesBotAddHelloFrom[author] = true
    end
end

function Echoes:OnEchoesRosterOrSpecChanged()
    if self.UpdateGroupCreationFromRoster then
        self:UpdateGroupCreationFromRoster(false)
    end

    -- Keep Bot Inventories bar in sync as members join/leave.
    if self.Inv_RefreshMembers then
        self:Inv_RefreshMembers()
    end
end

function Echoes:OnDisable()
end
