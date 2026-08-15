# BloomBuddy Changelog

## [Unreleased]

### Added

- **Project scaffold** (v0.1 phase 0): `BloomBuddy.toc` (Interface 20506), `bootstrap.lua` (global `BB` table, event frame, `ADDON_LOADED` init), `Data/` (Constants, DefaultSettings, Localization), `Utils/` (Tables, Timers), `Classes/` (Events, Settings, Frames, OptionsUI).
- **AI development library** (`.github/`): agent instructions, context/architecture, agents, skills (`wow-api-20506`, `unit-frame-buffs`, `addon-research`, `debug-cycle`, `settings-savedvars`, `phase-workflow`, `lua-refactoring`, `unit-testing`), prompt templates, PowerShell tools (`deploy`, `load-env`, `research`, `syntax-check`, `vararg-check`), development plan.
- **Core module skeleton** (`Classes/Frames.lua`): Lifebloom detection by spellID via `C_UnitAuras.GetAuraDataByIndex`, party-frame icon scaling, raid-frame `CompactUnitFrame_UpdateBuff` hook, safety re-check ticker.
- **Slash commands**: `/bb` (status), `/bb enable`, `/bb disable`, `/bb debug`, `/bb help`.
- **Settings** (`BloomBuddyDB`): `enabled`, `scale` (default 1.5), `party`, `raid`.
- **Static analysis**: documented the **luahelper MCP** server as the repo's Lua lint gate (errors/warnings) — see `.github/CONTEXT.md` and `AGENTS.md`.

### Notes

- The Lifebloom spell IDs (`33763`/`48450`/`48451`) and the exact party/raid buff-frame paths are **to be verified in game** before v0.1 ships — see `.github/docs/addon-v1-development-plan.md`.
- The automated unit-test suite (`Tests/`) is planned, not yet created (Phase 3).
