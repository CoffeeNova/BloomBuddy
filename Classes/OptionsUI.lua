-- BloomBuddy — Classes/OptionsUI
-- Slash commands (/bb) + status. A full Interface Options panel is Phase 3
-- (see .github/docs/addon-v1-development-plan.md); the Settings canvas API
-- gotchas live in the wow-api-20506 skill.

---@type BB
local _, BB = ...;

local strlower = _G.strlower;

_G.SLASH_BLOOMBUDDY1 = "/bb";
_G.SLASH_BLOOMBUDDY2 = "/bloombuddy";

---@class OptionsUI
local OptionsUI = {
    _initialized = false,
};

---@type OptionsUI
BB.OptionsUI = OptionsUI;

--- Trim surrounding whitespace.
---@param text string
---@return string
local function trim(text)
    return (text or ""):gsub("^%s+", ""):gsub("%s+$", "");
end

--- Show the current status and re-apply the scale (returns the scaled count).
local function showStatus()
    BB:print(BB.L.status,
        tostring(BB.Settings:get("enabled")),
        tonumber(BB.Settings:get("scale")) or 1,
        tostring(BB.Settings:get("party")),
        tostring(BB.Settings:get("raid")),
        tostring(BB.Settings:get("showTimer") ~= false));

    local scaled = BB.Frames:checkNow();
    BB:print(BB.L.scaledIcons, scaled);
end

local function printHelp()
    BB:print(BB.L.help);
end

--- Handle a slash command.
---@param input string
local function handleInput(input)
    local command = strlower(trim(input or ""));

    if (command == "" or command == "status") then
        showStatus();
    elseif (command == "enable") then
        BB.Settings:set("enabled", true);
        BB.Frames:ensureTicker();
        BB.Frames:checkNow();
        BB:print(BB.L.enabled);
    elseif (command == "disable") then
        BB.Settings:set("enabled", false);
        BB.Frames:stopTicker();
        BB.Frames:checkNow();
        BB:print(BB.L.disabled);
    elseif (command == "timer") then
        local showTimer = BB.Settings:get("showTimer") ~= false;
        BB.Settings:set("showTimer", not showTimer);
        BB.Frames:checkNow();
        BB:print(BB.L.timerToggled, tostring(not showTimer));
    elseif (command == "debug") then
        BB.debug = not BB.debug;
        BB:print(BB.L.debugToggled, BB.debug and "on" or "off");
        BB.Frames:dumpOverlays();
    elseif (command == "help") then
        printHelp();
    else
        BB:print(BB.L.unknownCommand, command);
    end
end

--- Register the slash command.
function OptionsUI:_init()
    if (self._initialized) then
        return;
    end
    self._initialized = true;

    SlashCmdList["BLOOMBUDDY"] = function(input)
        handleInput(input);
    end;
end

return BB;
