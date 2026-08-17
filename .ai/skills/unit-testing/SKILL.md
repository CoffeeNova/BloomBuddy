---
name: unit-testing
description: How to write and run the BloomBuddy unit tests (luaunit + luacov under LuaJIT, outside the game) — based on the proven ArenaChillPrep harness. Covers the runner, the WoW stub environment, suite layout, AAA conventions, and the cross-suite state-pollution gotchas. The suite does NOT exist yet (Phase 3 of the development plan) — use this skill when creating it.
---

# Unit testing (BloomBuddy)

The addon is unit-tested **outside the game** under LuaJIT (Lua 5.1 — the same version WoW uses). No game client needed. Coverage target: **≥ 90%** of all non-UI modules. `Classes/Frames.lua` and `Classes/OptionsUI.lua` are UI-heavy and expected to be excluded or lightly covered.

> **Status:** the `Tests/` suite does NOT exist yet — it is Phase 3 of the development plan (`.ai/docs/addon-v1-development-plan.md`). The harness described below is a port of the one proven in the sibling workspace **ArenaChillPrep** (same client, same module conventions).

## When to touch the tests

- **Do NOT edit the unit tests while implementing a feature.** Write/fix production code first; leave `Tests/` alone during the implementation phase.
- **Only after the feature is finished AND the user gives permission** may you update the tests (add coverage for the new behavior, fix tests broken by the change).
- **Exception:** the user explicitly asked to edit tests — then this skill applies in full.

## Planned layout

```
Tests/
├── run_tests.lua         # Runner: luacov + luaunit + stubs + loader + coverage gate
├── run-tests.ps1         # PowerShell wrapper (exit codes below)
├── loader.lua            # Loads every addon module in TOC order via the vararg chain
├── helpers.lua           # SINGLETON (cached on _G.__TEST_HELPERS): SyncTimers, deepCopy,
│                         #   reloadModule, resetAll()
├── stubs/wow_stubs.lua   # WoW API stubs; mutable state in _G.__stub
├── lib/                  # Vendored: luaunit 3.5 + luacov 0.17 (do not edit)
├── test_bootstrap.lua    # bootstrap suite (mirrors bootstrap.lua at the addon root)
├── Data/                 # Suites mirror the addon structure
│   └── test_*.lua        #   constants, defaultsettings, localization
├── Utils/
│   └── test_*.lua        #   tables, timers
└── Classes/
    └── test_*.lua        #   events, settings
```

- **Suite layout mirrors the addon structure**: `Classes/Settings.lua` → `Tests/Classes/test_settings.lua`. `test_bootstrap.lua` stays at the `Tests/` root.
- **The runner keeps an explicit ordered list of suite paths** — order matters because some suites capture file-scope state. When adding a suite, add its path to the `suites` list in `run_tests.lua`.
- **luaunit discovers `test*` functions alphabetically across ALL suites** — a test in one suite can break a test in another. This is the #1 gotcha (see below).

## Run the suite

```powershell
.\Tests\run-tests.ps1
```

or from the addon root:

```powershell
luajit Tests\run_tests.lua
```

Requires LuaJIT on PATH (`winget install DEVCOM.LuaJIT`).

**Exit codes:** `0` = all tests pass AND coverage ≥ 90%, `1` = test failures, `2` = coverage < 90%.

**Outputs:** test results to stdout; coverage report to `Tests/luacov.report.out`. Both `luacov.stats.out` and `luacov.report.out` are gitignored (regenerated every run).

## The WoW stub environment

`Tests/stubs/wow_stubs.lua` replaces the WoW API so modules load and run under plain LuaJIT:

- **Mutable state lives in `_G.__stub`**: `time`, `auraByIndex` (for `C_UnitAuras.GetAuraDataByIndex`), `partyMembers`, `chatMessages`, `cTimerCallbacks`, etc.
- **File-scope captures read `_G.__stub`**: `GetTime`, `C_UnitAuras`, `C_Timer.After/NewTicker`, `DEFAULT_CHAT_FRAME`. To change these, mutate `_G.__stub` — do NOT replace the globals (the modules already captured them).
- **Call-time reads can be overridden directly**: `SecureHook`, `SlashCmdList`, `GetNumPartyMembers`, etc.

## Helpers (`Tests/helpers.lua`)

`helpers.lua` is a **singleton** — `dofile` it in every suite; it returns the same table (`_G.__TEST_HELPERS`), so all suites share one `SyncTimers` recorder:

```lua
local H = dofile(_G.__TESTS_ROOT .. "/helpers.lua");
```

- **`H.SyncTimers`** — synchronous timer recorder. `after`/`interval` STORE the callback, nothing runs on its own. Swap it in: `BB.Utils.Timers = H.SyncTimers;`. Advance explicitly: `H.advance("Recheck")`, check with `H.hasTimer("Recheck")`.
- **`H.deepCopy(t)`** — recursive copy (for snapshotting Settings/defaults).
- **`H.reloadModule(relPath)`** — re-loads an addon module through the vararg chain.
- **`H.resetAll()`** — re-inits ALL modules + wipes the event bus + clears timers. **REQUIRED at the start of every event-driven test.**

## Writing tests — conventions

- **Compact**: each test ≤ 15 lines (preferably ≤ 10). No shared data factories — each test builds its own data.
- **AAA comments**: `-- Arrange` / `-- Act` / `-- Assert`.
- **Assert both result AND mock behavior**: e.g. check `SlashCmdList` was registered, `C_UnitAuras.GetAuraDataByIndex` was called — not just the return value.
- **Use the real modules where possible**: drive `Settings`/`Events` through `_G.__stub` + module state (no method overrides → no cross-suite leakage). Only swap `BB.Utils.Timers` for `H.SyncTimers`.
- **Restore everything you mutate**: Settings DB, module state, globals, event bus. A test that doesn't restore WILL break a later test in another suite.

## Gotchas (learned the hard way in ArenaChillPrep — read before writing tests)

1. **luaunit runs tests alphabetically across suites.** A test in one suite can break a test in another. Every test must restore what it mutates.
2. **`Settings:_init` uses `shallowCopy(defaults)` which SHARES nested tables.** Mutating `Settings.Data` corrupts `BB.Data.DefaultSettings` permanently. Settings tests must restore pristine defaults before each test:
   ```lua
   local PristineDefaults = H.deepCopy(BB.Data.DefaultSettings);
   local function freshSettings()
       BB.Data.DefaultSettings = H.deepCopy(PristineDefaults);
       _G.BloomBuddyDB = H.deepCopy(PristineDefaults);
       BB.Settings._initialized = false;
       BB.Settings:_init();
   end
   ```
3. **`Events` and `Frames` share the addon frame's `OnEvent`.** Tests that re-init `Events` must also re-register any other module that hooked the frame.
4. **State fields must be set BEFORE `installStubs()`** — `installStubs` copies State into module state; setting fields after is a no-op.

## Adding a new test suite

1. Create `Tests/<Data|Utils|Classes>/test_<module>.lua` mirroring the addon structure.
2. Add its path to the `suites` list in `Tests/run_tests.lua` (order matters — keep it near its dependency group).
3. Add the module to the luacov `include` list in `run_tests.lua` if it's a new addon module.
4. Run `.\Tests\run-tests.ps1` — must exit 0 (pass + coverage ≥ 90%).
5. If coverage drops below 90%, add tests for the uncovered branches (check `Tests/luacov.report.out` for `*0` lines).

## When a test fails

- Run the failing test in isolation first (set up `package.path`, load stubs, loader, then `dofile` the single suite and `lu.LuaUnit.run('testName')`). If it passes alone, it's cross-suite pollution (see gotchas).
- Check the coverage report for the exact uncovered lines (`*0` prefix).
- Remember: a test that passes in isolation but fails in the full run is ALWAYS cross-suite state pollution — find what the previous alphabetical test left behind.
