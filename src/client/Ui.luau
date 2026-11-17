-- The UI kit: clean, flat simulator style. Rounded bold mixed-case text with a thin
-- dark outline, flat buttons with a thin outline. Sizes are in pixels for a
-- 1366x720 screen and scaled to the real screen by Ui.scaled.
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Ui = {}

-- one quiet tick for every button press
local pressSound = Instance.new("Sound")
pressSound.Name = "ButtonPress"
pressSound.SoundId = "rbxassetid://17779566040"
pressSound.Volume = 0.25
pressSound.PlaybackSpeed = 1.2
pressSound.Parent = SoundService

Ui.Font = Enum.Font.GothamBlack
Ui.Ink = Color3.fromRGB(22, 22, 32)
Ui.Yellow = Color3.fromRGB(255, 222, 50)
Ui.Gold = Color3.fromRGB(255, 196, 40)

function Ui.new(class, props, children)
	local inst = Instance.new(class)
	for k, v in props or {} do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function Ui.corner(px)
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, px or 10) })
end

function Ui.stroke(thickness, color)
	return Ui.new("UIStroke", { Thickness = thickness or 2.5, Color = color or Ui.Ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function Ui.gradient(top, bottom)
	return Ui.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90 })
end

-- Outlined text. Extra prop: StrokeThickness
function Ui.label(props)
	local label = Ui.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Ui.Font,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		Text = "",
	})
	for k, v in props do
		if k ~= "Parent" and k ~= "StrokeThickness" then
			label[k] = v
		end
	end
	Ui.new("UIStroke", { Thickness = props.StrokeThickness or 2, Color = Ui.Ink, Parent = label })
	label.Parent = props.Parent
	return label
end

-- A flat panel: solid colour (soft top-to-bottom shade), thin outline, rounded corners
function Ui.panel(props)
	local panel = Ui.new("Frame", {
		Name = props.Name or "Panel",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Visible = if props.Visible == nil then true else props.Visible,
		Parent = props.Parent,
	}, {
		Ui.corner(props.Radius or 12),
		Ui.stroke(props.StrokeThickness or 3),
		Ui.gradient(props.Top, props.Bottom or props.Top),
	})
	return panel
end

-- A flat button that dips slightly when pressed. Label is its text.
function Ui.button(props)
	local button = Ui.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	}, {
		Ui.corner(props.Radius or 10),
		Ui.stroke(props.StrokeThickness or 3),
		Ui.gradient(props.Top, props.Bottom or props.Top),
	})
	if props.Text then
		Ui.label({
			Name = "Label",
			Text = props.Text,
			Size = props.TextSize or UDim2.fromScale(0.84, 0.62),
			Position = props.TextPosition or UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			StrokeThickness = props.TextStroke or 2,
			Parent = button,
		})
	end
	local scale = Ui.new("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		pressSound:Play()
		TweenService:Create(scale, TweenInfo.new(0.05), { Scale = 0.94 }):Play()
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	return button
end

function Ui.recolor(button, top, bottom)
	button.UIGradient.Color = ColorSequence.new(top, bottom or top)
end

function Ui.pop(instance, amount)
	local scale = instance:FindFirstChild("PopScale") or Ui.new("UIScale", { Name = "PopScale", Parent = instance })
	scale.Scale = amount or 1.12
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Groups are laid out in pixels for a 720-pixel-tall screen; this keeps them the same
-- share of the screen on phones, tablets and big monitors.
local scaled = {}
local function screenScale()
	local camera = workspace.CurrentCamera
	local height = if camera then camera.ViewportSize.Y else 720
	return math.clamp(height / 650, 0.6, 1.5)
end
function Ui.scaled(group)
	local scale = Ui.new("UIScale", { Name = "ScreenScale", Scale = screenScale(), Parent = group })
	table.insert(scaled, scale)
	return group
end
task.spawn(function()
	local camera = workspace.CurrentCamera or workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
	camera = workspace.CurrentCamera
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		for _, scale in scaled do
			scale.Scale = screenScale()
		end
	end)
end)

return Ui
