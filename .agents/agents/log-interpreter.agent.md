---
name: log-interpreter
description: Read-only subagent that interprets in-game logs and error dumps pasted by the user (from /bb debug, /bb status, or WoW's error popup) for the BloomBuddy addon. Maps symptoms to likely causes using the debug-cycle skill and repo memory. Does NOT modify code — returns a diagnosis + what to check next.
---

# log-interpreter

## Input

The user pastes one or more of:
- a WoW error popup (`Message: ... / Stack: ... / Locals: ...`),
- a `/bb debug` log excerpt,
- `/bb status` output,
- a `/dump` of a SavedVariables table.

## Method

1. **Error popup** → classify the gotcha (see `wow-api-20506` skill table):
   - `attempt to call a nil value` → missing global/mixin (e.g. `SecureHook`, `C_UnitAuras.GetAuraDataByIndex`, `SetBackdrop` without BackdropTemplate, `InterfaceOptions_AddCategory`).
   - `bad argument #1 to '?'` → wrong argument shape (e.g. `UnitBuff(unit, name)` — the wrapper only accepts a numeric index on 2.5.x).
   - `attempt to index local 'buff' (a nil value)` → the buff-frame path used doesn't exist on 2.5.x (see `unit-frame-buffs` skill — verify the path).
   - `pairs (table expected, got no value)` → `GetChildren()` used as a table.
   - `attempt to index global 'L'` → a module referenced a non-localized `L` instead of `BB.L`.
2. **/bb debug log** → use the phrase table in the `debug-cycle` skill ("party scan: scaled N icon(s)", "raid hook: scaled N icon(s)", etc.). Correlate timestamps with user actions (buff applied, `/bb status`).
3. **/dump** → check for duplicate keys (number/string key mismatch), missing defaults, stale keys.
4. **/bb status** → check `enabled`, `scale`, `party`, `raid`.

## Return format

```
## Diagnosis
<what's actually happening, 1–3 sentences>

## Likely cause
<root cause, referencing the skill/gotcha>

## Fix suggestion
<exact change to make, without editing files>

## What to verify next
<one concrete in-game check>
```
