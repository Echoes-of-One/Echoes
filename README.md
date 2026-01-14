# Echoes

Echoes is a lightweight **playerbot control helper** for **World of Warcraft 3.3.5 (WotLK)**.

It provides an Ace3-based window (draggable, ElvUI-ish dark skin) with quick actions for common bot commands, plus basic group-setup helpers.

## Requirements

- WoW client: **3.3.5**
- Library: **Ace3 (embedded)**
  - Echoes embeds Ace3 in `Echoes/Ace3/`, so it does **not** require a separate `Interface/AddOns/Ace3/` addon folder.
  - Having other addons that also embed Ace3 is usually fine (LibStub picks the highest library version).

## Installation

### From a release zip

1. Download the latest `Echoes-<build>.zip` from GitHub Releases.
2. Extract into your WoW folder:

   `World of Warcraft/Interface/AddOns/`

3. You should end up with:

- `Interface/AddOns/Echoes/`

### From source (this repo)

This repository is already laid out like an addon folder.

- Place the entire `Echoes/` folder into `Interface/AddOns/`.

## Usage

### Open / close the window

- Slash commands:
  - `/echoes`
  - `/ech`

### Minimap button

Echoes creates a minimap button labeled **"E"**.

- Left-click: Toggle the Echoes window
- Right-click + drag: Reposition the button around the minimap

## UI Overview

Echoes has three tabs:

- **Bot Control**: Quick actions that send bot-related chat commands.
- **Group Creation**: Group template / slot helpers (some actions may be stubs/WIP).
- **Echoes**: Misc settings (currently includes a **UI Scale** slider).

## How commands are sent

Echoes sends predefined command strings using `SendChatMessage(...)`.

- Default behavior sends to **PARTY**.
- You can toggle **Send commands to a chat channel** and choose a **Channel** on the **Echoes** tab.
- The **Group Creation → Set Talents** button uses a configurable **Talent Command** template (also on the **Echoes** tab).

## SavedVariables

Echoes stores settings in `EchoesDB` (per-account SavedVariables), including:

- `uiScale`: Window scale (default `1.0`)
- `minimapAngle`: Minimap button angle
- `lastPanel`: Last selected tab
- `classIndex`, `groupTemplateIndex`: UI selections

## Development

- Main addon code: `Echoes.lua`
- Addon metadata: `Echoes.toc`
- Vendored library: `Ace3/`

### Releases

This repo includes a GitHub Actions workflow that:

- Generates release notes from git history
- Packages `Echoes/` and `Ace3/` into a zip
- Creates a GitHub Release with that artifact

See [.github/workflows/release.yml](.github/workflows/release.yml).

## Credits

- Built on the Ace3 framework (vendored in this repository).

## License

No license file is currently included in this repository. If you want, I can add one (MIT/GPL/etc.) based on your preference.
