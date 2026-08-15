---
name: wow-api-20506
description: Verified knowledge base for the WoW TBC Anniversary client (Interface 20506 / build 2.5.x). Use whenever writing, fixing, or debugging WoW API calls in this addon — it lists the APIs that crash, the APIs that return shifted data, and the shims/patterns that are proven to work on this exact client.
---

# Wow API — TBC Anniversary (20506)

**Client:** WoW TBC Anniversary, build 2.5.x (the user's client prints `2.5.6 The Burning Crusade`). This client is a hybrid: it backports many modern `C_*` APIs but keeps some broken legacy wrappers. Do NOT assume a function behaves like retail OR like classic TBC — verify against this list, then against a working addon if unsure.

## The #1 rule

If a WoW API call errors or returns nonsense on this client, **check this list first**, then look at a **working addon** (see the `addon-research` skill) before inventing a workaround. Almost every "impossible" bug in this workspace was already solved by Gargul / sArena_Reloaded / BigDebuffs / WeakAuras / OmniCD / BuffSizeShifter / LunaUnitFrames running on the same client.

**But absence is evidence too** if NO working addon implements a feature, the honest conclusion is usually that the client does not allow it. Do NOT keep searching for a pattern that does not exist; conclude "impossible on this client" and report it. Never repeat the same search query in one session — after 2 failed attempts, stop and synthesize.

## Verified gotchas (all confirmed live in the sibling addon ArenaChillPrep)

| API | What happens | Working alternative |
|---|---|---|
| `UnitBuff(unit, "name")` | **CRASHES** — the deprecated wrapper proxies to `C_UnitAuras.GetBuffDataByIndex(unit, index[, filter])` which only accepts a NUMERIC index | `C_UnitAuras.GetAuraDataByIndex(unit, index, filter)` → aura object with `.spellId/.name/.expirationTime/...`; for the player: `C_UnitAuras.GetPlayerAuraBySpellID(spellID)` |
| `UnitAura(unit, i, filter)` | Returns **SHIFTED legacy positions** — live dump: value #6 was `sourceUnit`, #10 was `isBossAura`; real spellID/expirationTime never captured | `C_UnitAuras.GetAuraDataByIndex(unit, i, filter)` → object |
| `GetContainerNumSlots(bag)` | **NOT a global** — only `C_Container.GetContainerNumSlots` exists; calling the global → "attempt to call a nil value" | call-time shim: `_G.GetContainerNumSlots or (C_Container and C_Container.GetContainerNumSlots)` |
| `GetContainerItemInfo(bag, slot)` | Not a global; `C_Container.GetContainerItemInfo` returns an **object** (not 11 positional values) | shim unpacks `info.stackCount, info.isLocked, ...` (11th = `info.isBound`) |
| `C_Item.GetItemGUID(bag, slot)` | **CRASHES** — takes an `ItemLocation`, not `(bag, slot)` | `ItemLocation:CreateFromBagAndSlot(bag, slot)` → `C_Item.GetItemGUID(location)` |
| `InterfaceOptions_AddCategory` | **NIL** on 2.5.5 — the legacy settings API is gone | `Settings.RegisterCanvasLayoutCategory` + `Settings.RegisterAddOnCategory`; subcategories via `Settings.RegisterCanvasLayoutSubcategory(parentCategory, frame, title)` |
| `frame:GetChildren()` | Returns **multiple values, not a table** — `pairs(frame:GetChildren())` → "bad argument to pairs" | wrap: `for _, child in ipairs({ frame:GetChildren() })` |
| `OptionsSliderTemplate` | Does **NOT** create a global `"<name>Text"` (unlike `UICheckButtonTemplate`) | create the label yourself: `parent:CreateFontString(...)` |
| `CreateFrame("Frame", ...)` + `SetBackdrop` | `SetBackdrop` is **nil** unless the frame is created with the `"BackdropTemplate"` mixin | `CreateFrame("Frame", nil, parent, "BackdropTemplate")` |
| `CLASS_*` constants | **NOT defined** on TBC FrameXML — `[CLASS_DRUID] = ...` throws "table index is nil" | `local CLASS_DRUID = _G.CLASS_DRUID or "DRUID"` |
| SavedVariables numeric keys | `[33763]` (number) and `"33763"` (string) are **DIFFERENT table keys** — dot-path get/set with string segments hit the string key while defaults use numeric | `Settings:normalizeSegment()` converts integer-looking path segments to numbers |
| `C_Timer` handle `Cancel()` | **UNRELIABLE — a "cancelled" timer can still fire** (verified live 2026-08-10: a cancelled timer fired after the event it was meant to be cancelled by) | named timers with an `active` flag (`BB.Utils.Timers`) — `handle:Cancel()` is best-effort only |
| `CompactUnitFrame_UpdateBuff` | **NOT hookable on TBC 2.5.6** — the function does not exist (zero references in installed addons; the C-rendered auras skip the Lua buff pipeline). `CompactUnitFrame_UpdateAuras`/`buffFrames` are also absent on 2.5.6 | the real per-frame hook is **`CompactUnitFrame_UpdateAll(frame)`** (fires per compact frame on setup/reuse; used by SweepyBoop + BigDebuffs on this client) |
| Compact-frame buff icons | **C-rendered on 2.5.6** — no Lua-accessible per-buff icon to `SetSize`, no `buffFrames` array, **no per-buff hide filter** (you can only hide ALL buffs via `raidFramesDisplayBuffs` CVar / "display buffs" option, all-or-nothing) | draw a **custom overlay icon** on the frame (SweepyBoop pattern): child frame + texture, unit from `frame.displayedUnit or frame.unit`, detect by spellID via `GetAuraDataByIndex` |
| `frame.auraSize` (compact frames) | Scales **ALL** buffs+debuffs of a member uniformly; often nil until an addon writes it; the C layout only re-reads it on a full `CompactUnitFrame_UpdateAll` | do NOT use it to single out one buff — that is not possible |

## Verified working patterns

### Buff detection (this addon's core)
```lua
local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL");  -- index = 1-based
if (aura and aura.spellId == 33763) then ... end                      -- .spellId/.name/.icon/.expirationTime
```
- Filter strings: `"HELPFUL"` (buffs), `"HARMFUL"` (debuffs), `"PLAYER"`, `"RAID"`, etc. — the standard filter.
- `C_UnitAuras.GetPlayerAuraBySpellID(spellID)` returns the player's own aura object (or nil).

### Hook a global function safely (SecureHook)
`SecureHook` is available on 2.5.x (secure templates exist). Prefer it over wrapping, but guard for environments without it:
```lua
local SecureHook = _G.SecureHook;
if (SecureHook) then
    SecureHook("CompactUnitFrame_UpdateBuff", afterHandler);
else
    local orig = _G.CompactUnitFrame_UpdateBuff;
    _G.CompactUnitFrame_UpdateBuff = function(...)
        local a, b, c, d, e, f = orig(...);
        afterHandler(...);
        return a, b, c, d, e, f;
    end;
end
```

### Feature detection
Guard everything modern with `_G.X or (C_X and C_X.Y)` — never assume a global exists.

### Call-time shims (resolve at call time so sandbox tests can stub)
```lua
local function getAuraDataByIndex(unit, index, filter)
    local fn = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex;
    return fn and fn(unit, index, filter);
end
```

## Unit frame buffs (the core feature — see the `unit-frame-buffs` skill)

- **Compact frames (raid + raid-style party) on 2.5.6:** native buff icons are **C-rendered** — no
  Lua-accessible per-icon to resize, no per-buff hide. Real hook point: `CompactUnitFrame_UpdateAll`.
  Frame names: `CompactPartyFrameMember<N>` / `CompactRaidFrame<N>`; unit via
  `frame.displayedUnit or frame.unit`. Show a custom overlay icon (SweepyBoop pattern).
- **Matching:** by **spellID** via `GetAuraDataByIndex(unit, i, "HELPFUL")`; iterate until nil.
- **Overlay:** child frame + one texture (`GetSpellTexture` / the Lifebloom texture), sized
  `OVERLAY_BASE_SIZE * scale`, cached on the compact frame.
- **Classic party frames (`PartyMemberFrame1..4`):** not the v0.1 target; icons there are
  classic-era Lua frames (`.BuffFrame.Buff<N>.Icon`), a `SetSize` path is future work.

## References to consult when unsure
- `sArena_Reloaded/` — aura iteration, buff detection, compact raid frame interaction (same client, proven)
- `BigDebuffs/`, `OmniCD/`, `WeakAuras/` — aura object fields, `AuraUtil.ForEachAura`
- `BuffSizeShifter/`, `LunaUnitFrames/`, `ShadowedUnitFrames/` — enlarging/sizing buff icons on party/raid frames
- `Auctionator/`, `MiniFramework/`, `BetterBlizzFrames/` — settings/subcategory registration
- `Questie/Database/Classic/` and `TBC/tbcItemDB.lua` — item ID/name verification

See `Data/Constants.lua`, `Classes/Frames.lua`, `Classes/Settings.lua` for live examples of every pattern above.
