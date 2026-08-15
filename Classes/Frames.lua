-- BloomBuddy — Classes/Frames
-- CORE: detect the Lifebloom buff on party/raid members and enlarge its icon.
--
-- Blizzard resets buff-icon sizes every time its update functions run (any buff
-- gain/fade, unit layout change, frame show). So we re-apply the scale after
-- each draw: a hook on CompactUnitFrame_UpdateBuff for raid frames (primary) and
-- a periodic safety ticker for everything else (backstop).
--
-- Detection is by spellID via C_UnitAuras.GetAuraDataByIndex — the legacy
-- UnitBuff/UnitAura wrappers are broken on 2.5.5 (see the wow-api-20506 skill).
-- Lifebloom is matched against the full rank list in Data/Constants.
--
-- VERIFY (Phase 1/2, in game): the exact party/raid buff-frame paths below and
-- the Lifebloom spell IDs. See .github/skills/unit-frame-buffs/SKILL.md.

---@type BB
local _, BB = ...;

local ipairs = _G.ipairs;
local pairs = _G.pairs;
local math = _G.math;
local SecureHook = _G.SecureHook;

---@class Frames
local Frames = {
    _initialized = false,
    _hookedRaid = false,
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

--- Resize an icon to base * scale (never compounds — uses the cached base).
---@param icon Texture
---@param base number
---@return boolean
local function resizeIcon(icon, base)
    if (not icon or not icon.SetSize) then
        return false;
    end

    local original = icon._bbBaseSize or (icon:GetWidth() or base);
    icon._bbBaseSize = original;

    local size = math.max(1, math.floor(original * scaleFactor()));
    icon:SetSize(size, size);

    return true;
end

--- Is the aura at (unit, index) a Lifebloom? Matches by spellID; falls back to
--- the icon texture when no aura object is available for the index.
---@param unit string
---@param index number
---@param icon Texture|nil
---@return boolean
function Frames:isLifebloomAura(unit, index, icon)
    local aura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL");

    if (aura and aura.spellId) then
        for _, id in ipairs(BB.Data.Constants.LIFEBLOOM_SPELL_IDS) do
            if (aura.spellId == id) then
                return true;
            end
        end

        return false;
    end

    -- Fallback: compare the icon texture (some frame paths expose the icon
    -- without a usable aura index).
    if (icon and icon.GetTexture) then
        local texture = GetSpellTexture(BB.Data.Constants.LIFEBLOOM_SPELL_IDS[1]);
        if (texture and icon:GetTexture() == texture) then
            return true;
        end
    end

    return false;
end

--- Resize one buff button's icon if it shows Lifebloom.
---@param unit string
---@param buffFrame table|nil
---@param index number
---@return boolean
function Frames:applyToBuffButton(unit, buffFrame, index)
    if (not buffFrame) then
        return false;
    end

    local icon = buffFrame.Icon or buffFrame.icon;
    if (not icon or not icon.SetSize) then
        return false;
    end

    if (not self:isLifebloomAura(unit, index, icon)) then
        return false;
    end

    return resizeIcon(icon, icon:GetWidth() or 16);
end

--- Apply the scale to all party member frames.
--- VERIFY the buff-frame path on 2.5.x: <PartyMemberFrame<N>>.BuffFrame.Buff<K>.
---@return number count
function Frames:applyToParty()
    local count = 0;

    local GetNumPartyMembers = _G.GetNumPartyMembers;
    local numMembers = GetNumPartyMembers and GetNumPartyMembers() or 0;

    for member = 1, numMembers do
        local unit = "party" .. member;
        local frame = _G["PartyMemberFrame" .. member];

        if (frame) then
            local buffFrame = frame.BuffFrame or frame.buffFrame;

            if (buffFrame) then
                for buffIndex = 1, BB.Data.Constants.MAX_PARTY_BUFFS do
                    local buff = buffFrame["Buff" .. buffIndex] or buffFrame["buff" .. buffIndex];
                    if (self:applyToBuffButton(unit, buff, buffIndex)) then
                        count = count + 1;
                    end
                end
            end
        end
    end

    return count;
end

--- Handler for the raid buff update hook. Re-applies the scale to the icon the
--- moment CompactUnitFrame finishes drawing it.
--- VERIFY on 2.5.x: `unitButton.Buff[index]` / `unitButton.Debuff[index]` naming.
---@param unitButton Frame|nil
---@param index number
---@param isDebuff boolean
function Frames:onCompactUnitFrameUpdateBuff(unitButton, index, isDebuff)
    if (not isEnabled() or not BB.Settings:get("raid")) then
        return;
    end

    if (not unitButton or not unitButton.unit or not index) then
        return;
    end

    local filter = isDebuff and "HARMFUL" or "HELPFUL";
    local aura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex(unitButton.unit, index, filter);

    if (not aura or not aura.spellId) then
        return;
    end

    for _, id in ipairs(BB.Data.Constants.LIFEBLOOM_SPELL_IDS) do
        if (aura.spellId == id) then
            local container = isDebuff and unitButton.Debuff or unitButton.Buff;
            local buff = container and container[index];

            if (buff) then
                local icon = buff.Icon or buff.icon;
                if (icon and icon.SetSize) then
                    resizeIcon(icon, icon:GetWidth() or 16);
                end
            end

            return;
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

--- Initialize the module: hook the raid buff updater and start the safety ticker.
function Frames:_init()
    if (self._initialized) then
        return;
    end
    self._initialized = true;

    self._hookedRaid = hookAfter("CompactUnitFrame_UpdateBuff", function(unitButton, index, numBuffs, isDebuff)
        self:onCompactUnitFrameUpdateBuff(unitButton, index, isDebuff);
    end);

    if (isEnabled()) then
        BB.Utils.Timers:interval("Recheck", BB.Data.Constants.RECHECK_TICK, function()
            self:checkNow();
        end);
    end
end

--- Re-apply the scale right now (also the initial/`/reload` check).
---@return number
function Frames:checkNow()
    return self:apply();
end

--- Apply the scale to every visible party/raid Lifebloom buff.
---@return number
function Frames:apply()
    local count = 0;

    if (not isEnabled()) then
        BB:debugPrint("apply: disabled, skipping");
        return 0;
    end

    if (BB.Settings:get("party")) then
        count = count + self:applyToParty();
    else
        BB:debugPrint("apply: party disabled, skipping");
    end

    if (BB.Settings:get("raid") and not self._hookedRaid) then
        -- The raid hook covers the common path. If it is unavailable, re-scan
        -- compact raid frames here (Phase 2, see the unit-frame-buffs skill).
        BB:debugPrint("apply: raid hook unavailable, no raid fallback scan yet");
    end

    BB:debugPrint("apply: scaled %d icon(s)", count);
    return count;
end

return BB;
