# BloomBuddy — Phase: Settings UI Window

> Phase plan for the settings window (a sub-phase of Phase 3 in `addon-v1-development-plan.md`).
> Contract-first: `.agents/CONTEXT.md` + `ARCHITECTURE.md` are updated BEFORE code (see the
> `phase-workflow` skill). This file is the task list + Definition of Done for this phase.

**Goal:** a minimal Blizzard-style settings window, opened with `/bb options` (lazy creation
on first use). No Interface Options panel, no Ace — vanilla widgets only.

---

## Design (client-verified patterns)

- **Window:** `CreateFrame("Frame", "BloomBuddyOptionsFrame", UIParent, "UIPanelDialogTemplate")`.
  - The template pattern is proven on this client (OmniCC_Config `preview.lua:19`). OmniCC NAMES
    its dialog frame — the `UIPanelDialogTemplate` children use `$parent`-based names (e.g.
    `$parentTitleBG`), so an unnamed frame risks bad/empty global names. **Deviation from the
    original sketch (`nil` name): the window IS named** (also gives `/dump` access).
  - `SetAlpha(0.9)` (90 % opaque), `SetClampedToScreen(true)`, `SetMovable(true)`,
    `SetToplevel(true)`, drag via `OnMouseDown` → `StartMoving()` / `OnMouseUp` →
    `StopMovingOrSizing()`.
- **Close:** the `UIPanelDialogTemplate` DOES ship its own close button on this
  client — but it is **NOT reliably reachable via the `$parentCloseButton`
  global** (round-2 feedback 2026-08-17: `_G["<name>CloseButton"]` came back nil
  while a second X was still visible → two overlapping X's again). **Robust
  pattern: enumerate the window's children** (`window:GetChildren()`) right after
  `CreateFrame`, BEFORE creating any of our own buttons — the first `Button`
  child found IS the template's close button. Reuse it, hide any further Button
  strays, and create our own `UIPanelCloseButton` only when the template has
  none. Reposition explicitly (`TOPRIGHT` of the window, `(2, -2)`), set
  `OnClick` → `window:Hide()`, `Enable()` + `Show()`. **Exactly ONE close button,
  always.** (Round-1 feedback 2026-08-16: creating our own button while the
  template's exists produced two overlapping X's.)
- **Help:** small "?" button (named, `UIPanelButtonTemplate`) in the window's TOP-LEFT
  area, anchored to the WINDOW `TOPLEFT (CORNER_INSET, -CORNER_INSET)` with
  `CORNER_INSET = 10` — the button's 24×24 background must be **fully inside the
  template's border ring** (≈10 px thick on this client; calibrated by OmniCC_Config's
  content inset `TOPLEFT (10, -27)`). NOT anchored to the title band (its left edge can
  sit inset — round-3) and NOT flush to the corner (that overlaps the border ring —
  round-4 feedback 2026-08-17). The 10 px inset mirrors the X's visually rendered
  position (32 px button at `TOPRIGHT (2,-2)` → glyph ≈10 px from the edges): same
  horizontal inset, same vertical level, same distance from the title bar's top edge.
  `GameTooltip` (`OnEnter`: `SetOwner(self, "ANCHOR_RIGHT")`, one `AddLine` per `/bb`
  command; `OnLeave`: `Hide()`).
- **Title:** the window title FontString is centered on `$parentTitleBG`'s CENTER
  (the template's title band) — the band exists on this client (OmniCC references
  `$parentTitleBG`). Fallback: `TOP (0, -18)`.
- **Layout constants:** `CONTENT_TOP_PADDING` (window TOP →
  first slider **LABEL** TOP, clears the title band), `ROW_GAP` (**ONE uniform
  vertical gap between every adjacent row** — revised 2026-08-17 from feedback:
  spacing was uneven 24/24/32/24/6), `BOTTOM_PADDING`. Slider rows are
  label + gap + slider; the next row anchors to the previous row's BOTTOM with
  `ROW_GAP` after the row's own label, so every visual gap equals `ROW_GAP`
  exactly. `WINDOW_HEIGHT` is **computed** from the constants (3 slider rows +
  2 checkbox rows + Reset + 5 × `ROW_GAP`) so the layout always fits — 327 px
  with the current values.
- **Element order (top → bottom):** title bar (title + "?" + one close) → three
  centered sliders (Icon size, Position X, Position Y, labels above) → two centered
  checkboxes (Clockwise darkening, Show remaining time; label right of the check,
  block centered via `GetStringWidth`) → centered `Reset to defaults` at the bottom.
  Every adjacent row is separated by the same `ROW_GAP`.
- **Reset:** `UIPanelButtonTemplate` → `BB.Settings:reset()` +
  re-sync controls + `BB.Frames:checkNow()` + chat confirmation. Anchored `TOP` to the
  last checkbox's BOTTOM with x-offset **`+checkBlockHalfWidth(timerCheck)`**: the
  checkbox's own CENTER is offset by the label-compensation (the block is centered, not
  the box), so a plain x=0 anchor drifted the button left of the window axis (round-3
  feedback 2026-08-17). The +offset moves it to the block's center = the window axis.
  Vertical position unchanged.
- **Sliders** (`OptionsSliderTemplate` — named; the template DOES create `<name>Low`/`<name>High`
  but NOT `<name>Text` on this client — LoseControltbc_anni comments out the Text line; label
  FontStrings are created manually, per the `wow-api-20506` skill):
  - "Icon size": 1.0–3.0, step 0.1 → `Settings:set("scale", value)` + `Frames:checkNow()` (live).
  - "Position X": −40..40, step 1 → `Settings:set("overlayPosX", value)` ONLY (no apply —
    stub). Tooltip on hover: "Not implemented yet".
  - "Position Y": −40..40, step 1 → `Settings:set("overlayPosY", value)` ONLY (no apply —
    stub). Tooltip on hover: "Not implemented yet".
  - `OnValueChanged` also fires from `SetValue` (sync) — guard with a `_syncing` flag.
- **Checkboxes** (`UICheckButtonTemplate`, manual label FontStrings — AtlasLootClassic pattern):
  - "Clockwise darkening" → `Settings:set("showSwipe", ...)` + `Frames:checkNow()` (live).
  - "Show remaining time" → `Settings:set("showTimer", ...)` + `Frames:checkNow()` (live).
- **sync():** on every open, controls read current values from `BB.Settings`
  (`scale`, `overlayPosX`, `overlayPosY`, `showSwipe`, `showTimer`).
- **Command:** `/bb options` toggles the window (show/hide). `help` lists it.

## Settings added (this phase)

```lua
showSwipe   = true,  -- functional: native cooldown swipe on the overlay (false → clear+hide, icon only)
overlayPosX = 0,     -- stub: persisted, NOT applied yet (future overlay repositioning)
overlayPosY = 0,     -- stub: persisted, NOT applied yet (future overlay repositioning)
```

Migration: automatic via the existing `deepMerge` + `ensureDefaults` in `Settings:_init` —
new keys appear for users with an existing `BloomBuddyDB`.

## Tasks

1. Update the contract FIRST: `CONTEXT.md` (settings block, slash-command table, status line),
   `ARCHITECTURE.md` (`2.5 OptionsUI` section + ADR entry), `addon-v1-development-plan.md`
   (Phase 3 record: settings window done).
2. `Data/DefaultSettings.lua` — add `showSwipe` / `overlayPosX` / `overlayPosY`.
3. `Classes/Settings.lua` — `Settings:reset()` (restore defaults + persist).
4. `Classes/Frames.lua` — `updateOverlay`: `showSwipe = false` → `CooldownFrame_Clear` +
   hide, skip `CooldownFrame_Set` (only functional core change). `/bb debug` settings line
   gains `showSwipe`.
5. `Data/Localization.lua` — new enUS + ruRU strings (window, labels, tooltips, reset message;
   `status`/`help` gain `options` + `swipe`).
6. `Classes/OptionsUI.lua` — the window + `/bb options`.
7. `BloomBuddy.toc` — NO change (no new files).
8. Verify: `vararg-check.ps1`, `syntax-check.ps1`, luahelper MCP (file + project).
9. Deploy: `deploy.ps1` → in-game check; `deploy.ps1 -Bundle` → `dist/` zip.
10. Memory: append phase record to `.agents/memories/repo/`.

## Definition of Done

- `/bb options` opens the window (90 % opaque); it drags, clamps to screen, closes via the X.
- Exactly ONE close button (the template's built-in, found via child enumeration), title + "?" + close all inside the title bar, no overlaps.
- Help "?" shows a tooltip with the `/bb` command summary; tooltip hides on leave.
- Reset restores defaults, re-syncs the controls and re-applies frames; chat confirmation.
- Sliders are centered under the title bar (Icon size → Position X → Position Y, labels above); checkboxes follow centered below them (label on the same line); Reset is centered at the bottom; **every adjacent row is at the same vertical distance (one `ROW_GAP`)**.
- Size slider live-resizes a visible Lifebloom icon; Position sliders persist (`/reload`
  keeps values) and show the "Not implemented yet" tooltip; checkboxes toggle the swipe
  (visible on a live Lifebloom) and the digital countdown.
- `/bb status` reflects `scale`/`showSwipe`/`showTimer`; values survive `/reload`;
  `/console scriptErrors 1` → zero errors.
- `vararg-check.ps1`, `syntax-check.ps1`, `luahelper_check_lua_project` clean;
  `deploy.ps1 -Bundle` produces the zip.

## Known limitations (expected)

- Position sliders are stubs — they persist but do NOT move the overlay yet (future phase).
- The window is a standalone dialog (no Interface Options category) — deliberate, per the ADR.