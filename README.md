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


### Launcher auto-detection and installation

The launcher checks its own folder and common per-user/system install paths for `PandaRoyale.exe`. If it cannot find a valid executable, it warns the user and offers to download the latest Windows build from the official GitHub Releases asset. Accepted downloads install to `%LOCALAPPDATA%\\PandaRoyale\\PandaRoyale.exe`; the launcher then offers to start the game. If the release asset is unavailable, it offers to open the official Releases page. An internet connection is required for downloading, and a published Windows executable must exist in the latest release.


## Add Panda Royale to Steam (non-Steam shortcut)

You can add the Windows game to your personal Steam Library without publishing it on Steam or paying a Steam Direct fee. First install Panda Royale, then open the launcher and click **ADD TO STEAM**. The launcher copies the detected `PandaRoyale.exe` path and opens Steam. In Steam, choose **Games → Add a Non-Steam Game to My Library**, select **Browse**, choose `PandaRoyale.exe`, and add it. You can rename the shortcut and customise its artwork from your Steam Library. This is a local shortcut only; it does not upload or publish Panda Royale to Steam. Steam must be installed for the Steam Library step.


## System requirements (provisional estimates)

These are preliminary targets for the current Godot 4.7 prototype, not verified minimum specifications. The game is still under development and performance may change between builds.

### Minimum target

- **OS:** Windows 10 or Windows 11, 64-bit
- **CPU:** 2-core processor around 2.0 GHz
- **Memory:** 4 GB RAM
- **Graphics:** GPU/driver supporting OpenGL 3.3 or the Godot GL Compatibility renderer
- **Storage:** At least 1 GB free space for the game; updates may require additional space
- **Network:** Internet connection for online play

### Recommended target

- **OS:** Windows 10 or Windows 11, 64-bit
- **CPU:** 4-core processor
- **Memory:** 8 GB RAM or more
- **Graphics:** Dedicated graphics card or recent integrated graphics
- **Storage:** At least 2 GB free space

**Important:** These figures are estimates and have not been validated through a broad hardware benchmark. Actual performance depends on the build, resolution, graphics settings, drivers, background applications, and the state of game optimization. Requirements will be updated after testing on a range of PCs.

The Windows launcher includes a **SYSTEM REQUIREMENTS** button to view these provisional targets before starting the game.
