---
name: unit-frame-buffs
description: The core feature skill. Verified/researched patterns for detecting a specific buff (Lifebloom) on party and raid frames and enlarging its icon on the WoW TBC Anniversary client (Interface 20506). Use before touching Classes/Frames.lua, before verifying the frame paths in game, and when the scale "doesn't stick" or targets the wrong icon.
---

# Unit frame buffs — detecting a buff and enlarging its icon

The addon's one job: when a party/raid member has **Lifebloom**, make that member's buff icon bigger.

## The fundamental problem

Blizzard redraws and **resizes buff icons every time its update functions run** (any buff gain/fade, unit layout change, frame show). So a one-time `SetSize` is immediately overwritten. Two complementary strategies:

1. **Hook the update functions** and re-apply the scale right after each draw (primary, instant).
2. **A periodic safety ticker** that re-runs the whole scan (backstop for paths a hook misses).

Both are used by `Classes/Frames.lua` and by proven frame addons on this client (see `addon-research`).

## Matching the buff (which icon is Lifebloom?)

Never match by buff *name* — it is locale-dependent and `UnitBuff(unit, name)` crashes on 2.5.5. Match by **spellID** first, **texture** as fallback:

```lua
-- Primary: the C_UnitAuras object API (verified on 2.5.5).
local aura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL");
if (aura and aura.spellId) then
    for _, id in ipairs(BB.Data.Constants.LIFEBLOOM_SPELL_IDS) do
        if (aura.spellId == id) then
            -- resize the icon for `index`
        end
    end
end

-- Fallback (no aura object available): compare the icon texture.
local texture = GetSpellTexture(BB.Data.Constants.LIFEBLOOM_SPELL_IDS[1]);
if (icon and icon.GetTexture and icon:GetTexture() == texture) then
    -- resize
end
```

Lifebloom has **three ranks** (distinct spellIDs): `33763` (R1), `48450` (R2), `48451` (R3). Match all of them. **Verify these IDs in game** before trusting them (`/run for _, id in ipairs(BB.Data.Constants.LIFEBLOOM_SPELL_IDS) do print(id, GetSpellInfo(id)) end`).

## Scaling an icon (never compound)

The icon's `GetWidth()` returns the CURRENT (already scaled) size after the first resize. Store the original once:

```lua
local base = icon._bbBaseSize or (icon:GetWidth() or 16);  -- original size, cached
icon._bbBaseSize = base;
local size = math.max(1, math.floor(base * scale));
icon:SetSize(size, size);
```

Only the icon texture is resized — never move/re-parent the buff frame, or Blizzard and other addons break.

## Party frames (TBC Anniversary 2.5.x) — VERIFY paths in game

- Frames: `PartyMemberFrame1..4` (one per party member).
- Buffs live under a per-member buff container. **The exact container/child naming and the buff count per member must be verified on 2.5.x** (mark the paths in `Data/Constants.lua` and confirm against a working addon — see `addon-research`).
- Expected shape (classic-era convention, confirm): `frame.BuffFrame.Buff<1..N>` with each buff holding an `.Icon` texture.
- Hook point: the party buff update function (`PartyMemberFrame_UpdateBuffs` on classic-era clients) — SecureHook it, then re-scan the member's buffs.

## Raid frames (TBC Anniversary 2.5.x)

- Buffs are drawn by the global `CompactUnitFrame_UpdateBuff(unitButton, index, numBuffs, isDebuff)` — a stable, widely-hooked function on this client (used by sArena_Reloaded, BigDebuffs, BuffSizeShifter).
- `unitButton.unit` is populated; `index` is the 1-based aura index.
- Inside the hook, look up the aura and resize when it matches:
  ```lua
  local filter = isDebuff and "HARMFUL" or "HELPFUL";
  local aura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex(unitButton.unit, index, filter);
  ```
- The buff button holding the icon: resolve defensively (`unitButton.Buff` / `unitButton.Debuff` containers and their children). **Verify the exact child naming on 2.5.x** against a working addon before hardcoding.

## General gotchas

- **SecureHook first, manual wrapper as fallback** (`_G.SecureHook` guard — see `wow-api-20506`). A manual wrapper MUST return the original's values.
- **`GetChildren()` returns multiple values, not a table** — wrap: `ipairs({ frame:GetChildren() })`.
- **Only scan what's needed.** Check `enabled`/`party`/`raid` settings before scanning; return early.
- **The ticker is cheap but noisy in debug** — log its scaled count through `BB:debugPrint` (only when `/bb debug` is on), not `BB:print`.
- **Don't resize dead/hidden frames unnecessarily** — guard with `frame:IsShown()` where cheap (optional for v0.1).
- **A buff that fades between the aura lookup and the resize** — harmless: the resize targets an icon that will be redrawn anyway.

## Verification workflow (do this in game before trusting any path)

1. Enable `/bb debug`, queue into a group/raid, put Lifebloom on a member.
2. `/bb status` — should report the scaled-icon count > 0.
3. Check `/dump PartyMemberFrame1.BuffFrame` and the compact raid frames to confirm the buff-frame paths on 2.5.x.
4. Use `tools/research.ps1` on `BuffSizeShifter`, `BigDebuffs`, `sArena_Reloaded` for the exact naming conventions on this client.
5. Record verified facts back into this skill and `Data/Constants.lua` (contract-first).
