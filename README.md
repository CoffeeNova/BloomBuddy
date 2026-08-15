# BloomBuddy

Makes the **Lifebloom** buff icon bigger on **party and raid frames** in World of Warcraft: TBC Anniversary (Classic). Nothing more, nothing less.

> For developers and AI agents: technical docs live in `AGENTS.md` and the `.github/` directory (context and architecture). `README.md` is for players.

## What it does

When a party or raid member has a Druid **Lifebloom** HoT on them, BloomBuddy enlarges that member's Lifebloom icon on the unit frame (default **1.5×**), so you can spot who has your HoT at a glance.

- Party frames and raid frames — both supported, each can be toggled.
- Scales only the Lifebloom icon; no other buffs, no layout changes, no interference with other addons.
- Re-applies the scale whenever the game redraws the buff icons (Blizzard resets their size on every update).

## Slash commands

| Command | Action |
|---|---|
| `/bb` | Show status: enabled, scale, party/raid toggles |
| `/bb enable` / `/bb disable` | Enable/disable the addon |
| `/bb debug` | Toggle verbose logging (useful for reporting issues) |
| `/bb help` | List commands |

## Configuration

BloomBuddy is configured in **Interface Options → AddOns → BloomBuddy**:

- **General** — master switch, icon size multiplier.
- **Frames** — scale on party frames, scale on raid frames.

All settings persist between sessions.

## Requirements

- World of Warcraft: TBC Anniversary (Interface 20506).
- A Druid with Lifebloom (the addon scales the icon on *any* member who has the buff — the source can be yourself or another healer).
- No libraries required.

## Development

See `AGENTS.md` → `.github/` (context, architecture, and the development plan).

## Changelog

See `CHANGELOG.md`.

## License

MIT — see `LICENSE`.
