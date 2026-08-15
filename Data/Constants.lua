-- BloomBuddy — Data/Constants
-- Static constants: Lifebloom spell IDs, icon texture, scale defaults, timings.
-- No game calls at file scope.

---@type BB
local _, BB = ...;

BB.Data = BB.Data or {};

---@class Constants
BB.Data.Constants = {
    -- Lifebloom (Druid HoT) — all ranks the addon matches. Spell IDs are stable
    -- across locales, but VERIFY them in game before shipping v0.1:
    --   /run for _, id in ipairs(BB.Data.Constants.LIFEBLOOM_SPELL_IDS) do print(id, GetSpellInfo(id)) end
    LIFEBLOOM_SPELL_IDS = {
        33763,  -- Lifebloom (Rank 1)
        48450,  -- Lifebloom (Rank 2)
        48451,  -- Lifebloom (Rank 3)
    },

    -- Lifebloom icon texture. VERIFY via GetSpellTexture(LIFEBLOOM_SPELL_IDS[1]);
    -- used as a fallback matcher when no aura object is available for an index.
    LIFEBLOOM_TEXTURE = "Interface\\Icons\\Spell_Nature_LifeBloom",

    -- Default icon size multiplier (baseSize * scale).
    DEFAULT_SCALE = 1.5,

    -- Buff icons per party member frame (PartyMemberFrame<N>.BuffFrame.Buff<K>).
    -- VERIFY the count and the exact frame paths on 2.5.x (see the unit-frame-buffs skill).
    MAX_PARTY_BUFFS = 4,

    -- Buff icons per compact raid frame.
    MAX_RAID_BUFFS = 4,

    -- Safety re-check interval (seconds). Blizzard resets icon sizes on every
    -- buff update; the ticker re-applies the scale for paths a hook misses.
    RECHECK_TICK = 0.5,
};

return BB;
