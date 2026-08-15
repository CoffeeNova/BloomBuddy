-- BloomBuddy — bootstrap
-- Entry point: creates the global BB table, the event frame, and initializes
-- modules in dependency order on ADDON_LOADED.

---@type string
local ADDON_NAME, BB = ...;
BB = BB or {};

local DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME;
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata;

-- Expose the single global table.
_G.BB = BB;

BB.name = ADDON_NAME;
BB.version = GetAddOnMetadata(ADDON_NAME, "Version") or "0.1.0";
BB._initialized = false;
BB.debug = false;

BB.Data = BB.Data or {};
BB.Utils = BB.Utils or {};

-- Invisible frame that receives raw game events.
BB.Frame = CreateFrame("Frame", "BloomBuddyFrame");

--- Log a message to the default chat frame with the addon prefix.
---@param message string
function BB:print(message, ...)
    if (message == nil) then
        return;
    end

    DEFAULT_CHAT_FRAME:AddMessage(("|cff00ff66BB|r: " .. tostring(message)):format(...));
end

--- Log a message to chat only when debug mode is on.
---@param message string
function BB:debugPrint(message, ...)
    if (not self.debug) then
        return;
    end

    self:print(message, ...);
end

--- Initialize every module in strict dependency order.
function BB:_init()
    if (self._initialized) then
        return;
    end
    self._initialized = true;

    self.Events:_init(self.Frame);
    self.Settings:_init();
    self.Frames:_init();
    self.OptionsUI:_init();

    -- Handle /reload inside a group/raid: re-apply the scale immediately.
    self.Frames:checkNow();

    self:debugPrint(self.L.loaded, self.version);
end

BB.Frame:RegisterEvent("ADDON_LOADED");
BB.Frame:SetScript("OnEvent", function(_, event, addonName)
    if (event == "ADDON_LOADED" and addonName == ADDON_NAME) then
        BB.Frame:UnregisterEvent("ADDON_LOADED");
        BB:_init();
    end
end);

return BB;
