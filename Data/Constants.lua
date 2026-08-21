---@type BB
local _, BB = ...;

BB.Data = BB.Data or {};

BB.Data.Constants = {
    LIFEBLOOM_SPELL_IDS = {
        33763,
        48450,
        48451,
    },

    LIFEBLOOM_TEXTURE = "Interface\\Icons\\Spell_Nature_LifeBloom",

    DEFAULT_SCALE = 0.5,

    OVERLAY_FRAME_HEIGHT_RATIO = 0.75,

    OVERLAY_ANCHOR = "TOPRIGHT",
    OVERLAY_OFFSET_X = -2,
    OVERLAY_OFFSET_Y = -2,

    OVERLAY_FRAME_LEVEL = 10,

    SHOW_TIMER = true,
    SHOW_STACKS = true,

    -- Stack count scales with the Lifebloom icon.
    OVERLAY_STACKS_SIZE = 10,
    OVERLAY_STACKS_ANCHOR = "BOTTOMRIGHT",
    OVERLAY_STACKS_OFFSET_X = -2,
    OVERLAY_STACKS_OFFSET_Y = 1,

    -- Timer scales with the Lifebloom icon.
    OVERLAY_TIMER_SIZE = 16,
    OVERLAY_TIMER_SCALE = 0.55,
    OVERLAY_TIMER_MIN_SIZE = 8,
    OVERLAY_TIMER_MAX_SIZE = 24,

    OVERLAY_TIMER_ANCHOR = "CENTER",
    OVERLAY_TIMER_OFFSET_X = 0,
    OVERLAY_TIMER_OFFSET_Y = 0,

    -- Countdown becomes increasingly red during the final 5 seconds.
    TIMER_RED_THRESHOLD = 5,

    MAX_AURA_SCAN = 40,

    RECHECK_TICK = 0.5,
};

return BB;