---@type BB
local _, BB = ...;

local ipairs = _G.ipairs;
local tonumber = _G.tonumber;
local tostring = _G.tostring;
local strlower = _G.strlower;
local CreateFrame = _G.CreateFrame;
local UIParent = _G.UIParent;
local GameTooltip = _G.GameTooltip;

_G.SLASH_BLOOMBUDDY1 = "/bb";
_G.SLASH_BLOOMBUDDY2 = "/bloombuddy";

---@class OptionsUI
local OptionsUI = {
    _initialized = false,
    _window = nil,
    _syncing = false,
};

BB.OptionsUI = OptionsUI;

local WINDOW_WIDTH = 280;

local CONTENT_TOP_PADDING = 48;
local ROW_GAP = 20;
local BOTTOM_PADDING = 16;

local SLIDER_WIDTH = 170;
local SLIDER_HEIGHT = 16;
local SLIDER_LABEL_HEIGHT = 13;
local SLIDER_LABEL_GAP = 2;

local CHECKBOX_SIZE = 24;
local CHECKBOX_LABEL_GAP = 6;

local HELP_INSET_X = 7;
local HELP_INSET_Y = 5;

local RESET_HEIGHT = 22;

local WINDOW_HEIGHT =
    CONTENT_TOP_PADDING
    + 3 * (
        SLIDER_LABEL_HEIGHT
        + SLIDER_LABEL_GAP
        + SLIDER_HEIGHT
    )
    + 2 * CHECKBOX_SIZE
    + RESET_HEIGHT
    + 5 * ROW_GAP
    + BOTTOM_PADDING;

local function trim(text)
    return (text or "")
        :gsub("^%s+", "")
        :gsub("%s+$", "");
end

local function createSlider(
    parent,
    name,
    label,
    low,
    high,
    step
)
    local slider =
        CreateFrame(
            "Slider",
            name,
            parent,
            "OptionsSliderTemplate"
        );

    slider:SetSize(
        SLIDER_WIDTH,
        SLIDER_HEIGHT
    );

    slider:SetMinMaxValues(
        low,
        high
    );

    slider:SetValueStep(step);

    local labelText =
        parent:CreateFontString(
            nil,
            "ARTWORK",
            "GameFontNormalSmall"
        );

    labelText:SetPoint(
        "BOTTOMLEFT",
        slider,
        "TOPLEFT",
        -2,
        SLIDER_LABEL_GAP
    );

    labelText:SetText(label);

    local lowText =
        _G[name .. "Low"];

    local highText =
        _G[name .. "High"];

    if lowText then
        lowText:SetText(low);
    end

    if highText then
        highText:SetText(high);
    end

    return slider;
end

local function createCheckbox(
    parent,
    label
)
    local check =
        CreateFrame(
            "CheckButton",
            nil,
            parent,
            "UICheckButtonTemplate"
        );

    check:SetSize(
        CHECKBOX_SIZE,
        CHECKBOX_SIZE
    );

    local text =
        parent:CreateFontString(
            nil,
            "ARTWORK",
            "GameFontNormal"
        );

    text:SetPoint(
        "LEFT",
        check,
        "RIGHT",
        CHECKBOX_LABEL_GAP,
        0
    );

    text:SetText(label);
    text:SetJustifyH("LEFT");

    check.label = text;

    return check;
end

local function checkBlockHalfWidth(check)
    local labelWidth =
        check.label
        and check.label:GetStringWidth()
        or 0;

    return (
        labelWidth
        + CHECKBOX_LABEL_GAP
    ) / 2;
end

local function attachTooltip(
    widget,
    lines,
    title
)
    widget:SetScript(
        "OnEnter",
        function(self)
            if not GameTooltip then
                return;
            end

            GameTooltip:SetOwner(
                self,
                "ANCHOR_RIGHT"
            );

            if title then
                GameTooltip:AddLine(
                    title,
                    1,
                    1,
                    1
                );
            end

            if lines then
                for _, line in ipairs(lines) do
                    GameTooltip:AddLine(
                        line,
                        1,
                        0.82,
                        0
                    );
                end
            end

            GameTooltip:Show();
        end
    );

    widget:SetScript(
        "OnLeave",
        function()
            if GameTooltip then
                GameTooltip:Hide();
            end
        end
    );
end

local function syncControls(window)
    local settings = BB.Settings;

    OptionsUI._syncing = true;

    window.scaleSlider:SetValue(
        tonumber(settings:get("scale"))
        or BB.Data.Constants.DEFAULT_SCALE
    );

    window.posXSlider:SetValue(
        tonumber(settings:get("overlayPosX"))
        or 0
    );

    local storedY =
        settings:get("overlayPosY");

    if storedY == "TOP" then
        -- "TOP" is a special automatic position.
        -- Show the slider at its maximum as a visual indication
        -- that the icon is aligned to the upper boundary.
        window.posYSlider:SetValue(40);
    else
        window.posYSlider:SetValue(
            tonumber(storedY)
            or 0
        );
    end

    window.swipeCheck:SetChecked(
        settings:get("showSwipe") ~= false
    );

    window.timerCheck:SetChecked(
        settings:get("showTimer") == true
    );

    OptionsUI._syncing = false;
end

local function ensureWindow()
    if OptionsUI._window then
        return OptionsUI._window;
    end

    local window =
        CreateFrame(
            "Frame",
            "BloomBuddyOptionsFrame",
            UIParent,
            "UIPanelDialogTemplate"
        );

    window:SetSize(
        WINDOW_WIDTH,
        WINDOW_HEIGHT
    );

    window:SetPoint(
        "CENTER"
    );

    window:SetClampedToScreen(true);
    window:SetMovable(true);
    window:EnableMouse(true);
    window:SetToplevel(true);
    window:Hide();

    window:SetScript(
        "OnMouseDown",
        function(self, button)
            if button == "LeftButton" then
                self:StartMoving();
            end
        end
    );

    window:SetScript(
        "OnMouseUp",
        function(self)
            self:StopMovingOrSizing();
        end
    );

    local titleBand =
        _G["BloomBuddyOptionsFrameTitleBG"];

    local title =
        window:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormalLarge"
        );

    title:SetText(
        BB.L.panelTitle
    );

    if titleBand then
        title:SetPoint(
            "CENTER",
            titleBand,
            "CENTER",
            0,
            0
        );
    else
        title:SetPoint(
            "TOP",
            window,
            "TOP",
            0,
            -18
        );
    end

    local closeButton;

    for _, child in ipairs({
        window:GetChildren()
    }) do
        if child:GetObjectType() == "Button" then
            if closeButton then
                child:Hide();
            else
                closeButton = child;
            end
        end
    end

    if not closeButton then
        closeButton =
            CreateFrame(
                "Button",
                "BloomBuddyOptionsCloseButton",
                window,
                "UIPanelCloseButton"
            );
    end

    closeButton:SetPoint(
        "TOPRIGHT",
        window,
        "TOPRIGHT",
        2,
        -2
    );

    closeButton:SetScript(
        "OnClick",
        function()
            window:Hide();
        end
    );

    closeButton:Show();

    local helpButton =
        CreateFrame(
            "Button",
            "BloomBuddyOptionsHelpButton",
            window,
            "UIPanelButtonTemplate"
        );

    helpButton:SetSize(
        24,
        24
    );

    helpButton:SetText("?");

    helpButton:SetPoint(
        "TOPLEFT",
        window,
        "TOPLEFT",
        HELP_INSET_X,
        -HELP_INSET_Y
    );

    attachTooltip(
        helpButton,
        {
            BB.L.optionsHelpStatus,
            BB.L.optionsHelpOptions,
            BB.L.optionsHelpEnable,
            BB.L.optionsHelpTimer,
            BB.L.optionsHelpDebug,
            BB.L.optionsHelpHelp,
        },
        BB.L.optionsHelpTitle
    );

    window.scaleSlider =
        createSlider(
            window,
            "BloomBuddyOptionsScaleSlider",
            BB.L.sizeLabel,
            0.5,
            1.5,
            0.1
        );

    window.scaleSlider:SetPoint(
        "TOP",
        window,
        "TOP",
        0,
        -(
            CONTENT_TOP_PADDING
            + SLIDER_LABEL_HEIGHT
            + SLIDER_LABEL_GAP
        )
    );

    window.scaleSlider:SetScript(
        "OnValueChanged",
        function(self, value)
            if OptionsUI._syncing then
                return;
            end

            BB.Settings:set(
                "scale",
                tonumber(value)
                or BB.Data.Constants.DEFAULT_SCALE
            );

            BB.Frames:checkNow();
        end
    );

    window.posXSlider =
        createSlider(
            window,
            "BloomBuddyOptionsPosXSlider",
            BB.L.positionXLabel,
            -40,
            40,
            1
        );

    window.posXSlider:SetPoint(
        "TOP",
        window.scaleSlider,
        "BOTTOM",
        0,
        -(
            SLIDER_LABEL_HEIGHT
            + SLIDER_LABEL_GAP
            + ROW_GAP
        )
    );

    window.posXSlider:SetScript(
        "OnValueChanged",
        function(self, value)
            if OptionsUI._syncing then
                return;
            end

            BB.Settings:set(
                "overlayPosX",
                tonumber(value) or 0
            );

            BB.Frames:checkNow();
        end
    );

    attachTooltip(
        window.posXSlider,
        {
            BB.L.positionXHelp
        },
        BB.L.positionXLabel
    );

    window.posYSlider =
        createSlider(
            window,
            "BloomBuddyOptionsPosYSlider",
            BB.L.positionYLabel,
            -40,
            40,
            1
        );

    window.posYSlider:SetPoint(
        "TOP",
        window.posXSlider,
        "BOTTOM",
        0,
        -(
            SLIDER_LABEL_HEIGHT
            + SLIDER_LABEL_GAP
            + ROW_GAP
        )
    );

    window.posYSlider:SetScript(
        "OnValueChanged",
        function(self, value)
            if OptionsUI._syncing then
                return;
            end

            BB.Settings:set(
                "overlayPosY",
                tonumber(value) or 0
            );

            BB.Frames:checkNow();
        end
    );

    attachTooltip(
        window.posYSlider,
        {
            BB.L.positionYHelp
        },
        BB.L.positionYLabel
    );

    window.swipeCheck =
        createCheckbox(
            window,
            BB.L.swipeLabel
        );

    window.swipeCheck:SetPoint(
        "TOP",
        window.posYSlider,
        "BOTTOM",
        -checkBlockHalfWidth(
            window.swipeCheck
        ),
        -ROW_GAP
    );

    window.swipeCheck:SetScript(
        "OnClick",
        function(self)
            if OptionsUI._syncing then
                return;
            end

            BB.Settings:set(
                "showSwipe",
                self:GetChecked() == true
            );

            BB.Frames:checkNow();
        end
    );

    window.timerCheck =
        createCheckbox(
            window,
            BB.L.timerLabel
        );

    window.timerCheck:SetPoint(
        "TOP",
        window.swipeCheck,
        "BOTTOM",
        checkBlockHalfWidth(
            window.swipeCheck
        )
        - checkBlockHalfWidth(
            window.timerCheck
        ),
        -ROW_GAP
    );

    window.timerCheck:SetScript(
        "OnClick",
        function(self)
            if OptionsUI._syncing then
                return;
            end

            BB.Settings:set(
                "showTimer",
                self:GetChecked() == true
            );

            BB.Frames:checkNow();
        end
    );

    local resetButton =
        CreateFrame(
            "Button",
            "BloomBuddyOptionsResetButton",
            window,
            "UIPanelButtonTemplate"
        );

    resetButton:SetSize(
        160,
        RESET_HEIGHT
    );

    resetButton:SetPoint(
        "TOP",
        window.timerCheck,
        "BOTTOM",
        checkBlockHalfWidth(
            window.timerCheck
        ),
        -ROW_GAP
    );

    resetButton:SetText(
        BB.L.resetButton
    );

    resetButton:SetScript(
        "OnClick",
        function()
            BB.Settings:reset();

            syncControls(window);

            BB.Frames:checkNow();

            BB:print(
                BB.L.optionsReset
            );
        end
    );

    OptionsUI._window = window;

    return window;
end

local function toggleOptions()
    local window =
        ensureWindow();

    if window:IsShown() then
        window:Hide();
        return;
    end

    syncControls(window);
    window:Show();
end

local function showStatus()
    BB:print(
        BB.L.status,
        tostring(
            BB.Settings:get("enabled")
        ),
        tonumber(
            BB.Settings:get("scale")
        ) or 0.5,
        tostring(
            BB.Settings:get("party")
        ),
        tostring(
            BB.Settings:get("raid")
        ),
        tostring(
            BB.Settings:get("showTimer")
            == true
        ),
        tostring(
            BB.Settings:get("showSwipe")
            ~= false
        )
    );

    BB.Frames:checkNow();
end

local function printHelp()
    BB:print(
        BB.L.help
    );
end

local function handleInput(input)
    local command =
        strlower(
            trim(input or "")
        );

    if command == "" then
        toggleOptions();

    elseif command == "options" then
        toggleOptions();

    elseif command == "status" then
        showStatus();

    elseif command == "enable" then
        BB.Settings:set(
            "enabled",
            true
        );

        BB.Frames:ensureTicker();
        BB.Frames:checkNow();

        BB:print(
            BB.L.enabled
        );

    elseif command == "disable" then
        BB.Settings:set(
            "enabled",
            false
        );

        BB.Frames:stopTicker();
        BB.Frames:checkNow();

        BB:print(
            BB.L.disabled
        );

    elseif command == "timer" then
        local current =
            BB.Settings:get("showTimer")
            == true;

        BB.Settings:set(
            "showTimer",
            not current
        );

        BB.Frames:checkNow();

        BB:print(
            BB.L.timerToggled,
            tostring(not current)
        );

    elseif command == "debug" then
        BB.debug = not BB.debug;

        BB:print(
            BB.L.debugToggled,
            BB.debug
                and "on"
                or "off"
        );

        BB.Frames:dumpOverlays();

    elseif command == "help" then
        printHelp();

    else
        BB:print(
            BB.L.unknownCommand,
            command
        );
    end
end

function OptionsUI:_init()
    if self._initialized then
        return;
    end

    self._initialized = true;

    SlashCmdList["BLOOMBUDDY"] =
        function(input)
            handleInput(input);
        end;
end

return BB;