# UI review request

Use this template when reviewing or iterating on the addon's settings panel (or any UI). It structures the user's feedback so you can act on it without guessing. Paste it as your message (self-contained).

---

Review the settings panel (`/bb` → Interface Options → AddOns → BloomBuddy) and describe what you see, section by section. This lets me fix layout precisely instead of guessing.

Please answer in this format:

1. **Sections** — for each box (General, Frames): is the title aligned with the other titles? Does the content touch the frame edges?
2. **Overlaps / clipping** — any text or control that overlaps another, or is cut off at a frame border?
3. **Spacing** — any section where items feel too cramped, or too much empty space inside/around a box?
4. **Controls** — do the master switch, scale slider and party/raid checkboxes reflect their values, and do changes apply immediately (and persist after `/reload`)?
5. **Bottom of the window** — is there a large empty area, or does content fill it?
6. **Anything else** that looks off (alignment, font, disabled states).

If possible, describe positions relative to the frame ("Frames title is 2px lower than General title") rather than "looks wrong". Screenshot descriptions are fine too.
