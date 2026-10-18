# Panda Royale

An original first-person battle royale prototype built with Godot 4. It uses procedurally-created geometry and original placeholder visuals, so no Fortnite assets are included.

## Play the game

1. Install **Godot Engine 4.3 or newer** from https://godotengine.org/download/windows/
2. Extract the `PandaRoyale` folder from the ZIP.
3. Open Godot Project Manager → **Import**.
4. Select the `project.godot` file in this folder.
5. Open the project, then press **F6** or **F5** to run.

## Controls

- **W A S D** — move
- **Mouse** — look / aim
- **Left mouse button** — fire
- **R** — reload
- **Shift** — sprint
- **Space** — jump
- **Esc** — unlock mouse; click the game again to recapture

## Build a Windows executable

1. Open the project in Godot.
2. Go to **Editor → Manage Export Templates** and install templates for your Godot version.
3. Go to **Project → Export**.
4. Add a **Windows Desktop** preset.
5. Choose an output such as `build/PandaRoyale.exe`.
6. Click **Export Project**.

Godot export templates are version-specific, so install the templates matching the version you use.

## Prototype features

- First-person mouse-look and movement
- Rifle, firing, reload and ammo reserve
- 12 rival bots with simple combat AI
- Health and shield
- Health, shield and ammo pickups
- Shrinking safe zone with damage outside it
- Alive counter, HUD, victory/defeat state and replay button
- Procedurally generated terrain, buildings, trees, roads and radio tower

## Notes

This is a playable starter prototype, not a finished commercial game. The world is generated from simple 3D shapes at runtime. Bots use simplified combat logic and can sometimes get stuck on geometry. Online multiplayer, advanced animations, sound design, settings, save data and production-grade navigation are not included yet.
