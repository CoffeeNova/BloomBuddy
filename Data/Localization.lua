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
        status = "enabled: %s | scale: %.1fx | party: %s | raid: %s | timer: %s | swipe: %s",
        help = "BloomBuddy commands: status, options, enable, disable, timer, debug, help",
        unknownCommand = "Unknown command: %s. Type /bb help",
        enabled = "Addon enabled",
        disabled = "Addon disabled",
        debugToggled = "Debug logging: %s",
        timerToggled = "Digital countdown: %s",
        scaledIcons = "Scaled %d Lifebloom icon(s)",

        -- Options window (/bb options)
        panelTitle = "BloomBuddy",
        optionsReset = "Settings reset to defaults",
        optionsHelpTitle = "BloomBuddy commands",
        optionsHelpStatus = "/bb — status + re-apply",
        optionsHelpOptions = "/bb options — open settings",
        optionsHelpEnable = "/bb enable | disable — toggle addon",
        optionsHelpTimer = "/bb timer — digital countdown",
        optionsHelpDebug = "/bb debug — verbose logging",
        optionsHelpHelp = "/bb help — command list",
        swipeLabel = "Clockwise darkening",
        timerLabel = "Show remaining time",
        sizeLabel = "Icon size:",
        positionXLabel = "Position X:",
        positionYLabel = "Position Y:",
        resetButton = "Reset to defaults",
        positionNotImplemented = "Not implemented yet",
        positionStubNote = "Value is saved, the overlay does not move yet",
    },
    ruRU = {
        loaded = "v%s загружен",
        status = "включён: %s | масштаб: %.1fx | party: %s | raid: %s | timer: %s | swipe: %s",
        help = "BloomBuddy команды: status, options, enable, disable, timer, debug, help",
        unknownCommand = "Неизвестная команда: %s. Введите /bb help",
        enabled = "Аддон включён",
        disabled = "Аддон выключен",
        debugToggled = "Отладка: %s",
        timerToggled = "Цифровой отсчёт: %s",
        scaledIcons = "Увеличено иконок Lifebloom: %d",

        -- Options window (/bb options)
        panelTitle = "BloomBuddy",
        optionsReset = "Настройки сброшены к значениям по умолчанию",
        optionsHelpTitle = "Команды BloomBuddy",
        optionsHelpStatus = "/bb — статус и повторное применение",
        optionsHelpOptions = "/bb options — открыть настройки",
        optionsHelpEnable = "/bb enable | disable — включить/выключить аддон",
        optionsHelpTimer = "/bb timer — цифровой отсчёт",
        optionsHelpDebug = "/bb debug — подробное логирование",
        optionsHelpHelp = "/bb help — список команд",
        swipeLabel = "Затемнение по часовой стрелке",
        timerLabel = "Показывать остаток времени",
        sizeLabel = "Размер иконки:",
        positionXLabel = "Позиция X:",
        positionYLabel = "Позиция Y:",
        resetButton = "Сбросить настройки",
        positionNotImplemented = "Пока не реализовано",
        positionStubNote = "Значение сохраняется, оверлей пока не двигается",
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
