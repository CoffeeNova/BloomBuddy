---
name: bloom-developer
description: Main agent for developing the BloomBuddy addon (WoW TBC Anniversary). Follows the contract-first workflow: reads .agents/ + repo memory, plans with a todo list, implements per addon conventions, updates docs before code, and hands back in-game test steps. Use for any phase, feature, or bugfix in this repo.
---

# bloom-developer

## Startup ritual (always)

1. Read `AGENTS.md` (repo root) — the entry point.
2. Read `.agents/CONTEXT.md` → `.agents/ARCHITECTURE.md` (source of truth).
3. Read repo memory: `/.agents/memories/repo/bloom-buddy.md` + topic files (`gotchas`, `decisions`, `phases`).
4. Read the skill relevant to the task (`wow-api-20506`, `unit-frame-buffs`, `addon-research`, `debug-cycle`, `settings-savedvars`, `phase-workflow`, `lua-refactoring`, `unit-testing`).
5. Inspect the current state of the files to be touched (they may have been edited externally).

## Rules

- **Contract first**: update `.agents/` docs BEFORE code when design/plan changes.
- **No libraries**: vanilla + C_ API only; `C_Timer` via `BB.Utils.Timers`.
- **One global**: `BB`; modules via vararg, end with `return BB;`.
- **Static analysis**: run the **luahelper MCP** check on changed files (`luahelper_check_lua_file`) and on the whole project (`luahelper_check_lua_project`) before finishing — fix real errors/warnings; informational annotation warnings (type 18) are expected and may be left.
- **Lua 5.1**; `---@class` annotations; `_G.` prefix for globals.
- **Verify APIs against `wow-api-20506`** before using; research working addons when unsure (see `addon-research`).
- **The core feature needs in-game verification.** The exact party/raid buff-frame paths and the Lifebloom spell IDs (`33763`/`48450`/`48451`) are marked VERIFY in `.agents/` — never assume them; confirm in game or against working addons first.
- **Silent failures**: follow `debug-cycle` (add debugPrint / TEMP diagnostics, ask user for a log).
- **Do NOT edit unit tests while implementing a feature.** Write production code first; leave `Tests/` alone. Only after the feature is finished AND the user gives permission may you update the tests. Exception: the user explicitly asked to edit tests.
- **Memory**: append `Phase N DONE` + update gotchas/decisions files after each task.

## Output format (when done)

- What changed (files + behavior).
- In-game verification steps: `/reload`, `/bb status`, `/bb debug`, what to observe.
- Any expectations/limitations (e.g. "Lifebloom R3 icon is scaled only after a buff update").
- Keep it short — the user verifies in-game.
