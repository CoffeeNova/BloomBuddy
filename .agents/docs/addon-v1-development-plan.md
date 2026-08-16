# BloomBuddy — v0.1 Development Plan

> This is the plan for the **first version** of the addon. It is the reference used by the
> `phase-workflow` skill. Every phase ends with a working build that can be loaded in game
> (`/reload`) and verified. Don't move to the next phase until the Definition of Done is met.

**Target version:** v0.1 — show an enlarged Lifebloom icon on party and raid frames.

**Game:** WoW TBC Anniversary, Interface `20506`.

**Current state:** Phase 0 (scaffold) is done. The design was revised after client research
(2026-08): on this client the native buff icons on compact frames (raid + raid-style party) are
**C-rendered** — they cannot be resized or hidden per-buff. The feature is implemented as a
**custom Lifebloom overlay icon** on compact frames (the SweepyBoop pattern, verified on the same
client). Core mechanics are verified in game (2026-08-15): spell ID `33763` (R1), the
`CompactUnitFrame_UpdateAll` hook, `CompactPartyFrameMember<N>` frames, show/hide, `/bb` enable/
disable. Phase 1 is implemented and pending final in-game acceptance (overlay placement +
timer/stacks). Phase 2 (raid) verified the frames are nil outside a raid — pending a raid test.

---

## Phase 0 — Scaffold and data ✅ (done)

**Goal:** the addon loads without errors; the file structure, static data and AI library exist.

### Tasks

- [x] `BloomBuddy.toc`:
  - `## Interface: 20506`, `## Title`, `## Notes`, `## Version: 0.1.0`, `## SavedVariables: BloomBuddyDB`, `## License: MIT`, `## DefaultState: enabled`.
  - File order: `bootstrap.lua` → `Data/*` → `Utils/*` → `Classes/*`.
- [x] `bootstrap.lua`: global `BB` table, `BB.Frame`, `ADDON_LOADED` → module init, initial `Frames:checkNow()`.
- [x] `Data/Constants.lua`: `LIFEBLOOM_SPELL_IDS` (33763/48450/48451 — VERIFY), `LIFEBLOOM_TEXTURE` (VERIFY), `DEFAULT_SCALE = 1.5`, `MAX_PARTY_BUFFS`, `MAX_RAID_BUFFS`, `RECHECK_TICK = 0.5`.
- [x] `Data/DefaultSettings.lua`: `enabled/scale/party/raid`.
- [x] `Data/Localization.lua`: enUS + ruRU minimal strings.
- [x] `Utils/Tables.lua`, `Utils/Timers.lua` (ported from ArenaChillPrep, same client).
- [x] `Classes/Events.lua`, `Classes/Settings.lua` (ported, `BB` global, `BloomBuddyDB`).
- [x] `Classes/Frames.lua` — core skeleton: spellID detection, compact-frame overlay, safety ticker.
- [x] `Classes/OptionsUI.lua` — `/bb` slash commands + status.
- [x] AI library: `AGENTS.md`, `.agents/` (CONTEXT, ARCHITECTURE, agents, skills, prompts, tools, docs), `.env.example`, `.gitignore`, `LICENSE`, `luahelper.json`, `README.md`, `CHANGELOG.md`.

### Definition of Done

- [x] `/reload` — no Lua errors (check via `/console scriptErrors 1`).
- [x] `/bb` prints status; `/bb help` lists commands; `/bb debug` toggles logging.
- [x] `tools/vararg-check.ps1` passes (every `.lua` ends `return BB;`, TOC order correct).
- [x] `tools/syntax-check.ps1` passes if a Lua interpreter is available.

---

## Phase 1 — Compact party frame overlay

**Goal:** on raid-style (compact) party frames, a member with Lifebloom shows an enlarged Lifebloom icon.

> **Design revision (2026-08, client research):** the original plan (resize `PartyMemberFrame<N>.BuffFrame.Buff<K>.Icon` via `SetSize`) is replaced by an **overlay icon** on compact frames — on 2.5.6 native compact-frame buff icons are C-rendered and cannot be resized per-buff (verified: BigDebuffs code comment + zero `CompactUnitFrame_UpdateBuff` references; SweepyBoop's overlay pattern). See `.agents/skills/unit-frame-buffs/SKILL.md`.

### Tasks

- [x] **Verify in game** the client facts (see the checklist in `Classes/Frames.lua`):
  - `CompactUnitFrame_UpdateBuff` → nil; `CompactUnitFrame_UpdateAll` → function; `CompactPartyFrameMember1` exists. ✅ (2026-08-15: `nil` / `function` / table with `unit="player"`).
  - Confirm `C_UnitAuras.GetAuraDataByIndex("party"..n, i, "HELPFUL")` returns `.spellId` on a compact party unit. ✅ (overlay shows for the member's unit).
- [x] **Verify the Lifebloom spell IDs**: `33763` → "Lifebloom" ✅. `48450`/`48451` returned empty (not learned on the tester) — keep in the list, confirm on a 70 Druid. `LIFEBLOOM_TEXTURE` still to verify via `GetSpellTexture`.
- [x] Harden `Classes/Frames.lua` compact-party path (frame filter, overlay lifecycle, `pcall`-guarded creation).
- [x] Confirm the overlay placement/size in game (anchor constant `OVERLAY_ANCHOR`, `OVERLAY_BASE_SIZE`); adjust from user feedback. (Overlay shows; size/position tuning awaited.)
- [x] Add `/bb debug` diagnostics: `compact scan: showing N overlay(s)` per scan. ✅
- [x] Update `.agents/` docs first if the design changes (contract-first).
- [x] **Overlay timer + stacks** (user request 2026-08-15): default display is a native **cooldown swipe** (darkening clockwise, C-driven); a **digital countdown** is opt-in (`showTimer`, default off, `/bb timer`). Stacks come from `aura.applications or aura.charges` (`.count` is NOT the field on this client — fixed after user feedback: stacks were invisible).

### Definition of Done

- [x] With raid-style party frames enabled and a member holding Lifebloom: an enlarged Lifebloom icon is visible on that member's frame and hidden when Lifebloom fades. ✅
- [x] The overlay stays correct across frame reuse / unit changes (hook + events + ticker work). ✅
- [x] Disabling `/bb disable` stops the overlay; `/bb enable` resumes it. ✅
- [ ] **Final acceptance (pending):** the cooldown swipe sweeps clockwise on the overlay; stacks show at 2–3 (hidden at 1); `/bb timer` toggles the digital countdown (default off); overlay placement/size look right on the party frame.

---

## Phase 2 — Raid frame overlay

**Goal:** on raid frames, a member with Lifebloom shows an enlarged Lifebloom icon.

### Tasks

- [ ] **Verify in game** that `CompactUnitFrame_UpdateAll` fires for `CompactRaidFrame<N>` and `frame.displayedUnit` is populated for raid units. (2026-08-15: `CompactRaidFrame1` is nil outside a raid — expected; needs a raid to confirm.)
- [x] Harden the raid path in `Classes/Frames.lua` (same overlay machinery as party; frame-name gate: `CompactRaid*` → `raid` setting).
- [ ] Confirm overlay placement on a raid frame (same anchor as party; adjust from user feedback).
- [x] Add `/bb debug` diagnostics: `compact scan: showing N overlay(s)` (shared with party). ✅
- [x] Update `.agents/` docs first if the design changes.

### Definition of Done

- [ ] In a raid: a member's Lifebloom icon is shown enlarged and stays correct across updates.
- [x] Party and raid can be toggled independently (`party`/`raid` settings). ✅ (settings gate by frame-name prefix; raid path shares the machinery)

---

## Phase 3 — Settings UI, polish, tests, release

### Sub-phase 3a — Settings UI window (`.agents/docs/settings-ui-plan.md`)

**Goal:** a minimal Blizzard-style settings window opened with `/bb options` (lazy creation, vanilla widgets, standalone dialog — ADR 9).

- [x] Contract updated FIRST: `CONTEXT.md` (settings + `/bb options`), `ARCHITECTURE.md` (2.5 OptionsUI section + ADRs 9/10).
- [x] `Data/DefaultSettings.lua`: `showSwipe = true` (functional), `overlayPosX = 0` / `overlayPosY = 0` (persisted stubs) — migration via existing `deepMerge`/`ensureDefaults`.
- [x] `Classes/Settings.lua`: `Settings:reset()` (restore defaults + persist).
- [x] `Classes/Frames.lua`: `showSwipe = false` → `CooldownFrame_Clear` + hide, skip `Set` (only functional core change); `/bb debug` settings line gains `showSwipe`.
- [x] `Data/Localization.lua`: new enUS + ruRU strings (window, labels, tooltips, reset message); `status`/`help` updated.
- [x] `Classes/OptionsUI.lua`: window + `/bb options` (drag, close, help "?", reset, size slider live, position sliders persist-only, showSwipe/showTimer checkboxes, sync on open).
- [x] `BloomBuddy.toc` — unchanged (no new files).
- [ ] **In-game verification pending** (user): window opens/drags/closes; help tooltip; reset re-syncs; size slider live; position sliders persist across `/reload`; checkboxes toggle swipe + timer; `/bb status` reflects changes; zero errors with `/console scriptErrors 1`.

### Remaining Phase 3 tasks (after 3a)

- [ ] **Interface Options panel** (Interface Options → AddOns → BloomBuddy), native Settings API (`Settings.RegisterCanvasLayoutCategory`; legacy `InterfaceOptions_AddCategory` is nil on 2.5.5): master switch, scale slider, party/raid checkboxes. All strings via `BB.L` (enUS/ruRU). See the `wow-api-20506` skill for the UI gotchas (BackdropTemplate mixin, `GetChildren()` wrap, slider label). *(Note: ADR 9 now favors the standalone window — an Options-panel variant is optional, not required.)*
- [ ] **Automated unit tests** (`Tests/`, mirroring the ArenaChillPrep harness): read the `unit-testing` skill first. Cover bootstrap, Data, Utils, Settings, Events (non-UI). Target ≥ 90% coverage of non-UI modules.
- [ ] **Polish:** tooltips, default handling, `CHANGELOG.md`, final `README.md`.
- [ ] **Release:** `tools/deploy.ps1 -Bundle` → CurseForge/Wago zip.

### Definition of Done

- Settings persist between sessions; disabling the addon makes it idle.
- `.\Tests\run-tests.ps1` exits 0 (tests pass, coverage ≥ 90% of non-UI modules).
- Clean in-game check: `/console scriptErrors 1`, extended play with zero errors.

---

## Effort estimate (rough)

| Phase | Estimate |
|---|---|
| 0. Scaffold | 1–2 h (done) |
| 1. Compact party overlay | 1–2 h |
| 2. Raid overlay | 1–2 h |
| 3. Settings/UI/tests/release | 3–5 h |
| **Total** | **~6–11 h** |
