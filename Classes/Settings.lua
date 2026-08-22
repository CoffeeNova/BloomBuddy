---@type BB
local _, BB = ...;

local pairs = _G.pairs;
local tinsert = _G.tinsert;
local tonumber = _G.tonumber;
local math = _G.math;
local type = _G.type;

---@class Settings
local Settings = {
    _initialized = false,
    Data = nil,
};

BB.Settings = Settings;

local function normalizeSegment(segment)
    local number = tonumber(segment);

    if (number and number == math.floor(number)) then
        return number;
    end

    return segment;
end

function Settings:_init()
    if self._initialized then
        return;
    end

    self._initialized = true;

    local defaults = BB.Data.DefaultSettings;

    self.Data = BB.Utils.Tables:deepMerge(
        BB.Utils.Tables:shallowCopy(defaults),
        BloomBuddyDB or {}
    );

    self:ensureDefaults(self.Data, defaults);

    BloomBuddyDB = self.Data;
end

function Settings:ensureDefaults(target, defaults)
    for key, defaultValue in pairs(defaults) do
        if type(defaultValue) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {};
            end

            self:ensureDefaults(target[key], defaultValue);
        elseif target[key] == nil then
            target[key] = defaultValue;
        end
    end
end

function Settings:get(path)
    local current = self.Data;

    for segment in (path or ""):gmatch("[^.]+") do
        current = current and current[normalizeSegment(segment)];
    end

    return current;
end

function Settings:set(path, value)
    local segments = {};

    for segment in (path or ""):gmatch("[^.]+") do
        tinsert(segments, normalizeSegment(segment));
    end

    if #segments == 0 then
        return;
    end

    local current = self.Data;

    for i = 1, #segments - 1 do
        local segment = segments[i];

        if type(current[segment]) ~= "table" then
            current[segment] = {};
        end

        current = current[segment];
    end

    current[segments[#segments]] = value;
end

function Settings:reset()
    local defaults = BB.Data.DefaultSettings;
    local data = BB.Utils.Tables:deepMerge({}, defaults);

    self.Data = data;
    BloomBuddyDB = self.Data;
end

return BB;