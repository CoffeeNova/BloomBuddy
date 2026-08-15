# BloomBuddy — Agent Instructions

This file is the **entry point** for AI agents working in this repository.

Everything an agent needs — project context, architecture, as well as skills, agents and instructions — lives in the **`.github/`** directory. It is the single source of truth.

## Reading order

1. `.github/CONTEXT.md` — what the addon does, code conventions, key mechanics & gotchas, proven patterns, settings reference
2. `.github/ARCHITECTURE.md` — module design, data flow, edge cases, ADR decisions
3. `.github/skills/wow-api-20506/SKILL.md` — **before writing/fixing any WoW API call**: verified client gotchas & patterns (many APIs crash or return shifted data on 2.5.5)
4. `.github/skills/unit-frame-buffs/SKILL.md` — **before touching the core feature**: verified/researched patterns for enlarging buff icons on party and raid frames

## Rules

- Follow everything in `.github/`. It is the source of truth.
- When the design or plan changes, update the files in `.github/` **first** — they are the contract.
- `README.md` at the repo root is for **human users** — do not treat it as technical documentation.
- All documentation and code in this workspace must be written in English.
- **Contract-first, memory-last**: update `.github/` before code; record outcomes in `/memories/repo/` after.
- **Static analysis**: every Lua file is analyzed for **errors and warnings** with the **luahelper MCP** server before it is considered done (see `.github/CONTEXT.md`).

## Skills (`.github/skills/`)

| Skill | When to use |
|---|---|
| `wow-api-20506` | Any WoW API call: verified gotchas (crashes/shifted APIs) + working patterns for this client |
| `unit-frame-buffs` | The core feature: detecting a specific buff (Lifebloom) and resizing its icon on party/raid frames |
| `addon-research` | Researching API behavior in working addons (workspace search does NOT index the WoW AddOns folder — path from `.env` `addons_path_anniversary`) |
| `debug-cycle` | Silent failures (no Lua error): debugPrint, TEMP diagnostics, log reading, cleanup |
| `settings-savedvars` | Settings/`BloomBuddyDB`: dot-path get/set, numeric-vs-string keys, migration |
| `phase-workflow` | End-to-end phase/feature workflow (contract-first, todo, verify, document, hand back) |
| `lua-refactoring` | Refactoring/cleanup/restructuring of Lua files |
| `unit-testing` | Writing/running the unit tests (luaunit + luacov under LuaJIT): runner, stubs, suite layout, AAA conventions, cross-suite gotchas |

## Agents (`.github/agents/`)

- `bloom-developer` — main agent for any phase/feature/bugfix (startup ritual + rules + output format).
- `wow-api-researcher` — research-only subagent: answers API questions with evidence from working addons.
- `log-interpreter` — read-only subagent: interprets pasted logs/error dumps → diagnosis + next check.

## Prompts (`.github/prompts/`)

- `phase-start.md` — template to begin a phase in a fresh session (context + tasks + DoD + workflow).
- `debug-report.md` — structured request for an in-game debug log from the user.
- `ui-review.md` — structured UI review request (section-by-section, so layout fixes are precise).

## Tools (`.github/tools/`)

- `research.ps1` — search working addons via PowerShell `Select-String` (workspace search misses the WoW AddOns folder; path from `.env` `addons_path_anniversary`).
- `vararg-check.ps1` — every `.lua` ends with `return BB;` + TOC load-order check.
- `syntax-check.ps1` — `luac/luajit -p` syntax check (requires a Lua interpreter; LuaJIT is installed via winget).
- `load-env.ps1` — loads `.env` (machine-specific paths, e.g. `addons_path_anniversary`) into the session.
- `deploy.ps1` — copies only the game artifacts (TOC + files it references + LICENSE) to `addons_path_anniversary`, or builds a release zip (`-Bundle`) for CurseForge/CI.

## Static analysis (luahelper MCP)

- All Lua code is analyzed for **errors and warnings** with the **luahelper MCP** server.
- While editing a file: `luahelper_check_lua_file <absolute path>`. Before finishing a phase/feature: `luahelper_check_lua_project <repo root>`.
- Fix all real errors/warnings. Informational annotation warnings (type 18, `---@class`/`---@type` underlines) are expected workspace noise in this repo — do not churn code to silence them (see `.github/CONTEXT.md`).

## Local development environment (`.env`)

Machine-specific paths live in `.env` at the repo root (copy `.env.example` → `.env`, fill in the values). The WoW TBC Anniversary client with its addons is NOT part of this repo — it lives wherever `addons_path_anniversary` points (e.g. `G:\games\World of Warcraft\_anniversary_\Interface\AddOns`). Scripts and docs read that variable instead of hardcoding a path.

## Unit tests (`Tests/` — planned)

- The addon mirrors the test harness proven in the sibling workspace `ArenaChillPrep`: `Tests/` runs **outside the game** under LuaJIT (luaunit + luacov + WoW stubs), target **≥ 90%** coverage of non-UI modules.
- The suite does NOT exist yet — it is Phase 3 of the development plan (`.github/docs/addon-v1-development-plan.md`).
- Before writing or running tests, read the `unit-testing` skill (`.github/skills/unit-testing/SKILL.md`).

## Why this repo looks the way it does

This repository is a lean, adapted port of the development toolkit proven in the sibling addon **ArenaChillPrep** (same client, same module conventions). The `.github/` library, the `Data/Utils/Classes` split, the `BB` vararg chain and the tooling are intentionally shared patterns — keep them consistent when you extend this addon.
