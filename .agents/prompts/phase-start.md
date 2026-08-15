# Phase start prompt

Use this template to begin work on a phase (or major feature) of BloomBuddy in a fresh session. Replace the placeholders in `[...]`.

---

Start **[Phase N — Name]** for the BloomBuddy addon (WoW TBC Anniversary, Interface 20506).

**READ FIRST (in this order):**
1. `AGENTS.md` (repo root) — entry point.
2. `.agents/CONTEXT.md`, `.agents/ARCHITECTURE.md` — source of truth.
3. Repo memory `/.agents/memories/repo/` (main file + gotchas/decisions/phases).
4. The relevant skill(s): `wow-api-20506`, `unit-frame-buffs`, `addon-research`, `debug-cycle`, `settings-savedvars`, `phase-workflow` (and `lua-refactoring` for code cleanup).

**Context (already done, phases 0 done and verified):**
- Addon: enlarges the Lifebloom buff icon on party and raid frames. v0.1: party + raid, default scale 1.5×.
- Stack: Lua 5.1, no libraries, one global `BB`, modules via vararg ending in `return BB;`.
- Key mechanics (2.5.5): buff detection via `C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")` → `.spellId`; raid hook on `CompactUnitFrame_UpdateBuff`; party frames `PartyMemberFrame1..4` (buff paths to be verified in game); Lifebloom spell IDs `33763`/`48450`/`48451` (to verify); named timers via `BB.Utils.Timers`.
- Gotchas (2.5.5): see `wow-api-20506` skill — do NOT use `UnitBuff(name)`, `UnitAura(...)` positional, bare `GetContainerNumSlots`, `InterfaceOptions_AddCategory`, or `pairs(frame:GetChildren())`; `C_Timer` `Cancel()` is unreliable.

**This phase's tasks:** [paste the phase's tasks]

**Definition of Done:** [paste the phase's Definition of Done]

**Workflow:**
1. Follow the `phase-workflow` skill: contract-first, todo list, implement per conventions, update `.agents/` first when behavior changes, update repo memory.
2. Verify: no editor errors; run `tools/vararg-check.ps1` (and `tools/syntax-check.ps1` if a Lua interpreter is available).
3. Finish with: list of changed/created files, in-game verification steps (exact commands + expected output), and any expectations/limitations.

Begin by reading the contract files and showing a short plan, then implement.
