# BloomBuddy — v0.1 Development Plan

> This is the plan for the **first version** of the addon. It is the reference used by the
> `phase-workflow` skill. Every phase ends with a working build that can be loaded in game
> (`/reload`) and verified. Don't move to the next phase until the Definition of Done is met.

**Target version:** v0.1 — enlarge the Lifebloom buff icon on party and raid frames.

**Game:** WoW TBC Anniversary, Interface `20506`.

**Current state:** Phase 0 (scaffold) is done. Phases 1–2 need in-game verification (the exact
frame paths and the spell IDs must be confirmed on the 2.5.x client).

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
- [x] `Classes/Frames.lua` — core skeleton: spellID detection, party scaling, raid hook, ticker.
- [x] `Classes/OptionsUI.lua` — `/bb` slash commands + status.
- [x] AI library: `AGENTS.md`, `.github/` (CONTEXT, ARCHITECTURE, agents, skills, prompts, tools, docs), `.env.example`, `.gitignore`, `LICENSE`, `luahelper.json`, `README.md`, `CHANGELOG.md`.

### Definition of Done

- [x] `/reload` — no Lua errors (check via `/console scriptErrors 1`).
- [x] `/bb` prints status; `/bb help` lists commands; `/bb debug` toggles logging.
- [x] `tools/vararg-check.ps1` passes (every `.lua` ends `return BB;`, TOC order correct).
- [x] `tools/syntax-check.ps1` passes if a Lua interpreter is available.

---

## Phase 1 — Party frame scaling

**Goal:** on party frames, the Lifebloom icon of every party member is visibly larger.

### Tasks

- [ ] **Verify in game** the party buff-frame structure on 2.5.x:
  - `PartyMemberFrame1..4`, the buff container name and child naming (`Buff<1..N>`), the buff-icon texture path (`buff.Icon`), and the buff count per member.
  - Confirm `C_UnitAuras.GetAuraDataByIndex("party"..n, i, "HELPFUL")` returns `.spellId` on a party unit. Use `tools/research.ps1` + the `addon-research` skill on working addons (e.g. `BuffSizeShifter`, `BigDebuffs`, `sArena_Reloaded`) if anything is unclear.
- [ ] **Verify the Lifebloom spell IDs**: `/run for _, id in ipairs(BB.Data.Constants.LIFEBLOOM_SPELL_IDS) do print(id, GetSpellInfo(id)) end` — fix `Constants.lua` if needed (also verify `LIFEBLOOM_TEXTURE` via `GetSpellTexture`).
- [ ] Harden `Classes/Frames.lua` party path against the verified structure.
- [ ] Add `/bb debug` diagnostics: `party scan: scaled N icon(s)` per scan.
- [ ] Update `.github/` docs first if the design changes (contract-first).

### Definition of Done

- In a 2v2/3v3/5v5 group: a party member's Lifebloom icon is ~1.5× larger than other buffs.
- The size persists across buff updates (hook + ticker re-apply works).
- Disabling `/bb disable` stops scaling; `/bb enable` resumes it.

---

## Phase 2 — Raid frame scaling

**Goal:** on raid frames, the Lifebloom icon of every raid member is visibly larger.

### Tasks

- [ ] **Verify in game** the raid buff rendering on 2.5.x:
  - `CompactUnitFrame_UpdateBuff(unitButton, index, numBuffs, isDebuff)` exists and is called per buff; `unitButton.unit` is populated.
  - The buff button path used to resize the icon (`unitButton.Buff[<index>].Icon` or the equivalent) — confirm against working addons.
  - Confirm the hook fires for a raid member's Lifebloom.
- [ ] Harden the raid hook in `Classes/Frames.lua`; keep the SecureHook → manual-wrapper fallback.
- [ ] Add `/bb debug` diagnostics: `raid hook: scaled N icon(s)`.
- [ ] Update `.github/` docs first if the design changes.

### Definition of Done

- In a raid: a member's Lifebloom icon is larger than other buffs and stays so across updates.
- Party and raid can be toggled independently (`party`/`raid` settings).

---

## Phase 3 — Settings UI, polish, tests, release

### Tasks

- [ ] **Interface Options panel** (Interface Options → AddOns → BloomBuddy), native Settings API (`Settings.RegisterCanvasLayoutCategory`; legacy `InterfaceOptions_AddCategory` is nil on 2.5.5): master switch, scale slider, party/raid checkboxes. All strings via `BB.L` (enUS/ruRU). See the `wow-api-20506` skill for the UI gotchas (BackdropTemplate mixin, `GetChildren()` wrap, slider label).
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
| 1. Party frames | 1–2 h |
| 2. Raid frames | 1–2 h |
| 3. Settings/UI/tests/release | 3–5 h |
| **Total** | **~6–11 h** |
