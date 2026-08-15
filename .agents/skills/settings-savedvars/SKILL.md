---
name: settings-savedvars
description: Patterns and pitfalls for this addon's settings system (BloomBuddyDB): dot-path get/set, numeric vs string keys, defaults migration. Use whenever touching Settings.lua, DefaultSettings.lua, or reading settings values.
---

# Settings & SavedVariables

## Structure

- Global: `BloomBuddyDB` (SavedVariables in the TOC).
- Access ONLY via `BB.Settings:get(path)` / `:set(path, value)` — never touch `BloomBuddyDB` directly except in `Settings:_init` (which persists `BloomBuddyDB = self.Data`) and inside `setSetting()`.
- Defaults live in `Data/DefaultSettings.lua`; `Settings:_init` does:
  1. `deepMerge(shallowCopy(defaults), BloomBuddyDB or {})` — saved wins;
  2. `ensureDefaults(Data, defaults)` — fills keys MISSING from saved (migration);
  3. `BloomBuddyDB = self.Data` — persist the fixed structure.

## The number-vs-string key trap (IMPORTANT)

In Lua, `[33763]` (number) and `["33763"]` (string) are **different table keys**. Defaults use numeric keys; a naive dot-path get/set builds string segments → reads/writes the STRING key, while defaults sit under the NUMBER key. Symptoms seen live in the sibling addon:
- settings never reflected defaults;
- toggling "didn't save" (wrote the string key; the numeric default stayed).

**Fix (already in `Settings.lua`)**: `normalizeSegment(segment)` converts integer-looking path segments to numbers in BOTH `get` and `set`:
```lua
local function normalizeSegment(segment)
    local n = tonumber(segment);
    if (n and n == math.floor(n)) then return n; end
    return segment;
end
```

**Always use numeric keys in DefaultSettings** (BloomBuddy currently has none — `scale`/`party`/`raid` are all string-keyed — but keep the discipline for the future, e.g. a per-spell scale map keyed by spellID).

## Migration (`ensureDefaults`)

Recursively copies DEFAULT values for keys MISSING from saved data (does NOT overwrite existing values — user choices win):
```lua
function Settings:ensureDefaults(target, defaults)
    for key, defaultValue in pairs(defaults) do
        if (type(defaultValue) == "table") then
            if (type(target[key]) ~= "table") then target[key] = {}; end
            self:ensureDefaults(target[key], defaultValue);
        elseif (target[key] == nil) then
            target[key] = defaultValue;
        end
    end
end
```
This is how new settings (e.g. a future `scale.raid` override) reach users who already have a SavedVariables file.

## Current defaults (v0.1)

```lua
BloomBuddyDB = {
    enabled = true,   -- master switch
    scale   = 1.5,    -- icon size multiplier (baseSize * scale)
    party   = true,   -- scale on party frames
    raid    = true,   -- scale on raid frames
}
```

## Setting values from UI

Slash commands write through `BB.Settings:set` (which persists). A future Interface Options panel will do the same (see `wow-api-20506` for the registration gotchas). All control values must re-sync from Settings when the panel opens.
