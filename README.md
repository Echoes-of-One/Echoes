<p align="center">
  <img src="https://i.gyazo.com/b857069092e8cd0f96b57d15d093d919.png" alt="Echoes" width="256" />
</p>

# Echoes

Echoes is a lightweight **playerbot control helper** for **World of Warcraft 3.3.5 (WotLK)**.

It adds a clean, tabbed control panel (Ace3 UI) for common bot actions and group setup, plus a few quality-of-life tools like UI scaling and quick panels.

## Requirements

- WoW client: **3.3.5**
- Library: **Ace3 (embedded)**
  - Echoes embeds Ace3 in `Echoes/Ace3/`, so it does **not** require a separate `Interface/AddOns/Ace3/` addon folder.
  - Having other addons that also embed Ace3 is usually fine (LibStub picks the highest library version).

## Installation

### Using an addon client

If your addon page is connected to an auto-installer client:

1. Search for **Echoes**.
2. Click **Install** / **Update**.
3. Launch the game (or `/reload`).

### From a release zip

1. Download the latest release zip from GitHub Releases.
2. Extract into your WoW folder:

   `World of Warcraft/Interface/AddOns/`

3. You should end up with:

- `Interface/AddOns/Echoes/`

### From source (this repo)

This repository is already laid out like an addon folder.

- Place the entire `Echoes/` folder into `Interface/AddOns/`.

## Usage

### Quick start

1. Type `/echoes` to open the window.
2. Use the tabs at the top:
   - **Bot Control**: common bot actions
   - **Group Creation**: group templates and slot planning
   - **Echoes**: UI scale and settings/tools

### Open / close the window

Slash commands:

- `/echoes` (main command)
- `/ech` (short alias)
- `/echoes help` (shows all commands)

### Minimap button

Echoes creates a minimap button labeled **"E"**.

- Left-click: Toggle the Echoes window
- Right-click + drag: Reposition the button around the minimap
- Ctrl + click: Reset the window position to center

## Commands

- `/echoes` — Toggle the main window
- `/echoes help` — Show help
- `/echoes scale <0.5-2.0>` — Set UI scale
- `/echoes reset` — Reset window position
- `/echoes spec` — Toggle the spec whisper panel
- `/echoes inv` — Open the inventory scan UI

## UI Overview

Echoes has three tabs:

- **Bot Control**: Quick actions that send bot-related chat commands.
- **Group Creation**: Group template / slot helpers (some actions may be stubs/WIP).
- **Echoes**: Misc settings (currently includes a **UI Scale** slider).

## How it works

Echoes is built on Ace3 (embedded in the addon folder) and uses an AceGUI window for the main UI.

For bot actions, Echoes sends predefined command strings using `SendChatMessage(...)`.

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

This repo includes GitHub Actions workflows that:

- Read the addon version from `Echoes.VERSION` in `Bootstrap.lua`
- Tag the commit as `vX.YY`
- Package the addon into a zip with the correct folder layout (`Echoes/...`)
- Publish a GitHub Release marked as the latest

Release artifacts:

- `Echoes-vX.YY.zip` (versioned)
- `Echoes-latest.zip` (stable name, always replaced)

See [.github/workflows/release.yml](.github/workflows/release.yml).

## Credits

- Built on the Ace3 framework (vendored in this repository).

## License

Licensed under **GPL-3.0-only**. See [LICENSE](LICENSE).

