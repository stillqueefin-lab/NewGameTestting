# Steal From the Beast

Co-op monster-lair heist + creature raising. Plan and rules live in the Obsidian vault:
`D:\ObsidianVault\Games\Steal From the Beast - Game Plan.md` (gated stages, one open at a time).

## Run it
1. `rojo serve` in this folder.
2. Open `place/SFTB_Test.rbxl` in Studio (it holds the map: `Workspace.SFTB_Mockup`).
3. Rojo plugin > Connect. Code syncs into `SFTBShared`, `SFTBServer`, `SFTBClient`.
4. Test > Play (2 clients for anything multiplayer).

## Layout
```
src/shared/   Config/  Catalogs/  Rules/  Visuals/  Remotes.luau
src/server/   Bootstrap.server.luau  Data/  Infrastructure/  <one folder per domain>
src/client/   Main.client.luau  UI/  Effects/
```
- Every tunable goes in `src/shared/Config`.
- Every remote is listed in `src/shared/Remotes.luau` **and** declared in `default.project.json`; Bootstrap refuses to start if one is missing.
- Commit after every round of changes and add a Feature Round Log entry in the vault.
