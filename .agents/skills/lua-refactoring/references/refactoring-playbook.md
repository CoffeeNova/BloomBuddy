# Lua Refactoring Playbook

The full catalog of smells and techniques, with before/after examples in Lua 5.1 (WoW addon flavor, matching the workspace module pattern).

## Refactoring Mindset

- One refactor at a time; verify each step.
- Structure changes only — same events, same state, same settings paths, same return values.
- If a step would change behavior, stop and separate it into a feature/bugfix change instead.
- Prefer the simplest construct that is obviously correct. "Clever" Lua hurts both humans and AI readers.

---

## Smell Catalog

### S1. Global pollution
Assignments without `local` leak into `_G` (or the file's environment) — name collisions, state bleed, hard-to-trace bugs.

```lua
-- Bad
total_count = 0  -- global!

-- Good
local total_count = 0
```

### S2. God function / god module
A function > ~30 lines doing several things, or a module that scans frames, sizes icons, and renders UI at once.

**Symptoms**: many `self.` fields mutated in one method, many `and`/`or` chains, several responsibilities in the name.

**Fix**: extract functions (T2), extract modules (T3).

### S3. Arrow code (deep nesting)
More than 3 levels of `if`/`for`. Hard to read; easy to misplace an `end`.

```lua
-- Bad
function apply()
    if enabled then
        if party then
            for member = 1, n do
                if is_lifebloom(member) then
                    resize(member)
                end
            end
        end
    end
end

-- Good (T1 guard clauses)
function apply()
    if not enabled then return end
    if not party then return end
    for member = 1, n do
        if is_lifebloom(member) then resize(member) end
    end
end
```

### S4. Magic numbers and strings
Inline IDs, timings, thresholds with no name.

```lua
-- Bad
C_Timer.After(0.5, recheck)
if spell_id == 33763 then ...

-- Good
local RECHECK_TICK = 0.5  -- or Data/Constants
C_Timer.After(RECHECK_TICK, recheck)
```

### S5. Duplicated logic
The same loop/check copy-pasted in several modules (e.g. buff scans, size computations). One fix site later turns into three.

**Fix**: extract to `Utils/` or a shared helper (T3), then delete the copies.

### S6. Long parameter lists
More than ~4 positional parameters — call sites are unreadable and order mistakes compile silently.

```lua
-- Bad
function scale_icon(icon, base, scale, min, max) ...

-- Good (T5 options table)
---@class ScaleOptions
---@field base number
---@field scale number
---@field min number
---@field max number
function scale_icon(icon, options) ...
```

### S7. Stringly-typed if-chains
`if frame == "party" then ... elseif frame == "raid"` — grows forever, easy to typo.

```lua
-- Bad
if frame_type == "party" then
    self:scale_party()
elseif frame_type == "raid" then
    self:scale_raid()
end

-- Good (T6 table lookup)
local SCALERS = {
    party = function(self) self:scale_party() end,
    raid = function(self) self:scale_raid() end,
}
local scaler = SCALERS[frame_type]
if scaler then scaler(self) end
```

### S8. Primitive obsession
Passing bare strings/numbers where a small structured value communicates intent — e.g. two parallel arrays `{spell_ids}`, `{sizes}` that must stay in sync.

```lua
-- Bad
local ids = {33763, 48450, 48451}
local sizes = {1.5, 1.5, 1.5}  -- must always be edited together

-- Good
---@class SpellSpec
---@field id number
---@field scale number
local spells = {
    { id = 33763, scale = 1.5 },
    { id = 48450, scale = 1.5 },
    { id = 48451, scale = 1.5 },
}
```

### S9. Unclear names
`t`, `tmp`, `hnd`, `cnt`, abbreviations. AI models (and humans) read names as documentation.

**Fix**: intention-revealing names (T8). `local icon_resized = ...` instead of `local rsz`.

### S10. Table key type confusion (Lua-specific, real bug)
`t[33763]` and `t["33763"]` are **different slots**. Classic in WoW SavedVariables: defaults use numeric keys, dot-path setters write strings — the code then reads the other type and gets `nil`.

```lua
-- Bad
settings["33763"] = true   -- string key
if settings[33763] then    -- number key -> nil! silent bug

-- Good
settings[33763] = true     -- numeric key everywhere
if settings[33763] then ...

-- Or normalize once on load:
local function normalize_keys(t)
    for k, v in pairs(t) do
        if type(k) == "string" and tonumber(k) then
            t[tonumber(k)] = v
            t[k] = nil
        end
    end
    return t
end
```

### S11. Dead code
Unused functions, unreachable branches, commented-out blocks, unused parameters. Remove them — the refactor is the cleanup moment.

### S12. Unsafe boolean ternaries
`local ok = cond and x or y` breaks when `x` is `nil`/`false`. Never use it to compute booleans.

```lua
-- Bad
local is_lifebloom = self.spell_id == 33763 and self.aura or false

-- Good
local is_lifebloom = false
if self.spell_id == 33763 and self.aura then
    is_lifebloom = true
end
```

---

## Technique Catalog

### T1. Guard clauses (early return)
Flatten nested conditionals by inverting conditions and returning early. See S3.

- Do this *first* when a function is deeply nested — it unlocks all other extractions.
- Keep the function's public signature identical.

### T2. Extract function
Split a god function into named `local function`s. Place helpers **below** the caller or at the bottom of the module (Lua hoists `local function` within its scope — but only if declared before use at runtime, so put helpers above the first call site or use forward `local f` declarations).

```lua
-- Before: aura check buried inside a big method
if aura and aura.spellId == 33763 then
    resize(icon, base)
end

-- After: named helper with a contract
--- Is the aura at (unit, index) a Lifebloom?
---@param unit string
---@param index number
---@return boolean
local function is_lifebloom(unit, index)
    local aura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL");
    return aura and aura.spellId == 33763 or false;
end
```

- Good extraction boundaries: one clear input → one clear output; no hidden side effects.
- When extracting, move the `---@param`/`---@return` annotations with the code.

### T3. Extract module / move to Utils
Logic reused by several modules belongs in a shared helper.

- Move generic helpers (table ops, size math, timers) to `Utils/`.
- Move a cohesive service (e.g. buff-icon scaling) to its own `Classes/` module.
- In this workspace: update `bootstrap.lua` load order and `.agents/` docs if the file list changes.
- Keep the module API small and stable: few public functions, everything else `local`.

### T4. Extract constants
Replace inline values with named constants — module-local `local` at the top, or `Data/Constants` when shared.

```lua
-- Before
if icon:GetWidth() < 24 then return end
C_Timer.After(0.5, recheck)

-- After
local MIN_ICON_SIZE = 24   -- local when file-private
-- shared: BB.Data.Constants.RECHECK_TICK
if icon:GetWidth() < MIN_ICON_SIZE then return end
C_Timer.After(BB.Data.Constants.RECHECK_TICK, recheck)
```

### T5. Options / parameter table
Bundle long positional parameter lists into a single options table with `or` defaults. See S6.

- Document the table shape with a `---@class` annotation.
- Use `options.delay or DEFAULT` for optional fields; keep required fields positional.

### T6. Table lookup over if-chains
Replace `if/elseif` dispatch on strings with a map from key → handler. See S7.

- Build the map once as a module-level `local` (not per call).
- Fall through gracefully: `local handler = map[key]` then `if handler then handler(...) end`.

### T7. Local aliases for globals
Alias frequently used globals at the top of the file. Faster (no `_G` chain lookup on old clients) and signals dependencies.

```lua
-- Before
if _G.SecureHook then _G.SecureHook("CompactUnitFrame_UpdateBuff", handler) end

-- After
local SecureHook = _G.SecureHook
if SecureHook then SecureHook("CompactUnitFrame_UpdateBuff", handler) end
```

- Guard optional globals: `local SecureHook = _G.SecureHook` — if the global may be missing, check it before calling (verified: some APIs are absent on TBC Anniversary — an unguarded alias becomes `nil` and crashes at call time).
- For APIs that may not exist at all, use call-time shims instead of load-time aliases:

```lua
local function getAuraDataByIndex(unit, index, filter)
    local fn = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex;
    return fn and fn(unit, index, filter);
end
```

### T8. Rename for intention
Make names state *what* the code does:

```lua
-- Bad
local function upd(i, s) i:SetSize(s, s) end

-- Good
--- Resize an icon to a square of `size`.
---@param icon Texture
---@param size number
local function resize_square(icon, size)
    icon:SetSize(size, size)
end
```

- Boolean predicates: `is_lifebloom`, `has_icon`, `can_scale` (T8 with S9).
- Renaming a **public** method/field requires updating every call site — grep for usages first.

### T9. Remove dead code
Delete unused locals/functions, commented-out blocks, and unreachable branches. If a branch is intentionally a no-op ("pass"), keep it with a `-- pass` comment instead of deleting (preserves switch-style case lists).

---

## Verification Checklist

After each refactor step:

1. **Read the changed region** in full. Reading the whole file is cheap and catches context breaks.
2. **Block balance**: every `function`/`if`/`do`/`for`/`while`/`repeat` has its `end`. A quick count of `end` keywords vs opening keywords catches unbalanced blocks.
3. **Module contract intact**: `return BB;` present; `---@class` annotations updated; public names unchanged (or call sites updated).
4. **No behavior drift**: same events fired, same state transitions, same Settings paths, same timings.
5. **Static analysis**: run the **luahelper MCP** check on the changed files — fix real errors/warnings; informational annotation warnings (type 18) are expected and may be left.
6. **Tests**: run sandbox tests if they exist (the `Tests/` harness). Run before and after to prove no behavior change.
7. **Gotchas re-checked**: no `x and y or z` returning booleans, no mixed number/string keys, no `#` on sparse tables, no unguarded globals.
8. If no interpreter is available (common for WoW addons), say verification was manual and list what was checked.

## End-to-End Mini Case

An `apply()` with 4 levels of nesting, inline magic values, and a duplicated aura loop:

1. **T1** guard clauses → flat linear flow.
2. **T4** extract `RECHECK_TICK`, `MIN_ICON_SIZE` → named constants.
3. **T2** extract the aura-check loop → `is_lifebloom(unit, index)` with `---@param`/`---@return`.
4. **T7** alias `SecureHook`/`C_UnitAuras` at the top of the file.
5. **T9** delete the now-unused local that the extraction replaced.
6. **Verify** → read file, balance check, run the `Tests/` harness if available.
