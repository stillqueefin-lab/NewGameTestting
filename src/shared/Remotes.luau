--!strict
-- Every remote the game uses. The instances live in ReplicatedStorage.SFTBRemotes
-- (declared in default.project.json); Bootstrap asserts each one exists at start.
-- Add a remote in both places, or the server refuses to start.

export type RemoteSpec = { Name: string, ClassName: "RemoteEvent" | "UnreliableRemoteEvent" }

local Remotes: { RemoteSpec } = {
	{ Name = "StateChanged", ClassName = "RemoteEvent" }, -- server -> client profile state
	{ Name = "Toast", ClassName = "RemoteEvent" }, -- server -> client short message
	{ Name = "NoiseEvent", ClassName = "UnreliableRemoteEvent" }, -- server -> client noise ring
}

return Remotes
