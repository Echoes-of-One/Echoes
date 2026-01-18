-- Core\Inventory.lua
-- /echoes inv: request "items" from party/raid members and display results in a small UI.

local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")

local NormalizeName = Echoes.NormalizeName
local Echoes_Print = Echoes.Print
local SkinBackdrop = Echoes.SkinBackdrop
local SetEchoesFont = Echoes.SetEchoesFont
local ECHOES_FONT_FLAGS = Echoes.ECHOES_FONT_FLAGS

local CRATE_ITEM_FALLBACK_NAME = "Foror's Crate of Endless Resist Gear Storage"
local CRATE_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"
local CLASS_ICON_ATLAS = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
local CLASS_ICON_COORDS = {
    WARRIOR = { 0.00, 0.25, 0.00, 0.25 },
    MAGE = { 0.25, 0.50, 0.00, 0.25 },
    ROGUE = { 0.50, 0.75, 0.00, 0.25 },
    DRUID = { 0.75, 1.00, 0.00, 0.25 },
    HUNTER = { 0.00, 0.25, 0.25, 0.50 },
    SHAMAN = { 0.25, 0.50, 0.25, 0.50 },
    PRIEST = { 0.50, 0.75, 0.25, 0.50 },
    WARLOCK = { 0.75, 1.00, 0.25, 0.50 },
    PALADIN = { 0.00, 0.25, 0.50, 0.75 },
    DEATHKNIGHT = { 0.25, 0.50, 0.50, 0.75 },
}

local TryResolveEntryInPlace
local EntryKey

local CLASS_NAME_TO_FILE = {}
if _G.LOCALIZED_CLASS_NAMES_MALE then
    for file, loc in pairs(_G.LOCALIZED_CLASS_NAMES_MALE) do
        if loc and file then
            CLASS_NAME_TO_FILE[loc] = file
        end
    end
end
if _G.LOCALIZED_CLASS_NAMES_FEMALE then
    for file, loc in pairs(_G.LOCALIZED_CLASS_NAMES_FEMALE) do
        if loc and file then
            CLASS_NAME_TO_FILE[loc] = file
        end
    end
end

local function Trim(s)
    s = tostring(s or "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function GetCrateIconTexture()
    local EchoesDB = _G.EchoesDB
    local configured = EchoesDB and EchoesDB.invCrateItem
    local itemKey = configured and Trim(configured)
    if not itemKey or itemKey == "" then
        itemKey = CRATE_ITEM_FALLBACK_NAME
    end

    if type(GetItemInfo) == "function" then
        local _, _, _, _, _, _, _, _, _, tex = GetItemInfo(itemKey)
        if tex then return tex end
    end

    return CRATE_ICON_FALLBACK
end

local function IsInventoryHeaderLine(msg)
    msg = Trim(msg)
    if msg == "" then return false end
    local lower = msg:lower()
    if lower:match("^=+%s*inventory%s*=+") then return true end
    if lower:match("^inventory%s*$") then return true end
    return false
end
local function GetEntryName(entry)
    if not entry then return "" end
    if entry.name and entry.name ~= "" then
        return tostring(entry.name)
    end
    if entry.link and entry.link ~= "" then
        local n = entry.link:match("%[(.-)%]")
        if n and n ~= "" then return n end
    end
    if entry.itemId and type(GetItemInfo) == "function" then
        local name = GetItemInfo(entry.itemId)
        if name and name ~= "" then return name end
    end
    return ""
end

local function IsKeyEntry(entry)
    local itemId = entry and entry.itemId
    local link = entry and entry.link

    if type(GetItemInfo) == "function" then
        local name, _, _, _, _, itemType, itemSubType = GetItemInfo(itemId or link or GetEntryName(entry))
        if itemType == "Key" or itemSubType == "Key" then
            return true
        end
        if name and type(name) == "string" then
            if name:lower():find("key", 1, true) then
                return true
            end
        end
    end

    local n = GetEntryName(entry)
    if n ~= "" and n:lower():find("key", 1, true) then
        return true
    end
    return false
end

-- Items we never want to display in the inventory UI (e.g. dungeon/attunement keys).
-- This is intentionally a simple name set; extend as needed.
local INV_ALWAYS_HIDDEN_NAMES = {
    ["The Master's Key"] = true,
    ["Shadow Labyrinth Key"] = true,
    ["Shattered Halls Key"] = true,
    ["Flamewrought Key"] = true,
    ["Reservoir Key"] = true,
    ["Auchenai Key"] = true,
    ["Warpforged Key"] = true,
    ["Key of Time"] = true,
    ["Key to the Arcatraz"] = true,
}

local function IsAlwaysHiddenEntry(entry)
    local name = Trim(GetEntryName(entry))
    if name == "" then return false end

    if INV_ALWAYS_HIDDEN_NAMES[name] then
        return true
    end

    -- If the name clearly looks like a key, hide it even if item type info isn't available.
    local lower = name:lower()
    if lower:match(" key$") then return true end
    if lower:match("^key to ") then return true end
    if lower:match("^key of ") then return true end

    return false
end

local function ParseSoldItemFromMessage(msg)
    msg = Trim(msg)
    if msg == "" then return nil end
    if not msg:lower():match("^selling") then return nil end

    local link = msg:match("(|c%x%x%x%x%x%x%x%x|Hitem:.-|h.-|h|r)")
    if link then
        local name = link:match("%[(.-)%]")
        return { link = link, name = name }
    end

    local name = msg:match("^Selling%s+%[([^%]]+)%]")
    if not name then
        name = msg:match("^Selling%s+(.+)$")
    end
    name = Trim(name or "")
    if name ~= "" then
        return { name = name }
    end

    return nil
end

local function GetGroupMemberNames()
    local names = {}

    local me = ""
    if type(UnitName) == "function" then
        me = NormalizeName(UnitName("player"))
    end

    local seen = {}
    local function ResolveClassFile(classFile, className)
        if classFile and CLASS_ICON_COORDS[classFile] then
            return classFile
        end
        if className and CLASS_NAME_TO_FILE[className] then
            return CLASS_NAME_TO_FILE[className]
        end
        return classFile
    end

    local function addMember(name, classFile, className)
        if not name or name == "" then return end
        local norm = NormalizeName(name)
        if norm == "" or norm == me or seen[norm] then return end
        seen[norm] = true
        classFile = ResolveClassFile(classFile, className)
        names[#names + 1] = {
            name = norm,
            classFile = classFile,
            display = name,
        }
    end

    -- Raid
    if type(GetNumRaidMembers) == "function" and type(GetRaidRosterInfo) == "function" then
        local n = GetNumRaidMembers() or 0
        if n > 0 then
            for i = 1, n do
                local name, _, _, _, className, classFile = GetRaidRosterInfo(i)
                addMember(name, classFile, className)
            end
            return names
        end
    end

    -- Party
    if type(GetNumPartyMembers) == "function" then
        local nParty = GetNumPartyMembers() or 0
        if nParty > 0 then
            if type(UnitName) == "function" then
                for i = 1, math.min(4, nParty) do
                    local unit = "party" .. i
                    local name = UnitName(unit)
                    local className, classFile = type(UnitClass) == "function" and UnitClass(unit) or nil
                    addMember(name, classFile, className)
                end
            end
            return names
        end
    end

    -- Solo: just player
    return names
end

local function GetClassIconTexture(classFile)
    if classFile and type(classFile) == "string" then
        local coords = CLASS_ICON_COORDS[classFile]
        if coords then
            return CLASS_ICON_ATLAS, coords
        end
    end
    return GetCrateIconTexture(), nil
end

local function IsSelf(name)
    if type(UnitName) ~= "function" then return false end
    local me = NormalizeName(UnitName("player"))
    return me ~= "" and NormalizeName(name) == me
end

-- Parses item responses from a message string.
-- Supported formats (examples):
--   "items [Frostweave Cloth]x20, [Infinite Dust] x5"
--   "items 12345:20, 67890:5"
-- Returns: array of { itemId=?, link=?, count=? }
local function ParseItemsFromMessage(msg)
    msg = Trim(msg)
    local lower = msg:lower()

    -- Strip leading "items" keyword if present.
    if lower:match("^items%s") or lower == "items" then
        msg = Trim(msg:gsub("^[Ii][Tt][Ee][Mm][Ss]", "", 1))
    end

    local items = {}

    -- IMPORTANT: WoW item links contain many ":<number>" segments (e.g. "item:17030:0:0...").
    -- If we run a naive "itemId:count" parser on a message that contains links, we will
    -- accidentally treat "item:<id>:0" as an id/count pair and create a bogus count=1 entry.
    -- So: only parse explicit id:count pairs when there are *no* item links in the message.
    local hasLinks = msg:find("|Hitem:", 1, true) ~= nil

    -- 1) Parse WoW item links with optional xN counts after each.
    local i = 1
    while true do
        local s, e = msg:find("|Hitem:", i, true)
        if not s then break end

        local linkStart = msg:find("|c", math.max(1, s - 20), true) or s
        local linkEnd = msg:find("|h|r", e, true)
        if not linkEnd then break end
        linkEnd = linkEnd + 3

        local link = msg:sub(linkStart, linkEnd)

        local after = msg:sub(linkEnd + 1)
        local count = after:match("^%s*[xX]%s*(%d+)")
        count = tonumber(count) or 1

        items[#items + 1] = { itemId = nil, link = link, count = math.max(1, count) }

        i = linkEnd + 1
    end

    -- 2) Parse explicit itemID:count pairs (only when there are no embedded item links).
    if not hasLinks then
        for itemId, count in msg:gmatch("(%d+)%s*[:=]%s*(%d+)") do
            local idNum = tonumber(itemId)
            local cNum = tonumber(count) or 1
            if idNum and idNum > 0 then
                items[#items + 1] = { itemId = idNum, link = nil, count = math.max(1, cNum) }
            end
        end
    end

    return items
end

local function ParseItemsFromInventoryLine(msg)
    msg = Trim(msg)
    if msg == "" then return {} end

    -- Ignore obvious headers/separators.
    if msg:match("^=+") then return {} end
    if msg:lower():find("inventory", 1, true) then
        if msg:match("^=+%s*inventory%s*=+") then
            return {}
        end
    end

    -- Item link in message
    if msg:find("|Hitem:", 1, true) then
        local items = ParseItemsFromMessage("items " .. msg)
        if #items > 0 then return items end
    end

    -- Bracket name like: [Earth Totem] (soulbound) or [Ankh]x20
    local bracketName, countStr = msg:match("^%[([^%]]+)%]%s*[xX]?%s*(%d*)")
    if bracketName and bracketName ~= "" then
        local count = tonumber(countStr)
        if not count or count < 1 then count = 1 end
        return { { itemId = nil, link = nil, name = Trim(bracketName), count = count } }
    end

    -- Fallback: itemId:count
    local id, c = msg:match("^(%d+)%s*[:=]%s*(%d+)")
    if id then
        return { { itemId = tonumber(id), link = nil, count = math.max(1, tonumber(c) or 1) } }
    end

    return {}
end

local function EnsureInvState(self)
    self.Inv = self.Inv or {}
    self.Inv.responses = self.Inv.responses or {}
    self.Inv.byName = self.Inv.byName or {}
    self.Inv.members = self.Inv.members or {}
    self.UI = self.UI or {}
end

local function EnsureTradeState(self)
    self.Trade = self.Trade or {}
    self.Trade.byName = self.Trade.byName or {}
    self.UI = self.UI or {}
end

local function TradeFeaturesEnabled()
    local EchoesDB = _G.EchoesDB
    return not (EchoesDB and EchoesDB.tradeFeaturesEnabled == false)
end

local function GetTradeTargetName()
    local name = nil
    if _G.TradeFrameRecipientNameText and _G.TradeFrameRecipientNameText.GetText then
        name = _G.TradeFrameRecipientNameText:GetText()
    elseif _G.TradeFrameRecipientName and _G.TradeFrameRecipientName.GetText then
        name = _G.TradeFrameRecipientName:GetText()
    end
    if (not name or name == "") and type(UnitName) == "function" then
        name = UnitName("target")
    end
    return NormalizeName(name or "")
end

local function EnsureTradeFrame(self)
    EnsureTradeState(self)

    if self.UI.tradeFrame and self.UI.tradeFrame._EchoesIsTradeFrame then
        return self.UI.tradeFrame
    end

    local f = CreateFrame("Frame", "EchoesTradeItemsFrame", UIParent)
    f._EchoesIsTradeFrame = true
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)

    f:SetSize(240, 180)
    f:Hide()

    SkinBackdrop(f, 0.92)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function()
        f:Hide()
    end)

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -6)
    title:SetTextColor(0.9, 0.8, 0.5, 1)
    SetEchoesFont(title, 12, ECHOES_FONT_FLAGS)
    title:SetText("Tradable Items")
    f._EchoesTitle = title

    local inTradeLabel = f:CreateFontString(nil, "OVERLAY")
    inTradeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -6)
    inTradeLabel:SetTextColor(0.85, 0.85, 0.85, 1)
    SetEchoesFont(inTradeLabel, 11, ECHOES_FONT_FLAGS)
    inTradeLabel:SetText("In Trade (Click to cancel)")
    inTradeLabel:Hide()
    f._EchoesInTradeLabel = inTradeLabel

    local empty = f:CreateFontString(nil, "OVERLAY")
    empty:SetPoint("TOP", f, "TOP", 0, -40)
    empty:SetTextColor(0.7, 0.7, 0.7, 1)
    SetEchoesFont(empty, 11, ECHOES_FONT_FLAGS)
    empty:SetText("Waiting for tradable items...")
    f._EchoesEmptyText = empty

    f._EchoesSlots = {}
    f._EchoesInTradeSlots = {}

    self.UI.tradeFrame = f
    return f
end

local function UpdateTradeItemTooltip(btn)
    if not btn then return end
    local tooltip = rawget(_G, "GameTooltip")
    if not tooltip then return end

    tooltip:SetOwner(btn, "ANCHOR_RIGHT")
    if tooltip.ClearLines then tooltip:ClearLines() end

    if btn._EchoesItemLink and btn._EchoesItemLink ~= "" and tooltip.SetHyperlink then
        tooltip:SetHyperlink(btn._EchoesItemLink)
    else
        tooltip:SetText(btn._EchoesItemName or "Item", 1, 1, 1)
    end

    tooltip:AddLine(" ")
    tooltip:AddLine("Click: Whisper item link", 0.8, 0.8, 0.8)
    tooltip:Show()
end

local function GetTradeTargetOfferEntries()
    local offered = {}
    local list = {}

    if type(GetTradeTargetItemInfo) ~= "function" then
        return list, offered
    end

    for i = 1, 7 do
        local name, _, numItems = GetTradeTargetItemInfo(i)
        local link = (type(GetTradeTargetItemLink) == "function") and GetTradeTargetItemLink(i) or nil
        local count = tonumber(numItems) or 1

        if (link and link ~= "") or (name and name ~= "") then
            local entry = { link = link, name = name, count = math.max(1, count) }
            TryResolveEntryInPlace(entry)
            local key = EntryKey(entry)
            if key then
                local existing = offered[key]
                if existing then
                    existing.count = (tonumber(existing.count) or 0) + entry.count
                else
                    offered[key] = {
                        itemId = entry.itemId,
                        link = entry.link,
                        name = entry.name,
                        count = entry.count,
                    }
                end
            end
        end
    end

    for _, v in pairs(offered) do
        list[#list + 1] = v
    end

    return list, offered
end


local function EnsureInvBar(self)
    EnsureInvState(self)

    if self.UI.invBar and self.UI.invBar._EchoesIsInvBar then
        return self.UI.invBar
    end

    local bar = CreateFrame("Frame", "EchoesInvBar", UIParent)
    bar._EchoesIsInvBar = true
    bar:SetFrameStrata("DIALOG")
    bar:SetClampedToScreen(true)

    -- Movable (drag anywhere on the bar background).
    bar:SetMovable(true)
    bar:EnableMouse(true)
    if bar.RegisterForDrag then bar:RegisterForDrag("LeftButton") end
    bar:SetScript("OnDragStart", function(selfBar)
        if selfBar.StartMoving then selfBar:StartMoving() end
    end)
    bar:SetScript("OnDragStop", function(selfBar)
        if selfBar.StopMovingOrSizing then selfBar:StopMovingOrSizing() end
    end)

    -- Slightly taller so crate buttons aren't clipped at the bottom.
    -- Start narrower (the bar will expand as buttons are added).
    bar:SetSize(275, 62)
    -- Always spawn centered when opened.
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    -- Frames are visible by default; keep it closed until explicitly toggled.
    bar:Hide()

    SkinBackdrop(bar, 0.92)

    local title = bar:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", bar, "TOPLEFT", 10, -6)
    title:SetTextColor(0.9, 0.8, 0.5, 1)
    SetEchoesFont(title, 12, ECHOES_FONT_FLAGS)
    title:SetText("Bot Inventories")
    bar._EchoesTitle = title

    -- Compute a minimum width so the title never overflows.
    local function UpdateMinWidth()
        if not (bar and bar.GetWidth and bar.SetWidth) then return end
        local w = 0
        if title and title.GetStringWidth then
            w = title:GetStringWidth() or 0
        end
        -- Left pad (10) + text width + right pad & close button space.
        -- Keep this as small as possible while preventing title overflow.
        local minW = math.max(140, math.ceil(10 + w + 54))
        bar._EchoesMinWidth = minW
        if (bar:GetWidth() or 0) < minW then
            bar:SetWidth(minW)
        end
    end
    UpdateMinWidth()

    local close = CreateFrame("Button", nil, bar, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -2, -2)

    bar:HookScript("OnShow", function(selfBar)
        -- Recenter every time it opens.
        selfBar:ClearAllPoints()
        selfBar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        UpdateMinWidth()
    end)

    bar._EchoesButtons = {}

    -- (Removed) Hide-keys toggle

    self.UI.invBar = bar
    return bar
end

local function EnsurePlayerInvFrame(self)
    EnsureInvState(self)

    if self.UI.invPlayerFrame and self.UI.invPlayerFrame._EchoesIsInvPlayerFrame then
        return self.UI.invPlayerFrame
    end

    local f = CreateFrame("Frame", "EchoesInvPlayerFrame", UIParent)
    f._EchoesIsInvPlayerFrame = true
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
    f:SetScript("OnDragStart", function(selfFrame)
        if selfFrame.StartMoving then selfFrame:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(selfFrame)
        if selfFrame.StopMovingOrSizing then selfFrame:StopMovingOrSizing() end
    end)

    -- Start compact; Inv_ShowPlayer will expand as needed.
    -- Anchor by TOP so height changes only move the bottom edge.
    f:SetSize(410, 160)
    f:SetPoint("TOP", UIParent, "TOP", 0, -180)
    f._EchoesTopAnchored = true

    SkinBackdrop(f, 0.92)

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    title:SetTextColor(0.9, 0.8, 0.5, 1)
    SetEchoesFont(title, 14, ECHOES_FONT_FLAGS)
    title:SetJustifyH("LEFT")
    title:SetText("Inventory")
    f._EchoesTitle = title

    local search = CreateFrame("EditBox", nil, f)
    search:SetAutoFocus(false)
    search:SetSize(160, 20)
    search:SetPoint("TOP", f, "TOP", 0, -10)
    if search.SetTextInsets then
        search:SetTextInsets(6, 6, 3, 3)
    end
    if search.GetRegions then
        local regs = { search:GetRegions() }
        for _, r in ipairs(regs) do
            if r and r.IsObjectType and r:IsObjectType("Texture") then
                r:SetTexture(nil)
            end
        end
    end
    SkinBackdrop(search, 0.95)
    search:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    search:SetBackdropBorderColor(0, 0, 0, 1)
    if search.SetFont then
        search:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    end
    if search.SetTextColor then
        search:SetTextColor(0.90, 0.85, 0.70, 1)
    end


    local clearBtn = CreateFrame("Button", nil, f)
    clearBtn:SetSize(16, 16)
    clearBtn:SetPoint("LEFT", search, "RIGHT", 6, 0)
    clearBtn:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    clearBtn:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    clearBtn:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    if clearBtn.GetNormalTexture then
        local tex = clearBtn:GetNormalTexture()
        if tex and tex.SetVertexColor then
            tex:SetVertexColor(0.7, 0.7, 0.7, 1)
        end
    end
    clearBtn:SetScript("OnClick", function()
        if search and search.ClearFocus then
            search:ClearFocus()
        end
        if f and f._EchoesSetSearchText then
            f._EchoesSetSearchText("Search", true)
        end
        if f and f._EchoesActivePlayer and f.IsShown and f:IsShown() then
            Echoes:Inv_ShowPlayer(f._EchoesActivePlayer)
        end
    end)
    f._EchoesSearchClear = clearBtn

    local function SetSearchText(text, isPlaceholder)
        search._EchoesInternalUpdate = true
        search:SetText(text)
        if isPlaceholder and search.SetTextColor then
            search:SetTextColor(0.6, 0.6, 0.6, 1)
        elseif search.SetTextColor then
            search:SetTextColor(0.90, 0.85, 0.70, 1)
        end
        search._EchoesInternalUpdate = false
    end

    f._EchoesSetSearchText = SetSearchText

    SetSearchText("Search", true)

    search:SetScript("OnEditFocusGained", function(selfBox)
        if selfBox:GetText() == "Search" then
            SetSearchText("", false)
        end
    end)
    search:SetScript("OnEditFocusLost", function(selfBox)
        if selfBox:GetText() == "" then
            SetSearchText("Search", true)
        end
    end)
    search:SetScript("OnEscapePressed", function(selfBox)
        if selfBox.ClearFocus then
            selfBox:ClearFocus()
        end
        if selfBox:GetText() == "" then
            SetSearchText("Search", true)
        end
    end)
    search:SetScript("OnEnterPressed", function(selfBox)
        if selfBox.ClearFocus then
            selfBox:ClearFocus()
        end
        if selfBox:GetText() == "" then
            SetSearchText("Search", true)
        end
    end)
    search:SetScript("OnTextChanged", function(selfBox)
        if selfBox._EchoesInternalUpdate then return end
        local parent = selfBox:GetParent()
        if parent and parent._EchoesActivePlayer and parent.IsShown and parent:IsShown() then
            Echoes:Inv_ShowPlayer(parent._EchoesActivePlayer)
        end
    end)

    f._EchoesSearchBox = search

    -- (Removed) hint line under the title

    f._EchoesSlots = {}
    f._EchoesActivePlayer = nil

    f:Hide()

    self.UI.invPlayerFrame = f
    return f
end

local function EnsureTopAnchoredFrame(f)
    if not f or f._EchoesTopAnchored then return end
    if not (f.GetLeft and f.GetTop and f.ClearAllPoints and f.SetPoint) then return end

    local left = f:GetLeft()
    local top = f:GetTop()
    if not left or not top then return end

    -- Preserve the current top-left screen position.
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    f._EchoesTopAnchored = true
end

local function ResolveItemVisual(entry)
    local link = entry.link
    local itemId = entry.itemId
    local name = entry.name

    if link and type(link) == "string" and link:find("|Hitem:") then
        -- Try to get itemId out of the hyperlink.
        local id = link:match("|Hitem:(%d+):")
        if id then itemId = tonumber(id) end
    end

    local tex
    local finalLink = link

    if type(GetItemInfo) == "function" then
        if itemId then
            local ilink = select(2, GetItemInfo(itemId))
            local icon = select(10, GetItemInfo(itemId))
            if ilink then finalLink = ilink end
            if icon then tex = icon end
        elseif name and name ~= "" then
            local ilink = select(2, GetItemInfo(name))
            local icon = select(10, GetItemInfo(name))
            if ilink then finalLink = ilink end
            if icon then tex = icon end
        elseif finalLink and finalLink ~= "" then
            local icon = select(10, GetItemInfo(finalLink))
            if icon then tex = icon end
        end
    end

    return tex or CRATE_ICON_FALLBACK, finalLink, itemId
end

local function GetEntrySellPrice(entry)
    if not entry or type(GetItemInfo) ~= "function" then return nil end
    local key = entry.itemId or entry.link or entry.name
    if (not key or key == "") then
        local n = GetEntryName(entry)
        if n ~= "" then key = n end
    end
    if not key or key == "" then return nil end
    return select(11, GetItemInfo(key))
end

local function UpdateInvItemTooltipAndCursor(btn)
    if not btn then return end
    local tooltip = rawget(_G, "GameTooltip")
    if not tooltip then return end

    tooltip:SetOwner(btn, "ANCHOR_RIGHT")
    if tooltip.ClearLines then tooltip:ClearLines() end

    if btn._EchoesItemLink and btn._EchoesItemLink ~= "" and tooltip.SetHyperlink then
        tooltip:SetHyperlink(btn._EchoesItemLink)
    else
        tooltip:SetText(btn._EchoesItemName or "Item", 1, 1, 1)
    end

    tooltip:AddLine(" ")

    local sellPrice = btn._EchoesEntry and GetEntrySellPrice(btn._EchoesEntry) or nil
    if sellPrice and sellPrice > 0 then
        tooltip:AddLine("Right-Click: Sell Item", 0.8, 0.8, 0.8)
    else
        tooltip:AddLine("Right-Click: Sell Item (unsellable)", 0.55, 0.55, 0.55)
    end
    tooltip:AddLine("Ctrl+Right-Click: Destroy Item", 0.8, 0.8, 0.8)
    tooltip:AddLine("Shift+Right-Click: Equip Item", 0.8, 0.8, 0.8)
    tooltip:AddLine("Alt+Right-Click: Use Item", 0.8, 0.8, 0.8)

    tooltip:Show()

    if sellPrice and sellPrice > 0 and type(SetCursor) == "function" then
        -- Closest built-in cursor to "sell item" behavior.
        SetCursor("BUY_CURSOR")
    elseif type(ResetCursor) == "function" then
        ResetCursor()
    end
end

TryResolveEntryInPlace = function(entry)
    if type(entry) ~= "table" then return false end

    local changed = false

    if entry.link and type(entry.link) == "string" and entry.link:find("|Hitem:") then
        local id = entry.link:match("|Hitem:(%d+):")
        if id then
            local n = tonumber(id)
            if n and n > 0 and entry.itemId ~= n then
                entry.itemId = n
                changed = true
            end
        end
    end

    if (not entry.link or entry.link == "") and (not entry.itemId) and entry.name and entry.name ~= "" and type(GetItemInfo) == "function" then
        local ilink = select(2, GetItemInfo(entry.name))
        if ilink and ilink ~= "" then
            entry.link = ilink
            local id = ilink:match("|Hitem:(%d+):")
            if id then
                local n = tonumber(id)
                if n and n > 0 then
                    entry.itemId = n
                end
            end
            changed = true
        end
    end

    return changed
end

EntryKey = function(entry)
    if not entry then return nil end
    if entry.itemId then
        return "id:" .. tostring(entry.itemId)
    end
    if entry.link and entry.link ~= "" then
        return "link:" .. tostring(entry.link)
    end
    if entry.name and entry.name ~= "" then
        return "name:" .. tostring(entry.name)
    end
    return nil
end

local function NormalizeAndAggregateItems(items)
    local agg = {}
    local out = {}

    if type(items) ~= "table" then
        return out, agg
    end

    for _, it in ipairs(items) do
        if type(it) == "table" then
            TryResolveEntryInPlace(it)

            local key = EntryKey(it)
            if key then
                local existing = agg[key]
                if existing then
                    existing.count = (tonumber(existing.count) or 0) + (tonumber(it.count) or 1)
                else
                    local copy = {
                        itemId = it.itemId,
                        link = it.link,
                        name = it.name,
                        count = tonumber(it.count) or 1,
                    }
                    agg[key] = copy
                    out[#out + 1] = copy
                end
            end
        end
    end

    return out, agg
end

function Echoes:Inv_SubtractItem(ownerName, entryKey, amount)
    EnsureInvState(self)

    ownerName = NormalizeName(ownerName)
    if ownerName == "" then return end
    if not entryKey or entryKey == "" then return end

    amount = tonumber(amount) or 1
    if amount < 1 then amount = 1 end

    local rec = self.Inv.byName and self.Inv.byName[ownerName]
    if not rec then return end

    rec._agg = rec._agg or {}
    rec.items = rec.items or {}

    local existing = rec._agg[entryKey]
    if not existing then
        -- Fallback: try to find a matching item by recomputing keys.
        for _, it in ipairs(rec.items) do
            if EntryKey(it) == entryKey then
                existing = it
                break
            end
        end
    end
    if not existing then return end

    existing.count = (tonumber(existing.count) or 1) - amount
    if existing.count and existing.count > 0 then
        rec._agg[entryKey] = existing
    else
        rec._agg[entryKey] = nil
        for i = #rec.items, 1, -1 do
            if EntryKey(rec.items[i]) == entryKey then
                table.remove(rec.items, i)
                break
            end
        end
    end

    self.Inv.byName[ownerName] = rec

    local f = self.UI and self.UI.invPlayerFrame
    if f and f._EchoesActivePlayer == ownerName and f.IsShown and f:IsShown() then
        self:Inv_ShowPlayer(ownerName)
    end
end

function Echoes:Inv_RequestPlayerInventory(targetName)
    EnsureInvState(self)

    targetName = NormalizeName(targetName)
    if targetName == "" then return end
    if IsSelf(targetName) then return end

    self.Inv._sessionSeq = (tonumber(self.Inv._sessionSeq) or 0) + 1
    self.Inv._scanStartedAt = (type(GetTime) == "function" and GetTime()) or 0

    -- Only listen for this target during this request window.
    self.Inv._memberSet = {}
    self.Inv._memberSet[targetName] = true

    -- Fresh record for this player.
    local rec = self.Inv.byName[targetName] or {}
    rec.lines = {}
    rec.items = {}
    rec._agg = {}
    rec._invDumpSeq = self.Inv._sessionSeq
    rec._invDumpStartedAt = self.Inv._scanStartedAt
    self.Inv.byName[targetName] = rec

    -- Listen for only 2 seconds.
    self._EchoesInvSessionActive = true
    if self.CancelTimer and self.Inv and self.Inv._listenTimer then
        self:CancelTimer(self.Inv._listenTimer, true)
        self.Inv._listenTimer = nil
    end
    if self.ScheduleTimer then
        local seq = self.Inv._sessionSeq
        self.Inv._listenTimer = self:ScheduleTimer(function()
            if self.Inv and self.Inv._sessionSeq == seq then
                self._EchoesInvSessionActive = false
            end
        end, 2)
    end

    if type(SendChatMessage) == "function" then
        SendChatMessage("items", "WHISPER", nil, targetName)
    end

    -- Lazily register item-info refresh so icons resolve when cached.
    if self.RegisterEvent and not self._EchoesInvItemInfoRegistered then
        self._EchoesInvItemInfoRegistered = true
        self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnInvItemInfoReceived")
    end
end

-- Requery inventory without wiping the existing UI list.
-- Inv_RequestPlayerInventory resets the record (blank UI) which feels bad when
-- we just performed an action on a single item.
function Echoes:Inv_RequeryPlayerInventory(targetName)
    EnsureInvState(self)

    targetName = NormalizeName(targetName)
    if targetName == "" then return end
    if IsSelf(targetName) then return end

    self.Inv._sessionSeq = (tonumber(self.Inv._sessionSeq) or 0) + 1
    self.Inv._scanStartedAt = (type(GetTime) == "function" and GetTime()) or 0

    self.Inv._memberSet = {}
    self.Inv._memberSet[targetName] = true

    local rec = self.Inv.byName[targetName] or {}
    rec.lines = rec.lines or {}
    rec.items = rec.items or {}
    rec._agg = rec._agg or {}

    -- Buffer refreshed inventory into a new array/map so the UI doesn't "flash"
    -- (no wiping/rebuilding mid-refresh). We'll swap in the new snapshot once the
    -- 2s listen window closes.
    rec._nextLines = {}
    rec._nextItems = {}
    rec._nextAgg = {}
    rec._nextSeq = self.Inv._sessionSeq
    rec._invDumpSeq = self.Inv._sessionSeq
    rec._invDumpStartedAt = self.Inv._scanStartedAt
    self.Inv.byName[targetName] = rec

    self._EchoesInvSessionActive = true
    if self.CancelTimer and self.Inv and self.Inv._listenTimer then
        self:CancelTimer(self.Inv._listenTimer, true)
        self.Inv._listenTimer = nil
    end
    if self.ScheduleTimer then
        local seq = self.Inv._sessionSeq
        self.Inv._listenTimer = self:ScheduleTimer(function()
            if self.Inv and self.Inv._sessionSeq == seq then
                self._EchoesInvSessionActive = false
            end
        end, 2)
    end

    if type(SendChatMessage) == "function" then
        SendChatMessage("items", "WHISPER", nil, targetName)
    end

    -- Commit buffered results after the listen window. Guard against overlap by seq.
    if self.ScheduleTimer then
        local seq = self.Inv._sessionSeq
        self:ScheduleTimer(function()
            local r = self.Inv and self.Inv.byName and self.Inv.byName[targetName]
            if not r or r._nextSeq ~= seq then return end
            if r._nextItems and r._nextAgg then
                r.lines = r._nextLines or {}
                r.items = r._nextItems
                r._agg = r._nextAgg
            end
            r._nextLines = nil
            r._nextItems = nil
            r._nextAgg = nil
            r._nextSeq = nil
            self.Inv.byName[targetName] = r

            local f = self.UI and self.UI.invPlayerFrame
            if f and f._EchoesActivePlayer == targetName and f.IsShown and f:IsShown() then
                self:Inv_ShowPlayer(targetName)
            end
        end, 2.05)
    end

    if self.RegisterEvent and not self._EchoesInvItemInfoRegistered then
        self._EchoesInvItemInfoRegistered = true
        self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "OnInvItemInfoReceived")
    end
end

function Echoes:Inv_ShowPlayer(name)
    EnsureInvState(self)

    name = NormalizeName(name)
    if name == "" then return end

    local f = EnsurePlayerInvFrame(self)
    EnsureTopAnchoredFrame(f)
    f._EchoesActivePlayer = name

    if f._EchoesTitle then
        f._EchoesTitle:SetText(name)
    end

    local rec = self.Inv.byName[name]
    local items = rec and rec.items or nil

    -- Incremental repaint: keep existing buttons shown and only hide extras.

    local list = {}
    if items and type(items) == "table" then
        list = items
    end
    local cols = 10
    local slotSize = 32
    local pad = 6

    local startX = 13
    local startY = -45

    -- Auto-size the frame based on number of items.
    local total = #list
    local rows = (total > 0) and math.ceil(total / cols) or 0

    -- startY is the TOPLEFT anchor point for the first item row.
    -- Use it to compute the exact top padding so the frame height matches the visible rows.
    local topPad = math.max(0, -startY)
    local bottomH = 14
    local minH = 80
    local maxH = 520

    local gridH = 0
    if rows > 0 then
        gridH = (rows * (slotSize + pad)) - pad
    end
    local desiredH = topPad + gridH + bottomH
    local finalH = math.max(minH, math.min(maxH, desiredH))
    if f.SetHeight then f:SetHeight(finalH) end

    -- Determine how many items we can actually show in the available space.
    local maxGridH = finalH - topPad - bottomH
    local maxRows = 0
    if maxGridH > 0 then
        maxRows = math.max(0, math.floor((maxGridH + pad) / (slotSize + pad)))
    end
    local maxVisible = maxRows * cols
    if maxVisible < 0 then maxVisible = 0 end
    local visibleCount = math.min(total, maxVisible)

    -- (Removed) hint text under the title

    for idx = 1, visibleCount do
        local entry = list[idx]
        local b = f._EchoesSlots[idx]
        local needsRecreate = false
        if b and b.GetName and not b:GetName() then
            needsRecreate = true
        end

        if (not b) or needsRecreate then
            if b and b.Hide then b:Hide() end
            local parentName = (f.GetName and f:GetName()) or "EchoesInvPlayerFrame"
            local btnName = parentName .. "Item" .. tostring(idx)
            b = CreateFrame("Button", btnName, f, "ItemButtonTemplate")
            b:SetSize(slotSize, slotSize)
            f._EchoesSlots[idx] = b

            if b.RegisterForClicks then
                b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            end

            b:SetScript("OnEnter", function(selfBtn)
                UpdateInvItemTooltipAndCursor(selfBtn)
            end)
            b:SetScript("OnLeave", function()
                if rawget(_G, "GameTooltip") then GameTooltip:Hide() end
                if type(ResetCursor) == "function" then ResetCursor() end
            end)

            b:SetScript("OnClick", function(selfBtn, mouseButton)
                local target = selfBtn._EchoesOwnerName
                if not target or target == "" then return end

                local link = selfBtn._EchoesItemLink
                local plain = selfBtn._EchoesItemPlainName
                local entry = selfBtn._EchoesEntry

                local payload
                if link and link ~= "" then
                    payload = link
                elseif plain and plain ~= "" then
                    payload = "[" .. plain .. "]"
                end
                if not payload then return end

                if mouseButton == "LeftButton" then
                    if type(IsShiftKeyDown) == "function" and IsShiftKeyDown() then
                        if type(ChatEdit_InsertLink) == "function" then
                            if (type(ChatEdit_GetActiveWindow) == "function") and not ChatEdit_GetActiveWindow() and type(ChatFrame_OpenChat) == "function" then
                                ChatFrame_OpenChat("")
                            end
                            ChatEdit_InsertLink(payload)
                        elseif type(HandleModifiedItemClick) == "function" and link and link ~= "" then
                            HandleModifiedItemClick(link)
                        end
                    end
                    return
                end

                if mouseButton ~= "RightButton" then return end

                local isCtrl = (type(IsControlKeyDown) == "function") and IsControlKeyDown() or false
                local isShift = (type(IsShiftKeyDown) == "function") and IsShiftKeyDown() or false
                local isAlt = (type(IsAltKeyDown) == "function") and IsAltKeyDown() or false

                -- Ctrl+RightClick: destroy with confirmation.
                if isCtrl then
                    local itemName = plain
                    if (not itemName or itemName == "") and entry then
                        itemName = GetEntryName(entry)
                    end
                    itemName = itemName or "item"
                    local itemNameBracketed = itemName
                    if type(itemNameBracketed) == "string" and not itemNameBracketed:match("^%[") then
                        itemNameBracketed = "[" .. itemNameBracketed .. "]"
                    end

                    local key = tostring(target) .. "|" .. tostring(selfBtn._EchoesEntryKey or payload)
                    local now = (type(GetTime) == "function" and GetTime()) or 0
                    Echoes.Inv = Echoes.Inv or {}
                    local c = Echoes.Inv._destroyConfirm

                    if c and c.key == key and (tonumber(c.expires) or 0) > now then
                        Echoes.Inv._destroyConfirm = nil
                        if type(SendChatMessage) == "function" then
                            SendChatMessage("destroy " .. payload, "WHISPER", nil, target)
                        end
                        -- Destroy should update locally (no requery) to avoid flashing.
                        if Echoes and Echoes.Inv_SubtractItem then
                            Echoes:Inv_SubtractItem(target, selfBtn._EchoesEntryKey, selfBtn._EchoesEntryCount)
                        end
                    else
                        Echoes.Inv._destroyConfirm = { key = key, expires = now + 8 }
                        Echoes_Print("Are you sure you want to destroy " .. tostring(itemNameBracketed) .. " from " .. tostring(target) .. "'s inventory?")
                    end

                    return
                end

                -- Shift+RightClick: equip
                if isShift then
                    if type(SendChatMessage) == "function" then
                        SendChatMessage("e " .. payload, "WHISPER", nil, target)
                    end
                    if Echoes and Echoes.Inv_RequeryPlayerInventory then
                        Echoes:Inv_RequeryPlayerInventory(target)
                    end
                    return
                end

                -- Alt+RightClick: use (by name)
                if isAlt then
                    local itemName = plain
                    if (not itemName or itemName == "") and entry then
                        itemName = GetEntryName(entry)
                    end
                    if not itemName or itemName == "" then
                        itemName = payload
                    end
                    local itemNameBracketed = itemName
                    if type(itemNameBracketed) == "string" and not itemNameBracketed:match("^%[") then
                        itemNameBracketed = "[" .. itemNameBracketed .. "]"
                    end
                    if type(SendChatMessage) == "function" then
                        SendChatMessage("u " .. tostring(itemNameBracketed), "WHISPER", nil, target)
                    end
                    if Echoes and Echoes.Inv_RequeryPlayerInventory then
                        Echoes:Inv_RequeryPlayerInventory(target)
                    end
                    return
                end

                -- Default RightClick: sell (only if item has a sell price)
                local sellPrice = entry and GetEntrySellPrice(entry) or nil
                if not sellPrice or sellPrice <= 0 then
                    Echoes_Print(tostring(payload) .. " can not be sold")
                    return
                end

                if type(SendChatMessage) ~= "function" then return end
                SendChatMessage("s " .. payload, "WHISPER", nil, target)
                Echoes.Inv = Echoes.Inv or {}
                Echoes.Inv._pendingSell = Echoes.Inv._pendingSell or {}
                Echoes.Inv._pendingSell[#Echoes.Inv._pendingSell + 1] = {
                    owner = NormalizeName(target),
                    entryKey = selfBtn._EchoesEntryKey,
                    count = selfBtn._EchoesEntryCount,
                    link = selfBtn._EchoesItemLink,
                    name = selfBtn._EchoesItemPlainName,
                }
                -- Wait for "Selling" whisper before removing locally.
            end)
        end

        local row = math.floor((idx - 1) / cols)
        local col = (idx - 1) % cols

        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f, "TOPLEFT", startX + col * (slotSize + pad), startY - row * (slotSize + pad))

        local tex, link, itemId = ResolveItemVisual(entry)
        b._EchoesEntryKey = EntryKey(entry)
        b._EchoesEntry = entry
        b._EchoesOwnerName = name
        b._EchoesItemLink = link
        b._EchoesItemId = itemId
        b._EchoesItemPlainName = GetEntryName(entry)
        b._EchoesItemName = link or (b._EchoesItemPlainName ~= "" and b._EchoesItemPlainName) or (itemId and ("item:" .. tostring(itemId)) or "item")

        local searchQuery = ""
        if f._EchoesSearchBox and f._EchoesSearchBox.GetText then
            local t = tostring(f._EchoesSearchBox:GetText() or "")
            if t ~= "" and t ~= "Search" then
                searchQuery = t:lower()
            end
        end
        local match = true
        if searchQuery ~= "" then
            local itemName = b._EchoesItemPlainName ~= "" and b._EchoesItemPlainName or b._EchoesItemName
            itemName = tostring(itemName or ""):lower()
            match = itemName:find(searchQuery, 1, true) ~= nil
        end
        if b.SetAlpha then
            b:SetAlpha(match and 1 or 0.2)
        end

        if _G.SetItemButtonTexture then
            _G.SetItemButtonTexture(b, tex)
        elseif b.icon and b.icon.SetTexture then
            b.icon:SetTexture(tex)
        else
            local icon = b:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(b)
            icon:SetTexture(tex)
            b.icon = icon
        end

        local count = tonumber(entry.count) or 1
        b._EchoesEntryCount = count
        if _G.SetItemButtonCount then
            _G.SetItemButtonCount(b, count)
        elseif b.Count and b.Count.SetText then
            b.Count:SetText((count and count > 1) and tostring(count) or "")
        end

        b:Show()

        -- If the user is currently hovering this slot, keep tooltip/cursor in sync.
        local tt = rawget(_G, "GameTooltip")
        if tt and tt.GetOwner and tt:GetOwner() == b then
            UpdateInvItemTooltipAndCursor(b)
        end
    end

    -- Hide any leftover slots beyond the current visible range.
    for i = visibleCount + 1, #f._EchoesSlots do
        local b = f._EchoesSlots[i]
        if b then
            local tt = rawget(_G, "GameTooltip")
            if tt and tt.GetOwner and tt:GetOwner() == b then
                tt:Hide()
                if type(ResetCursor) == "function" then ResetCursor() end
            end
            if b.Hide then b:Hide() end
        end
    end

    f:Show()
end

local function IsTradableMessageLine(msg)
    local lower = tostring(msg or ""):lower()
    if lower:find("soulbound", 1, true) or lower:find("soul bound", 1, true) then
        return false
    end
    if lower:find("quest item", 1, true) then
        return false
    end
    if lower:find("(quest", 1, true) or lower:find("quest)", 1, true) then
        return false
    end
    return true
end

function Echoes:Trade_OnShow()
    if not TradeFeaturesEnabled() then return end
    EnsureTradeState(self)

    local target = GetTradeTargetName()
    if target == "" then
        return
    end


    self.Trade.activeName = target
    self.Trade.byName[target] = { items = {}, _agg = {}, _received = false }

    local now = (type(GetTime) == "function" and GetTime()) or 0
    self.Trade.byName[target]._acceptInvUntil = now + 2

    local f = EnsureTradeFrame(self)
    if f and _G.TradeFrame then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", _G.TradeFrame, "TOPRIGHT", 10, 0)
        f:Show()
    end

    if self.Trade_ShowItems then
        self:Trade_ShowItems(target)
    end

    if type(SendChatMessage) == "function" then
        SendChatMessage("items", "WHISPER", nil, target)
    end
end

function Echoes:Trade_OnClosed()
    if self.UI and self.UI.tradeFrame then
        self.UI.tradeFrame:Hide()
    end
    if self.Trade then
        self.Trade.activeName = nil
    end
end

function Echoes:Trade_OnTargetItemChanged()
    if not TradeFeaturesEnabled() then return end
    if not (_G.TradeFrame and _G.TradeFrame.IsShown and _G.TradeFrame:IsShown()) then return end
    if not self.Trade or not self.Trade.activeName then return end
    self:Trade_ShowItems(self.Trade.activeName)
end

function Echoes:Trade_AddItems(ownerName, items)
    if not TradeFeaturesEnabled() then return end
    EnsureTradeState(self)

    ownerName = NormalizeName(ownerName)
    if ownerName == "" then return end

    local rec = self.Trade.byName[ownerName]
    if not rec then
        rec = { items = {}, _agg = {}, _received = false }
        self.Trade.byName[ownerName] = rec
    end

    if type(items) ~= "table" then return end
    for _, it in ipairs(items) do
        if type(it) == "table" then
            local sellPrice = GetEntrySellPrice(it)
            if sellPrice and sellPrice > 0 then
                rec.items[#rec.items + 1] = it
            end
        end
    end

    rec._received = true

    local out, agg = NormalizeAndAggregateItems(rec.items)
    rec.items = out
    rec._agg = agg

    if self.Trade_ShowItems then
        self:Trade_ShowItems(ownerName)
    end
end

function Echoes:Trade_ClearItems(ownerName)
    if not TradeFeaturesEnabled() then return end
    EnsureTradeState(self)

    ownerName = NormalizeName(ownerName)
    if ownerName == "" then return end

    local rec = self.Trade.byName[ownerName]
    if not rec then
        rec = { items = {}, _agg = {}, _received = false }
        self.Trade.byName[ownerName] = rec
    else
        rec.items = {}
        rec._agg = {}
        rec._received = false
    end

    if self.Trade_ShowItems then
        self:Trade_ShowItems(ownerName)
    end
end

function Echoes:Trade_ShowItems(ownerName)
    if not TradeFeaturesEnabled() then return end
    EnsureTradeState(self)

    ownerName = NormalizeName(ownerName)
    if ownerName == "" then return end

    local f = EnsureTradeFrame(self)
    if not f then return end

    if _G.TradeFrame then
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", _G.TradeFrame, "TOPRIGHT", 10, 0)
    end

    local rec = self.Trade.byName[ownerName]
    local baseList = rec and rec.items or {}

    local offeredList, offeredMap = GetTradeTargetOfferEntries()
    if #offeredList > 0 then
        local filtered = {}
        for _, it in ipairs(offeredList) do
            local sellPrice = GetEntrySellPrice(it)
            if sellPrice and sellPrice > 0 then
                filtered[#filtered + 1] = it
            end
        end
        offeredList = filtered
        offeredMap = {}
        for _, it in ipairs(offeredList) do
            local key = EntryKey(it)
            if key then
                offeredMap[key] = it
            end
        end
    end

    local list = {}
    for _, entry in ipairs(baseList) do
        local key = EntryKey(entry)
        local totalCount = tonumber(entry.count) or 1
        local offeredEntry = key and offeredMap[key]
        local offeredCount = offeredEntry and (tonumber(offeredEntry.count) or 0) or 0
        local remaining = totalCount - offeredCount
        if remaining > 0 then
            local copy = {
                itemId = entry.itemId,
                link = entry.link,
                name = entry.name,
                count = remaining,
            }
            list[#list + 1] = copy
        end
    end

    local total = #list
    local offeredTotal = #offeredList

    local slotSize = 32
    local pad = 6
    local cols = 5
    local startX = 12
    local startY = -30

    local rows = math.max(1, math.ceil(total / cols))
    local offeredRows = (offeredTotal > 0) and math.max(1, math.ceil(offeredTotal / cols)) or 0

    local width = startX * 2 + cols * slotSize + (cols - 1) * pad
    local height = 36 + rows * slotSize + (rows - 1) * pad + 14
    if offeredTotal > 0 then
        height = height + 12 + 12 + offeredRows * slotSize + (offeredRows - 1) * pad
    end
    height = math.max(140, height)
    f:SetSize(width, height)

    if f._EchoesEmptyText then
        if total == 0 then
            if rec and rec._received then
                f._EchoesEmptyText:SetText("No tradable items.")
            else
                f._EchoesEmptyText:SetText("Waiting for tradable items...")
            end
            f._EchoesEmptyText:Show()
        else
            f._EchoesEmptyText:Hide()
        end
    end

    for idx = 1, total do
        local entry = list[idx]
        local b = f._EchoesSlots[idx]

        if not b then
            local btnName = "EchoesTradeItem" .. tostring(idx)
            b = CreateFrame("Button", btnName, f, "ItemButtonTemplate")
            b:SetSize(slotSize, slotSize)
            f._EchoesSlots[idx] = b

            if b.RegisterForClicks then
                b:RegisterForClicks("LeftButtonUp")
            end

            b:SetScript("OnEnter", function(selfBtn)
                UpdateTradeItemTooltip(selfBtn)
            end)
            b:SetScript("OnLeave", function()
                if rawget(_G, "GameTooltip") then GameTooltip:Hide() end
                if type(ResetCursor) == "function" then ResetCursor() end
            end)

            b:SetScript("OnClick", function(selfBtn)
                local target = selfBtn._EchoesOwnerName
                if not target or target == "" then return end

                local link = selfBtn._EchoesItemLink
                local plain = selfBtn._EchoesItemPlainName
                local payload
                if link and link ~= "" then
                    payload = link
                elseif plain and plain ~= "" then
                    payload = "[" .. plain .. "]"
                end
                if not payload then return end

                if type(SendChatMessage) == "function" then
                    SendChatMessage(payload, "WHISPER", nil, target)
                end
            end)
        end

        local row = math.floor((idx - 1) / cols)
        local col = (idx - 1) % cols
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", f, "TOPLEFT", startX + col * (slotSize + pad), startY - row * (slotSize + pad))

        local tex, link, itemId = ResolveItemVisual(entry)
        b._EchoesEntry = entry
        b._EchoesOwnerName = ownerName
        b._EchoesItemLink = link
        b._EchoesItemId = itemId
        b._EchoesItemPlainName = GetEntryName(entry)
        b._EchoesItemName = link or (b._EchoesItemPlainName ~= "" and b._EchoesItemPlainName) or (itemId and ("item:" .. tostring(itemId)) or "item")

        if _G.SetItemButtonTexture then
            _G.SetItemButtonTexture(b, tex)
        elseif b.icon and b.icon.SetTexture then
            b.icon:SetTexture(tex)
        else
            local icon = b:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(b)
            icon:SetTexture(tex)
            b.icon = icon
        end

        local count = tonumber(entry.count) or 1
        if _G.SetItemButtonCount then
            _G.SetItemButtonCount(b, count)
        elseif b.Count and b.Count.SetText then
            b.Count:SetText((count and count > 1) and tostring(count) or "")
        end

        b:Show()
    end

    local i = total + 1
    while f._EchoesSlots[i] do
        f._EchoesSlots[i]:Hide()
        i = i + 1
    end

    local inTradeLabel = f._EchoesInTradeLabel
    if offeredTotal > 0 then
        local labelY = startY - rows * (slotSize + pad) - 12
        if inTradeLabel then
            inTradeLabel:ClearAllPoints()
            inTradeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 10, labelY)
            inTradeLabel:Show()
        end

        local offeredStartY = labelY - 16
        for idx = 1, offeredTotal do
            local entry = offeredList[idx]
            local b = f._EchoesInTradeSlots[idx]

            if not b then
                local btnName = "EchoesTradeOfferedItem" .. tostring(idx)
                b = CreateFrame("Button", btnName, f, "ItemButtonTemplate")
                b:SetSize(slotSize, slotSize)
                f._EchoesInTradeSlots[idx] = b

                if b.RegisterForClicks then
                    b:RegisterForClicks("LeftButtonUp")
                end

                b:SetScript("OnEnter", function(selfBtn)
                    UpdateTradeItemTooltip(selfBtn)
                end)
                b:SetScript("OnLeave", function()
                    if rawget(_G, "GameTooltip") then GameTooltip:Hide() end
                    if type(ResetCursor) == "function" then ResetCursor() end
                end)

                b:SetScript("OnClick", function(selfBtn)
                    local target = selfBtn._EchoesOwnerName
                    if not target or target == "" then return end

                    local link = selfBtn._EchoesItemLink
                    local plain = selfBtn._EchoesItemPlainName
                    local payload
                    if link and link ~= "" then
                        payload = link
                    elseif plain and plain ~= "" then
                        payload = "[" .. plain .. "]"
                    end
                    if not payload then return end

                    if type(SendChatMessage) == "function" then
                        SendChatMessage(payload, "WHISPER", nil, target)
                    end
                end)
            end

            local row = math.floor((idx - 1) / cols)
            local col = (idx - 1) % cols
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", f, "TOPLEFT", startX + col * (slotSize + pad), offeredStartY - row * (slotSize + pad))

            local tex, link, itemId = ResolveItemVisual(entry)
            b._EchoesEntry = entry
            b._EchoesOwnerName = ownerName
            b._EchoesItemLink = link
            b._EchoesItemId = itemId
            b._EchoesItemPlainName = GetEntryName(entry)
            b._EchoesItemName = link or (b._EchoesItemPlainName ~= "" and b._EchoesItemPlainName) or (itemId and ("item:" .. tostring(itemId)) or "item")

            if _G.SetItemButtonTexture then
                _G.SetItemButtonTexture(b, tex)
            elseif b.icon and b.icon.SetTexture then
                b.icon:SetTexture(tex)
            else
                local icon = b:CreateTexture(nil, "ARTWORK")
                icon:SetAllPoints(b)
                icon:SetTexture(tex)
                b.icon = icon
            end

            local count = tonumber(entry.count) or 1
            if _G.SetItemButtonCount then
                _G.SetItemButtonCount(b, count)
            elseif b.Count and b.Count.SetText then
                b.Count:SetText((count and count > 1) and tostring(count) or "")
            end

            b:Show()
        end

        local j = offeredTotal + 1
        while f._EchoesInTradeSlots[j] do
            f._EchoesInTradeSlots[j]:Hide()
            j = j + 1
        end
    else
        if inTradeLabel then
            inTradeLabel:Hide()
        end
        local j = 1
        while f._EchoesInTradeSlots[j] do
            f._EchoesInTradeSlots[j]:Hide()
            j = j + 1
        end
    end

    f:Show()
end

function Echoes:Trade_OnWhisper(msg, author)
    if not TradeFeaturesEnabled() then return end
    if not (_G.TradeFrame and _G.TradeFrame.IsShown and _G.TradeFrame:IsShown()) then return end

    local target = GetTradeTargetName()
    if target == "" then return end
    if NormalizeName(author) ~= NormalizeName(target) then return end

    EnsureTradeState(self)
    local rec = self.Trade.byName[target]
    if not rec then
        rec = { items = {}, _agg = {}, _received = true }
        self.Trade.byName[target] = rec
    else
        rec._received = true
    end

    local now = (type(GetTime) == "function" and GetTime()) or 0
    local acceptUntil = tonumber(rec._acceptInvUntil) or 0
    if now > acceptUntil then
        if IsInventoryHeaderLine(msg) then return end
        if tostring(msg or ""):lower():match("^items") then return end
        local invItems = ParseItemsFromInventoryLine(msg)
        if invItems and #invItems > 0 then return end
    end

    if tostring(msg or ""):find("Equipping", 1, true) then return end
    if not IsTradableMessageLine(msg) then return end

    local items = ParseItemsFromInventoryLine(msg)
    if #items == 0 then
        items = ParseItemsFromMessage(msg)
    end
    if #items == 0 then return end

    self:Trade_AddItems(target, items)
end

local function RebuildInvBarButtons(self)
    local bar = EnsureInvBar(self)
    local members = self.Inv.members or {}

    -- Hide old
    for _, b in ipairs(bar._EchoesButtons) do
        if b and b.Hide then b:Hide() end
    end

    local x0 = 10
    local y0 = -24
    local size = 30
    local gap = 6
    local firstRowCount = 4
    local perRow = 5

    for i, member in ipairs(members) do
        local b = bar._EchoesButtons[i]
        if not b then
            b = CreateFrame("Button", nil, bar)
            b:SetSize(size, size)
            SkinBackdrop(b, 0.85)

            if b.RegisterForClicks then
                b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            end

            local icon = b:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("CENTER")
            icon:SetSize(size - 6, size - 6)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            b._EchoesIcon = icon

            b:SetScript("OnEnter", function(selfBtn)
                if rawget(_G, "GameTooltip") then
                    GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
                    GameTooltip:SetText(tostring(selfBtn._EchoesDisplayName or selfBtn._EchoesPlayerName or ""), 1, 1, 1)
                    GameTooltip:AddLine("Ctrl+Shift+Right-Click: Sell All Items", 0.8, 0.8, 0.8)
                    GameTooltip:Show()
                end
            end)
            b:SetScript("OnLeave", function()
                if rawget(_G, "GameTooltip") then GameTooltip:Hide() end
            end)
            b:SetScript("OnClick", function(selfBtn, button)
                local target = selfBtn._EchoesPlayerName
                if not target or target == "" then return end

                if button == "RightButton" and type(IsControlKeyDown) == "function" and type(IsShiftKeyDown) == "function" then
                    if IsControlKeyDown() and IsShiftKeyDown() then
                        if type(SendChatMessage) == "function" then
                            SendChatMessage("s vendor", "WHISPER", nil, target)
                        end
                        return
                    end
                end

                local f = Echoes.UI and Echoes.UI.invPlayerFrame
                if f and f.IsShown and f:IsShown() and f._EchoesActivePlayer == target then
                    if f.Hide then f:Hide() end
                    return
                end

                Echoes:Inv_RequestPlayerInventory(target)
                Echoes:Inv_ShowPlayer(target)
            end)

            bar._EchoesButtons[i] = b
        end

        local normName = member.name or ""
        local displayName = member.display or normName
        local classFile = member.classFile
        b._EchoesPlayerName = normName
        b._EchoesDisplayName = displayName
        if b._EchoesIcon and b._EchoesIcon.SetTexture then
            local tex, coords = GetClassIconTexture(classFile)
            b._EchoesIcon:SetTexture(tex)
            if coords then
                b._EchoesIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            else
                b._EchoesIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            end
        end

        local index = i - 1
        local row, col
        if index < firstRowCount then
            row = 0
            col = index
        else
            row = 1 + math.floor((index - firstRowCount) / perRow)
            col = (index - firstRowCount) % perRow
        end

        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bar, "TOPLEFT", x0 + col * (size + gap), y0 - row * (size + gap))
        b:Show()
    end

    -- Resize bar to fit (cap width so it doesn't run off screen).
    local maxCols = math.max(firstRowCount, perRow)
    local w = x0 + (maxCols * (size + gap)) + 44
    if bar._EchoesMinWidth then
        w = math.max(w, bar._EchoesMinWidth)
    end
    w = math.min(w, 760)
    bar:SetWidth(w)

    local rows = 1
    if #members > firstRowCount then
        rows = 1 + math.ceil((#members - firstRowCount) / perRow)
    end
    local h = 24 + rows * (size + gap) + 10
    if bar.SetHeight then
        bar:SetHeight(h)
    end
end

function Echoes:Inv_RefreshMembers()
    EnsureInvState(self)

    local members = GetGroupMemberNames()
    self.Inv.members = members

    local bar = self.UI and self.UI.invBar
    if bar and bar._EchoesIsInvBar then
        RebuildInvBarButtons(self)
        if bar.IsShown and not bar:IsShown() then
            -- Keep it hidden if the user closed it.
        end
    end
end

function Echoes:Inv_ToggleBar()
    EnsureInvState(self)

    local bar = EnsureInvBar(self)
    if bar and bar.IsShown and bar:IsShown() then
        if bar.Hide then bar:Hide() end
        return
    end

    -- Refresh members and rebuild buttons on open.
    self.Inv.members = GetGroupMemberNames()
    RebuildInvBarButtons(self)
    if bar and bar.Show then bar:Show() end
end

function Echoes:Inv_OnWhisper(msg, author)
    EnsureInvState(self)

    if not self._EchoesInvSessionActive then return end

    -- Hard cutoff: only accept inventory lines for 1 second after scan starts.
    local now = (type(GetTime) == "function" and GetTime()) or 0
    local started = tonumber(self.Inv and self.Inv._scanStartedAt) or 0
        if started > 0 and (now - started) > 2 then
        return
    end

    author = NormalizeName(author)
    if author == "" then return end

    -- Only accept responses from members we pinged.
    if not (self.Inv._memberSet and self.Inv._memberSet[author]) then
        return
    end

    local trimmed = Trim(msg)
    if trimmed == "" then return end

    -- Header starts a fresh dump for this author (prevents duplicates across multiple scans/dumps).
    if IsInventoryHeaderLine(trimmed) then
        local rec = self.Inv.byName[author] or {}
        if rec._invEndTimer and self.CancelTimer then
            self:CancelTimer(rec._invEndTimer, true)
            rec._invEndTimer = nil
        end
        rec._invDumpClosed = false
        if rec._nextSeq == self.Inv._sessionSeq and rec._nextItems and rec._nextAgg then
            rec._nextLines = {}
            rec._nextItems = {}
            rec._nextAgg = {}
        else
            rec.lines = {}
            rec.items = {}
            rec._agg = {}
        end
        rec._invDumpSeq = self.Inv._sessionSeq
        rec._invDumpStartedAt = (type(GetTime) == "function" and GetTime()) or nil
        if rec._nextSeq == self.Inv._sessionSeq and rec._nextLines then
            rec._nextLines[#rec._nextLines + 1] = trimmed
        else
            rec.lines[#rec.lines + 1] = trimmed
        end
        self.Inv.byName[author] = rec

        self.Inv.responses[#self.Inv.responses + 1] = {
            from = author,
            msg = trimmed,
            items = {},
            t = (type(GetTime) == "function" and GetTime()) or nil,
        }
        return
    end

    local rec = self.Inv.byName[author] or {}
    if rec._invDumpClosed and rec._invDumpSeq == self.Inv._sessionSeq then
        return
    end
    rec.lines = rec.lines or {}
    rec.items = rec.items or {}
    rec._agg = rec._agg or {}

    local useBuffered = (rec._nextSeq == self.Inv._sessionSeq) and rec._nextItems and rec._nextAgg

    -- If we haven't seen a header for this author this scan, ignore late/stale lines from older scans.
    -- Allow a short grace window right after starting the scan for servers that don't send a header.
    now = (type(GetTime) == "function" and GetTime()) or 0
    if rec._invDumpSeq ~= self.Inv._sessionSeq then
        started = tonumber(self.Inv._scanStartedAt) or 0
        local withinGrace = (now - started) <= 1
        if not withinGrace then
            return
        end
        rec._invDumpSeq = self.Inv._sessionSeq
        rec._invDumpStartedAt = now
    end

    -- Some servers send a header first ("=== Inventory ==="), then one line per item.
    if useBuffered and rec._nextLines then
        rec._nextLines[#rec._nextLines + 1] = trimmed
    else
        rec.lines[#rec.lines + 1] = trimmed
    end

    local newItems = {}
    if trimmed:lower():match("^items") then
        newItems = ParseItemsFromMessage(trimmed)
    else
        newItems = ParseItemsFromInventoryLine(trimmed)
    end

    if newItems and #newItems > 0 then
        -- Merge into aggregate list. We allow item names only; if GetItemInfo later resolves them,
        -- the GET_ITEM_INFO_RECEIVED handler will rebuild keys.
        for _, it in ipairs(newItems) do
            if type(it) == "table" then
                TryResolveEntryInPlace(it)

                -- Permanently hidden items (mostly keys/attunements): do not store or display.
                if IsAlwaysHiddenEntry(it) then
                    -- skip
                else
                    local key = EntryKey(it)
                    if key then
                        local agg = useBuffered and rec._nextAgg or rec._agg
                        local itemsArr = useBuffered and rec._nextItems or rec.items
                        local existing = agg[key]
                        if existing then
                            existing.count = (tonumber(existing.count) or 0) + (tonumber(it.count) or 1)
                        else
                            local copy = {
                                itemId = it.itemId,
                                link = it.link,
                                name = it.name,
                                count = tonumber(it.count) or 1,
                            }
                            agg[key] = copy
                            itemsArr[#itemsArr + 1] = copy
                        end
                    end
                end
            end
        end
    end

    self.Inv.byName[author] = rec

    -- If no more lines arrive shortly, close the dump for this author.
    if self.ScheduleTimer then
        if rec._invEndTimer and self.CancelTimer then
            self:CancelTimer(rec._invEndTimer, true)
        end
        local seq = self.Inv._sessionSeq
        rec._invEndTimer = self:ScheduleTimer(function()
            local r = self.Inv and self.Inv.byName and self.Inv.byName[author]
            if not r then return end
            if r._invDumpSeq == seq then
                r._invDumpClosed = true
                self.Inv.byName[author] = r
            end
        end, 0.4)
        self.Inv.byName[author] = rec
    end

    self.Inv.responses[#self.Inv.responses + 1] = {
        from = author,
        msg = trimmed,
        items = newItems,
        t = (type(GetTime) == "function" and GetTime()) or nil,
    }

    -- Avoid repainting mid-refresh when using the buffered snapshot; we'll repaint once on commit.
    if not useBuffered then
        local f = self.UI and self.UI.invPlayerFrame
        if f and f._EchoesActivePlayer == author and f.IsShown and f:IsShown() then
            self:Inv_ShowPlayer(author)
        end
    end
end

function Echoes:Inv_OnSellWhisper(msg, author)
    EnsureInvState(self)

    local info = ParseSoldItemFromMessage(msg)
    if not info then return false end

    author = NormalizeName(author)
    if author == "" then return false end

    local pending = self.Inv._pendingSell or {}
    local matchIndex
    for i, p in ipairs(pending) do
        if p and p.owner == author then
            if info.link and p.link and p.link == info.link then
                matchIndex = i
                break
            end
            if info.name and p.name and p.name:lower() == info.name:lower() then
                matchIndex = i
                break
            end
        end
    end

    if matchIndex then
        local p = table.remove(pending, matchIndex)
        self.Inv._pendingSell = pending
        if p and p.entryKey and p.count then
            self:Inv_SubtractItem(author, p.entryKey, p.count)
        end
        return true
    end

    return false
end

function Echoes:RunInventoryScan()
    EnsureInvState(self)

    -- /echoes inv now only opens the bar; requesting inventory happens when a crate is clicked.
    self._EchoesInvSessionActive = false
    self.Inv._scanStartedAt = 0

    -- Reset all previously known inventory results each time.
    self.Inv.responses = {}
    self.Inv.byName = {}
    self.Inv.members = {}
    self.Inv._memberSet = {}

    if self.UI and self.UI.invPlayerFrame then
        local f = self.UI.invPlayerFrame
        if f._EchoesSlots then
            for _, b in ipairs(f._EchoesSlots) do
                if b and b.Hide then b:Hide() end
            end
        end
        f._EchoesActivePlayer = nil
        if f.Hide then f:Hide() end
    end

    local members = GetGroupMemberNames()
    self.Inv.members = members

    -- Show the bar immediately.
    RebuildInvBarButtons(self)
    local bar = self.UI.invBar
    if bar and bar.Show then bar:Show() end

    Echoes_Print("inv: click a crate to request that player's items")
end

function Echoes:OnInvItemInfoReceived()
    -- Try to resolve any name-only entries into real item links/ids and rebuild aggregates.
    if self.Inv and self.Inv.byName then
        for _, rec in pairs(self.Inv.byName) do
            if type(rec) == "table" and type(rec.items) == "table" then
                local rebuilt, agg = NormalizeAndAggregateItems(rec.items)
                rec.items = rebuilt
                rec._agg = agg
            end
        end
    end

    -- Repaint current player frame if open.
    local f = self.UI and self.UI.invPlayerFrame
    if f and f._EchoesActivePlayer and f.IsShown and f:IsShown() then
        self:Inv_ShowPlayer(f._EchoesActivePlayer)
    end
end
