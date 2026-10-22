# Panda Royale Development Checklist

This file is the hand-off point for ongoing development. Statuses distinguish code changes from tests actually executed.

## Current status

- [x] Launcher supports optional Discord Rich Presence using a configured Discord application ID.
- [x] Presence connection is best-effort; RPC failure does not intentionally block game launch.
- [x] Launcher clears presence when the launcher closes.
- [x] Launcher automatically attempts the local Discord IPC connection and retries when Discord is unavailable at first.
- [ ] Configure a real Panda Royale Discord Application ID once; no game-specific ID has been created or verified in this repository.
- [ ] Verify presence with the Discord desktop client on Windows.
- [ ] Run Godot 4.7 headless import and main-scene smoke test.
- [ ] Build and test the Windows game + launcher ZIP end-to-end.
- [ ] Improve presence states for lobby, solo/duos, and active match; current presence is generic.
- [ ] Add game-native RPC for launches that bypass the launcher, or document launcher-required presence.

## Discord Rich Presence setup

1. Create a Discord application in the Discord Developer Portal for Panda Royale.
2. Copy its Application ID (not a bot token) and configure it once in the release package or environment; players will not need their own IDs.
3. Ensure the official Discord desktop client is running and signed in. The launcher tries the local Rich Presence IPC connection and retries if Discord starts later.
4. Never package a Discord bot token or other secret.

## Verification log

- No Godot executable or Windows Discord client was run during this edit; RPC and game startup remain unverified until tested on Windows.
- The release workflow has a Python syntax-check step, but a passing workflow run has not been confirmed here.

## Next priorities

1. Configure the real Discord application ID and add optional `pypresence` to the Windows launcher build.
2. Fix launcher process monitoring so unexpected exits after startup are detected, not only immediate startup exits.
3. Run the Godot 4.7 import and headless main-scene smoke test; fix parser/runtime errors.
4. Test Discord RPC connected, Discord closed, missing ID, and normal launcher shutdown.
5. Continue toward server-authoritative combat and match state; movement validation alone is not cheat-proof.