--!strict
-- Every remote the game uses. The instances live in ReplicatedStorage.SFTBRemotes
-- (declared in default.project.json); Bootstrap asserts each one exists at start.
-- Add a remote in both places, or the server refuses to start.

export type RemoteSpec = { Name: string, ClassName: "RemoteEvent" | "UnreliableRemoteEvent" }

local Remotes: { RemoteSpec } = {
	{ Name = "StateChanged", ClassName = "RemoteEvent" }, -- server -> client profile state
	{ Name = "Toast", ClassName = "RemoteEvent" }, -- server -> client short message
	{ Name = "NoiseEvent", ClassName = "UnreliableRemoteEvent" }, -- server -> client noise ring
	{ Name = "HushCaught", ClassName = "RemoteEvent" }, -- server -> client: a player was swatted
	{ Name = "EggDropPass", ClassName = "RemoteEvent" }, -- client -> server: Drop/Pass the egg (Action Guard)
	{ Name = "HatchReveal", ClassName = "RemoteEvent" }, -- server -> client: play the hatch reveal
	{ Name = "UsePower", ClassName = "RemoteEvent" }, -- client -> server: hatchling power (Action Guard)
	{ Name = "Listen", ClassName = "RemoteEvent" }, -- server -> client: show the Hush for a few seconds
	{ Name = "Ping", ClassName = "RemoteEvent" }, -- client -> server: a ping where you aim (Action Guard)
	{ Name = "PingShow", ClassName = "RemoteEvent" }, -- server -> client: show a crewmate's ping
}

return Remotes
