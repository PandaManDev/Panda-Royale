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

## Friend Codes

The party screen uses a friend-code flow instead of Steam invites. The host enters a reachable public IP address or hostname, hosts a party, and shares the generated code (for example, `PR-example.com:24560`). Friends paste the code into **JOIN WITH A FRIEND CODE**.

Friend codes currently package the host address and ENet port; they are not short account-based codes and there is no matchmaking/relay service. For friends connecting over the internet, the host may need to forward UDP port 24560 and allow the game through their firewall. The current ENet setup still replicates basic player movement only; shared combat, loot, and match state remain future work.

Steam is not required for this flow.
