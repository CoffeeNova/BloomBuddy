# Debug report request

Use this template when the addon misbehaves and you need a structured in-game report from the user. Paste it as your message to the user (filling nothing — it's self-contained). The `log-interpreter` agent can then analyze the response.

---

To debug this, I need a structured in-game report. Please do exactly this:

1. **`/reload`** (apply latest code).
2. **`/bb debug`** (enable verbose logging — you should see `BB: Debug logging: on`).
3. **Reproduce** the issue: [describe the exact steps, e.g. "apply Lifebloom to a party member, wait ~1 s"].
4. **Right after**, run **`/bb status`** and copy its output.
5. Paste back:
   - the **log output** (from step 2 onward, including timestamps — they let me correlate actions with events),
   - the **`/bb status`** output,
   - any **error popups** (the full `Message/Stack/Locals` text).

Useful extra dumps (only if asked or if they seem relevant):
- `/dump BloomBuddyDB` — full saved variables,
- `/dump PartyMemberFrame1` — party frame structure (only if the bug is about party buff paths),
- `/run for i = 1, 40 do local a = C_UnitAuras.GetAuraDataByIndex("party1", i, "HELPFUL"); if a then print(i, a.spellId, a.name) end end` — verify the aura object API on a party unit.

Notes:
- The 0.5 s safety ticker produces a LOT of debug lines while the addon is enabled — that's expected.
- If `/bb debug` output resets after `/reload`, re-run it after the reload (the flag is runtime-only).
