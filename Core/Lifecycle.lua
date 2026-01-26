-- Core\Lifecycle.lua
-- AceAddon lifecycle and event handlers.

if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100Echoes:|r Lifecycle.lua executing")
end

local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")

local function Echoes_SlashHandler(msg, editBox)
    local addon = _G.Echoes or Echoes
    if addon and addon.ChatCommand then
        local ok, err = pcall(addon.ChatCommand, addon, msg, editBox)
        if not ok and addon.Print then
            addon:Print("Slash error: " .. tostring(err))
        end
    end
end

-- Fallback slash registration at file load (avoids missing commands on some clients).
_G.SlashCmdList = _G.SlashCmdList or {}
_G.SLASH_ECHOES1 = "/echoes"
_G.SLASH_ECHOES2 = "/ech"
_G.SlashCmdList["ECHOES"] = Echoes_SlashHandler

local NormalizeName = Echoes.NormalizeName

function Echoes:OnInitialize()
    -- Ensure saved vars exist and defaults are present.
    if self.EnsureDefaults then
        self:EnsureDefaults()
    end

    self:RegisterChatCommand("echoes", Echoes_SlashHandler)
    self:RegisterChatCommand("ech",    Echoes_SlashHandler)
end

function Echoes:OnEnable()
    if self.BuildMinimapButton then
        self:BuildMinimapButton()
    end

    do
        local loaded = tostring(self._GroupTabLoaded)
        local guid = tostring(self._EchoesGuid)
        local gguid = tostring(self._GroupTabGuid)
        if self.Print then
            self:Print("GroupTab load status: loaded=" .. loaded .. " guid=" .. guid .. " gguid=" .. gguid)
        elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100Echoes:|r GroupTab load status: loaded=" .. loaded .. " guid=" .. guid .. " gguid=" .. gguid)
        end
    end

    -- Prebuild the main window and last active tab so /echoes never opens to a blank page.
    if self.CreateMainWindow and self.SetActiveTab then
        self:CreateMainWindow()
        local EchoesDB = _G.EchoesDB
        local last = (EchoesDB and EchoesDB.lastPanel) or "BOT"
        if last ~= "BOT" and last ~= "GROUP" and last ~= "ECHOES" then
            last = "BOT"
        end
        self:SetActiveTab(last)
        if self.UI and self.UI.frame and self.UI.frame.Hide then
            self.UI.frame:Hide()
        end
    end

    -- Keep Group Creation in sync with roster changes and player spec changes.
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEchoesRosterOrSpecChanged")
    self:RegisterEvent("RAID_ROSTER_UPDATE", "OnEchoesRosterOrSpecChanged")
    self:RegisterEvent("PARTY_MEMBERS_CHANGED", "OnEchoesRosterOrSpecChanged")
    self:RegisterEvent("PLAYER_TALENT_UPDATE", "OnEchoesRosterOrSpecChanged")
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED", "OnEchoesRosterOrSpecChanged")

    -- Bot "Hello!" whisper detection for invite verification.
    if _G.EchoesDB and _G.EchoesDB.botSpamFilterEnabled then
        if self.InstallChatMessageCleanup then
            self:InstallChatMessageCleanup()
        end
    else
        self:RegisterEvent("CHAT_MSG_WHISPER", "OnEchoesChatMsgWhisper")
    end

    -- Trade helper frame events.
    self:RegisterEvent("TRADE_SHOW", "OnEchoesTradeShow")
    self:RegisterEvent("TRADE_CLOSED", "OnEchoesTradeClosed")
    self:RegisterEvent("TRADE_TARGET_ITEM_CHANGED", "OnEchoesTradeTargetItemChanged")
end

function Echoes:ShouldSuppressWhisper(msg)
    return false
end

function Echoes:ProcessWhisperMessage(msg, author)
    msg = tostring(msg or "")
    msg = msg:gsub("^%s+", ""):gsub("%s+$", "")

    author = NormalizeName(author)
    if author == "" then return false end

    if self.Inv_OnWhisper then
        self:Inv_OnWhisper(msg, author)
    end

    if self.Inv_OnSellWhisper then
        self:Inv_OnSellWhisper(msg, author)
    end

    if self.Trade_OnWhisper then
        self:Trade_OnWhisper(msg, author)
    end

    if msg == "Hello!" then
        if self._EchoesInviteSessionActive then
            self._EchoesInviteHelloFrom = self._EchoesInviteHelloFrom or {}
            self._EchoesInviteHelloFrom[author] = true

            if self._EchoesWaitHelloActive and (not self._EchoesWaitHelloName or self._EchoesWaitHelloName == "") then
                self._EchoesWaitHelloName = author

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

        if self._EchoesBotAddSessionActive then
            self._EchoesBotAddHelloFrom = self._EchoesBotAddHelloFrom or {}
            self._EchoesBotAddHelloFrom[author] = true
        end
    end

    return self:ShouldSuppressWhisper(msg)
end

function Echoes:InstallChatMessageCleanup()
    if self._EchoesChatCleanupInstalled then return end
    self._EchoesChatCleanupInstalled = true

    if type(ChatFrame_AddMessageEventFilter) ~= "function" then
        self:RegisterEvent("CHAT_MSG_WHISPER", "OnEchoesChatMsgWhisper")
        return
    end

    ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", function(_, _, msg, author, ...)
        local suppress = false
        if Echoes and Echoes.ProcessWhisperMessage then
            suppress = Echoes:ProcessWhisperMessage(msg, author)
        end
        if _G.EchoesDB and _G.EchoesDB.botSpamFilterEnabled then
            return suppress
        end
        return false
    end)
end

function Echoes:OnEchoesChatMsgWhisper(event, msg, author)
    self:ProcessWhisperMessage(msg, author)
end

function Echoes:OnEchoesTradeShow()
    if self.Trade_OnShow then
        self:Trade_OnShow()
    end
end

function Echoes:OnEchoesTradeClosed()
    if self.Trade_OnClosed then
        self:Trade_OnClosed()
    end
end

function Echoes:OnEchoesTradeTargetItemChanged()
    if self.Trade_OnTargetItemChanged then
        self:Trade_OnTargetItemChanged()
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
