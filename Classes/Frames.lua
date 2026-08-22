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
local UnitExists = _G.UnitExists;
local UnitGUID = _G.UnitGUID;
local SecureHook = _G.SecureHook;
local CooldownFrame_Set = _G.CooldownFrame_Set;
local CooldownFrame_Clear = _G.CooldownFrame_Clear;

---@class Frames
local Frames = {
    _initialized = false,
    _frames = {},
    _tickerActive = false,
};

BB.Frames = Frames;

local cachedTexture;

local function isEnabled()
    return BB.Settings:get("enabled") ~= false;
end

local function frameEnabled(frame)
    local unit = frame and (frame.displayedUnit or frame.unit);

    if unit and unit:sub(1, 5) == "party" then
        return BB.Settings:get("party") ~= false;
    end

    if unit and unit:sub(1, 4) == "raid" then
        return BB.Settings:get("raid") ~= false;
    end

    return BB.Settings:get("party") ~= false;
end

local function getScale()
    local scale = tonumber(
        BB.Settings:get("scale")
    );

    if not scale then
        scale = BB.Data.Constants.DEFAULT_SCALE;
    end

    return math.max(
        0.5,
        math.min(1.5, scale)
    );
end

local function overlayTexture()
    if cachedTexture then
        return cachedTexture;
    end

    local GetSpellTexture = _G.GetSpellTexture;

    cachedTexture =
        (GetSpellTexture and GetSpellTexture(
            BB.Data.Constants.LIFEBLOOM_SPELL_IDS[1]
        ))
        or BB.Data.Constants.LIFEBLOOM_TEXTURE;

    return cachedTexture;
end

local function getOverlaySize(frame)
    local frameHeight =
        frame:GetHeight() or 0;

    if frameHeight <= 0 then
        frameHeight = 40;
    end

    local baseSize =
        frameHeight
        * BB.Data.Constants.OVERLAY_FRAME_HEIGHT_RATIO;

    return math.max(
        1,
        math.floor(
            baseSize * getScale() + 0.5
        )
    );
end

local function getPositionLimits(
    frame,
    size
)
    local width =
        frame:GetWidth() or size;

    local height =
        frame:GetHeight() or size;

    local halfWidth =
        width / 2;

    local halfHeight =
        height / 2;

    local halfSize =
        size / 2;

    return {
        minX = -(
            halfWidth - halfSize
        ),

        maxX =
            halfWidth - halfSize,

        minY = -(
            halfHeight - halfSize
        ),

        maxY =
            halfHeight - halfSize,
    };
end

local function clampPosition(
    frame,
    size,
    x,
    y
)
    local limits =
        getPositionLimits(
            frame,
            size
        );

    x = math.max(
        limits.minX,
        math.min(
            limits.maxX,
            x
        )
    );

    y = math.max(
        limits.minY,
        math.min(
            limits.maxY,
            y
        )
    );

    return x, y;
end

local function getPosition(
    frame,
    size
)
    local x =
        tonumber(
            BB.Settings:get("overlayPosX")
        )
        or 0;

    local storedY =
        BB.Settings:get("overlayPosY");

    local y;

    if storedY == "TOP" then
        local frameHeight =
            frame:GetHeight() or 0;

        if frameHeight <= 0 then
            frameHeight = 40;
        end

        -- CENTER anchor:
        -- move the icon upward by half the frame height
        -- minus half the icon height.
        y =
            (
                frameHeight / 2
            )
            - (
                size / 2
            );
    else
        y =
            tonumber(storedY)
            or 0;
    end

    return clampPosition(
        frame,
        size,
        x,
        y
    );
end

local function createOverlay(frame)
    local ok, overlay =
        pcall(function()
            local child =
                CreateFrame(
                    "Frame",
                    nil,
                    frame
                );

            child:SetFrameLevel(
                frame:GetFrameLevel()
                + BB.Data.Constants.OVERLAY_FRAME_LEVEL
            );

            child.texture =
                child:CreateTexture(
                    nil,
                    "ARTWORK"
                );

            child.texture:SetAllPoints(
                child
            );

            child.texture:SetTexture(
                overlayTexture()
            );

            child.cooldown =
                CreateFrame(
                    "Cooldown",
                    nil,
                    child,
                    "CooldownFrameTemplate"
                );

            child.cooldown:SetAllPoints(
                child
            );

            child.cooldown:SetAlpha(1);

            child.cooldown:SetSwipeColor(
                0,
                0,
                0,
                0.7
            );

            child.cooldown:SetDrawEdge(
                false
            );

            child.cooldown:SetDrawBling(
                false
            );

            child.cooldown:SetReverse(
                true
            );

            child.cooldown:SetDrawSwipe(
                true
            );

            child.cooldown:SetHideCountdownNumbers(
                true
            );

            child.cooldown.noCooldownCount =
                true;

            child.cooldown:Hide();

            local fontFile =
                (
                    _G.GameFontNormal
                    and _G.GameFontNormal:GetFont()
                )
                or "Fonts\\FRIZQT__.TTF";

            if BB.Data.Constants.SHOW_STACKS then
                child.stacks =
                    child:CreateFontString(
                        nil,
                        "OVERLAY"
                    );

                child.stacks:SetDrawLayer(
                    "OVERLAY",
                    1
                );

                child.stacks:SetFont(
                    fontFile,
                    BB.Data.Constants.OVERLAY_STACKS_SIZE,
                    "THICKOUTLINE"
                );

                child.stacks:SetPoint(
                    BB.Data.Constants.OVERLAY_STACKS_ANCHOR,
                    child,
                    BB.Data.Constants.OVERLAY_STACKS_ANCHOR,
                    BB.Data.Constants.OVERLAY_STACKS_OFFSET_X,
                    BB.Data.Constants.OVERLAY_STACKS_OFFSET_Y
                );

                child.stacks:SetTextColor(
                    1,
                    1,
                    1
                );

                child.stacks:SetText("");
            end

            if BB.Data.Constants.SHOW_TIMER then
                child.timer =
                    child:CreateFontString(
                        nil,
                        "OVERLAY"
                    );

                child.timer:SetDrawLayer(
                    "OVERLAY",
                    7
                );

                child.timer:SetFont(
                    fontFile,
                    BB.Data.Constants.OVERLAY_TIMER_SIZE,
                    "THICKOUTLINE"
                );

                child.timer:SetPoint(
                    BB.Data.Constants.OVERLAY_TIMER_ANCHOR,
                    child,
                    BB.Data.Constants.OVERLAY_TIMER_ANCHOR,
                    BB.Data.Constants.OVERLAY_TIMER_OFFSET_X,
                    BB.Data.Constants.OVERLAY_TIMER_OFFSET_Y
                );

                child.timer:SetTextColor(
                    1,
                    1,
                    0
                );

                child.timer:SetText("");
            end

            child:Hide();

            return child;
        end);

    if not ok or not overlay then
        return nil;
    end

    frame.BB_LifebloomOverlay =
        overlay;

    return overlay;
end

local function ensureOverlay(frame)
    if frame.BB_LifebloomOverlay then
        return frame.BB_LifebloomOverlay;
    end

    return createOverlay(frame);
end

local function formatDuration(seconds)
    if not seconds or seconds <= 0 then
        return "";
    end

    if seconds >= 60 then
        return string.format(
            "%d:%02d",
            math.floor(seconds / 60),
            math.floor(seconds % 60)
        );
    end

    return string.format(
        "%d",
        math.ceil(seconds)
    );
end

local function updateCooldown(
    overlay,
    aura
)
    if not overlay.cooldown then
        return;
    end

    local showSwipe =
        BB.Settings:get("showSwipe") ~= false;

    local duration =
        aura
        and tonumber(aura.duration)
        or 0;

    local expiration =
        aura
        and tonumber(aura.expirationTime)
        or 0;

    local remaining =
        expiration > 0
        and expiration - GetTime()
        or 0;

    if showSwipe
        and duration > 0
        and remaining > 0 then

        overlay.cooldown:SetDrawSwipe(
            true
        );

        overlay.cooldown:SetAlpha(
            1
        );

        overlay.cooldown:Show();

        CooldownFrame_Set(
            overlay.cooldown,
            expiration - duration,
            duration,
            true
        );

    else
        overlay.cooldown:SetDrawSwipe(
            false
        );

        overlay.cooldown:SetAlpha(
            0
        );

        CooldownFrame_Clear(
            overlay.cooldown
        );

        overlay.cooldown:Hide();
    end
end

local function updateStacks(
    overlay,
    aura,
    iconSize
)
    if not overlay.stacks then
        return;
    end

    local stacks =
        aura
        and (
            tonumber(
                aura.applications
            )
            or tonumber(
                aura.charges
            )
        )
        or 0;

    local proportionalSize =
        iconSize
        * 0.34;

    local stackFontSize =
        math.max(
            6,
            math.min(
                16,
                proportionalSize
            )
        );

    local fontFile =
        (
            _G.GameFontNormal
            and _G.GameFontNormal:GetFont()
        )
        or "Fonts\\FRIZQT__.TTF";

    overlay.stacks:SetFont(
        fontFile,
        stackFontSize,
        "THICKOUTLINE"
    );

    if stacks > 1 then
        overlay.stacks:SetText(
            tostring(stacks)
        );

        overlay.stacks:Show();
    else
        overlay.stacks:SetText("");
        overlay.stacks:Hide();
    end
end

local function updateTimer(
    overlay,
    aura,
    iconSize
)
    if not overlay.timer then
        return;
    end

    if BB.Settings:get("showTimer") ~= true then
        overlay.timer:SetText("");
        overlay.timer:Hide();
        return;
    end

    local expiration =
        aura
        and tonumber(aura.expirationTime)
        or 0;

    local remaining =
        expiration > 0
        and expiration - GetTime()
        or 0;

    if remaining <= 0 then
        overlay.timer:SetText("");
        overlay.timer:Hide();
        return;
    end

    -- Scale the digital timer proportionally with the icon.
    local timerFontSize =
        iconSize
        * BB.Data.Constants.OVERLAY_TIMER_SCALE;

    timerFontSize =
        math.max(
            BB.Data.Constants.OVERLAY_TIMER_MIN_SIZE,
            math.min(
                BB.Data.Constants.OVERLAY_TIMER_MAX_SIZE,
                timerFontSize
            )
        );

    local fontFile =
        (
            _G.GameFontNormal
            and _G.GameFontNormal:GetFont()
        )
        or "Fonts\\FRIZQT__.TTF";

    overlay.timer:SetFont(
        fontFile,
        timerFontSize,
        "THICKOUTLINE"
    );

    overlay.timer:SetText(
        formatDuration(
            remaining
        )
    );

    local redThreshold =
        BB.Data.Constants.TIMER_RED_THRESHOLD;

    if remaining <= redThreshold then
        local t =
            math.max(
                0,
                math.min(
                    1,
                    1 - (
                        remaining
                        / redThreshold
                    )
                )
            );

        local green =
            1 - (
                0.8 * t
            );

        overlay.timer:SetTextColor(
            1,
            green,
            0
        );
    else
        overlay.timer:SetTextColor(
            1,
            1,
            0
        );
    end

    overlay.timer:Show();
end

local function updateOverlay(
    overlay,
    aura,
    iconSize
)
    updateCooldown(
        overlay,
        aura
    );

    updateStacks(
        overlay,
        aura,
        iconSize
    );

    updateTimer(
        overlay,
        aura,
        iconSize
    );
end

local function hideOverlay(frame)
    local overlay =
        frame.BB_LifebloomOverlay;

    if not overlay then
        return;
    end

    if overlay.cooldown then
        overlay.cooldown:SetDrawSwipe(
            false
        );

        overlay.cooldown:SetAlpha(
            0
        );

        CooldownFrame_Clear(
            overlay.cooldown
        );

        overlay.cooldown:Hide();
    end

    if overlay.timer then
        overlay.timer:SetText("");
        overlay.timer:Hide();
    end

    if overlay.stacks then
        overlay.stacks:SetText("");
        overlay.stacks:Hide();
    end

    overlay:Hide();
end

function Frames:getLifebloomAura(unit)
    if not unit then
        return nil;
    end

    if not C_UnitAuras
        or not C_UnitAuras.GetAuraDataByIndex then
        return nil;
    end

    local playerGUID =
        UnitGUID("player");

    for i = 1,
        BB.Data.Constants.MAX_AURA_SCAN do

        local aura =
            C_UnitAuras.GetAuraDataByIndex(
                unit,
                i,
                "HELPFUL"
            );

        if not aura then
            break;
        end

        local isLifebloom = false;

        if aura.spellId then
            for _, id in ipairs(
                BB.Data.Constants.LIFEBLOOM_SPELL_IDS
            ) do
                if aura.spellId == id then
                    isLifebloom = true;
                    break;
                end
            end
        end

        if isLifebloom then
            if aura.sourceUnit == "player" then
                return aura;
            end

            if aura.sourceUnit
                and playerGUID
                and UnitGUID(
                    aura.sourceUnit
                ) == playerGUID then

                return aura;
            end
        end
    end

    return nil;
end

function Frames:isLifebloomAura(unit)
    return self:getLifebloomAura(unit)
        ~= nil;
end

local function updateFrame(
    self,
    frame
)
    if not frame
        or frame:IsForbidden()
        or not isEnabled() then

        return 0;
    end

    if not frameEnabled(frame) then
        hideOverlay(frame);
        return 0;
    end

    local unit =
        frame.displayedUnit
        or frame.unit;

    if not frame:IsShown()
        or not unit
        or not UnitExists(unit) then

        hideOverlay(frame);
        return 0;
    end

    local aura =
        self:getLifebloomAura(unit);

    if not aura then
        hideOverlay(frame);
        return 0;
    end

    local overlay =
        ensureOverlay(frame);

    if not overlay then
        return 0;
    end

    local size =
        getOverlaySize(frame);

    local x, y =
        getPosition(
            frame,
            size
        );

    overlay:ClearAllPoints();

    overlay:SetPoint(
        "CENTER",
        frame,
        "CENTER",
        x,
        y
    );

    overlay:SetSize(
        size,
        size
    );

    overlay:Show();

    updateOverlay(
        overlay,
        aura,
        size
    );

    return 1;
end

function Frames:onCompactUnitFrameUpdateAll(
    frame
)
    if not frame
        or frame:IsForbidden() then
        return;
    end

    self._frames[frame] = true;

    updateFrame(
        self,
        frame
    );
end

function Frames:onUnitAura(unit)
    if not unit then
        return;
    end

    for frame in pairs(
        self._frames
    ) do
        local frameUnit =
            frame.displayedUnit
            or frame.unit;

        if frameUnit == unit then
            updateFrame(
                self,
                frame
            );
        end
    end
end

local function hookAfter(
    funcName,
    callback
)
    local original =
        _G[funcName];

    if not original then
        return false;
    end

    if SecureHook then
        SecureHook(
            funcName,
            callback
        );

        return true;
    end

    _G[funcName] =
        function(...)
            local a, b, c, d, e, f =
                original(...);

            callback(...);

            return a, b, c, d, e, f;
        end;

    return true;
end

function Frames:ensureTicker()
    if self._tickerActive then
        return;
    end

    self._tickerActive = true;

    BB.Utils.Timers:interval(
        "Recheck",
        BB.Data.Constants.RECHECK_TICK,
        function()
            self:checkNow();
        end
    );
end

function Frames:stopTicker()
    if not self._tickerActive then
        return;
    end

    self._tickerActive = false;

    BB.Utils.Timers:cancel(
        "Recheck"
    );
end

function Frames:_init()
    if self._initialized then
        return;
    end

    self._initialized = true;

    self._hookedUpdateAll =
        hookAfter(
            "CompactUnitFrame_UpdateAll",
            function(frame)
                self:onCompactUnitFrameUpdateAll(
                    frame
                );
            end
        );

    BB.Events:register(
        "BBFrames_UnitAura",
        "UNIT_AURA",
        function(unit)
            self:onUnitAura(unit);
        end
    );

    BB.Events:register(
        "BBFrames_GroupRoster",
        "GROUP_ROSTER_UPDATE",
        function()
            self:apply();
        end
    );

    if isEnabled() then
        self:ensureTicker();
    end
end

function Frames:checkNow()
    return self:apply();
end

function Frames:apply()
    if not isEnabled() then
        self:stopTicker();

        for frame in pairs(
            self._frames
        ) do
            hideOverlay(frame);
        end

        return 0;
    end

    self:ensureTicker();

    local count = 0;

    for frame in pairs(
        self._frames
    ) do
        count =
            count
            + updateFrame(
                self,
                frame
            );
    end

    return count;
end

function Frames:dumpOverlays()
    local lines = {};
    local count = 0;

    for _ in pairs(
        self._frames
    ) do
        count = count + 1;
    end

    BB:print(
        "overlay dump: %d tracked frame(s)",
        count
    );

    for frame in pairs(
        self._frames
    ) do
        local ok, err =
            pcall(
                function()
                    local name =
                        frame:GetName()
                        or "?";

                    local unit =
                        frame.displayedUnit
                        or frame.unit
                        or "?";

                    lines[#lines + 1] =
                        string.format(
                            "[%s] unit=%s shown=%s",
                            name,
                            unit,
                            frame:IsShown()
                                and "Y"
                                or "N"
                        );

                    local overlay =
                        frame.BB_LifebloomOverlay;

                    if not overlay then
                        lines[#lines + 1] =
                            "  overlay=nil";

                        return;
                    end

                    lines[#lines + 1] =
                        string.format(
                            "  overlay=%dx%d",
                            overlay:GetWidth()
                                or 0,
                            overlay:GetHeight()
                                or 0
                        );

                    local aura =
                        self:getLifebloomAura(
                            unit
                        );

                    if aura then
                        local remaining =
                            aura.expirationTime
                            and (
                                aura.expirationTime
                                - GetTime()
                            )
                            or 0;

                        lines[#lines + 1] =
                            string.format(
                                "  Lifebloom remaining=%.1f stacks=%s",
                                remaining,
                                tostring(
                                    aura.applications
                                    or aura.charges
                                    or 0
                                )
                            );
                    else
                        lines[#lines + 1] =
                            "  Lifebloom=nil";
                    end
                end
            );

        if not ok then
            lines[#lines + 1] =
                "  error: "
                .. tostring(err);
        end
    end

    lines[#lines + 1] =
        string.format(
            "settings: scale=%s X=%s Y=%s timer=%s swipe=%s",
            tostring(
                BB.Settings:get("scale")
            ),
            tostring(
                BB.Settings:get("overlayPosX")
            ),
            tostring(
                BB.Settings:get("overlayPosY")
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

    BB:print(
        table.concat(
            lines,
            "\n"
        )
    );
end

return BB;