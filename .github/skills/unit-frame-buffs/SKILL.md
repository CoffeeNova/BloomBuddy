---
name: unit-frame-buffs
description: The core feature skill. VERIFIED patterns for showing the Lifebloom buff prominently on compact unit frames (raid + raid-style party frames) on the WoW TBC Anniversary client (Interface 20506). On this client the native compact-frame buff icons are C-rendered and CANNOT be resized or hidden per-buff — the working pattern is a custom overlay icon. Use before touching Classes/Frames.lua, before verifying in game, and when the Lifebloom indicator "doesn't show" or targets the wrong frame.
---

# Unit frame buffs — showing a buff prominently on compact frames

The addon's one job: when a party/raid member has **Lifebloom**, show an enlarged Lifebloom icon on that member's compact unit frame.

## The fundamental problem (client-verified, 2026-08)

On **TBC Anniversary 2.5.6** the native buff icons on compact frames (raid frames AND raid-style
party frames, i.e. every `CompactUnitFrame`) are **rendered by the game engine (C)**, not by Lua
frames:

- There is **no Lua-accessible per-buff icon** to `SetSize` and **no `buffFrames` array** to enumerate.
- `frame.auraSize` is the only native size lever, but it scales **ALL** buffs+debuffs of a member
  uniformly — it CANNOT single out Lifebloom. Do not use it for "highlight one buff".
- There is **no per-buff hide filter** (you cannot hide just Lifebloom). Hiding all buffs is only
  possible all-or-nothing (CVar `raidFramesDisplayBuffs` / the frame's "display buffs" option).

Evidence: BigDebuffs' own code comment names "TBC Anniversary 2.5.6": *"native buff icons render in
C with no buffFrames array to resize, so the only lever is frame.auraSize"*. No installed addon
resizes or hides individual native compact-frame buffs on this client.

## The proven pattern: a custom overlay icon

Working addons on this client (SweepyBoop `RaidFrames/BuffHelper.lua`, BigDebuffs) draw **their own
icons** on compact frames instead of touching native ones. This is the pattern BloomBuddy uses:

1. **Hook `CompactUnitFrame_UpdateAll`** (the real per-frame hook on 2.5.6 — fires for every compact
   party/raid frame as it's set up / reused). `CompactUnitFrame_UpdateBuff` does **NOT** exist on 2.5.6.
   ```lua
   if type(CompactUnitFrame_UpdateAll) == "function" then
       hooksecurefunc("CompactUnitFrame_UpdateAll", function(frame) ... end)
   end
   ```
2. **Frame filter** by name: starts with `CompactPartyFrame` (party) or `CompactRaid` (raid).
   Guard with `frame:IsForbidden()` and `frame:IsShown()`.
3. **Unit**: `local unit = frame.displayedUnit or frame.unit;`.
4. **Detect Lifebloom** by spellID (see below).
5. **Draw** a child frame with one texture (Lifebloom icon) on the member frame; show/hide it.
   SweepyBoop's primary buff is 20 px — `OVERLAY_BASE_SIZE` in this addon.
6. **Remaining time = native cooldown swipe (VERIFIED pattern on this client).** A `Cooldown` widget
   on the overlay is driven with `CooldownFrame_Set(cooldown, expirationTime - duration, duration, true)`
   when `duration > 0`, else `CooldownFrame_Clear(cooldown)`. BigDebuffs and ClassicAuraDurations use
   exactly this on 2.5.x. Configure `SetSwipeColor(0, 0, 0, 0.7)` (plain darkening), `SetDrawEdge(false)`,
   `SetDrawBling(false)`, `SetHideCountdownNumbers(true)` (M6/BetterBlizzFrames confirm these methods),
   and **`SetReverse(true)`** — REQUIRED on this client for the correct sweep direction (every working
   addon sets it; the default sweeps backwards, lightening instead of darkening — round-5 user feedback).
   **CREATE THE WIDGET WITH THE TEMPLATE:** `CreateFrame("Cooldown", nil, parent, "CooldownFrameTemplate")`
   — every working addon on this client does this (BigDebuffs, ClassicAuraDurations, SweepyBoop). A bare
   `CreateFrame("Cooldown")` has NO swipe texture: the sweep runs (CooldownFrame_Set works) but renders
   nothing — BloomBuddy's round-4 bug, caught via the `/bb debug` dump (`sweep=Y` but invisible).
   **Countdown add-ons (OmniCC) interfere:** they draw their own numbers on every active
   Cooldown widget. Set `cooldown.noCooldownCount = true` (their official opt-out — OmniCC's
   `CanShowText`/`CanShowFinishEffect`/`OnCooldownDone` all check `self.noCooldownCount`) or the
   user will see numbers that the addon's own timer toggle cannot hide.
7. **Stack count is `.applications`, not `.count` (VERIFIED on this client).** BigDebuffs reads
   `aura.applications or aura.charges or 0`; BetterBlizzFrames and ArenaAnalytics read
   `aura.applications`. The overlay's `stacks` FontString shows it when > 1 (standard buff UX).
8. **Digital countdown is opt-in.** The `timer` FontString (`expirationTime - GetTime()`, "N" under
   60 s, "m:ss" above) renders only when `showTimer` is on (`/bb timer`, default off). The swipe is
   the default display.

Refresh triggers: the hook (frame reuse), `UNIT_AURA` / `GROUP_ROSTER_UPDATE`, and a periodic
safety ticker.

## Matching the buff (which member has Lifebloom?)

Never match by buff *name* — it is locale-dependent and `UnitBuff(unit, name)` crashes on 2.5.5.
Match by **spellID** via the C_UnitAuras object API (verified on 2.5.5):

```lua
for i = 1, MAX_AURA_SCAN do
    local aura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL");
    if (not aura) then break end
    for _, id in ipairs(BB.Data.Constants.LIFEBLOOM_SPELL_IDS) do
        if (aura.spellId == id) then return true end
    end
end
```

Lifebloom has **three ranks** (distinct spellIDs): `33763` (R1), `48450` (R2), `48451` (R3). Match
all of them. **`33763` is verified in game** (2026-08-15, `GetSpellInfo` → "Lifebloom"); R2/R3 were
not learned on the tester and printed nothing — keep them in the list and confirm on a max-rank
Druid (`/run for _, id in ipairs(BB.Data.Constants.LIFEBLOOM_SPELL_IDS) do print(id, GetSpellInfo(id)) end`).

## Sizing and anchoring the overlay

- The native icon size is not readable from Lua on this client (`frame.auraSize` is often nil until
  an addon sets it), so use a fixed base: `OVERLAY_BASE_SIZE` (20 px, SweepyBoop's proven value).
- Overlay size = `OVERLAY_BASE_SIZE * scale` (clamped ≥ 1). `scale` default 1.5.
- Anchor: `OVERLAY_ANCHOR` (default `TOPRIGHT` of the member frame — user feedback 2026-08-15: the
  native buff/debuff strip runs along the bottom; a right-edge icon got its lower part covered by
  debuffs, the upper-right area is clear, proven by SweepyBoop's compact-frame placement). The exact spot
  is tunable after in-game review — ask the user to report where the overlay sits vs. the native buffs.
- Create the child frame lazily and cache it on the compact frame (`frame.BB_LifebloomOverlay`), so
  frames reused for different units keep their overlay.

## Frame types on this client

- **Raid-style party frames (v0.1 target):** `CompactPartyFrameMember1..5` — same CompactUnitFrame
  machinery as raid frames; same C-rendered icons; same overlay approach.
- **Raid frames:** `CompactRaidFrame1..40` — identical approach.
- **Classic party frames (`PartyMemberFrame1..4`):** NOT the v0.1 target. Their buff icons are
  classic-era Lua frames (`.BuffFrame.Buff<N>.Icon`); a `SetSize` path is future work (v0.2).

## General gotchas

- **`SecureHook` first, manual wrapper as fallback** (`_G.SecureHook` guard — see `wow-api-20506`).
  A manual wrapper MUST return the original's values.
- **`GetChildren()` returns multiple values, not a table** — wrap: `ipairs({ frame:GetChildren() })`.
- **Only scan what's needed.** Check `enabled`/`party`/`raid` settings before scanning; return early.
- **The ticker is cheap but noisy in debug** — log its counts through `BB:debugPrint` (only when
  `/bb debug` is on), not `BB:print`.
- **Protected frames:** creating a plain child frame on a compact frame is allowed (SweepyBoop does
  it); wrap the creation in `pcall` defensively. Never call protected methods on Blizzard frames.
- **UNIT_AURA fires on aura changes** — refresh only the affected units (compare `frame.displayedUnit`).

## Verification workflow (do this in game before trusting anything)

1. Enable `/bb debug`, queue into a group/raid, put Lifebloom on a member.
2. `/bb status` — should report the shown-overlay count > 0.
3. Confirm the client facts first (see the hand-back checklist in `Classes/Frames.lua`):
   - `/dump CompactUnitFrame_UpdateBuff` → expect `nil` (doesn't exist on 2.5.6)
   - `/dump CompactUnitFrame_UpdateAll` → expect `function`
   - `/dump CompactPartyFrameMember1` / `/dump CompactRaidFrame1` → the frames (raid one is `nil` outside a raid — expected)
   - `/run for i = 1, 40 do local a = C_UnitAuras.GetAuraDataByIndex("party1", i, "HELPFUL"); if a then print(i, a.spellId, a.name, a.applications, a.expirationTime - GetTime()) end end` → Lifebloom spellID, stack count (`.applications`), and remaining time visible
4. Record verified facts back into this skill and `Data/Constants.lua` (contract-first).
