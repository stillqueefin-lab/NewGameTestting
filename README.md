# Steal From the Beast

Co-op monster-lair heist + creature raising. Plan and rules live in the Obsidian vault:
`D:\ObsidianVault\Games\Steal From the Beast - Game Plan.md` (gated stages). Stages 6-10 were built
ahead of their gates for fun testing (Alex, 2026-11-02); the gates are still open.

## Run it
1. `rojo serve` in this folder.
2. Open the published test place "TEST" (place 88566244065044, WHITEOUT INC) in Studio. It holds the camp (`Workspace.SFTB_Mockup.Camp`) and an Edit preview of the lair (`Workspace.SFTB_Lair`). The old mockup lair is archived in `ServerStorage.SFTB_MockupArchive`.
3. Rojo plugin > Connect. Code syncs into `SFTBShared`, `SFTBServer`, `SFTBClient`. After adding a remote to `default.project.json`, reconnect Rojo so the place gets it.
4. Test > Play (Test > Clients and Servers with 2+ clients for anything multiplayer).

## How a session goes
- **Brand-new player:** no camp first. A solo run starts inside the nest door, Hush asleep, egg in view; one objective line walks you through grab, sneak out, hatch, Listen and the big-egg hint.
- **Camp:** spawn by the fire. Stand on a crew pad (alone or with up to 3 friends) for a 5 s countdown; your crew gets its own lair copy far away.
- **Lair:** Path and Side rooms are shuffled from 4 kits every run. The Hush hunts by sound in its nest only. Caught = back at your lair's mouth. Walk out of the mouth to go back to camp.
- **Eggs:** small egg (one carrier), big egg (two carriers: the front steers, the back stays close). Out of the mouth with an egg: back at camp, your first egg ever hatches right away, later ones go into the incubators (timers run offline). Hatch from the incubator's prompt.
- **Hushlings:** your newest one follows you and grows over 30 minutes; the rest idle in the pen. Power = Listen (the Hush shows through walls).

## Rebuild the Edit preview lair
Runs build their own lairs with `src/server/Lair/LairBuilder.luau`. To refresh the Edit preview, paste `tools/BuildLairGreybox.luau` into Studio's command bar with Rojo connected, run it, then save the place. It also sets the base lair lighting.

## Controls
- Stick or touch thumbstick: tilt sets speed (gentle = sneak, full = run). Keyboard: walk by default, hold **Shift** to sneak, hold **Ctrl** to run. No crouch button, no jump.
- **Power** Q / RB / phone button: Listen (needs a Hushling; 30 s cooldown shown on the phone button).
- **Ping** F / LB / phone button: opens a wheel; pick Here, Egg, Danger or Help with 1-4, the D-pad or a tap. It lands where you were aiming.
- **Drop/Pass** G / Y / phone button (only while carrying): passes a small egg to a crewmate within 10 studs, else drops it.
- Grab eggs and hatch incubator eggs with their prompts (E / X / tap).
- The server reads real speed for noise (`NoiseService`); clients only draw the rings.

## Layout
```
src/shared/   Config/  Catalogs/  Rules/  Visuals/  Remotes.luau
src/server/   Bootstrap.server.luau  Data/  Infrastructure/  Noise/  Hush/ (+ Senses/)  Eggs/  Hatch/
              Lair/ (LairBuilder, LairService)  Camp/  Pings/  Onboarding/
src/client/   Main.client.luau  State.luau  Controls/  UI/
              Effects/ (Flashlight, EggPulse, NoiseRings, HushView, HatchView, HushlingModel,
                        ZoneLighting, CampView, PingView, Objective)
tools/        Studio command-bar scripts (not synced by Rojo)
```
- Every tunable goes in `src/shared/Config`.
- Every remote is listed in `src/shared/Remotes.luau` **and** declared in `default.project.json`; Bootstrap refuses to start if one is missing. Client-to-server remotes go through the Action Guard.
- Commit after every round of changes and add a Feature Round Log entry in the vault.
