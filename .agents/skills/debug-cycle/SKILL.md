---
name: debug-cycle
description: Methodology for debugging this addon when there is NO Lua error (silent failure). Covers adding debugPrint diagnostics, temporary /bb status output, reading the user's pasted log, and cleaning up afterwards. Use whenever a feature "does nothing" but the game loads fine.
---

# Debug cycle (silent failures)

Most bugs in this project are silent: the addon loads, no errors, but the Lifebloom icon never grows (or grows in the wrong place). The diagnosis loop below resolves every one of them.

## 1. Add visibility FIRST

The addon has `BB:debugPrint(msg, ...)` (only prints when `/bb debug` is on) and `BB:print(msg, ...)` (always prints). Before changing logic, add targeted output at each decision point:

- **Frames**: `isLifebloomAura` prints its verdict per icon (`unit %s index %d aura.spellId=%s`); `applyToParty`/raid hook print `party scan: scaled N icon(s)` / `raid hook: scaled N icon(s)`; `apply()` prints `enabled=false, skipping` / `party/raid disabled`.
- **OptionsUI**: `/bb status` already prints `enabled`, `scale`, `party`, `raid` + the scaled-icon count.
- **Settings**: `Settings:_init` prints the merged DB shape when a settings bug is suspected.

Use `debugPrint` for the noisy per-tick spam (the 0.5 s ticker logs a LOT — keep that debug-only), `print` for user-meaningful single events.

## 2. Temporary diagnostics in `/bb status`

For things that only happen in-game (frames, auras, textures), add a TEMP block to the status handler in `Classes/OptionsUI.lua`:

```lua
-- TEMP diagnostics (describe bug here)
BB:print("diag: %s=%s", key, tostring(BB.Settings:get(key)));
```

Proven examples from the sibling addon:
- dump a party member's buff frame (`/dump PartyMemberFrame1.BuffFrame`) → revealed the real buff-child naming on the client;
- dump every buff icon's texture → revealed whether the texture-match fallback works;
- print `spellId=%s` per aura index → confirmed the C_UnitAuras object API on a party unit.

**Always remove TEMP diagnostics before finishing** — grep for `TEMP diagnostics` / `diag:` when done.

## 3. Ask the user for a structured report

Use the `debug-report` prompt template. Key: ask for `/bb debug` ON, reproduce (e.g. "apply Lifebloom to a party member"), then paste the log AND `/bb status` output. Timestamps in the log let you correlate events (e.g. "buff at 18:29:57 → scan scaled 1 at 18:29:57").

## 4. Read the log — known phrases and what they mean

| Log line | Meaning |
|---|---|
| `enabled=false, skipping` | The addon is disabled — `/bb enable` |
| `party disabled, skipping` / `raid disabled, skipping` | Per-frame toggle off — check `party`/`raid` in `BloomBuddyDB` |
| `aura index %d: spellId=%s` | The aura lookup works — compare the spellID against `LIFEBLOOM_SPELL_IDS` |
| `party scan: scaled 0 icon(s)` | The party buff-frame path is wrong on 2.5.x — verify against a working addon (see `unit-frame-buffs` skill) |
| `raid hook: scaled 0 icon(s)` | The `CompactUnitFrame_UpdateBuff` hook fires but the buff button path is wrong — verify the child naming |
| `icon:SetSize(%d, %d)` (repeated) | Re-apply is running — if it grows unbounded, the base size is not cached (`_bbBaseSize`) |

## 5. The "it worked before the edit" case

If a change broke something that worked, diff the edit. Most UI regressions in this workspace came from: wrong buff-frame path, label anchoring (`CreateFontString` vs `_G[name.."Text"]`), and `GetChildren()` misuse.

## 6. Cleanup checklist

- [ ] TEMP diagnostics removed
- [ ] debug lines that are useful long-term kept (they're guarded by `/bb debug`)
- [ ] Root cause recorded in repo memory (`bloom-buddy-gotchas.md` if it's an API gotcha, else `phases`)
- [ ] If it's a new gotcha → add to the `wow-api-20506` and/or `unit-frame-buffs` skill
