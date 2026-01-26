-- Core\LoadProbe.lua
-- Simple load marker to verify TOC execution order.

if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
    DEFAULT_CHAT_FRAME:AddMessage("|cffFFD100Echoes:|r LoadProbe reached (before GroupTab)")
end
