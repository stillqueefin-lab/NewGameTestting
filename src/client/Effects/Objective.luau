--!strict
-- Stage 10: one objective line at a time (the server sets SFTB_Objective). Horror HUD per
-- the UI Style Guide: barely there, typed out letter by letter, no panel behind it.
local Players = game:GetService("Players")

local Objective = {}

local TYPE_SECONDS = 0.6 -- whole line typed out in this long

function Objective.Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "SFTB_Objective"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0.05)
	label.Size = UDim2.fromScale(0.85, 0.045)
	label.BackgroundTransparency = 1
	label.FontFace = Font.fromEnum(Enum.Font.Code)
	label.TextColor3 = Color3.fromRGB(235, 230, 215)
	label.TextScaled = true
	label.Text = ""
	local stroke = Instance.new("UIStroke")
	stroke.Transparency = 0.3
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")

	local token = 0
	local function refresh()
		token += 1
		local mine = token
		local text = player:GetAttribute("SFTB_Objective")
		if type(text) ~= "string" then
			label.Text = ""
			return
		end
		label.Text = text
		label.MaxVisibleGraphemes = 0
		local count = utf8.len(text) or #text
		for i = 1, count do
			if token ~= mine then
				return
			end
			label.MaxVisibleGraphemes = i
			task.wait(TYPE_SECONDS / count)
		end
		label.MaxVisibleGraphemes = -1
	end
	player:GetAttributeChangedSignal("SFTB_Objective"):Connect(function()
		task.spawn(refresh)
	end)
	task.spawn(refresh)
end

return Objective
