# BloomBuddy — repo memory

Working record for AI agents. Source of truth is `.agents/`; this mirrors verified outcomes and phase status.

## Status (2026-08-15)

- **v0.1 in development.** Core = **custom Lifebloom overlay icon on compact frames** (party + raid) with a native **cooldown swipe** for remaining time (default), opt-in digital countdown (`showTimer`, `/bb timer`, default off), and a **stack count** (hidden at ≤ 1).
- Phase 0 (scaffold) DONE. Phases 1–2 implemented; **core verified in game** (2026-08-15). Round-3 feedback: stacks render (`.applications`), but the cooldown swipe was not visible and OmniCC (installed on the tester's client) drew countdown numbers that `/bb timer` could not hide — fixed via `noCooldownCount = true`, show-before-sweep ordering, and a `/bb debug` overlay dump. **Re-verify in game: swipe sweeps, OmniCC numbers gone, stacks position, timer toggle.** Real raid test still pending. Phase 3 not started.

## Verified client facts (TBC Anniversary 2.5.6 — verified in game 2026-08-15 + working addons on the machine)

- **In game (round 3, user):** `aura.applications` returns the stack count (dump showed 1 for the tester's anniversary buffs); stacks text renders at > 1 but sits at the icon's bottom-right corner, which with the overlay at the frame's bottom-left reads as "bottom-middle" of the frame (placement tuning pending). The tester runs **OmniCC + OmniCC_Config** (plus M6, ClassicAuraDurations, BigDebuffs, SweepyBoop, BetterBlizzFrames, sArena_Reloaded — a good research pool in the AddOns folder).
- **In game (user):** `CompactUnitFrame_UpdateBuff` = `nil`; `CompactUnitFrame_UpdateAll` = `function`; `CompactPartyFrameMember1` exists with `unit="player"`, `displayedUnit` populated; Lifebloom spell ID `33763` (R1) confirmed via `GetSpellInfo`; overlay shows/hides per member + per aura; `/bb enable`/`disable` lifecycle works; `CompactRaidFrame1` = `nil` outside a raid (expected — frames exist only in a raid).
- Native buff icons on **compact frames** (raid + raid-style party) are **C-rendered** — no Lua-accessible per-buff icon, no `buffFrames`, **no per-buff hide filter**.
- **Real hook: `CompactUnitFrame_UpdateAll(frame)`**; unit = `frame.displayedUnit or frame.unit`. `frame.auraSize` scales ALL buffs+debuffs uniformly — never use.
- Overlay pattern proven on this client: SweepyBoop `RaidFrames/BuffHelper.lua` (TBC build). Aura scan via `C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")` → object with `.spellId`, `.duration`, `.expirationTime`, and **`.applications`** (stack count — NOT `.count`; BigDebuffs reads `aura.applications or aura.charges or 0`, same for BetterBlizzFrames/ArenaAnalytics).
- Cooldown swipe: native `Cooldown` widget + `CooldownFrame_Set(cd, expirationTime - duration, duration, true)` / `CooldownFrame_Clear` (BigDebuffs, ClassicAuraDurations, M6 on this client). Widget methods `SetSwipeColor(0,0,0)`, `SetDrawEdge(false)`, `SetDrawBling(false)`, `SetHideCountdownNumbers(true)` all exist here (M6, BetterBlizzFrames). **Set `noCooldownCount = true` on the widget** — the OmniCC opt-out (OmniCC's `CanShowText`/`CanShowFinishEffect`/`OnCooldownDone` all check `self.noCooldownCount`; without it the tester's OmniCC drew numbers the addon could not hide).
- User's client: `Config.wtf` has no compact/raid-style party CVars (defaults apply). User USES raid-style party frames and wants the overlay there.
- Addons folder: `G:\games\World of Warcraft\_anniversary_\Interface\AddOns` (recorded in `.env`).

## Decisions

- **Overlay icon, not native resize** (ADR 3 in ARCHITECTURE.md): client-forced; native compact icons are C-rendered.
- **Cooldown swipe is the default remaining-time display** (user feedback 2026-08-15): C-driven smooth sweep, no Lua timer. **Digital countdown is opt-in** — `showTimer` setting (default false) + `/bb timer` toggle.
- **Stacks field = `aura.applications`** (fallback `aura.charges`), shown only when > 1 (standard buff UX; user confirmed "only when > 1"). Our first version read `aura.count` → always blank (bug, fixed).
- **v0.1 scope = compact frames only.** Classic party frames (`PartyMemberFrame1..4`) are future work (v0.2).
- **Hiding the native small Lifebloom icon: impossible per-buff**; hiding ALL compact buffs is all-or-nothing — not in v0.1.
- Overlay anchor/size defaults (TOPRIGHT of the frame, base 20 px) + text anchors/sizes: anchor iterated per user feedback 2026-08-15 — bottom-left (covered debuffs on the left) → RIGHT (native bottom strip covered the icon's lower part) → **TOPRIGHT** (clear of the bottom strip, SweepyBoop-proven). Stacks number at the icon's TOPLEFT (user request; the clockwise swipe covers it last). Still tunable.

## To verify in game (before v0.1 ships)

1. R2/R3 spell IDs (`48450`/`48451`) on a max-rank Druid (R1 `33763` verified).
2. Final acceptance: swipe sweeps clockwise, stacks show at 2–3 (hidden at 1), `/bb timer` toggles digital countdown (default off), overlay placement/size.
3. Raid path: `CompactUnitFrame_UpdateAll` + `displayedUnit` on `CompactRaidFrame<N>` in a real raid.

## Phases

- Phase 0 — scaffold: DONE.
- Phase 1 — compact party overlay: implemented; **core verified in game** (2026-08-15), final acceptance of placement/size + timer/stacks pending.
- Phase 2 — raid overlay: implemented; raid frames confirmed nil outside a raid; **real-raid test pending**.
- Phase 3 — settings UI / tests / release: NOT started.
