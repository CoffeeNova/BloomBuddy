# BloomBuddy — Context (for AI agents)

> Source of truth: this directory (`.github/`). Entry point: `AGENTS.md` at the repo root.
> This file is the main source of context when working on the addon. **Read `ARCHITECTURE.md` before changing any code.**

**Current status:** v0.1 in development — scaffold complete (bootstrap, Data, Utils, shared Classes, slash commands). The core scaling logic (`Classes/Frames.lua`) is implemented for party frames and hooked for raid frames, but **both paths must be verified in game** before v0.1 ships.

---

## What the addon does

BloomBuddy is intentionally tiny. It has ONE job:

> **When a party or raid member has the Druid Lifebloom HoT on them, make that member's Lifebloom buff icon bigger on the unit frame.**

1. Watches the buff icons of party members (`PartyMemberFrame1..4`) and raid members (`CompactUnitFrame`).
2. Detects Lifebloom among the buffs by **spellID** via `C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")` — `UnitBuff` / `UnitAura` are broken on 2.5.5 (see the `wow-api-20506` skill).
3. Resizes the matching icon to `baseSize * scale` (default `1.5×`).
4. Re-applies the scale whenever the game redraws the icons (Blizzard's update functions reset the size): a hook on `CompactUnitFrame_UpdateBuff` for raid frames + a periodic safety re-check ticker.

### Important to understand

- The addon only calls `SetSize` on the Lifebloom icon texture. It never changes frame layout, never repositions buffs, and never touches other addons' frames.
- It is completely idle when disabled.
- No libraries (no Ace). Vanilla + `C_` APIs only.

---

## Technical data (TBC Anniversary)

| Entity | Value |
|---|---|
| Game version | TBC Anniversary (2.5.x), Interface `20506` |
| Lifebloom (Druid HoT) | Spell IDs `33763` (R1) / `48450` (R2) / `48451` (R3) — **VERIFY in game** (`GetSpellInfo(id)`) |
| Lifebloom icon | `Interface\Icons\Spell_Nature_LifeBloom` — **VERIFY** (`GetSpellTexture(id)`) |
| Party frames | `PartyMemberFrame1..4`; buffs at `<frame>.BuffFrame.Buff<1..N>` (**VERIFY** count & paths on 2.5.x) |
| Raid frames | `CompactRaidFrameManager` → `CompactUnitFrame`; buffs drawn by `CompactUnitFrame_UpdateBuff(unitButton, index, numBuffs, isDebuff)` |
| Buff lookup | `C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")` → object with `.spellId/.name/.expirationTime/...` (verified API on 2.5.5) |

---

## Project structure

```
BloomBuddy/
├── AGENTS.md                 # Agent entry point → read .github/ (this directory)
├── BloomBuddy.toc            # TOC (Interface: 20506, SavedVariables: BloomBuddyDB)
├── bootstrap.lua             # Entry point: global BB table, event frame, initialization
├── README.md                 # Human-facing description (users) — not technical docs
├── .github/                  # Agent documentation & instructions (source of truth)
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
  - `tools/load-env.ps1` — loads `.env` into the session (dot-source it: `. .\.github\tools\load-env.ps1`).
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
  `ignoreModules`, e.g. `SecureHook`, `SlashCmdList`; `.github/` and `Tests/` excluded).
- Fix loop: run → fix errors/warnings → re-run → until only informational type-18
  messages remain.

---

## Unit tests (run outside the game — planned)

The addon will mirror the test harness proven in the sibling workspace `ArenaChillPrep`
(`Tests/`, run under LuaJIT — Lua 5.1, the same version WoW uses). It does **not** exist
yet; it is Phase 3 of the development plan (`.github/docs/addon-v1-development-plan.md`).
Before writing or running tests, read the `unit-testing` skill
(`.github/skills/unit-testing/SKILL.md`).

---

## Key mechanics and gotchas

1. **Buff detection.** On 2.5.5, `UnitBuff(unit, name)` **crashes** (the deprecated wrapper only accepts a numeric index) and `UnitAura(unit, i, filter)` returns **shifted legacy positions** (spellID/expirationTime are never captured). Use `C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")` → object with `.spellId`. For the player's own Lifebloom, `C_UnitAuras.GetPlayerAuraBySpellID(id)` also works.
2. **Blizzard resets icon sizes.** Every `CompactUnitFrame_UpdateBuff` / `PartyMemberFrame_UpdateBuffs` run rebuilds/resizes the icons — a one-time `SetSize` is not enough. Hook the update functions and re-apply after each run; a safety re-check ticker covers cases a hook misses.
3. **Lifebloom has several ranks.** A member may hold R1/R2/R3 (spell IDs `33763`/`48450`/`48451`). Match by spellID against the full list. **Verify the IDs in game** (`/run for _, id in ipairs(BB.Data.Constants.LIFEBLOOM_SPELL_IDS) do print(id, GetSpellInfo(id)) end`).
4. **Texture fallback.** If an icon cannot be matched by spellID (e.g. no aura object for the index), fall back to comparing `icon:GetTexture()` with `GetSpellTexture(LIFEBLOOM_SPELL_IDS[1])`. This is how several frame addons match buffs on this client.
5. **Do not compound the scale.** Once an icon is resized, `GetWidth()` returns the scaled size. Store the **base size once** on the icon (`icon._bbBaseSize`) and always compute `baseSize * scale` from it.
6. **Frames module is UI-only.** Keep the matching/scaling logic in `Classes/Frames.lua`; the decision logic (which frames, enabled?) reads settings. Unit tests will target the non-UI parts (Settings, Events, bootstrap).
7. **Diagnostics.** All actions are logged to chat via `BB:` prefix; per-tick spam goes through `BB:debugPrint` (only when `/bb debug` is on). No file logging in v0.1.
8. **`C_Timer` handle `Cancel()` is UNRELIABLE on this client.** A "cancelled" timer can still fire (verified live in ArenaChillPrep 2026-08-10). Always use `BB.Utils.Timers` (named entries with an `active` flag), never raw `C_Timer` handles.

---

## Proven patterns (researched from working addons)

- **Buff-icon enlargement on party frames** — addons like `BuffSizeShifter` / `BigDebuffs` on this client hook the party buff update function, then match buffs by spellID/texture and `SetSize` the icon. **Verify** the exact `PartyMemberFrame` buff-frame path on 2.5.x via the `addon-research` skill before relying on it.
- **Raid buff icons** — `CompactUnitFrame_UpdateBuff(unitButton, index, numBuffs, isDebuff)` is a stable global hook point (used by `sArena_Reloaded` / `BigDebuffs` on the same client). `unitButton.unit` gives the unit; `index` maps to the aura index.
- **Named timers** — `BB.Utils.Timers:after/interval/cancel` (thin wrapper over `C_Timer`) — the same dependency-free pattern proven in ArenaChillPrep.

---

## Slash commands

| Command | Action |
|---|---|
| `/bb` | Show status (enabled, scale, party/raid toggles) + re-apply now |
| `/bb enable` / `/bb disable` | Enable/disable the addon |
| `/bb debug` | Toggle verbose logging |
| `/bb help` | List commands |

---

## Settings (v0.1)

```lua
BloomBuddyDB = {
    enabled = true,   -- master switch
    scale   = 1.5,    -- icon size multiplier (baseSize * scale)
    party   = true,   -- scale on party frames
    raid    = true,   -- scale on raid frames
}
```
