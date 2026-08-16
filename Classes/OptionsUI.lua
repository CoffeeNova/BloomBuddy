-- BloomBuddy — Classes/OptionsUI
-- Slash commands (/bb) + status + the options window (/bb options).
--
-- The window is a minimal standalone dialog (ADR 9, ARCHITECTURE.md): created
-- lazily on the first /bb options, vanilla widgets only, no Ace, no Interface
-- Options registration (legacy InterfaceOptions_AddCategory is nil on 2.5.5).
--
-- LAYOUT (revised 2026-08-17 from user feedback): title bar (title + "?" help +
-- ONE close button — the template's built-in, found by child enumeration, never
-- a second one) → three centered sliders (labels above) → two centered
-- checkboxes (label right of the check) → centered Reset at the bottom. Every
-- adjacent row is separated by the SAME vertical gap (ROW_GAP); the window
-- height is computed from the constants so the layout always fits.
--
-- CLIENT GOTCHAS (verified in working addons / in game on this client, 2026-08):
--   * UIPanelDialogTemplate — proven by OmniCC_Config preview.lua:19. The
--     frame IS named ("BloomBuddyOptionsFrame"): the template children use
--     $parent-based names (e.g. $parentTitleBG) and an unnamed frame risks
--     bad/empty global names — OmniCC names its dialog.
--   * The template DOES ship a close button on this client, but it is NOT
--     reachable via the $parentCloseButton global (round-2 feedback: the name
--     lookup was nil while a second X was still visible). Enumerate the
--     window's children right after CreateFrame — the first Button child IS
--     the template's close button; reuse it, hide strays, create our own only
--     if none (see ensureWindow).
--   * OptionsSliderTemplate creates <name>Low/<name>High globals but NOT
--     <name>Text (LoseControltbc_anni comments the Text line out) — labels
--     are manual FontStrings (wow-api-20506 skill).
--   * UICheckButtonTemplate + manual label FontStrings — AtlasLootClassic
--     pattern (unnamed checkboxes proven there).
--   * GameTooltip:AddLine works here (NovaWorldBuffs).

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

    ---@type table|nil
    _window = nil,
    _syncing = false,
};

---@type OptionsUI
BB.OptionsUI = OptionsUI;

-- Layout constants. Rows: 3 sliders (each with a label above), 2 checkboxes,
-- 1 Reset button. ONE uniform vertical gap (ROW_GAP) separates every adjacent
-- row; the window height is COMPUTED from the constants so the layout always
-- fits with equal spacing (revised 2026-08-17 from feedback: was 24/24/32/24/6).
local WINDOW_WIDTH = 260;

local CONTENT_TOP_PADDING = 48; -- window TOP → first slider LABEL TOP (clears the title band)
local ROW_GAP = 20;             -- UNIFORM visual gap between every adjacent row
local BOTTOM_PADDING = 16;      -- window BOTTOM → Reset button BOTTOM

local SLIDER_WIDTH = 150;
local SLIDER_HEIGHT = 16;       -- OptionsSliderTemplate track height
local SLIDER_LABEL_HEIGHT = 13; -- GameFontNormalSmall line height (approx)
local SLIDER_LABEL_GAP = 2;     -- gap between the slider and its label

local CHECKBOX_SIZE = 24;       -- UICheckButtonTemplate box size
local CHECKBOX_LABEL_GAP = 6;   -- gap between the check box and its label

-- Inset of the "?" help button from the window's TOP-left edges, split per
-- axis so each can be tuned separately:
--   HELP_INSET_X — horizontal inset from the window's LEFT edge (X position).
--   HELP_INSET_Y — vertical inset from the window's TOP edge (Y position).
-- The template's border ring is ~10 px thick on this client (calibrated by
-- OmniCC_Config's content inset "TOPLEFT (10, -27)"), so a button flush to
-- the corner (2 px) overlaps it. 10 px keeps the button fully inside the
-- border while mirroring the close button's visually rendered position
-- (32 px button at TOPRIGHT (2,-2) → its glyph sits ~10 px from the edges).
local HELP_INSET_X = 7;
local HELP_INSET_Y = 5;

local RESET_HEIGHT = 22;        -- UIPanelButtonTemplate height

-- Derived window height: content top + 3 slider rows (label + gap + slider)
-- + 2 checkbox rows + Reset + 5 uniform row gaps + bottom padding.
local WINDOW_HEIGHT = CONTENT_TOP_PADDING
    + 3 * (SLIDER_LABEL_HEIGHT + SLIDER_LABEL_GAP + SLIDER_HEIGHT)
    + 2 * CHECKBOX_SIZE
    + RESET_HEIGHT
    + 5 * ROW_GAP
    + BOTTOM_PADDING;

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
        tostring(BB.Settings:get("showTimer") ~= false),
        tostring(BB.Settings:get("showSwipe") ~= false));

    local scaled = BB.Frames:checkNow();
    BB:print(BB.L.scaledIcons, scaled);
end

local function printHelp()
    BB:print(BB.L.help);
end

--- Create a labeled slider (OptionsSliderTemplate). Named — the template
--- creates <name>Low/<name>High; the label is a manual FontString above it.
--- The caller anchors the slider (relative to the window or the previous row).
---@param parent table
---@param name string
---@param label string
---@param low number
---@param high number
---@param step number
---@return table
local function createSlider(parent, name, label, low, high, step)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate");
    slider:SetSize(SLIDER_WIDTH, SLIDER_HEIGHT);
    slider:SetMinMaxValues(low, high);
    slider:SetValueStep(step);

    local labelText = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall");
    labelText:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", -2, SLIDER_LABEL_GAP);
    labelText:SetText(label);

    local lowText = _G[name .. "Low"];
    local highText = _G[name .. "High"];

    if (lowText) then
        lowText:SetText(low);
    end

    if (highText) then
        highText:SetText(high);
    end

    return slider;
end

--- Create a labeled checkbox (UICheckButtonTemplate + manual label). The label
--- sits on the SAME line as the check box (anchored to its RIGHT, y = 0 → same
--- vertical center). The caller anchors the check box; use checkBlockHalfWidth
--- to center the whole block on the window's horizontal axis.
---@param parent table
---@param label string
---@return table
local function createCheckbox(parent, label)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate");
    check:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE);

    local text = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal");
    text:SetPoint("LEFT", check, "RIGHT", CHECKBOX_LABEL_GAP, 0);
    text:SetText(label);
    text:SetJustifyH("LEFT");
    check.label = text;

    return check;
end

--- Half-width of a checkbox block (check box + gap + label), measured from the
--- check box's center — the X offset that centers the block on the window axis.
---@param check table
---@return number
local function checkBlockHalfWidth(check)
    local labelWidth = (check.label and check.label:GetStringWidth()) or 0;
    return (labelWidth + CHECKBOX_LABEL_GAP) / 2;
end

--- Attach a hover tooltip to a widget.
---@param widget table
---@param lines table<string>|nil
---@param title string|nil
local function attachTooltip(widget, lines, title)
    widget:SetScript("OnEnter", function(self)
        if (not GameTooltip) then
            return;
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

        if (title) then
            GameTooltip:AddLine(title, 1, 1, 1);
        end

        if (lines) then
            for _, line in ipairs(lines) do
                GameTooltip:AddLine(line, 1, 0.82, 0);
            end
        end

        GameTooltip:Show();
    end);

    widget:SetScript("OnLeave", function()
        if (GameTooltip) then
            GameTooltip:Hide();
        end
    end);
end

--- Re-read every control from BB.Settings (called each time the window opens,
--- so external changes — /bb timer, /bb enable — are reflected).
---@param window table
local function syncControls(window)
    local settings = BB.Settings;
    OptionsUI._syncing = true;

    window.scaleSlider:SetValue(tonumber(settings:get("scale")) or BB.Data.Constants.DEFAULT_SCALE);
    window.posXSlider:SetValue(tonumber(settings:get("overlayPosX")) or 0);
    window.posYSlider:SetValue(tonumber(settings:get("overlayPosY")) or 0);
    window.swipeCheck:SetChecked(settings:get("showSwipe") ~= false);
    window.timerCheck:SetChecked(settings:get("showTimer") ~= false);

    OptionsUI._syncing = false;
end

--- Lazily create the options window on the first /bb options.
---@return table
local function ensureWindow()
    if (OptionsUI._window) then
        return OptionsUI._window;
    end

    local window = CreateFrame("Frame", "BloomBuddyOptionsFrame", UIParent, "UIPanelDialogTemplate");
    window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT);
    window:SetPoint("CENTER");
    window:SetAlpha(0.9);
    window:SetClampedToScreen(true);
    window:SetMovable(true);
    -- EnableMouse explicitly — OmniCC_Config's dialog (the same template) calls
    -- it too; the OnMouseDown drag below only works when the frame receives mouse.
    window:EnableMouse(true);
    window:SetToplevel(true);
    window:Hide();

    -- Drag: grab the window background / title area.
    window:SetScript("OnMouseDown", function(self, button)
        if (button == "LeftButton") then
            self:StartMoving();
        end
    end);
    window:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing();
    end);

    -- The template's title band ($parentTitleBG) — anchor point for the title
    -- and the "?" button (both vertically centered on the band). OmniCC uses
    -- the same child on this client.
    local titleBand = _G["BloomBuddyOptionsFrameTitleBG"];

    -- Title: centered on the title band.
    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
    title:SetText(BB.L.panelTitle);

    if (titleBand) then
        title:SetPoint("CENTER", titleBand, "CENTER", 0, 0);
    else
        title:SetPoint("TOP", window, "TOP", 0, -18);
    end

    -- Close ("X", top-right): the template DOES ship its own close button on
    -- this client, but it is NOT reliably reachable via the $parentCloseButton
    -- global (round-2 feedback: the name lookup came back nil while a second X
    -- was still visible — two overlapping X's again). Enumerate the window's
    -- children instead: at this point (before we create any of our own buttons)
    -- the only Button child IS the template's close button. Reuse it, hide any
    -- further strays, create our own only when the template has none — exactly
    -- ONE close button, always.
    local closeButton = nil;

    for _, child in ipairs({ window:GetChildren() }) do
        if (child:GetObjectType() == "Button") then
            if (closeButton) then
                child:Hide(); -- stray extra close buttons (shouldn't happen)
            else
                closeButton = child;
            end
        end
    end

    if (not closeButton) then
        closeButton = CreateFrame("Button", "BloomBuddyOptionsCloseButton", window, "UIPanelCloseButton");
    end

    closeButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", 2, -2);
    closeButton:Enable();
    closeButton:SetScript("OnClick", function()
        window:Hide();
    end);
    closeButton:Show();

    -- Help ("?", top-left): anchored to the WINDOW with separate per-axis
    -- insets (HELP_INSET_X / HELP_INSET_Y), NOT to the title band's left
    -- edge (the band can sit inset from the frame edge — round-3 feedback)
    -- and NOT flush to the corner (at (2,-2) the button's 24x24 background
    -- overlapped the template's border ring — round-4 feedback 2026-08-17).
    -- 10 px keeps the whole button inside the border and mirrors the X's
    -- visually rendered position (same horizontal inset, same vertical
    -- level, same distance from the title bar's top edge).
    local helpButton = CreateFrame("Button", "BloomBuddyOptionsHelpButton", window, "UIPanelButtonTemplate");
    helpButton:SetSize(24, 24);
    helpButton:SetText("?");
    helpButton:SetPoint("TOPLEFT", window, "TOPLEFT", HELP_INSET_X, -HELP_INSET_Y);

    attachTooltip(helpButton, {
        BB.L.optionsHelpStatus,
        BB.L.optionsHelpOptions,
        BB.L.optionsHelpEnable,
        BB.L.optionsHelpTimer,
        BB.L.optionsHelpDebug,
        BB.L.optionsHelpHelp,
    }, BB.L.optionsHelpTitle);

    -- Icon size slider (live) — first content row under the title bar. Its
    -- label (anchored inside createSlider, 15 px above the slider) must clear
    -- the title band: CONTENT_TOP_PADDING counts from the window TOP to the
    -- LABEL TOP.
    window.scaleSlider = createSlider(window, "BloomBuddyOptionsScaleSlider", BB.L.sizeLabel, 1.0, 3.0, 0.1);
    window.scaleSlider:SetPoint("TOP", window, "TOP", 0, -(CONTENT_TOP_PADDING + SLIDER_LABEL_HEIGHT + SLIDER_LABEL_GAP));
    window.scaleSlider:SetScript("OnValueChanged", function(self, value)
        if (OptionsUI._syncing) then
            return;
        end

        BB.Settings:set("scale", tonumber(value) or BB.Data.Constants.DEFAULT_SCALE);
        BB.Frames:checkNow();
    end);

    -- Position sliders: persisted stubs — values are saved but NOT applied
    -- (the overlay does not move yet). Tooltip says so. Next row: label + gap
    -- + ROW_GAP below the previous slider, so the visual gap (previous slider
    -- bottom → this row's label top) equals ROW_GAP — uniform spacing.
    window.posXSlider = createSlider(window, "BloomBuddyOptionsPosXSlider", BB.L.positionXLabel, -40, 40, 1);
    window.posXSlider:SetPoint("TOP", window.scaleSlider, "BOTTOM", 0, -(SLIDER_LABEL_HEIGHT + SLIDER_LABEL_GAP + ROW_GAP));
    window.posXSlider:SetScript("OnValueChanged", function(self, value)
        if (OptionsUI._syncing) then
            return;
        end

        BB.Settings:set("overlayPosX", tonumber(value) or 0);
    end);
    attachTooltip(window.posXSlider, { BB.L.positionStubNote }, BB.L.positionNotImplemented);

    window.posYSlider = createSlider(window, "BloomBuddyOptionsPosYSlider", BB.L.positionYLabel, -40, 40, 1);
    window.posYSlider:SetPoint("TOP", window.posXSlider, "BOTTOM", 0, -(SLIDER_LABEL_HEIGHT + SLIDER_LABEL_GAP + ROW_GAP));
    window.posYSlider:SetScript("OnValueChanged", function(self, value)
        if (OptionsUI._syncing) then
            return;
        end

        BB.Settings:set("overlayPosY", tonumber(value) or 0);
    end);
    attachTooltip(window.posYSlider, { BB.L.positionStubNote }, BB.L.positionNotImplemented);

    -- Checkboxes (live) — a centered block (check + label on one line).
    -- The sliders are centered, so their BOTTOM x = the window axis; anchoring
    -- the first block there with -halfWidth centers it exactly. Uniform ROW_GAP.
    window.swipeCheck = createCheckbox(window, BB.L.swipeLabel);
    window.swipeCheck:SetPoint("TOP", window.posYSlider, "BOTTOM", -checkBlockHalfWidth(window.swipeCheck), -ROW_GAP);
    window.swipeCheck:SetScript("OnClick", function(self)
        if (OptionsUI._syncing) then
            return;
        end

        BB.Settings:set("showSwipe", self:GetChecked() ~= nil);
        BB.Frames:checkNow();
    end);

    -- The second row anchors to the first; its X offset compensates for the
    -- first row's own centering offset, so THIS block is centered too.
    window.timerCheck = createCheckbox(window, BB.L.timerLabel);
    window.timerCheck:SetPoint("TOP", window.swipeCheck, "BOTTOM",
        checkBlockHalfWidth(window.swipeCheck) - checkBlockHalfWidth(window.timerCheck),
        -ROW_GAP);
    window.timerCheck:SetScript("OnClick", function(self)
        if (OptionsUI._syncing) then
            return;
        end

        BB.Settings:set("showTimer", self:GetChecked() ~= nil);
        BB.Frames:checkNow();
    end);

    -- Reset (centered at the bottom): defaults + re-sync + re-apply + confirmation.
    -- Anchored ROW_GAP below the last checkbox; BOTTOM_PADDING is the clearance
    -- to the window's bottom edge (window height is computed to match). The
    -- x-offset moves the button to the checkbox BLOCK's center (= the window
    -- axis): the check box's own CENTER is offset by the label compensation
    -- (checkBlockHalfWidth), so a plain x=0 drifted the button left of center
    -- (user feedback 2026-08-17). Vertical position is unchanged.
    local resetButton = CreateFrame("Button", "BloomBuddyOptionsResetButton", window, "UIPanelButtonTemplate");
    resetButton:SetSize(140, RESET_HEIGHT);
    resetButton:SetPoint("TOP", window.timerCheck, "BOTTOM", checkBlockHalfWidth(window.timerCheck), -ROW_GAP);
    resetButton:SetText(BB.L.resetButton);
    resetButton:SetScript("OnClick", function()
        BB.Settings:reset();
        syncControls(window);
        BB.Frames:checkNow();
        BB:print(BB.L.optionsReset);
    end);

    OptionsUI._window = window;

    return window;
end

--- Toggle the options window: open (re-synced from settings) or close.
local function toggleOptions()
    local window = ensureWindow();

    if (window:IsShown()) then
        window:Hide();
    else
        syncControls(window);
        window:Show();
    end
end

--- Handle a slash command.
---@param input string
local function handleInput(input)
    local command = strlower(trim(input or ""));

    if (command == "" or command == "status") then
        showStatus();
    elseif (command == "options") then
        toggleOptions();
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