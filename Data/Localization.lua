-- BloomBuddy — Data/Localization
-- UI strings. L has a metatable fallback to the key itself when a translation
-- is missing, so a missing string never crashes and is easy to spot in chat.

---@type BB
local _, BB = ...;

local GetLocale = _G.GetLocale;

BB.Data = BB.Data or {};

local locale = GetLocale();
local DefaultLocale = "enUS";

local strings = {
    enUS = {
        loaded = "v%s loaded",
        status = "enabled: %s | scale: %.1fx | party: %s | raid: %s | timer: %s",
        help = "BloomBuddy commands: status, enable, disable, timer, debug, help",
        unknownCommand = "Unknown command: %s. Type /bb help",
        enabled = "Addon enabled",
        disabled = "Addon disabled",
        debugToggled = "Debug logging: %s",
        timerToggled = "Digital countdown: %s",
        scaledIcons = "Scaled %d Lifebloom icon(s)",

        -- Options panel (Phase 3)
        panelTitle = "BloomBuddy",
        generalHeader = "General",
        enabledLabel = "Enlarge the Lifebloom buff icon",
        scaleLabel = "Icon size multiplier:",
        framesHeader = "Frames",
        partyLabel = "Party frames",
        raidLabel = "Raid frames",
    },
    ruRU = {
        loaded = "v%s загружен",
        status = "включён: %s | масштаб: %.1fx | party: %s | raid: %s | timer: %s",
        help = "BloomBuddy команды: status, enable, disable, timer, debug, help",
        unknownCommand = "Неизвестная команда: %s. Введите /bb help",
        enabled = "Аддон включён",
        disabled = "Аддон выключен",
        debugToggled = "Отладка: %s",
        timerToggled = "Цифровой отсчёт: %s",
        scaledIcons = "Увеличено иконок Lifebloom: %d",

        -- Options panel (Phase 3)
        panelTitle = "BloomBuddy",
        generalHeader = "Общие",
        enabledLabel = "Увеличивать иконку бафа Lifebloom",
        scaleLabel = "Множитель размера иконки:",
        framesHeader = "Фреймы",
        partyLabel = "Фреймы группы",
        raidLabel = "Фреймы рейда",
    },
};

---@class Localization
local L = setmetatable({}, {
    __index = function(_, key)
        local table_ = strings[locale] or strings[DefaultLocale];
        local value = table_[key];

        if (value == nil) then
            -- Missing translation — fall back to the key so it stands out.
            return tostring(key);
        end

        return value;
    end,
});

BB.Data.Localization = L;
-- Convenience alias used by modules (bootstrap, slash commands, UI).
BB.L = L;

return BB;
