-- Bootstrap.lua
-- Minimal addon bootstrap.
-- This file exists to keep load order clean and avoid keeping a monolithic implementation in the runtime path.

local AceAddon = LibStub("AceAddon-3.0")

-- Create the addon object exactly once.
local Echoes = AceAddon:NewAddon("Echoes", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

-- Single source of truth for the addon version.
-- CI reads this value to create the release tag (vX.YY) and package the zip.
Echoes.VERSION = Echoes.VERSION or "0.12"

-- Backwards-compatible globals.
_G.Echoes = Echoes
_G.EchoesDB = _G.EchoesDB or {}
