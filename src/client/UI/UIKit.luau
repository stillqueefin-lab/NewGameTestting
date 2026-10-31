-- Shared motion and surface helpers for the arcade menus. Every effect is
-- cosmetic, respects Reduced Motion, and cleans itself up with its object.
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Kit = {}
local White = Color3.new(1, 1, 1)
local Ink = Color3.fromRGB(20, 22, 34)
local reducedMotion = function()
	return false
end

-- Same hues as the shop rarity chips, deepened enough to read on white cards.
Kit.Rarity = {
	Common = Color3.fromRGB(168, 164, 154),
	Rare = Color3.fromRGB(64, 156, 230),
	Epic = Color3.fromRGB(168, 112, 232),
	Legendary = Color3.fromRGB(240, 176, 48),
	Mythic = Color3.fromRGB(240, 96, 164),
}
-- Crafting accent. Purple is the menu brand, so fusion stays orange.
Kit.Fusion = Color3.fromRGB(255, 122, 42)

-- UIGradient colors multiply the face color: a lit top, a crisp midline, and a
-- shaded base give flat buttons the chunky 3D look without extra frames.
Kit.Bevel = ColorSequence.new({
	ColorSequenceKeypoint.new(0, White),
	ColorSequenceKeypoint.new(0.48, Color3.fromRGB(244, 244, 244)),
	ColorSequenceKeypoint.new(0.52, Color3.fromRGB(218, 218, 218)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 190)),
})

function Kit.SetReducedMotion(getter)
	reducedMotion = getter
end
function Kit.Reduced()
	return reducedMotion() == true
end

function Kit.IsLight(color)
	local _, saturation, value = color:ToHSV()
	return saturation < 0.22 and value > 0.78
end

function Kit.Tween(instance, seconds, goal, style, direction, delay)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(
			seconds,
			style or Enum.EasingStyle.Quad,
			direction or Enum.EasingDirection.Out,
			0,
			false,
			delay or 0
		),
		goal
	)
	tween:Play()
	return tween
end
local tween = Kit.Tween

-- Looping tweens are cancelled with their owner so rebuilt pages never leak.
local function loop(owner, instance, seconds, goal, style)
	local animation = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		goal
	)
	animation:Play()
	owner.Destroying:Connect(function()
		animation:Cancel()
	end)
	return animation
end

function Kit.Scale(object)
	local scale = object:FindFirstChild("MotionScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = "MotionScale"
		scale.Parent = object
	end
	return scale
end

local function corner(parent, radius)
	local rounding = Instance.new("UICorner")
	rounding.CornerRadius = UDim.new(0, radius)
	rounding.Parent = parent
end

-- UIScale grows from the AnchorPoint, but layouts place objects by their
-- corner. Laid-out objects move into a same-sized cell so they can grow from
-- their center; free objects just re-anchor without moving on screen.
function Kit.CenterPivot(object, shadowRadius)
	if not object.Parent or object:GetAttribute("MotionPivot") then
		return
	end
	object:SetAttribute("MotionPivot", true)
	if object.AutomaticSize ~= Enum.AutomaticSize.None then
		return
	end
	local parent = object.Parent
	if parent:FindFirstChildWhichIsA("UIGridStyleLayout") then
		local cell = Instance.new("Frame")
		cell.Name = object.Name .. "Cell"
		cell.BackgroundTransparency = 1
		cell.BorderSizePixel = 0
		cell.Size = object.Size
		cell.LayoutOrder = object.LayoutOrder
		cell.Visible = object.Visible
		cell:SetAttribute("MotionCell", true)
		if shadowRadius then
			local shadow = Instance.new("Frame")
			shadow.Name = "Shadow"
			shadow.AnchorPoint = Vector2.new(0.5, 0.5)
			shadow.Position = UDim2.new(0.5, 0, 0.5, 5)
			shadow.Size = UDim2.fromScale(1, 1)
			shadow.BackgroundColor3 = Ink
			shadow.BackgroundTransparency = 0.84
			shadow.BorderSizePixel = 0
			shadow.ZIndex = object.ZIndex - 1
			corner(shadow, shadowRadius)
			shadow.Parent = cell
		end
		cell.Parent = parent
		object.AnchorPoint = Vector2.new(0.5, 0.5)
		object.Position = UDim2.fromScale(0.5, 0.5)
		object.Size = UDim2.fromScale(1, 1)
		object.Parent = cell
		object:GetPropertyChangedSignal("Visible"):Connect(function()
			cell.Visible = object.Visible
		end)
		object:GetPropertyChangedSignal("LayoutOrder"):Connect(function()
			cell.LayoutOrder = object.LayoutOrder
		end)
	else
		local anchor, position, size = object.AnchorPoint, object.Position, object.Size
		local shift = Vector2.new(0.5, 0.5) - anchor
		object.AnchorPoint = Vector2.new(0.5, 0.5)
		object.Position = UDim2.new(
			position.X.Scale + size.X.Scale * shift.X,
			position.X.Offset + size.X.Offset * shift.X,
			position.Y.Scale + size.Y.Scale * shift.Y,
			position.Y.Offset + size.Y.Offset * shift.Y
		)
	end
end

-- A diagonal glint that sweeps across the object's face.
function Kit.Shine(object, radius)
	local sheen = object:FindFirstChild("Shine")
	if not sheen then
		sheen = Instance.new("Frame")
		sheen.Name = "Shine"
		sheen.Active = false
		sheen.BackgroundColor3 = White
		sheen.BorderSizePixel = 0
		sheen.Size = UDim2.fromScale(1, 1)
		sheen.ZIndex = object.ZIndex + 8
		corner(sheen, radius or 12)
		local gradient = Instance.new("UIGradient")
		gradient.Name = "Sweep"
		gradient.Rotation = 20
		gradient.Offset = Vector2.new(-1, 0)
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.40, 1),
			NumberSequenceKeypoint.new(0.47, 0.62),
			NumberSequenceKeypoint.new(0.53, 0.62),
			NumberSequenceKeypoint.new(0.60, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = sheen
		sheen.Parent = object
	end
	local gradient = sheen:FindFirstChild("Sweep")
	return function()
		if not gradient or Kit.Reduced() then
			return
		end
		gradient.Offset = Vector2.new(-1, 0)
		tween(
			gradient,
			0.6,
			{ Offset = Vector2.new(1, 0) },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.InOut
		)
	end
end

-- Periodic glint for the one action a screen wants players to notice.
function Kit.AutoShine(object, sweep, every, enabled)
	every = every or 3.2
	task.spawn(function()
		task.wait(0.6 + math.random() * 0.8)
		while object.Parent do
			if not enabled or enabled() then
				sweep()
			end
			task.wait(every)
		end
	end)
end

-- Hover grow, press squish, optional lift, stroke highlight, and hover glint.
-- options: Scale, Press, Lift, Shadow, Stroke, StrokeColor, StrokeGrow,
-- Shine (corner radius), Enabled(), Trigger (input source), Changed(over, down).
function Kit.Hover(object, options)
	options = options or {}
	local trigger = options.Trigger or object
	local scale = Kit.Scale(object)
	local stroke = options.Stroke
	local restThickness = stroke and stroke.Thickness or 0
	local restColor = stroke and stroke.Color
	local sweep = options.Shine and Kit.Shine(object, options.Shine)
	local hovered, pressed = false, false
	local rest
	task.defer(function()
		Kit.CenterPivot(object, options.Shadow)
		rest = object.Position
	end)
	local function live()
		return not options.Enabled or not not options.Enabled()
	end
	local function refresh()
		if not object.Parent then
			return
		end
		local enabled = live()
		local over, down = hovered and enabled, pressed and enabled
		local goal = down and (options.Press or 0.94) or over and (options.Scale or 1.05) or 1
		if Kit.Reduced() then
			scale.Scale = 1
		else
			tween(
				scale,
				down and 0.08 or 0.22,
				{ Scale = goal },
				down and Enum.EasingStyle.Quad or Enum.EasingStyle.Back
			)
			if options.Lift and rest then
				tween(
					object,
					0.2,
					{
						Position = (over and not down)
								and rest + UDim2.fromOffset(0, -options.Lift)
							or rest,
					}
				)
			end
		end
		if stroke then
			tween(
				stroke,
				0.16,
				{
					Thickness = over and restThickness + (options.StrokeGrow or 1) or restThickness,
					Color = over and (options.StrokeColor or restColor) or restColor,
				}
			)
		end
		if options.Changed then
			options.Changed(over, down)
		end
	end
	local function isPress(input)
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end
	trigger.MouseEnter:Connect(function()
		hovered = true
		if sweep and live() then
			sweep()
		end
		refresh()
	end)
	trigger.MouseLeave:Connect(function()
		hovered, pressed = false, false
		refresh()
	end)
	trigger.SelectionGained:Connect(function()
		hovered = true
		refresh()
	end)
	trigger.SelectionLost:Connect(function()
		hovered = false
		refresh()
	end)
	trigger.InputBegan:Connect(function(input)
		if isPress(input) then
			pressed = true
			refresh()
		end
	end)
	trigger.InputEnded:Connect(function(input)
		if isPress(input) then
			pressed = false
			refresh()
		end
	end)
	return scale
end

-- Entrance pop. Call while building; the pivot is fixed after layout settles.
function Kit.Pop(object, delay, from)
	if Kit.Reduced() then
		return
	end
	local scale = Kit.Scale(object)
	scale.Scale = from or 0
	task.defer(function()
		Kit.CenterPivot(object)
		local shadow = object.Parent
			and object.Parent:GetAttribute("MotionCell")
			and object.Parent:FindFirstChild("Shadow")
		local shade = shadow and shadow.BackgroundTransparency
		if shadow then
			shadow.BackgroundTransparency = 1
		end
		task.delay(delay or 0, function()
			if not object.Parent then
				return
			end
			tween(scale, 0.38, { Scale = 1 }, Enum.EasingStyle.Back)
			if shadow then
				tween(shadow, 0.38, { BackgroundTransparency = shade })
			end
		end)
	end)
end

-- Gentle idle bob for art. Call after the object's final Position is set.
function Kit.Float(object, pixels, seconds, phase)
	if Kit.Reduced() then
		return
	end
	local rest = object.Position
	task.delay(phase or 0, function()
		if object.Parent then
			loop(
				object,
				object,
				seconds or 1.8,
				{ Position = rest + UDim2.fromOffset(0, -(pixels or 5)) }
			)
		end
	end)
end

-- Slow scale breathing for badges and call-to-action accents.
function Kit.Breathe(object, amount, seconds)
	if Kit.Reduced() then
		return
	end
	loop(object, Kit.Scale(object), seconds or 0.9, { Scale = amount or 1.06 })
end

-- Soft outer glow drawn behind the object's main outline. Returns nil on
-- engines without layered border strokes so nothing covers the real outline.
function Kit.Glow(object, color, thickness, pulse)
	local glow = Instance.new("UIStroke")
	glow.Name = "Glow"
	glow.Color = color
	glow.Thickness = thickness or 5
	glow.Transparency = 0.45
	glow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local layered = pcall(function()
		glow.BorderStrokePosition = Enum.BorderStrokePosition.Outer
		glow.ZIndex = 0
	end)
	if not layered then
		glow:Destroy()
		return nil
	end
	glow.Parent = object
	if pulse ~= false and not Kit.Reduced() then
		loop(object, glow, 0.85, { Transparency = 0.85 })
	end
	return glow
end

-- Thin inner highlight rim for glossy surfaces.
function Kit.Gloss(object, transparency)
	local rim = Instance.new("UIStroke")
	rim.Name = "Gloss"
	rim.Color = White
	rim.Thickness = 1.5
	rim.Transparency = transparency or 0.5
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local layered = pcall(function()
		rim.BorderStrokePosition = Enum.BorderStrokePosition.Inner
		rim.ZIndex = 2
	end)
	if not layered then
		rim:Destroy()
		return nil
	end
	rim.Parent = object
	return rim
end

-- Progress fills grow in from empty. Call after the fill's final Size is set.
function Kit.Grow(bar, delay)
	if Kit.Reduced() then
		return
	end
	local goal = bar.Size
	bar.Size = UDim2.new(0, 0, goal.Y.Scale, goal.Y.Offset)
	task.delay(delay or 0, function()
		if bar.Parent then
			tween(bar, 0.6, { Size = goal }, Enum.EasingStyle.Quart)
		end
	end)
end

-- Turntable sway for golem portraits: rotates the model about its own center
-- so the fitted camera framing never drifts.
function Kit.Sway(viewport, degrees, seconds)
	if Kit.Reduced() or not viewport then
		return
	end
	local world = viewport:FindFirstChildWhichIsA("WorldModel")
	local model = world and world:FindFirstChildWhichIsA("Model")
	if not model then
		return
	end
	-- Yaw about the point the camera was fitted to, which is the body center.
	-- The full bounding box sits higher once hats are included, and turning
	-- around that point drops the body to the bottom of the card.
	local swing, period = math.rad(degrees or 20), seconds or 5.5
	local started = os.clock()
	local center, rest
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not model.Parent or not viewport.Parent then
			connection:Disconnect()
			return
		end
		if not viewport.Visible then
			return
		end
		-- Wait for the portrait fit. Turning before that uses the default
		-- camera and drops the body to the bottom of the card.
		local marked = viewport:GetAttribute("FitCenter")
		if typeof(marked) ~= "Vector3" then
			return
		end
		if not rest then
			center = CFrame.new(marked)
			rest = center:Inverse() * model:GetPivot()
			started = os.clock()
		end
		local yaw = math.sin((os.clock() - started) * math.pi * 2 / period) * swing
		model:PivotTo(center * CFrame.Angles(0, yaw, 0) * rest)
	end)
	viewport.Destroying:Connect(function()
		connection:Disconnect()
	end)
end

return Kit
