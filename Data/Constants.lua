-- BloomBuddy — Data/Constants
-- Static constants: Lifebloom spell IDs, icon texture, overlay defaults, timings.
-- No game calls at file scope.

---@type BB
local _, BB = ...;

BB.Data = BB.Data or {};

---@class Constants
BB.Data.Constants = {
    -- Lifebloom (Druid HoT) — all ranks the addon matches. Spell IDs are stable
    -- across locales. 33763 (R1) is VERIFIED in game (2026-08-15: GetSpellInfo
    -- returns "Lifebloom"); R2/R3 were not learned on the tester — confirm on a
    -- max-rank Druid:
    --   /run for _, id in ipairs(BB.Data.Constants.LIFEBLOOM_SPELL_IDS) do print(id, GetSpellInfo(id)) end
    LIFEBLOOM_SPELL_IDS = {
        33763,  -- Lifebloom (Rank 1)  [verified]
        48450,  -- Lifebloom (Rank 2)  [verify]
        48451,  -- Lifebloom (Rank 3)  [verify]
    },

    -- Lifebloom icon texture. VERIFY via GetSpellTexture(LIFEBLOOM_SPELL_IDS[1]);
    -- used as a fallback when the runtime spell texture lookup returns nil.
    LIFEBLOOM_TEXTURE = "Interface\\Icons\\Spell_Nature_LifeBloom",

    -- Default icon size multiplier (OVERLAY_BASE_SIZE * scale).
    DEFAULT_SCALE = 1.5,

    -- Overlay icon base size (px). The native compact-frame buff size is NOT
    -- readable from Lua on this client (2.5.6 renders them in C), so we use a
    -- fixed base — 20 px is the size SweepyBoop uses for its primary buff on
    -- the same client. Tune after in-game review.
    OVERLAY_BASE_SIZE = 20,

    -- Overlay anchor on the member frame. User feedback (2026-08-15): the native
    -- buff/debuff strip runs along the bottom of the frame — an icon anchored to
    -- the right edge (vertically centered) got its lower part covered by debuffs.
    -- SweepyBoop's proven compact-frame placement is the UPPER right area, clear
    -- of the bottom strip: anchor TOPRIGHT of the member frame.
    OVERLAY_ANCHOR = "TOPRIGHT",
    OVERLAY_OFFSET_X = -2,
    OVERLAY_OFFSET_Y = -2,
    OVERLAY_FRAME_LEVEL = 10, -- above the member frame's own children (SweepyBoop's offset)

    -- Overlay text: remaining time and stack count.
    -- Remaining time is shown as a native Cooldown swipe by default (the client
    -- animates the darkening sweep itself). The digital countdown below is opt-in
    -- via the `showTimer` setting (/bb timer; default off).
    SHOW_TIMER = true,  -- feature flag: allow the digital countdown text at all
    SHOW_STACKS = true, -- feature flag: stack count text on the overlay

    OVERLAY_TIMER_ANCHOR = "BOTTOM",      -- anchor point of the timer text (relative to the overlay)
    OVERLAY_TIMER_SIZE = 11,              -- timer font size (px)
    OVERLAY_TIMER_OFFSET_Y = -1,          -- timer vertical offset (px)

    OVERLAY_STACKS_ANCHOR = "TOPLEFT", -- anchor point of the stacks text (top-left, user feedback 2026-08-15)
    OVERLAY_STACKS_SIZE = 14,           -- stacks font size (px)
    OVERLAY_STACKS_OFFSET_X = 2,        -- stacks horizontal offset (px)
    OVERLAY_STACKS_OFFSET_Y = -1,       -- stacks vertical offset (px)

    -- Upper bound for the aura scan (GetAuraDataByIndex loop). Auras beyond
    -- this are never displayed on a compact frame.
    MAX_AURA_SCAN = 40,

    -- Safety re-check interval (seconds). Covers refresh paths the
    -- CompactUnitFrame_UpdateAll hook / events miss (e.g. frames reused
    -- without a redraw).
    RECHECK_TICK = 0.5,
};

return BB;
