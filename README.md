# Steal From the Beast

Co-op monster-lair heist + creature raising. Plan and rules live in the Obsidian vault:
`D:\ObsidianVault\Games\Steal From the Beast - Game Plan.md` (gated stages, one open at a time).

## Run it
1. `rojo serve` in this folder.
2. Open the published test place "TEST" (place 88566244065044, WHITEOUT INC) in Studio. It holds the map: `Workspace.SFTB_Lair` (Stage 1 greybox) and `Workspace.SFTB_Mockup.Camp`. The old mockup lair is archived in `ServerStorage.SFTB_MockupArchive`.
3. Rojo plugin > Connect. Code syncs into `SFTBShared`, `SFTBServer`, `SFTBClient`.
4. Test > Play (2 clients for anything multiplayer).

## Rebuild the greybox lair
The lair is built from `Config.Lair` (kit grid + fixed layout). With Rojo connected, paste `tools/BuildLairGreybox.luau` into Studio's command bar, run it, then save/publish the place. It replaces its own output and sets the lair lighting.

## Controls (Stage 2)
- Stick or touch thumbstick: tilt sets speed (gentle = sneak, full = run). Keyboard: walk by default, hold **Shift** to sneak, hold **Ctrl** to run. No crouch button, no jump.
- Power Q / RB and Ping F / LB are stubs; Drop/Pass G / Y shows only while carrying (Stage 4). Phone shows max 3 buttons.
- The server reads real speed for noise (`NoiseService`); clients only draw the rings. Noise traps are floor parts tagged `SFTB_NoiseTrap` with a `Trap` attribute, made by the lair builder.

## Layout
```
src/shared/   Config/  Catalogs/  Rules/  Visuals/  Remotes.luau
src/server/   Bootstrap.server.luau  Data/  Infrastructure/  Noise/ (NoiseService)  <one folder per domain>
src/client/   Main.client.luau  UI/  Controls/  Effects/ (Flashlight, EggPulse, NoiseRings)
tools/        Studio command-bar scripts (not synced by Rojo)
```
- Every tunable goes in `src/shared/Config`.
- Every remote is listed in `src/shared/Remotes.luau` **and** declared in `default.project.json`; Bootstrap refuses to start if one is missing.
- Commit after every round of changes and add a Feature Round Log entry in the vault.
