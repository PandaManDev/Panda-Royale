# Panda Royale Development Checklist

This file is the hand-off point for ongoing development. Statuses distinguish code changes from tests actually executed.

## Current status

- [x] Launcher supports optional Discord Rich Presence using a configured Discord application ID.
- [x] Presence connection is best-effort; RPC failure does not intentionally block game launch.
- [x] Launcher clears presence when the launcher closes.
- [x] Launcher automatically attempts the local Discord IPC connection and retries when Discord is unavailable at first.
- [x] Rich Presence uses the existing signed-in desktop session; no OAuth popup, password, user token, or bot token is requested.
- [x] Set the supplied Discord Application ID (`1562710544010584155`) as the launcher's default.
- [ ] Verify presence with the Discord desktop client on Windows.
- [ ] Run Godot 4.7 headless import and main-scene smoke test with script parse failures treated as build failures.
- [ ] Build and test the Windows game + launcher ZIP end-to-end.
- [ ] Improve presence states for lobby, solo/duos, and active match; current presence is generic.
- [ ] Add game-native RPC for launches that bypass the launcher, or document launcher-required presence.

## Discord Rich Presence setup

1. Confirm the supplied ID belongs to the Panda Royale application in Discord Developer Portal. The ID is public configuration, not a credential.
2. Test on Windows with the official Discord desktop client signed in; confirm presence appears and retries if Discord starts later.
3. Never package a Discord bot token or other secret.

## Verification log

- No Godot executable or Windows Discord client was run during this edit; RPC and game startup remain unverified until tested on Windows.
- The release workflow has a Python syntax-check step, but a passing workflow run has not been confirmed here.

## Next priorities

1. Verify the configured Discord application ID and test Rich Presence on Windows.
2. Fix launcher process monitoring so unexpected exits after startup are detected, not only immediate startup exits.
3. Run the Godot 4.7 import and headless main-scene smoke test; fix parser/runtime errors.
4. Test Discord RPC connected, Discord closed, missing ID, and normal launcher shutdown.
5. Continue toward server-authoritative combat and match state; movement validation alone is not cheat-proof.

## Multiplayer development log — 2026-10-22

- [x] Added an in-game network status label so host/join/connection messages remain visible during play.
- [x] Improved remote-player readability with emissive materials, a glowing floor ring, a purple shoulder accent, and a short spawn glow.
- [x] Fixed the party panel's bottom disconnect action to re-enable the actual host-address input instead of referencing an undefined variable.
- [x] Static source inspection confirmed the new network HUD and remote visual components exist, and the GDScript parentheses are balanced. This is not a GDScript parser or runtime test.
- [x] Reviewed GitHub Actions logs and found two GDScript parse errors that the previous workflow did not fail on; added explicit script-parse checks to the release workflow.
- [ ] Confirm the new parse-check step passes and that the rebuilt executable launches to the menu.
- [ ] Run Godot 4.7 import and headless main-scene smoke test.
- [ ] Test two separate instances on a LAN: host, join, movement replication, remote spawn/disconnect, and reconnect.
- [ ] Test internet joining with UDP 24560 forwarded; verify that UI explains connection failures clearly.
- [ ] Implement host-authoritative combat, health, inventory, loot, storm, and match results before describing online play as a complete battle royale.

## Next exact steps

1. Check the Actions run for commit `eae616b57376e30daabfc0a1fdac38c0460b6d84`; fix any parser/import/export failures before adding more multiplayer code.
2. If the build passes, use two local game instances to validate connection lifecycle and confirm remote-player effects render without errors.
3. Review peer disconnect and reconnect behavior, then add a small online party roster with connected peer IDs.
4. Prioritize server-authoritative gameplay actions; movement snapshot validation alone does not prevent combat or loot cheating.
5. Keep all unexecuted Godot and live-network tests marked pending until actually run.


## Black-screen incident — 2026-10-22

- [x] Root cause found in GitHub Actions logs: `scripts/game.gd` had duplicate local variable `disconnect_button` declarations in the same function scope, preventing the game script from loading.
- [x] Fixed the second button variable name to `disconnect_panel_button`.
- [x] Fixed strict type inference errors in `scripts/network_manager.gd` by explicitly typing elapsed time and allowed movement distance.
- [x] Updated the Windows release workflow to run Godot script parse checks for `network_manager.gd` and `game.gd` before smoke test/export.
- [ ] Verify the new GitHub Actions parse checks and export after these fixes.
- [ ] Launch the freshly rebuilt EXE on Windows and confirm the boot screen transitions to the main menu; CI cannot verify the actual rendered screen.

### Exact next steps

1. Inspect the newest Actions run and fix any GDScript parse failures it reports.
2. If checks pass, download the EXE from that successful release and launch it on Windows.
3. Confirm the purple boot screen clears and the main menu appears; if not, collect the Godot log from `%APPDATA%\\Godot\\app_userdata\\Panda Royale\\logs`.
4. Only mark the black-screen bug resolved after a real Windows launch is confirmed.
