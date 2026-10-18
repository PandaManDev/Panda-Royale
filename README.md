# Panda Royale

**Panda Royale** is a Godot-powered game project focused on bringing fast, fun royale-style gameplay to life. This repository contains the game's source project and its build workflow for exporting a Windows version.

## About

Panda Royale is being developed with **Godot Engine 4.7**. The project includes a party lobby interface with Solo and Duos options, player slots, and a ready/play flow. Gameplay and online features are a work in progress; selecting a mode in the lobby does not necessarily mean online multiplayer or invitations are fully implemented yet.

## Features

- Godot Engine project
- Custom party lobby UI
- Solo and Duos mode selection interface
- Windows build workflow using GitHub Actions
- Automated build artifact and GitHub Release publishing when the workflow completes successfully

## Getting Started

1. Clone or download this repository.
2. Open the project in Godot Engine **4.7**.
3. Import the project and run it from the Godot editor.

## Build for Windows

The GitHub Actions workflow in `.github/workflows/release.yml` installs Godot and its export templates, then attempts to export `build/PandaRoyale.exe`.

- **Workflow runs:** [GitHub Actions](https://github.com/PandaManDev/Panda-Royale/actions)
- **Releases:** [Panda Royale Releases](https://github.com/PandaManDev/Panda-Royale/releases)

A downloadable EXE will appear in Releases only after a build and release step succeeds. Builds may also provide a downloadable artifact on the individual Actions run page.

## Project Status

Panda Royale is under active development. Features, visuals, controls, and multiplayer functionality may change as development continues. The current build workflow is intended to automate Windows exports; successful publishing depends on the workflow completing without errors.

## Contributing

Bug reports, ideas, and improvements are welcome. Please open an issue or pull request in this repository with details about the change.

## License

No license is specified in this README. Unless a license is added to the repository, reuse and redistribution permissions may be limited.

## Steam In-Game Invites (Integration Preview)

Panda Royale now has an optional Steam invite bridge. When the party lobby is open, the party UI creates an INVITE VIA STEAM button with a direct click handler and displays Steam status/errors in the lobby. With a compatible GodotSteam GDExtension installed and initialized, the button creates a friends-only Steam lobby and opens the Steam overlay invite dialog.

**Important:** this is not plug-and-play until the native GodotSteam extension is installed for the exact Godot 4.7 build and a valid Steamworks App ID is configured. The repository does not bundle the native extension, and the game's current ENet multiplayer transport is still separate from Steam lobby membership. Steam invitations alone do not yet route players into the same network match.

Setup checklist:
1. Install and configure a GodotSteam GDExtension build compatible with the project's Godot 4.7 version and target Windows architecture.
2. Configure your own Steamworks App ID once you have Steamworks partner access. The 480 Spacewar ID in the script is for development/testing only, not a production game ID.
3. Launch Steam first, then launch Panda Royale through Steam (or the configured test app), and verify the Steam overlay is enabled.
4. Test creating a lobby and inviting a friend. A full production integration still needs Steam lobby join callbacks wired into the game's session/match flow and a Steam-capable networking transport (or a reachable ENet host).

Without GodotSteam installed, Panda Royale should still launch normally; the optional Steam button will report that Steam support needs setup.


### Local Steam invite testing

The repository includes `steam_appid.txt` set to `480` (Valve's Spacewar test app) for local development only. Keep Steam running when testing. This file does **not** install GodotSteam or make the game a Steamworks app by itself. You must install a GodotSteam GDExtension build compatible with the exact Godot 4.7 editor/export template and include its native Windows DLLs in the exported game. If Godot reports that the `Steam` singleton is missing, the extension is not loaded.

For production, replace the test ID with Panda Royale's own Steamworks App ID and ensure the App ID file is beside the executable when launching outside Steam. Do not publish a game using App ID 480. The current invite bridge creates a Steam lobby, but joining that lobby is not yet wired to the game's ENet match session.

Official references:
- GodotSteam initialization guidance: https://github.com/GodotSteam/GodotSteam-Docs
- GodotSteam releases and compatible binaries: https://github.com/GodotSteam/GodotSteam/releases
