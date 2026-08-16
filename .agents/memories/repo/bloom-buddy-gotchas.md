# BloomBuddy — gotchas (verified on the client)

Client-verified pitfalls for the WoW TBC Anniversary (Interface 20506 / 2.5.x) client. These are ALSO mirrored in `.agents/skills/wow-api-20506/SKILL.md` and `.agents/skills/unit-frame-buffs/SKILL.md` — keep all three in sync.

## Settings window templates (2026-08-16, read from working addons)

- **`UIPanelDialogTemplate`** — proven by OmniCC_Config `preview.lua:19`. **NAME the frame** (`CreateFrame("Frame", "Name", UIParent, "UIPanelDialogTemplate")`): the template children use `$parent`-based names (e.g. `$parentTitleBG`), an unnamed frame risks bad/empty globals. OmniCC names its dialog. **`<name>TitleBG` really exists on this client** — OmniCC anchors its drag area via `PreviewDialog:GetName() .. "TitleBG"` (preview.lua:51). OmniCC also calls `EnableMouse(true)` explicitly on its dialog — do the same if the window must receive mouse (OnMouseDown drag).
- **`UIPanelDialogTemplate` DOES ship a built-in close button — but it is NOT reliably
  reachable via `$parentCloseButton`** (round-2 evidence 2026-08-17: `_G["<name>CloseButton"]`
  came back nil while a second X was still visible → two overlapping X's again). **Robust
  pattern: enumerate `window:GetChildren()` right after `CreateFrame`, BEFORE creating any
  of our own buttons** — the first `Button` child IS the template's close button; reuse it,
  hide any further Button strays, create our own `UIPanelCloseButton` only if none found.
  Reposition explicitly + `Enable()` + `OnClick` + `Show()` → exactly one X, always.
  (Round-1 report 2026-08-16: creating our own button while the template's exists also
  produced two overlapping X's.) Anchor the window title to `$parentTitleBG`'s CENTER (the title band; OmniCC references `$parentTitleBG` too).
- **`OptionsSliderTemplate`** — creates `<name>Low`/`<name>High` FontStrings (LoseControltbc_anni sets them via `_G[name .. "Low"]`/`"High"]`) but **NOT `<name>Text`** — the label is a manual FontString. `SetValueStep` works; `OnValueChanged(self, value)` fires on `SetValue` too — guard with a `_syncing` flag.
- **`UICheckButtonTemplate`** — unnamed creation is safe (AtlasLootClassic does it); labels are manual FontStrings (`SetPoint("LEFT", check, "RIGHT", 6, 0)`). `SetChecked` does NOT fire `OnClick`.
- **`UIPanelCloseButton` / `UIPanelButtonTemplate`** — need an explicit `OnClick` (Leatrix_Maps); template-based buttons should be named.
- **`GameTooltip:AddLine(text, r, g, b)`** — works on this client (NovaWorldBuffs); one AddLine per line.

## Compact-frame buff icons are C-rendered (2026-08, verified)

- Native buff icons on compact frames (raid + raid-style party) are drawn by the game engine — there is **no Lua-accessible per-buff icon** to `SetSize` and **no `buffFrames` array**.
- **Per-buff hiding is impossible.** The only hide lever is all-or-nothing (`raidFramesDisplayBuffs` CVar / "display buffs" frame option). SweepyBoop uses the CVar on retail only; on TBC it draws overlays and leaves native buffs on.
- `frame.auraSize` scales ALL buffs+debuffs of a member uniformly; it is often nil until an addon writes it; the C layout only re-reads it on a full `CompactUnitFrame_UpdateAll`. Do NOT use it to highlight one buff.

## Hook points (2026-08, verified)

- `CompactUnitFrame_UpdateBuff` — **does not exist** on this client (zero references in installed addons; the contract originally assumed it — WRONG).
- `CompactUnitFrame_UpdateAuras` / `CompactUnitFrame_UpdateDebuffs` — absent on 2.5.6 (classic-era functions; BigDebuffs guards them with `type(...) == "function"`).
- **`CompactUnitFrame_UpdateAll(frame)`** — the real per-frame hook; fires for every compact party/raid frame on setup/reuse. Used by SweepyBoop (`hooksecurefunc`) and BigDebuffs on this client.
- Unit per frame: `frame.displayedUnit or frame.unit`.

## Auras

- `UnitBuff(unit, name)` crashes; `UnitAura(unit, i, filter)` returns shifted legacy positions. Use `C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")` → `.spellId`.
- **Stack count is `.applications`** on this client (BigDebuffs `aura.applications or aura.charges or 0`, BetterBlizzFrames, ArenaAnalytics). **`.count` is NOT the field** — BloomBuddy's first version read `.count` and always got nil (stacks never displayed; fixed).
- The same aura object carries `.duration` and `.expirationTime` — drive the cooldown swipe with `expirationTime - duration`.
- Lifebloom ranks: `33763` (R1) — **VERIFIED in game**; `48450` (R2), `48451` (R3) — unlearned on tester, keep in list, confirm on a max-rank Druid.
- Secret/restricted auras (PvP) can return nil or sentinel values for applications/expirationTime — guard with `tonumber`/`> 0` so text stays blank and the swipe clears (BigDebuffs uses `IsSecretValue`).

## Remaining-time swipe + overlay text

- **Cooldown swipe (default):** native `Cooldown` widget child of the overlay, created **with the `"CooldownFrameTemplate"`** — REQUIRED for the swipe texture on this client (BigDebuffs, ClassicAuraDurations, SweepyBoop all use it). A bare `CreateFrame("Cooldown")` runs the sweep invisibly (our round-4 bug: `/bb debug` showed `sweep=Y dur=7000` but nothing rendered). **`SetReverse(true)` is REQUIRED for the correct direction** — the default sweeps backwards (icon LIGHTENS instead of darkening; round-5 user feedback; every working addon sets it). `CooldownFrame_Set(cd, expirationTime - duration, duration, true)` when `duration > 0` AND `expirationTime - GetTime() > 0` AND **`showSwipe` is on** (settings window "Clockwise darkening" — off → `CooldownFrame_Clear` + hide, plain icon only), else `CooldownFrame_Clear` + hide. Configure `SetAlpha(1)`, `SetSwipeColor(0,0,0,0.7)`, `SetDrawEdge(false)`, `SetDrawBling(false)`, `SetHideCountdownNumbers(true)`. The client animates the darkening sweep itself — re-`Set` on each 0.5 s refresh just keeps it in sync; no Lua timer.
- **Countdown add-ons (OmniCC) hijack the swipe (VERIFIED 2026-08-15).** OmniCC is installed on the tester's client and draws its own numbers on every active `Cooldown` widget — the tester saw "OmniCC-style" countdown numbers that the addon's own `/bb timer` toggle could not hide. **Fix: `cooldown.noCooldownCount = true`** — OmniCC's `CanShowText`/`CanShowFinishEffect`/`OnCooldownDone` all bail on `self.noCooldownCount`. It is the reliable opt-out (stronger than `SetHideCountdownNumbers`, which OmniCC also hooks).
- **Show the overlay before driving the cooldown.** `overlay:Show()` then `CooldownFrame_Set` (the C-side sweep initializes while the widget is visible); the original order (set while the overlay was hidden) is a suspect for the swipe not rendering.
- **`/bb debug` dumps overlay state** (positions, cooldown widget + `GetCooldownTimes`, stacks/timer text + anchors, raw aura fields) — the in-game diagnostic to run before trusting placement/swipe behavior. The per-tick `compact scan` debugPrint was REMOVED (flooded chat every 0.5 s and scrolled the dump away).
- **Digital countdown (opt-in):** `timer` FontString renders only when `showTimer` is on (`/bb timer`, default false); "N" under 60 s, "m:ss" above.
- Stack text hidden at count ≤ 1 (standard buff UX — user confirmed).
- The 0.5 s safety ticker already re-runs `apply()` → `updateFrame` while enabled, refreshing swipe/text every 0.5 s.

## Timers

- `C_Timer` handle `Cancel()` is unreliable — a "cancelled" timer can still fire (verified 2026-08-10 in ArenaChillPrep). Always use `BB.Utils.Timers` (named entries with an `active` flag).

## Ticker lifecycle

- The 0.5 s safety ticker was originally only started at load; `/bb enable` after a load-while-disabled never started it. Fixed: `Frames:ensureTicker()` / `Frames:stopTicker()` driven by `_init` + `/bb enable`/`/bb disable` + `apply()`.
