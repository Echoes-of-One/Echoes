-- Core\DebugLog.lua
-- Debug log window (shown via /echoes debug).

local Echoes = LibStub("AceAddon-3.0"):GetAddon("Echoes")

Echoes._DebugLogLines = Echoes._DebugLogLines or {}

local function Echoes_GetCallerTag()
	if type(debugstack) ~= "function" then
		return nil
	end
	local s = debugstack(3, 1, 0)
	if not s or s == "" then return nil end
	local first = s:match("^([^\n]+)")
	if not first then return nil end
	return first
end

local function Echoes_UpdateDebugLogScrollBar(f, forceToBottom)
	if not f or not f.messageFrame or not f._EchoesScrollBar then return end

	local mf = f.messageFrame
	local num = (mf.GetNumMessages and mf:GetNumMessages()) or 0
	local font, fontHeight = mf.GetFont and mf:GetFont()
	local lineH = tonumber(fontHeight) or 12
	local height = (mf.GetHeight and mf:GetHeight()) or 0
	local visibleLines = math.max(1, math.floor((height - 2) / lineH))
	local maxOffset = math.max(0, num - visibleLines)

	local sb = f._EchoesScrollBar
	if sb.SetMinMaxValues then sb:SetMinMaxValues(0, maxOffset) end
	if sb.SetValueStep then sb:SetValueStep(1) end
	if sb.SetStepsPerPage then sb:SetStepsPerPage(visibleLines) end

	if forceToBottom then
		if mf.ScrollToBottom then mf:ScrollToBottom() end
		if sb.SetValue then sb:SetValue(maxOffset) end
	end
end

local function Echoes_AppendDebugLine(level, msg)
	if msg == nil then
		msg = level
		level = "INFO"
	end
	if type(msg) ~= "string" then
		msg = tostring(msg)
	end
	level = tostring(level or "INFO"):upper()
	local t = date and date("%H:%M:%S") or "--:--:--"
	local caller = Echoes_GetCallerTag()
	local line = "[" .. t .. "] [" .. level .. "] " .. msg
	if caller then
		line = line .. " <" .. caller .. ">"
	end
	local lines = Echoes._DebugLogLines
	lines[#lines + 1] = line
	if #lines > 500 then
		table.remove(lines, 1)
	end

	local f = Echoes._EchoesDebugLogFrame
	if f and f.messageFrame and f.messageFrame.AddMessage then
		f.messageFrame:AddMessage(line)
		Echoes_UpdateDebugLogScrollBar(f, true)
	end
end

function Echoes:Log(level, msg)
	Echoes_AppendDebugLine(level, msg)
end

function Echoes:Debug(msg)
	Echoes_AppendDebugLine("DEBUG", msg)
end

function Echoes:Info(msg)
	Echoes_AppendDebugLine("INFO", msg)
end

function Echoes:Warn(msg)
	Echoes_AppendDebugLine("WARN", msg)
end

function Echoes:Error(msg)
	Echoes_AppendDebugLine("ERROR", msg)
end

local function Echoes_InstallDebugHooks()
	if Echoes._DebugLogHooksInstalled then return end
	Echoes._DebugLogHooksInstalled = true

	if type(_G.SendChatMessage) == "function" and not _G._EchoesSendChatMessage then
		_G._EchoesSendChatMessage = _G.SendChatMessage
		_G.SendChatMessage = function(msg, chatType, lang, target)
			if Echoes.Log then
				Echoes:Log("INFO", "SendChatMessage: type=" .. tostring(chatType) .. " target=" .. tostring(target) .. " msg=" .. tostring(msg))
			end
			return _G._EchoesSendChatMessage(msg, chatType, lang, target)
		end
	end

	if type(_G.CreateFrame) == "function" and not _G._EchoesCreateFrame then
		_G._EchoesCreateFrame = _G.CreateFrame
		_G.CreateFrame = function(frameType, name, parent, template)
			if Echoes.Log and (frameType == "Button" or frameType == "Frame") then
				Echoes:Log("INFO", "CreateFrame: type=" .. tostring(frameType) .. " name=" .. tostring(name))
			end
			return _G._EchoesCreateFrame(frameType, name, parent, template)
		end
	end

	local ok, ace = pcall(LibStub, "AceGUI-3.0")
	if ok and ace and not ace._EchoesCreateWrapped then
		ace._EchoesCreateWrapped = true
		local orig = ace.Create
		ace.Create = function(self, widgetType)
			if Echoes.Log then
				Echoes:Log("INFO", "AceGUI:Create " .. tostring(widgetType))
			end
			local widget = orig(self, widgetType)
			if widget and widget.SetCallback and not widget._EchoesCallbackWrapped then
				widget._EchoesCallbackWrapped = true
				local origSetCallback = widget.SetCallback
				widget.SetCallback = function(w, event, func)
					local eventName = tostring(event)
					local id = (w and w._EchoesLogId) and tostring(w._EchoesLogId) or nil
					if Echoes.Log then
						Echoes:Log("INFO", "AceGUI:SetCallback id=" .. tostring(id or "-") .. " widget=" .. tostring(widgetType) .. " event=" .. eventName)
					end
					if type(func) == "function" then
						local wrapped = function(...)
							local wid = (w and w._EchoesLogId) and tostring(w._EchoesLogId) or nil
							if Echoes.Log then
								Echoes:Log("INFO", "AceGUI:Event id=" .. tostring(wid or "-") .. " widget=" .. tostring(widgetType) .. " event=" .. eventName)
							end
							return func(...)
						end
						return origSetCallback(w, event, wrapped)
					end
					return origSetCallback(w, event, func)
				end
			end
			return widget
		end
	end
end

local function Echoes_CreateDebugLogWindow()
	if Echoes._EchoesDebugLogFrame then
		return Echoes._EchoesDebugLogFrame
	end

	local f = CreateFrame("Frame", "EchoesDebugLogFrame", UIParent)
	f:SetSize(560, 300)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:SetResizable(true)
	f:SetMinResize(360, 180)
	f:EnableMouse(true)
	if f.RegisterForDrag then f:RegisterForDrag("LeftButton") end
	f:SetScript("OnDragStart", function(self)
		if self.StartMoving then self:StartMoving() end
	end)
	f:SetScript("OnDragStop", function(self)
		if self.StopMovingOrSizing then self:StopMovingOrSizing() end
	end)
	f:Hide()

	f:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		tile = false, tileSize = 0, edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 },
	})
	f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
	f:SetBackdropBorderColor(0, 0, 0, 1)

	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
	title:SetTextColor(0.95, 0.82, 0.25, 1)
	title:SetText("Echoes Debug Log")

	local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

	local mf = CreateFrame("ScrollingMessageFrame", nil, f)
	mf:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -28)
	mf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 10)
	mf:SetFontObject(ChatFontNormal)
	mf:SetJustifyH("LEFT")
	mf:SetFading(false)
	mf:SetMaxLines(500)
	mf:EnableMouseWheel(true)
	mf:SetScript("OnMouseWheel", function(self, delta)
		if delta > 0 then
			self:ScrollUp()
		else
			self:ScrollDown()
		end
		Echoes_UpdateDebugLogScrollBar(f, false)
		local sb = f._EchoesScrollBar
		if sb and sb.GetValue and self.GetScrollOffset and sb.SetValue then
			sb:SetValue(self:GetScrollOffset())
		end
	end)

	f.messageFrame = mf

	local sb = CreateFrame("Slider", nil, f, "UIPanelScrollBarTemplate")
	sb:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -24)
	sb:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 12)
	sb:SetMinMaxValues(0, 0)
	sb:SetValueStep(1)
	sb:SetScript("OnValueChanged", function(self, value)
		if mf.SetScrollOffset then
			mf:SetScrollOffset(value)
		end
	end)
	f._EchoesScrollBar = sb

	local resize = CreateFrame("Button", nil, f)
	resize:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
	resize:SetSize(16, 16)
	resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	resize:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" and f.StartSizing then
			f:StartSizing("BOTTOMRIGHT")
		end
	end)
	resize:SetScript("OnMouseUp", function()
		if f.StopMovingOrSizing then
			f:StopMovingOrSizing()
		end
		Echoes_UpdateDebugLogScrollBar(f, false)
	end)
	f._EchoesResizeHandle = resize

	f:HookScript("OnSizeChanged", function()
		Echoes_UpdateDebugLogScrollBar(f, false)
	end)

	for _, line in ipairs(Echoes._DebugLogLines) do
		mf:AddMessage(line)
	end

	Echoes_UpdateDebugLogScrollBar(f, true)
	if mf.GetScrollOffset and sb.SetValue then
		sb:SetValue(mf:GetScrollOffset())
	end

	_G.UISpecialFrames = _G.UISpecialFrames or {}
	local found = false
	for i = 1, #_G.UISpecialFrames do
		if _G.UISpecialFrames[i] == "EchoesDebugLogFrame" then
			found = true
			break
		end
	end
	if not found then
		table.insert(_G.UISpecialFrames, "EchoesDebugLogFrame")
	end

	Echoes._EchoesDebugLogFrame = f
	return f
end

function Echoes:ToggleDebugLogWindow()
	local f = Echoes_CreateDebugLogWindow()
	if f:IsShown() then
		f:Hide()
		if self.Log then
			self:Log("INFO", "Debug log window hidden")
		end
	else
		f:Show()
		Echoes_UpdateDebugLogScrollBar(f, true)
		if self.Log then
			self:Log("INFO", "Debug log window shown")
		end
	end
end

Echoes_InstallDebugHooks()
