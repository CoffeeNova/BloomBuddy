-- BloomBuddy — Classes/Settings
-- SavedVariables wrapper (BloomBuddyDB): dot-path get/set.
-- On load: deep-merge defaults (Data/DefaultSettings.lua) with the saved
-- data, so new keys added in future versions are safe.

---@type BB
local _, BB = ...;

local pairs = _G.pairs;
local tinsert = _G.tinsert;

---@class Settings
local Settings = {
    _initialized = false,

    ---@type table
    Data = nil,
};

---@type Settings
BB.Settings = Settings;

function Settings:_init()
    if (self._initialized) then
        return;
    end
    self._initialized = true;

    local defaults = BB.Data.DefaultSettings;
    self.Data = BB.Utils.Tables:deepMerge(
        BB.Utils.Tables:shallowCopy(defaults),
        BloomBuddyDB or {}
    );

    -- Migration: any key that exists in defaults but is MISSING from the saved
    -- data is filled from defaults. deepMerge only adds new keys, so a user
    -- who saved under an older structure would have nil for the new key.
    self:ensureDefaults(self.Data, defaults);

    -- Persist so the fixed structure is saved from now on.
    BloomBuddyDB = self.Data;
end

--- Recursively copy default values for keys missing from `target`.
---@param target table
---@param defaults table
function Settings:ensureDefaults(target, defaults)
    for key, defaultValue in pairs(defaults) do
        if (type(defaultValue) == "table") then
            if (type(target[key]) ~= "table") then
                target[key] = {};
            end

            self:ensureDefaults(target[key], defaultValue);
        elseif (target[key] == nil) then
            target[key] = defaultValue;
        end
    end
end

--- Normalize a dot-path segment: integer-looking segments become numbers so
--- they match numeric table keys (a future per-spell map would use
--- [33763] = true — number; paths built from strings would otherwise hit
--- "33763" — a DIFFERENT key).
---@param segment string
---@return string|number
local function normalizeSegment(segment)
    local asNumber = tonumber(segment);

    if (asNumber and asNumber == math.floor(asNumber)) then
        return asNumber;
    end

    return segment;
end

--- Dot-path getter, e.g. Settings:get("scale").
--- Returns nil for a missing path.
---@param path string
---@return any
function Settings:get(path)
    local current = self.Data;

    for segment in (path or ""):gmatch("[^.]+") do
        current = current and current[normalizeSegment(segment)];
    end

    return current;
end

--- Dot-path setter, e.g. Settings:set("scale", 2.0).
--- Intermediate tables are created on demand; the value is written into
--- BloomBuddyDB (which SavedVariables persist).
---@param path string
---@param value any
function Settings:set(path, value)
    local segments = {};

    for segment in (path or ""):gmatch("[^.]+") do
        tinsert(segments, normalizeSegment(segment));
    end

    local current = self.Data;

    for i = 1, #segments - 1 do
        local segment = segments[i];
        current[segment] = current[segment] or {};
        current = current[segment];
    end

    current[segments[#segments]] = value;
end

return BB;
