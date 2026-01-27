-- Core\Lifecycle.lua
-- AceAddon lifecycle and event handlers.

local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")

local function Echoes_FormatArgs(...)
    local parts = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil then
            parts[#parts + 1] = tostring(v)
        end
    end
    return table.concat(parts, ", ")
end

local function Echoes_Log(self, msg)
    if self and self.Log then
        self:Log("INFO", msg)
    end
end

local function Echoes_SlashHandler(msg, editBox)
    local addon = _G.Echoes or Echoes
    if addon and addon.ChatCommand then
        local ok, err = pcall(addon.ChatCommand, addon, msg, editBox)
        if not ok and addon.Print then
            addon:Print("Slash error: " .. tostring(err))
        end
        if not ok and addon.Log then
            addon:Log("ERROR", "Slash error: " .. tostring(err))
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

    if self.Log then
        self:Log("INFO", "Lifecycle: OnInitialize")
    end

    self:RegisterChatCommand("echoes", Echoes_SlashHandler)
    self:RegisterChatCommand("ech",    Echoes_SlashHandler)
end

function Echoes:OnEnable()
    if self.Log then
        self:Log("INFO", "Lifecycle: OnEnable")
    end
    if self.BuildMinimapButton then
        self:BuildMinimapButton()
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

    -- Additional debug events for full logging.
    self:RegisterEvent("ADDON_LOADED", "OnEchoesDebugEvent")
    self:RegisterEvent("PLAYER_LOGIN", "OnEchoesDebugEvent")
    self:RegisterEvent("PLAYER_LOGOUT", "OnEchoesDebugEvent")
    self:RegisterEvent("UI_ERROR_MESSAGE", "OnEchoesDebugEvent")
    self:RegisterEvent("CHAT_MSG_SYSTEM", "OnEchoesDebugEvent")
    self:RegisterEvent("CHAT_MSG_PARTY", "OnEchoesDebugEvent")
    self:RegisterEvent("CHAT_MSG_PARTY_LEADER", "OnEchoesDebugEvent")
    self:RegisterEvent("CHAT_MSG_RAID", "OnEchoesDebugEvent")
    self:RegisterEvent("CHAT_MSG_RAID_LEADER", "OnEchoesDebugEvent")
    self:RegisterEvent("CHAT_MSG_GUILD", "OnEchoesDebugEvent")
    self:RegisterEvent("CHAT_MSG_WHISPER_INFORM", "OnEchoesDebugEvent")
    self:RegisterEvent("CHAT_MSG_SAY", "OnEchoesDebugEvent")
    self:RegisterEvent("CHAT_MSG_YELL", "OnEchoesDebugEvent")
    self:RegisterEvent("CHAT_MSG_CHANNEL", "OnEchoesDebugEvent")
    self:RegisterEvent("TRADE_ACCEPT_UPDATE", "OnEchoesDebugEvent")
    self:RegisterEvent("TRADE_MONEY_CHANGED", "OnEchoesDebugEvent")
    self:RegisterEvent("TRADE_PLAYER_ITEM_CHANGED", "OnEchoesDebugEvent")
    self:RegisterEvent("BAG_UPDATE", "OnEchoesDebugEvent")
    self:RegisterEvent("ITEM_LOCK_CHANGED", "OnEchoesDebugEvent")

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

    if self.Log then
        self:Log("INFO", "Whisper recv from=" .. tostring(author) .. " msg=" .. tostring(msg))
    end

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
    if self.Log then
        self:Log("INFO", "Event: " .. tostring(event))
    end
    self:ProcessWhisperMessage(msg, author)
end

function Echoes:OnEchoesTradeShow()
    if self.Log then
        self:Log("INFO", "Event: TRADE_SHOW")
    end
    if self.Trade_OnShow then
        self:Trade_OnShow()
    end
end

function Echoes:OnEchoesTradeClosed()
    if self.Log then
        self:Log("INFO", "Event: TRADE_CLOSED")
    end
    if self.Trade_OnClosed then
        self:Trade_OnClosed()
    end
end

function Echoes:OnEchoesTradeTargetItemChanged()
    if self.Log then
        self:Log("INFO", "Event: TRADE_TARGET_ITEM_CHANGED")
    end
    if self.Trade_OnTargetItemChanged then
        self:Trade_OnTargetItemChanged()
    end
end

function Echoes:OnEchoesRosterOrSpecChanged()
    if self.Log then
        self:Log("INFO", "Event: roster/spec changed")
    end
    if self.UpdateGroupCreationFromRoster then
        self:UpdateGroupCreationFromRoster(false)
    end

    -- Keep Bot Inventories bar in sync as members join/leave.
    if self.Inv_RefreshMembers then
        self:Inv_RefreshMembers()
    end
end

function Echoes:OnEchoesDebugEvent(event, ...)
    if not self.Log then return end
    local args = Echoes_FormatArgs(...)
    if args ~= "" then
        self:Log("INFO", "Event: " .. tostring(event) .. " args=" .. args)
    else
        self:Log("INFO", "Event: " .. tostring(event))
    end
end

function Echoes:OnDisable()
end
