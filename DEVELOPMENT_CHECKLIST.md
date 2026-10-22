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
- [ ] Run Godot 4.7 headless import and main-scene smoke test.
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