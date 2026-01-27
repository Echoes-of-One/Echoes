-- Bootstrap.lua
-- Minimal addon bootstrap.
-- This file exists to keep load order clean and avoid keeping a monolithic implementation in the runtime path.

local AceAddon = LibStub("AceAddon-3.0")

-- Create the addon object exactly once.
local stub = _G.Echoes
local Echoes = AceAddon:GetAddon("Echoes", true)
if not Echoes then
	if type(stub) == "table" then
		Echoes = AceAddon:NewAddon(stub, "Echoes", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
	else
		Echoes = AceAddon:NewAddon("Echoes", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
	end
end

-- Single source of truth for the addon version.
-- CI reads this value to create the release tag (vX.YY) and package the zip.
Echoes.VERSION = Echoes.VERSION or "0.12"

-- Prefer a private dropdown template to avoid other UI packs (e.g., ElvUI)
-- overwriting Blizzard's default dropdown visuals.
Echoes.UsePrivateDropdownTemplate = true

-- Backwards-compatible globals.
_G.Echoes = Echoes


