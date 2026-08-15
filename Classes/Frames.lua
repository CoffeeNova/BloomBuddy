-- BloomBuddy — Classes/Frames
-- CORE: when a compact party/raid frame member has the Lifebloom HoT, show an
-- enlarged Lifebloom icon on that member's frame.
--
-- CLIENT FACT (verified 2026-08 on TBC Anniversary 2.5.6): the native buff icons
-- on compact frames are rendered by the game engine (C) — there is no Lua-accessible
-- per-buff icon to SetSize and no per-buff hide filter. `frame.auraSize` would scale
-- ALL buffs+debuffs of a member uniformly, so it is never used. The working-addon
-- pattern on this client (SweepyBoop, BigDebuffs) is a CUSTOM OVERLAY ICON, which is
-- what this module draws.
--
-- The real compact-frame hook point on 2.5.6 is `CompactUnitFrame_UpdateAll(frame)`
-- (fires per frame on setup/reuse). `CompactUnitFrame_UpdateBuff` does NOT exist on
-- this client. Detection is by spellID via C_UnitAuras.GetAuraDataByIndex (the legacy
-- UnitBuff/UnitAura wrappers are broken on 2.5.5 — see the wow-api-20506 skill).
--
-- Remaining time = native Cooldown swipe (CooldownFrame_Set, C-driven darkening sweep);
-- the widget opts out of countdown add-ons via `noCooldownCount` (OmniCC) and the
-- native numbers via SetHideCountdownNumbers. Stack count = aura.applications (NOT
-- .count — see the unit-frame-buffs skill); the digital countdown is opt-in via the
-- `showTimer` setting (/bb timer, default off).
--
-- VERIFY (in game) before trusting: the Lifebloom spell IDs (33763 R1 confirmed; R2/R3
-- unlearned on the tester), that `CompactUnitFrame_UpdateAll` fires for
-- `CompactPartyFrameMember<N>` / `CompactRaidFrame<N>`, and the overlay placement. See
-- .agents/skills/unit-frame-buffs/SKILL.md.

---@type BB
local _, BB = ...;

local ipairs = _G.ipairs;
local pairs = _G.pairs;
local math = _G.math;
local string = _G.string;
local table = _G.table;
local tonumber = _G.tonumber;
local tostring = _G.tostring;
local GetTime = _G.GetTime;
local SecureHook = _G.SecureHook;
local CooldownFrame_Set = _G.CooldownFrame_Set;
local CooldownFrame_Clear = _G.CooldownFrame_Clear;

---@class Frames
local Frames = {
    _initialized = false,

    ---@type table<table, boolean>
    _frames = {},
};

---@type Frames
BB.Frames = Frames;

--- Is the addon enabled?
---@return boolean
local function isEnabled()
    return BB.Settings:get("enabled") ~= false;
end

--- The configured scale multiplier (clamped to at least 1).
---@return number
local function scaleFactor()
    local scale = tonumber(BB.Settings:get("scale")) or BB.Data.Constants.DEFAULT_SCALE;
    return math.max(1, scale);
end

--- Should this compact frame be processed, based on its unit and the settings?
--- Compact party frames honor `party`; compact raid frames honor `raid`.
---@param frame table
---@return boolean
local function frameEnabled(frame)
    local unit = frame and (frame.displayedUnit or frame.unit);

    if (unit and unit:sub(1, 5) == "party") then
        return BB.Settings:get("party") ~= false;
    elseif (unit and unit:sub(1, 4) == "raid") then
        return BB.Settings:get("raid") ~= false;
    end

    -- Unknown unit token — default to the party gate.
    return BB.Settings:get("party") ~= false;
end

--- The Lifebloom icon texture, resolved once (runtime call, may be nil before login).
---@return string
local cachedTexture;
local function overlayTexture()
    if (cachedTexture) then
        return cachedTexture;
    end

    local GetSpellTexture = _G.GetSpellTexture;
    cachedTexture = (GetSpellTexture and GetSpellTexture(BB.Data.Constants.LIFEBLOOM_SPELL_IDS[1]))
        or BB.Data.Constants.LIFEBLOOM_TEXTURE;

    return cachedTexture;
end

--- Create (once) the overlay child frame on a compact frame and cache it there.
--- The overlay carries the icon texture, a native Cooldown widget for the
--- remaining-time swipe, and two FontStrings: the stack count (bottom-right)
--- and the optional digital countdown (bottom-center, only with `showTimer`).
--- Creation is pcall-guarded because compact frames can be protected.
---@param frame table
---@return table|nil
local function ensureOverlay(frame)
    local overlay = frame.BB_LifebloomOverlay;

    if (overlay) then
        return overlay;
    end

    local ok, created = pcall(function()
        local child = CreateFrame("Frame", nil, frame);
        child:SetFrameLevel(frame:GetFrameLevel() + BB.Data.Constants.OVERLAY_FRAME_LEVEL);
        child.texture = child:CreateTexture(nil, "ARTWORK");
        child.texture:SetAllPoints(child);
        child.texture:SetTexture(overlayTexture());
        child:Hide();

        -- Native cooldown swipe: the client animates the darkening clockwise
        -- sweep by itself (pattern: BigDebuffs, ClassicAuraDurations, M6).
        -- MUST use "CooldownFrameTemplate" (VERIFIED: every working addon on
        -- this client creates it that way) — a bare CreateFrame("Cooldown")
        -- has NO swipe texture, so the sweep ran invisibly (verified via
        -- /bb debug: sweep=Y, dur=7000, but nothing rendered).
        child.cooldown = CreateFrame("Cooldown", nil, child, "CooldownFrameTemplate");
        child.cooldown:SetAllPoints(child);
        child.cooldown:SetAlpha(1);
        child.cooldown:SetSwipeColor(0, 0, 0, 0.7);
        child.cooldown:SetDrawEdge(false);
        child.cooldown:SetDrawBling(false);
        -- SetReverse(true) is the client-correct sweep direction (VERIFIED: every
        -- working addon on this client — BigDebuffs, SweepyBoop, ClassicAuraDurations,
        -- BetterBlizzFrames — sets it). The default (false) sweeps the WRONG way:
        -- the icon lightens instead of darkening (round-5 user feedback).
        child.cooldown:SetReverse(true);
        child.cooldown:SetDrawSwipe(true);
        child.cooldown:SetHideCountdownNumbers(true);
        -- Opt out of countdown add-ons (OmniCC): `noCooldownCount` is their
        -- official per-widget flag to leave a Cooldown frame alone (no numbers).
        child.cooldown.noCooldownCount = true;
        child.cooldown:Hide();

        local fontFile = (_G.GameFontNormal and _G.GameFontNormal:GetFont()) or "Fonts\\FRIZQT__.TTF";

        if (BB.Data.Constants.SHOW_STACKS) then
            child.stacks = child:CreateFontString(nil, "OVERLAY");
            child.stacks:SetFont(fontFile, BB.Data.Constants.OVERLAY_STACKS_SIZE, "THICKOUTLINE");
            child.stacks:SetPoint(
                BB.Data.Constants.OVERLAY_STACKS_ANCHOR, child, BB.Data.Constants.OVERLAY_STACKS_ANCHOR,
                BB.Data.Constants.OVERLAY_STACKS_OFFSET_X, BB.Data.Constants.OVERLAY_STACKS_OFFSET_Y
            );
            child.stacks:SetTextColor(1, 1, 1);
            child.stacks:SetText("");
        end

        if (BB.Data.Constants.SHOW_TIMER) then
            child.timer = child:CreateFontString(nil, "OVERLAY");
            child.timer:SetFont(fontFile, BB.Data.Constants.OVERLAY_TIMER_SIZE, "THICKOUTLINE");
            child.timer:SetPoint(
                BB.Data.Constants.OVERLAY_TIMER_ANCHOR, child, BB.Data.Constants.OVERLAY_TIMER_ANCHOR,
                0, BB.Data.Constants.OVERLAY_TIMER_OFFSET_Y
            );
            child.timer:SetTextColor(1, 1, 1);
            child.timer:SetText("");
        end

        return child;
    end);

    if (ok and created) then
        created:ClearAllPoints();
        created:SetPoint(
            BB.Data.Constants.OVERLAY_ANCHOR, frame, BB.Data.Constants.OVERLAY_ANCHOR,
            BB.Data.Constants.OVERLAY_OFFSET_X, BB.Data.Constants.OVERLAY_OFFSET_Y
        );
        frame.BB_LifebloomOverlay = created;
    end

    return created;
end

--- Format a remaining duration (seconds) as "m:ss" (>= 60 s) or "N" (ceil).
---@param seconds number
---@return string
local function formatDuration(seconds)
    if (not seconds or seconds <= 0) then
        return "";
    end

    if (seconds >= 60) then
        return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60));
    end

    return string.format("%d", math.ceil(seconds));
end

--- Update the overlay's cooldown swipe, stacks and (optional) timer text from
--- the aura data. Missing/secret values are guarded (swipe cleared, text blank).
---@param overlay table
---@param aura table
local function updateOverlay(overlay, aura)
    if (overlay.cooldown) then
        local duration = aura and tonumber(aura.duration) or 0;
        local remaining = (aura and aura.expirationTime and (aura.expirationTime - GetTime())) or 0;

        if (duration and duration > 0 and remaining and remaining > 0) then
            CooldownFrame_Set(overlay.cooldown, aura.expirationTime - duration, duration, true);
            overlay.cooldown:Show();
        else
            CooldownFrame_Clear(overlay.cooldown);
            overlay.cooldown:Hide();
        end
    end

    if (overlay.stacks) then
        -- Stack count is `.applications` on this client (BigDebuffs,
        -- BetterBlizzFrames, ArenaAnalytics) — `.count` is NOT the field.
        local stacks = aura and (tonumber(aura.applications) or tonumber(aura.charges)) or 0;
        overlay.stacks:SetText((stacks and stacks > 1) and tostring(stacks) or "");
    end

    if (overlay.timer) then
        -- Digital countdown is opt-in (`showTimer`, default off).
        if (BB.Settings:get("showTimer")) then
            local remaining = (aura and aura.expirationTime and (aura.expirationTime - GetTime())) or 0;
            overlay.timer:SetText(formatDuration(remaining));
        else
            overlay.timer:SetText("");
        end
    end
end

--- Hide an overlay (and its cooldown swipe) for a compact frame.
---@param frame table
---@param unit string|nil
local function hideOverlay(frame, unit)
    local overlay = frame.BB_LifebloomOverlay;

    if (not overlay) then
        return;
    end

    if (overlay.cooldown and overlay.cooldown:IsShown()) then
        CooldownFrame_Clear(overlay.cooldown);
        overlay.cooldown:Hide();
    end

    if (overlay:IsShown()) then
        BB:debugPrint("compact overlay: hide %s (%s)", frame:GetName() or "?", unit or "?");
    end
    overlay:Hide();
end

--- Return the Lifebloom aura currently on `unit` (any rank), or nil. The aura
--- object carries the stack count (`.applications`) and expiry (`.expirationTime`
--- / `.duration`) used for the overlay — fields verified as read by BigDebuffs /
--- BetterBlizzFrames on this client.
---@param unit string
---@return table|nil
function Frames:getLifebloomAura(unit)
    if (not unit or not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex) then
        return nil;
    end

    for i = 1, BB.Data.Constants.MAX_AURA_SCAN do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL");

        if (not aura) then
            break;
        end

        if (aura.spellId) then
            for _, id in ipairs(BB.Data.Constants.LIFEBLOOM_SPELL_IDS) do
                if (aura.spellId == id) then
                    return aura;
                end
            end
        end
    end

    return nil;
end

--- Does the unit currently hold a Lifebloom (any rank)?
---@param unit string
---@return boolean
function Frames:isLifebloomAura(unit)
    return self:getLifebloomAura(unit) ~= nil;
end

--- Refresh one compact frame's overlay (show/hide/size).
---@param frame table
---@return number 1 if the overlay is shown, else 0
local function updateFrame(self, frame)
    if (frame == nil or frame:IsForbidden() or not isEnabled()) then
        return 0;
    end

    if (not frameEnabled(frame)) then
        hideOverlay(frame);
        return 0;
    end

    local unit = frame.displayedUnit or frame.unit;

    -- Skip hidden/invalid frames without creating an overlay for them (the
    -- CompactUnitFrame_UpdateAll hook + ticker create it once the frame is shown).
    if (not frame:IsShown() or not unit or not UnitExists(unit)) then
        hideOverlay(frame, unit);
        return 0;
    end

    local overlay = ensureOverlay(frame);
    if (not overlay) then
        return 0;
    end

    local aura = self:getLifebloomAura(unit);

    if (aura) then
        local size = math.max(1, math.floor(BB.Data.Constants.OVERLAY_BASE_SIZE * scaleFactor()));
        overlay:SetSize(size, size);

        if (not overlay:IsShown()) then
            BB:debugPrint("compact overlay: show %s (%s)", frame:GetName() or "?", unit);
        end
        -- Show the overlay BEFORE driving the Cooldown widget, so the C-side
        -- sweep initializes while the frame is visible.
        overlay:Show();

        updateOverlay(overlay, aura);

        return 1;
    end

    hideOverlay(frame, unit);

    return 0;
end

--- Dump diagnostic state of every tracked compact frame (used by /bb debug):
--- overlay placement vs the frame, cooldown widget state, stacks/timer anchors
--- and text, and the raw aura fields behind them. The header prints immediately;
--- each frame's section is pcall-guarded so one bad frame cannot kill the rest.
function Frames:dumpOverlays()
    local lines = {};
    local count = 0;

    for _ in pairs(self._frames) do
        count = count + 1;
    end

    BB:print("overlay dump: %d tracked frame(s)", count);

    for frame in pairs(self._frames) do
        local ok, err = pcall(function()
            local name = frame:GetName() or "?";
            local unit = frame.displayedUnit or frame.unit or "?";
            lines[#lines + 1] = string.format(
                "  [%s] unit=%s shown=%s", name, tostring(unit), frame:IsShown() and "Y" or "N"
            );

            local overlay = frame.BB_LifebloomOverlay;

            if (not overlay) then
                lines[#lines + 1] = "    overlay=nil";
                return;
            end

            lines[#lines + 1] = string.format(
                "    overlay shown=%s rect=%.0fx%.0f at L%.0f,B%.0f  (frame %dx%d at L%.0f,B%.0f)",
                overlay:IsShown() and "Y" or "N",
                overlay:GetWidth() or 0, overlay:GetHeight() or 0,
                overlay:GetLeft() or 0, overlay:GetBottom() or 0,
                frame:GetWidth() or 0, frame:GetHeight() or 0,
                frame:GetLeft() or 0, frame:GetBottom() or 0
            );

            if (overlay.cooldown) then
                local start, dur = 0, 0;
                if (overlay.cooldown.GetCooldownTimes) then
                    start, dur = overlay.cooldown:GetCooldownTimes();
                end
                lines[#lines + 1] = string.format(
                    "    cooldown shown=%s sweep=%s start=%.1f dur=%.1f",
                    overlay.cooldown:IsShown() and "Y" or "N",
                    (overlay.cooldown:IsShown() and start and start > 0) and "Y" or "N",
                    start or 0, dur or 0
                );
            end

            if (overlay.stacks) then
                local point, _, relPoint, x, y = overlay.stacks:GetPoint(1);
                lines[#lines + 1] = string.format(
                    "    stacks text=%q at %s/%s %s,%s  (rect L%.0f,B%.0f W%.0f,H%.0f)",
                    tostring(overlay.stacks:GetText() or ""),
                    tostring(point or "?"), tostring(relPoint or "?"),
                    tostring(x or "?"), tostring(y or "?"),
                    overlay.stacks:GetLeft() or 0, overlay.stacks:GetBottom() or 0,
                    overlay.stacks:GetWidth() or 0, overlay.stacks:GetHeight() or 0
                );
            end

            if (overlay.timer) then
                local point, _, relPoint, x, y = overlay.timer:GetPoint(1);
                lines[#lines + 1] = string.format(
                    "    timer text=%q at %s/%s %s,%s",
                    tostring(overlay.timer:GetText() or ""),
                    tostring(point or "?"), tostring(relPoint or "?"),
                    tostring(x or "?"), tostring(y or "?")
                );
            end

            local aura = self:getLifebloomAura(unit);
            if (aura) then
                local remaining = aura.expirationTime and (aura.expirationTime - GetTime()) or 0;
                lines[#lines + 1] = string.format(
                    "    aura spellId=%s remaining=%.1f duration=%s applications=%s",
                    tostring(aura.spellId or "?"), remaining,
                    tostring(aura.duration or "nil"), tostring(aura.applications or "nil")
                );
            else
                lines[#lines + 1] = "    aura=nil";
            end
        end);

        if (not ok) then
            lines[#lines + 1] = "  (frame error: " .. tostring(err) .. ")";
        end
    end

    lines[#lines + 1] = string.format(
        "settings: showTimer=%s", tostring(BB.Settings:get("showTimer") ~= false)
    );

    BB:print(table.concat(lines, "\n"));
end

--- Handler for the CompactUnitFrame_UpdateAll hook: track the frame and refresh it.
---@param frame table|nil
function Frames:onCompactUnitFrameUpdateAll(frame)
    if (not frame or frame:IsForbidden()) then
        return;
    end

    self._frames[frame] = true;
    updateFrame(self, frame);
end

--- UNIT_AURA handler: refresh only the frames currently showing `unit`.
---@param unit string
function Frames:onUnitAura(unit)
    if (not unit) then
        return;
    end

    for frame in pairs(self._frames) do
        if ((frame.displayedUnit or frame.unit) == unit) then
            updateFrame(self, frame);
        end
    end
end

--- Wrap a global function so `afterHandler` runs after the original. Prefers
--- SecureHook; falls back to a manual wrapper when it is unavailable.
---@param funcName string
---@param afterHandler function
---@return boolean hooked
local function hookAfter(funcName, afterHandler)
    local orig = _G[funcName];

    if (not orig) then
        return false;
    end

    if (SecureHook) then
        SecureHook(funcName, afterHandler);
        return true;
    end

    _G[funcName] = function(...)
        local a, b, c, d, e, f = orig(...);
        afterHandler(...);
        return a, b, c, d, e, f;
    end;

    return true;
end

--- Start the periodic safety ticker (idempotent).
function Frames:ensureTicker()
    if (self._tickerActive) then
        return;
    end

    self._tickerActive = true;
    BB.Utils.Timers:interval("Recheck", BB.Data.Constants.RECHECK_TICK, function()
        self:checkNow();
    end);
end

--- Stop the periodic safety ticker (idempotent).
function Frames:stopTicker()
    if (not self._tickerActive) then
        return;
    end

    self._tickerActive = false;
    BB.Utils.Timers:cancel("Recheck");
end

--- Initialize the module: hook the compact-frame updater and register events.
function Frames:_init()
    if (self._initialized) then
        return;
    end
    self._initialized = true;

    self._hookedUpdateAll = hookAfter("CompactUnitFrame_UpdateAll", function(frame)
        self:onCompactUnitFrameUpdateAll(frame);
    end);

    if (not self._hookedUpdateAll) then
        BB:debugPrint("CompactUnitFrame_UpdateAll not found — overlay feature inactive");
    end

    BB.Events:register("BBFrames_UnitAura", "UNIT_AURA", function(unit)
        self:onUnitAura(unit);
    end);
    BB.Events:register("BBFrames_GroupRoster", "GROUP_ROSTER_UPDATE", function()
        self:apply();
    end);

    if (isEnabled()) then
        self:ensureTicker();
    end
end

--- Re-apply the overlays right now (also the initial/`/reload` check).
---@return number
function Frames:checkNow()
    return self:apply();
end

--- Refresh every tracked compact frame. Returns how many overlays are shown.
---@return number
function Frames:apply()
    if (not isEnabled()) then
        self:stopTicker();

        for frame in pairs(self._frames) do
            local overlay = frame.BB_LifebloomOverlay;
            if (overlay) then
                overlay:Hide();
            end
        end

        BB:debugPrint("apply: disabled, hiding overlays");
        return 0;
    end

    self:ensureTicker();

    local count = 0;
    for frame in pairs(self._frames) do
        count = count + updateFrame(self, frame);
    end

    return count;
end

return BB;
