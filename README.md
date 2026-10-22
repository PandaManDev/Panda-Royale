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


## Anti-cheat baseline

The ENet host validates client movement snapshots before relaying them: it rejects non-finite coordinates, checks movement speed and world bounds, limits update frequency, logs strikes, and disconnects a peer after repeated violations. This is an early server-side sanity layer intended to make basic teleport/speed exploits harder.

**Security limitation:** this prototype is not yet cheat-proof. The current game still runs important movement, damage, loot, and match logic on clients, and the host does not yet authoritatively simulate all player actions. A production anti-cheat needs server-authoritative movement and combat, validated fire/reload/ammo/loot actions, and testing against false positives. Do not treat this baseline as a guarantee against cheating.


## Windows launcher

The Windows build workflow also packages a standalone **Panda Royale Launcher**. The launcher shows a launch/waiting status, checks for `PandaRoyale.exe` beside it, and starts the game when you press **PLAY NOW**. Download the `PandaRoyale-Windows-Launcher.zip` asset from [Releases](https://github.com/PandaManDev/Panda-Royale/releases), extract the entire ZIP, and run `PandaRoyaleLauncher.exe`. Keep both executables together in the extracted folder.

The launcher is a lightweight local front end; it does not yet download patches, authenticate accounts, or show live matchmaking/queue status. “Waiting for game” means it is checking for the local game executable, not waiting for an online server.

## Anti-cheat status and limits

The current prototype has server-side sanity checks for replicated movement snapshots, including non-finite values, world bounds, movement distance, and excessive update frequency. Repeated violations are logged and can disconnect a peer. This is a **baseline only**, not a complete anti-cheat: the prototype still has client-controlled movement and local combat/loot paths. A production-ready design needs host-authoritative movement, firing and hit validation, health/inventory changes, pickups, building, storm and match results, plus latency-aware multiplayer tests. Do not treat the current build as cheat-proof.
