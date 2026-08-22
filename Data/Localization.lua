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

        help = "BloomBuddy commands: /bb, /bb options, /bb status, /bb enable, /bb disable, /bb timer, /bb debug, /bb help",

        unknownCommand = "Unknown command: %s. Type /bb help",

        enabled = "Addon enabled",
        disabled = "Addon disabled",

        debugToggled = "Debug logging: %s",
        timerToggled = "Digital countdown: %s",

        optionsReset = "Settings reset to defaults",

        panelTitle = "BloomBuddy",

        optionsHelpTitle = "BloomBuddy commands",
        optionsHelpStatus = "/bb — open settings",
        optionsHelpOptions = "/bb options — open settings",
        optionsHelpEnable = "/bb enable | disable — enable or disable the addon",
        optionsHelpTimer = "/bb timer — toggle the digital countdown",
        optionsHelpDebug = "/bb debug — verbose logging",
        optionsHelpHelp = "/bb help — command list",

        sizeLabel = "Icon size:",

        positionXLabel = "Position X:",
        positionXHelp = "Move the icon left or right inside the raid frame.",

        positionYLabel = "Position Y:",
        positionYHelp = "Move the icon up or down inside the raid frame.",

        swipeLabel = "Clockwise darkening",
        timerLabel = "Show remaining time",

        resetButton = "Reset to defaults",
    },

    ruRU = {
        loaded = "v%s загружен",

        status = "включён: %s | масштаб: %.1fx | party: %s | raid: %s | таймер: %s | затемнение: %s",

        help = "BloomBuddy команды: /bb, /bb options, /bb status, /bb enable, /bb disable, /bb timer, /bb debug, /bb help",

        unknownCommand = "Неизвестная команда: %s. Введите /bb help",

        enabled = "Аддон включён",
        disabled = "Аддон выключен",

        debugToggled = "Отладка: %s",
        timerToggled = "Цифровой отсчёт: %s",

        optionsReset = "Настройки сброшены к значениям по умолчанию",

        panelTitle = "BloomBuddy",

        optionsHelpTitle = "Команды BloomBuddy",
        optionsHelpStatus = "/bb — открыть настройки",
        optionsHelpOptions = "/bb options — открыть настройки",
        optionsHelpEnable = "/bb enable | disable — включить или выключить аддон",
        optionsHelpTimer = "/bb timer — включить или выключить цифровой таймер",
        optionsHelpDebug = "/bb debug — подробная отладка",
        optionsHelpHelp = "/bb help — список команд",

        sizeLabel = "Размер иконки:",

        positionXLabel = "Позиция X:",
        positionXHelp = "Перемещает иконку влево или вправо внутри рейд-фрейма.",

        positionYLabel = "Позиция Y:",
        positionYHelp = "Перемещает иконку вверх или вниз внутри рейд-фрейма.",

        swipeLabel = "Затемнение по часовой стрелке",
        timerLabel = "Показывать оставшееся время",

        resetButton = "Сбросить настройки",
    },
};

local L = setmetatable({}, {
    __index = function(_, key)
        local table_ =
            strings[locale]
            or strings[DefaultLocale];

        local value =
            table_[key];

        if value == nil then
            return tostring(key);
        end

        return value;
    end,
});

BB.Data.Localization = L;
BB.L = L;

return BB;