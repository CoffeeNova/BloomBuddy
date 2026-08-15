# BloomBuddy — Context (for AI agents)

> Source of truth: this directory (`.agents/`). Entry point: `AGENTS.md` at the repo root.
> This file is the main source of context when working on the addon. **Read `ARCHITECTURE.md` before changing any code.**

**Current status:** v0.1 in development — design changed after client research (2026-08): on TBC Anniversary 2.5.6 the native buff icons on **compact frames** (raid frames and raid-style party frames) are **rendered by the game engine (C)**, so a single buff icon cannot be resized via Lua. The core feature is implemented as a **custom Lifebloom overlay icon** drawn on the compact frame (the pattern proven by SweepyBoop on the same client). Remaining time is shown as a native **cooldown swipe** (darkening clockwise, C-driven); a **digital countdown is opt-in** (`showTimer`, default off, `/bb timer`). The overlay shows the **stack count** (`aura.applications`, hidden at ≤ 1). Core mechanics verified in game (2026-08-15): spell ID `33763` (R1), the `CompactUnitFrame_UpdateAll` hook, the `CompactPartyFrameMember<N>` frames, show/hide on apply, `/bb enable`/`disable`. Round-3 feedback (2026-08-15): stacks render but the cooldown swipe was not visible and OmniCC (installed on the tester's client) drew countdown numbers that `/bb timer` could not hide — fixed via `noCooldownCount = true` + show-before-sweep ordering + a `/bb debug` overlay dump; **final acceptance pending**.

---

## What the addon does

BloomBuddy is intentionally tiny. It has ONE job:

> **When a party or raid member has the Druid Lifebloom HoT on them, show an enlarged Lifebloom icon on that member's compact unit frame.**

1. Tracks compact unit frames (`CompactPartyFrameMember1..5`, `CompactRaidFrame1..40`) via a hook on `CompactUnitFrame_UpdateAll` (the real per-frame hook point on 2.5.6 — `CompactUnitFrame_UpdateBuff` does NOT exist on this client).
2. Reads the member's unit from `frame.displayedUnit or frame.unit`.
3. Detects Lifebloom by **spellID** via `C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")` — `UnitBuff` / `UnitAura` are broken on 2.5.5 (see the `wow-api-20506` skill).
4. Draws a bigger Lifebloom icon (`OVERLAY_BASE_SIZE * scale`, default 1.5×) anchored on the member's frame, shows it while Lifebloom is up and hides it otherwise.
5. Remaining time on the icon is shown by a native **`Cooldown` swipe** (`CooldownFrame_Set(expirationTime - duration, duration)` — the client animates the darkening clockwise sweep on its own, no Lua timer). A **digital countdown** is optional (`showTimer` setting, default off, `/bb timer`).
6. Shows the **stack count** (`aura.applications or aura.charges`, hidden at ≤ 1; Lifebloom stacks to 3).
7. Re-applies on `CompactUnitFrame_UpdateAll`, on `UNIT_AURA` / `GROUP_ROSTER_UPDATE`, and via a periodic safety re-check ticker.

### Important to understand

- **Why an overlay, not a resize:** on this client (2.5.6) the native buff icons on compact frames are C-rendered — there is no Lua-accessible per-icon texture to `SetSize`, and `frame.auraSize` would enlarge ALL buffs+debuffs of a member uniformly. The proven addon approach on this client (SweepyBoop, BigDebuffs) is drawing a custom overlay icon. The native small Lifebloom icon stays visible next to ours.
- The addon only creates a child frame with one texture per tracked compact frame. It never moves/re-parents Blizzard frames, never repositions buffs, and never touches other addons' frames.
- It is completely idle when disabled.
- No libraries (no Ace). Vanilla + `C_` APIs only.

---

## Technical data (TBC Anniversary)

| Entity | Value |
|---|---|
| Game version | TBC Anniversary (2.5.x), Interface `20506` |
| Lifebloom (Druid HoT) | Spell IDs `33763` (R1) / `48450` (R2) / `48451` (R3) — **`33763` VERIFIED in game** (2026-08-15, `GetSpellInfo`); R2/R3 unlearned on the tester, still to confirm |
| Lifebloom icon | `Interface\Icons\Spell_Nature_LifeBloom` — **VERIFY** (`GetSpellTexture(id)`) |
| Compact frames (raid + raid-style party) | `CompactRaidFrame1..40` / `CompactPartyFrameMember1..5`; unit via `frame.displayedUnit or frame.unit`; **native buff icons are C-rendered on 2.5.6** (no Lua-accessible per-icon; only lever is `frame.auraSize`, uniform). `CompactRaidFrame1` is nil outside a raid group — expected |
| Compact frame hook point | `CompactUnitFrame_UpdateAll(frame)` — fires per frame on setup/reuse (**VERIFIED in game** 2026-08-15: exists as function; `CompactUnitFrame_UpdateBuff` = `nil`). The hook fires and `frame.displayedUnit` is populated for `CompactPartyFrameMember<N>` |
| Classic party frames | `PartyMemberFrame1..4`; buffs at `<frame>.BuffFrame.Buff<1..N>` — **NOT the v0.1 target** (user uses raid-style party frames); classic path is future work |
| Buff lookup | `C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")` → object with `.spellId/.name/.duration/.expirationTime/.applications/.charges/...` (`.expirationTime`/`.duration` VERIFIED in game; stack count is **`.applications`** on this client — read by BigDebuffs (`aura.applications or aura.charges or 0`), BetterBlizzFrames, ArenaAnalytics; `.count` is NOT the field here) |

---

## Project structure

```
BloomBuddy/
├── AGENTS.md                 # Agent entry point → read .agents/ (this directory)
├── BloomBuddy.toc            # TOC (Interface: 20506, SavedVariables: BloomBuddyDB)
├── bootstrap.lua             # Entry point: global BB table, event frame, initialization
├── README.md                 # Human-facing description (users) — not technical docs
├── .agents/                  # Agent documentation & instructions (source of truth)
│   ├── CONTEXT.md            # This file: context, conventions, gotchas, settings
│   ├── ARCHITECTURE.md       # Architecture: modules, data flow, decisions
│   ├── agents/               # Agent definitions (bloom-developer, ...)
│   ├── skills/               # Skills (wow-api-20506, unit-frame-buffs, ...)
│   ├── prompts/              # Prompt templates (phase-start, debug-report, ui-review)
│   ├── tools/                # PowerShell tools (deploy, vararg-check, ...)
│   └── docs/                 # Development plans
├── Data/                     # Static data
│   ├── Constants.lua         # Lifebloom spell IDs, icon texture, scale defaults, timings
│   ├── DefaultSettings.lua   # SavedVariables defaults (BloomBuddyDB)
│   └── Localization.lua      # Strings (enUS / ruRU)
├── Classes/                  # Service modules
│   ├── Events.lua            # Event frame wrapper / internal event bus
│   ├── Settings.lua          # SavedVariables wrapper (BloomBuddyDB)
│   ├── Frames.lua            # CORE: Lifebloom detection + icon scaling (party/raid)
│   └── OptionsUI.lua         # /bb slash commands + status (full panel: later phase)
└── Utils/                    # Utilities
    ├── Tables.lua            # Table helpers (deepMerge, shallowCopy)
    └── Timers.lua            # Named timers via C_Timer (after/interval/cancel)
Tests/                        # Unit tests (planned — Phase 3, run OUTSIDE the game)
```

---

## Development environment (where the WoW client lives)

This repo is developed **outside** the game client. The WoW TBC Anniversary client
with its addons is a separate folder on the machine — it is NOT part of this repo
and its path must never be hardcoded here.

- The client's AddOns folder is configured in **`.env`** at the repo root
  (copy `.env.example` → `.env`), variable **`addons_path_anniversary`**,
  e.g. `addons_path_anniversary=G:\games\World of Warcraft\_anniversary_\Interface\AddOns`.
- `.env` is git-ignored (machine-specific). `.env.example` documents the variable.
- Scripts that need the path read it from the environment:
  - `tools/research.ps1` — searches the working addons (default root = `$env:addons_path_anniversary`, override with `-Root`).
  - `tools/load-env.ps1` — loads `.env` into the session (dot-source it: `. .\.agents\tools\load-env.ps1`).
  - `tools/deploy.ps1` — deploys the addon to the client (see below).
- To test in game: run `tools/deploy.ps1` — it copies **only the game artifacts**
  (the `.toc` + every file it references + `LICENSE`) into `%addons_path_anniversary%\BloomBuddy`,
  keeping the repo clean of client files.

## Release bundle (CurseForge / CI)

`tools/deploy.ps1 -Bundle` builds a release zip in `dist/` (git-ignored) named
`<addon>-<version>.zip` (version read from the `.toc`). The zip contains exactly
the game artifacts — the same file set as a client deploy. `dist/` is never committed.

---

## Code conventions

- **Lua 5.1**, no external libraries (no Ace — the addon is self-contained).
- Every file is a module table. The addon's global table is `BB` (BloomBuddy).
- Modules receive the `BB` reference via vararg: `local _, BB = ...;`.
- Style follows the sibling **ArenaChillPrep** addon (same workspace): `---@class` annotations, `_G.` prefix for global APIs, local aliases for globals at the top of the file.
- UI strings go through `Data/Localization.lua` (table `L`, metatable fallback to the key).
- Cross-session state only via `BloomBuddyDB` (SavedVariables), accessed through `BB.Settings`.

---

## Static analysis (luahelper MCP)

The **luahelper MCP** server is the repo's static-analysis gate for all Lua code:

- **While editing** a file: `luahelper_check_lua_file <absolute path>`.
- **Before finishing** a phase/feature: `luahelper_check_lua_project <repo root>`.
- **Interpretation:** fix all real **errors** and **warnings**. Informational messages
  (Warn type 18 — `not define annotate type`, `duplicate annotate type`, `---@class` /
  `---@type` underlines) are the same annotation noise produced by the sibling
  `ArenaChillPrep` repo and are **expected** here — do not churn code to silence them.
- Config lives in `luahelper.json` at the repo root (ignored modules listed in
  `ignoreModules`, e.g. `SecureHook`, `SlashCmdList`; `.agents/` and `Tests/` excluded).
- Fix loop: run → fix errors/warnings → re-run → until only informational type-18
  messages remain.

---

## Unit tests (run outside the game — planned)

The addon will mirror the test harness proven in the sibling workspace `ArenaChillPrep`
(`Tests/`, run under LuaJIT — Lua 5.1, the same version WoW uses). It does **not** exist
yet; it is Phase 3 of the development plan (`.agents/docs/addon-v1-development-plan.md`).
Before writing or running tests, read the `unit-testing` skill
(`.agents/skills/unit-testing/SKILL.md`).

---

## Key mechanics and gotchas

1. **Buff detection.** On 2.5.5, `UnitBuff(unit, name)` **crashes** (the deprecated wrapper only accepts a numeric index) and `UnitAura(unit, i, filter)` returns **shifted legacy positions** (spellID/expirationTime are never captured). Use `C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")` → object with `.spellId`. For the player's own Lifebloom, `C_UnitAuras.GetPlayerAuraBySpellID(id)` also works.
2. **Compact-frame buff icons are C-rendered on 2.5.6.** There is no Lua-accessible per-buff icon to resize, no `buffFrames` array, and **no per-buff filter to hide one icon** (absence in all working addons = impossible on this client). `frame.auraSize` is the only native lever and it scales ALL buffs+debuffs of a member uniformly — never use it to "highlight" one buff. The proven approach is a custom overlay icon (SweepyBoop, BigDebuffs).
3. **The real compact-frame hook is `CompactUnitFrame_UpdateAll(frame)`** (fires per frame on setup/reuse; VERIFIED via SweepyBoop + BigDebuffs on this client). `CompactUnitFrame_UpdateBuff` does **not** exist on 2.5.6. Unit per frame: `frame.displayedUnit or frame.unit`.
4. **Lifebloom has several ranks.** A member may hold R1/R2/R3 (spell IDs `33763`/`48450`/`48451`). Match by spellID against the full list. `33763` is VERIFIED in game; R2/R3 unlearned on the tester — confirm before trusting. (Check: `/run for _, id in ipairs(BB.Data.Constants.LIFEBLOOM_SPELL_IDS) do print(id, GetSpellInfo(id)) end`)
5. **Overlay lifecycle.** The overlay is a child frame (`frame.BB_LifebloomOverlay`) created once per tracked compact frame, shown/hidden by the aura scan. The 0.5 s ticker + `UNIT_AURA` + `CompactUnitFrame_UpdateAll` keep it in sync when frames are reused for different units.
6. **Swipe + stacks + timer come from the aura object.** `GetAuraDataByIndex` returns `.expirationTime`/`.duration` (remaining-time) and the stack count as **`.applications`** (fallback `.charges`) on 2.5.x — NOT `.count`. 
   - **Swipe (default):** a native `Cooldown` widget on the overlay, created **with the `"CooldownFrameTemplate"`** (VERIFIED on this client: every working addon — BigDebuffs, ClassicAuraDurations, SweepyBoop — creates it that way; a bare `CreateFrame("Cooldown")` has NO swipe texture, so the sweep ran but rendered nothing — our round-4 bug). Driven with `CooldownFrame_Set(cd, expirationTime - duration, duration, true)`, configured `SetAlpha(1)`, `SetSwipeColor(0,0,0,0.7)` (BigDebuffs), `SetDrawEdge(false)`, `SetDrawBling(false)`, **`SetReverse(true)`** (client-correct sweep direction — every working addon sets it; the default sweeps the wrong way: the icon lightens instead of darkening — round-5 user feedback), `SetHideCountdownNumbers(true)` **and `noCooldownCount = true`** (the OmniCC-style opt-out — countdown add-ons leave a widget with `noCooldownCount` alone; without it OmniCC draws its own numbers on the swipe that the addon cannot hide). The client animates the darkening sweep itself — no Lua timer; re-`Set` on each refresh keeps it in sync when the buff is refreshed. `CooldownFrame_Clear(cd)` when `duration` ≤ 0.
   - **Stacks:** the `stacks` FontString shows `aura.applications or aura.charges` when > 1 (standard buff UX).
   - **Digital timer (opt-in):** the `timer` FontString shows `expirationTime - GetTime()` ("N"/"m:ss") only when `showTimer` is on (`/bb timer`, default off).
7. **Frames module is UI-only.** Keep the matching/overlay logic in `Classes/Frames.lua`; the decision logic (which frames, enabled?) reads settings. Unit tests will target the non-UI parts (Settings, Events, bootstrap).
8. **Diagnostics.** All actions are logged to chat via `BB:` prefix; per-tick spam goes through `BB:debugPrint` (only when `/bb debug` is on). No file logging in v0.1.
9. **`C_Timer` handle `Cancel()` is UNRELIABLE on this client.** A "cancelled" timer can still fire (verified live in ArenaChillPrep 2026-08-10). Always use `BB.Utils.Timers` (named entries with an `active` flag), never raw `C_Timer` handles.

---

## Proven patterns (researched from working addons)

- **Custom buff icons on compact frames** — SweepyBoop (`RaidFrames/BuffHelper.lua`, TBC Anniversary build) tracks compact frames via `hooksecurefunc("CompactUnitFrame_UpdateAll", ...)`, reads `frame.displayedUnit or frame.unit`, scans auras via `GetAuraDataByIndex(unit, i, "HELPFUL")`, and draws its own icons (20 px primary buff) as child frames anchored on the frame. Frame name filter: starts with `CompactPartyFrame` / `CompactRaid`. **This is the pattern BloomBuddy v0.1 uses.**
- **Cooldown swipe on icons** — BigDebuffs (`BigDebuffs.lua`) and ClassicAuraDurations (`code.lua`) drive the native `Cooldown` widget on this client via `CooldownFrame_Set(cooldown, expirationTime - duration, duration, true)` / `CooldownFrame_Clear`, with `SetHideCountdownNumbers`, `SetSwipeTexture`, `SetReverse`. M6 (`Repaint.lua`) shows `SetSwipeColor(0, 0, 0)` for a plain darkening sweep. **This is how BloomBuddy renders remaining time.** OmniCC's `cooldown.lua` checks `self.noCooldownCount` in `CanShowText`/`CanShowFinishEffect`/`OnCooldownDone` — set `noCooldownCount = true` on the widget to keep countdown add-ons off it.
- **Stack count field is `.applications`** on this client — BigDebuffs `aura.applications or aura.charges or 0`, BetterBlizzFrames & ArenaAnalytics `aura.applications`. Do NOT read `.count` here.
- **Raid/party frame mechanics on 2.5.6** — BigDebuffs confirms in code: "Midnight-era clients (MoP Classic 5.5.4, TBC Anniversary 2.5.6): native buff icons render in C with no buffFrames array to resize, so the only lever is frame.auraSize." BigDebuffs only hooks `CompactUnitFrame_UpdateAll` on this client.
- **Named timers** — `BB.Utils.Timers:after/interval/cancel` (thin wrapper over `C_Timer`) — the same dependency-free pattern proven in ArenaChillPrep.

---

## Slash commands

| Command | Action |
|---|---|
| `/bb` | Show status (enabled, scale, party/raid toggles, timer) + re-apply now |
| `/bb enable` / `/bb disable` | Enable/disable the addon |
| `/bb timer` | Toggle the digital countdown on the overlay (default off; the cooldown swipe is always shown) |
| `/bb debug` | Toggle verbose logging; always dumps tracked-overlay state (positions, cooldown swipe, stacks/timer text, raw aura fields) — the in-game diagnostic for overlay issues |
| `/bb help` | List commands |

---

## Settings (v0.1)

```lua
BloomBuddyDB = {
    enabled   = true,   -- master switch
    scale     = 1.5,    -- icon size multiplier (baseSize * scale)
    party     = true,   -- scale on party frames
    raid      = true,   -- scale on raid frames
    showTimer = false,  -- digital countdown on the overlay (default off; the cooldown swipe is always shown)
}
```
