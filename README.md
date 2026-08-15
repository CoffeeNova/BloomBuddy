# BloomBuddy

Shows a big **Lifebloom** icon on **party and raid frames** in World of Warcraft: TBC Anniversary (Classic). Nothing more, nothing less.

> For developers and AI agents: technical docs live in `AGENTS.md` and the `.agents/` directory (context and architecture). `README.md` is for players.

## What it does

When a party or raid member has a Druid **Lifebloom** HoT on them, BloomBuddy draws an enlarged Lifebloom icon on that member's unit frame (default **1.5×**), with the remaining time shown as a **cooldown swipe** (darkening clockwise) and the **stack count** on the icon, so you can spot who has your HoT at a glance.

- Works on **compact frames**: raid frames and raid-style party frames (Interface Options → Use raid-style party frames).
- Party frames and raid frames — both supported, each can be toggled.
- Remaining time: a cooldown swipe (default) or, optionally, a digital countdown (`/bb timer`).
- Shows the stack count (Lifebloom stacks up to 3) when there is more than one stack.
- Only draws the Lifebloom icon; no other buffs, no layout changes, no interference with other addons.
- Re-checks automatically whenever the game rebuilds the frames or the buffs change.

> **Note for TBC Anniversary (2.5.x):** on this client the native buff icons on compact frames are rendered by the game engine and cannot be resized individually. BloomBuddy therefore shows a larger Lifebloom icon next to the small native one. Classic (non-compact) party frames are not yet supported.

## Slash commands

| Command | Action |
|---|---|
| `/bb` | Show status: enabled, scale, party/raid toggles, timer |
| `/bb enable` / `/bb disable` | Enable/disable the addon |
| `/bb timer` | Toggle the digital countdown on the icon (default off; the cooldown swipe is always shown) |
| `/bb debug` | Toggle verbose logging (useful for reporting issues) |
| `/bb help` | List commands |

## Configuration

A full **Interface Options → AddOns → BloomBuddy** panel is planned. For now:

- **Master switch** — `/bb enable` / `/bb disable`.
- **Digital countdown** — `/bb timer` (default off).
- **Icon size multiplier** — edit `scale` in `BloomBuddyDB` (default 1.5).
- **Party / raid toggles** — edit `party` / `raid` in `BloomBuddyDB`.

All settings persist between sessions.

## Requirements

- World of Warcraft: TBC Anniversary (Interface 20506).
- A Druid with Lifebloom (the addon shows the icon on *any* member who has the buff — the source can be yourself or another healer).
- No libraries required.

## Development

See `AGENTS.md` → `.agents/` (context, architecture, and the development plan).

## Changelog

See `CHANGELOG.md`.

## License

MIT — see `LICENSE`.
