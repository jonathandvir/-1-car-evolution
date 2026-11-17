-- Our own chunky icons, drawn from UI shapes so they scale cleanly and need no image
-- uploads. Icons.make(name, props) returns a transparent Frame holding the drawing;
-- every shape is placed in 0-1 scale inside it.
local Icons = {}

local INK = Color3.fromRGB(22, 22, 32)

local function shape(parent, x, y, w, h, color, props)
	props = props or {}
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.BackgroundColor3 = color
	f.Rotation = props.Rotation or 0
	f.BackgroundTransparency = props.Transparency or 0
	f.ZIndex = props.ZIndex or 1
	if props.Radius ~= false then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = props.Radius or UDim.new(0.2, 0)
		corner.Parent = f
	end
	if props.Stroke ~= false then
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = props.Stroke or 2
		stroke.Color = props.StrokeColor or INK
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = f
	end
	if props.Gradient then
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(props.Gradient[1], props.Gradient[2])
		g.Rotation = props.GradientRotation or 90
		g.Parent = f
		f.BackgroundColor3 = Color3.new(1, 1, 1)
	end
	f.Parent = parent
	return f
end

local function ring(parent, x, y, w, h, color, thickness, zIndex)
	local f = shape(parent, x, y, w, h, color, { Transparency = 1, Radius = UDim.new(1, 0), Stroke = false, ZIndex = zIndex })
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	stroke.Color = color
	stroke.Parent = f
	return f
end

local function text(parent, x, y, w, h, value, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(x, y)
	label.Size = UDim2.fromScale(w, h)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.Text = value
	label.TextColor3 = color
	label.ZIndex = 5
	label.Parent = parent
	return label
end

local GOLD = { Color3.fromRGB(255, 226, 80), Color3.fromRGB(240, 150, 20) }

local draw = {}

function draw.Trophy(f)
	-- handles behind the cup
	ring(f, 0.06, 0.16, 0.26, 0.26, Color3.fromRGB(240, 170, 30), 4)
	ring(f, 0.68, 0.16, 0.26, 0.26, Color3.fromRGB(240, 170, 30), 4)
	shape(f, 0.2, 0.1, 0.6, 0.44, GOLD[1], { Gradient = GOLD, Radius = UDim.new(0.45, 0), ZIndex = 2 })
	shape(f, 0.16, 0.07, 0.68, 0.11, Color3.fromRGB(255, 240, 150), { Radius = UDim.new(0.5, 0), ZIndex = 3 })
	text(f, 0.36, 0.17, 0.28, 0.3, "1", Color3.fromRGB(200, 110, 10))
	shape(f, 0.44, 0.52, 0.12, 0.16, GOLD[2], { Radius = UDim.new(0.1, 0), ZIndex = 2 })
	shape(f, 0.3, 0.64, 0.4, 0.1, GOLD[1], { Gradient = GOLD, ZIndex = 3 })
	shape(f, 0.22, 0.73, 0.56, 0.16, Color3.fromRGB(150, 85, 40), { Gradient = { Color3.fromRGB(180, 110, 55), Color3.fromRGB(120, 65, 30) }, ZIndex = 3 })
end

function draw.Book(f)
	shape(f, 0.2, 0.16, 0.66, 0.74, Color3.fromRGB(25, 70, 160), { Radius = UDim.new(0.12, 0) })
	shape(f, 0.24, 0.18, 0.58, 0.66, Color3.fromRGB(250, 250, 255), { Radius = UDim.new(0.08, 0), ZIndex = 2 })
	local cover = shape(f, 0.14, 0.08, 0.62, 0.74, Color3.new(1, 1, 1), { Gradient = { Color3.fromRGB(90, 170, 255), Color3.fromRGB(40, 110, 230) }, Radius = UDim.new(0.12, 0), ZIndex = 3 })
	cover.Name = "Cover"
	shape(f, 0.14, 0.08, 0.1, 0.74, Color3.fromRGB(30, 85, 190), { Radius = UDim.new(0.3, 0), Stroke = false, ZIndex = 4 })
	shape(f, 0.32, 0.3, 0.34, 0.12, Color3.fromRGB(220, 240, 255), { Radius = UDim.new(0.5, 0), Stroke = 1.5, ZIndex = 4 })
	shape(f, 0.36, 0.5, 0.26, 0.06, Color3.fromRGB(200, 225, 255), { Radius = UDim.new(0.5, 0), Stroke = false, ZIndex = 4 })
end

function draw.Rebirth(f)
	shape(f, 0.1, 0.1, 0.8, 0.8, Color3.new(1, 1, 1), { Gradient = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 190, 230) }, Radius = UDim.new(1, 0) })
	ring(f, 0.27, 0.27, 0.46, 0.46, Color3.fromRGB(215, 40, 120), 5, 2)
	-- the gap and arrow tip that turn the ring into a loop arrow
	shape(f, 0.56, 0.2, 0.18, 0.18, Color3.fromRGB(255, 240, 248), { Radius = UDim.new(0.2, 0), Stroke = false, ZIndex = 3, Rotation = 45 })
	shape(f, 0.5, 0.16, 0.2, 0.2, Color3.fromRGB(215, 40, 120), { Radius = UDim.new(0.15, 0), Stroke = false, ZIndex = 4, Rotation = 45 })
	shape(f, 0.42, 0.42, 0.16, 0.16, Color3.fromRGB(255, 120, 190), { Radius = UDim.new(1, 0), Stroke = 1.5, ZIndex = 4 })
end

function draw.Trails(f)
	local colors = { Color3.fromRGB(120, 230, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 140, 255) }
	for i, c in colors do
		shape(f, 0.06 + i * 0.04, 0.2 + i * 0.16, 0.5 - i * 0.06, 0.1, c, { Radius = UDim.new(0.5, 0), Rotation = -18, ZIndex = 2 })
	end
	-- a four-point sparkle at the front
	shape(f, 0.56, 0.22, 0.14, 0.5, Color3.fromRGB(255, 230, 80), { Radius = UDim.new(0.5, 0), ZIndex = 3 })
	shape(f, 0.38, 0.4, 0.5, 0.14, Color3.fromRGB(255, 230, 80), { Radius = UDim.new(0.5, 0), ZIndex = 3 })
	shape(f, 0.56, 0.4, 0.14, 0.14, Color3.fromRGB(255, 255, 220), { Radius = UDim.new(1, 0), Stroke = false, ZIndex = 4 })
end

function draw.Calendar(f)
	shape(f, 0.12, 0.2, 0.76, 0.7, Color3.fromRGB(255, 255, 255), { Radius = UDim.new(0.14, 0) })
	shape(f, 0.12, 0.2, 0.76, 0.24, Color3.new(1, 1, 1), { Gradient = { Color3.fromRGB(255, 100, 100), Color3.fromRGB(215, 40, 50) }, Radius = UDim.new(0.25, 0), ZIndex = 2 })
	shape(f, 0.28, 0.1, 0.1, 0.2, Color3.fromRGB(70, 70, 90), { Radius = UDim.new(0.5, 0), Stroke = 1.5, ZIndex = 3 })
	shape(f, 0.62, 0.1, 0.1, 0.2, Color3.fromRGB(70, 70, 90), { Radius = UDim.new(0.5, 0), Stroke = 1.5, ZIndex = 3 })
	text(f, 0.2, 0.46, 0.6, 0.4, "31", Color3.fromRGB(40, 40, 60))
end

function draw.Gauge(f)
	shape(f, 0.08, 0.08, 0.84, 0.84, Color3.new(1, 1, 1), { Gradient = { Color3.fromRGB(70, 75, 100), Color3.fromRGB(30, 32, 50) }, Radius = UDim.new(1, 0), Stroke = 2.5 })
	ring(f, 0.2, 0.2, 0.6, 0.6, Color3.fromRGB(80, 220, 255), 4, 2)
	-- red zone over the top-right of the dial
	shape(f, 0.6, 0.18, 0.16, 0.16, Color3.fromRGB(255, 70, 70), { Radius = UDim.new(1, 0), Stroke = false, ZIndex = 3 })
	-- needle pointing up to the right
	local needle = shape(f, 0.47, 0.22, 0.07, 0.32, Color3.fromRGB(255, 80, 60), { Radius = UDim.new(0.5, 0), Stroke = 1.5, ZIndex = 4, Rotation = 40 })
	needle.AnchorPoint = Vector2.new(0, 0)
	shape(f, 0.41, 0.41, 0.18, 0.18, Color3.fromRGB(240, 240, 250), { Radius = UDim.new(1, 0), Stroke = 2, ZIndex = 5 })
end

function draw.Bolt(f)
	local yellow = { Color3.fromRGB(255, 240, 90), Color3.fromRGB(250, 170, 20) }
	shape(f, 0.4, 0.04, 0.24, 0.5, yellow[1], { Gradient = yellow, Radius = UDim.new(0.15, 0), Rotation = 22, Stroke = 2.5 })
	shape(f, 0.28, 0.4, 0.46, 0.16, yellow[1], { Gradient = yellow, Radius = UDim.new(0.3, 0), Rotation = -8, Stroke = 2.5, ZIndex = 2 })
	shape(f, 0.36, 0.46, 0.22, 0.5, yellow[2], { Gradient = yellow, Radius = UDim.new(0.15, 0), Rotation = 22, Stroke = 2.5, ZIndex = 3 })
	-- hide the seams where the pieces meet
	shape(f, 0.36, 0.42, 0.3, 0.12, yellow[1], { Radius = UDim.new(0.3, 0), Rotation = -8, Stroke = false, ZIndex = 4 })
end

function draw.Gift(f)
	shape(f, 0.14, 0.38, 0.72, 0.52, Color3.new(1, 1, 1), { Gradient = { Color3.fromRGB(110, 230, 120), Color3.fromRGB(40, 170, 70) }, Radius = UDim.new(0.12, 0) })
	shape(f, 0.1, 0.26, 0.8, 0.18, Color3.fromRGB(120, 240, 130), { Radius = UDim.new(0.2, 0), ZIndex = 2 })
	shape(f, 0.43, 0.26, 0.14, 0.64, Color3.fromRGB(255, 70, 80), { Radius = UDim.new(0.1, 0), Stroke = false, ZIndex = 3 })
	shape(f, 0.28, 0.1, 0.2, 0.18, Color3.fromRGB(255, 70, 80), { Radius = UDim.new(0.5, 0), ZIndex = 3, Rotation = -25 })
	shape(f, 0.52, 0.1, 0.2, 0.18, Color3.fromRGB(255, 70, 80), { Radius = UDim.new(0.5, 0), ZIndex = 3, Rotation = 25 })
end

-- a shopping cart with a green basket
function draw.Cart(f)
	local green = { Color3.fromRGB(130, 245, 110), Color3.fromRGB(40, 175, 60) }
	shape(f, 0.04, 0.16, 0.2, 0.09, Color3.fromRGB(230, 232, 240), { Radius = UDim.new(0.5, 0), Rotation = 12 })
	shape(f, 0.18, 0.26, 0.72, 0.4, green[1], { Gradient = green, Radius = UDim.new(0.16, 0), ZIndex = 2 })
	for i = 0, 2 do
		shape(f, 0.3 + i * 0.2, 0.32, 0.07, 0.28, Color3.fromRGB(30, 140, 50), { Radius = UDim.new(0.5, 0), Stroke = false, ZIndex = 3 })
	end
	shape(f, 0.22, 0.66, 0.62, 0.08, Color3.fromRGB(230, 232, 240), { Radius = UDim.new(0.5, 0), ZIndex = 2 })
	for _, x in { 0.24, 0.66 } do
		shape(f, x, 0.72, 0.17, 0.17, Color3.fromRGB(60, 62, 80), { Radius = UDim.new(1, 0), ZIndex = 3 })
	end
end

-- a red Horsepower can with a yellow bolt label
function draw.Can(f)
	local red = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(200, 30, 45) }
	shape(f, 0.36, 0.04, 0.26, 0.16, Color3.fromRGB(70, 72, 90), { Radius = UDim.new(0.2, 0) })
	shape(f, 0.2, 0.14, 0.6, 0.78, red[1], { Gradient = red, Radius = UDim.new(0.18, 0), ZIndex = 2 })
	shape(f, 0.2, 0.36, 0.6, 0.3, Color3.fromRGB(255, 225, 70), { Radius = UDim.new(0.05, 0), Stroke = 1.5, ZIndex = 3 })
	text(f, 0.24, 0.36, 0.52, 0.3, "HP", Color3.fromRGB(190, 30, 40))
	shape(f, 0.26, 0.18, 0.1, 0.14, Color3.fromRGB(255, 170, 170), { Radius = UDim.new(0.5, 0), Stroke = false, ZIndex = 3 })
end

-- a gold crown with gems
function draw.Crown(f)
	shape(f, 0.12, 0.42, 0.76, 0.4, GOLD[1], { Gradient = GOLD, Radius = UDim.new(0.12, 0), ZIndex = 2 })
	for i, x in { 0.1, 0.4, 0.7 } do
		shape(f, x, if i == 2 then 0.12 else 0.2, 0.2, 0.4, GOLD[1], { Gradient = GOLD, Radius = UDim.new(0.3, 0), Rotation = (i - 2) * 14 })
		shape(f, x + 0.04, if i == 2 then 0.06 else 0.14, 0.12, 0.12, Color3.fromRGB(255, 245, 170), { Radius = UDim.new(1, 0), ZIndex = 3 })
	end
	shape(f, 0.12, 0.72, 0.76, 0.1, Color3.fromRGB(220, 130, 20), { Radius = UDim.new(0.3, 0), Stroke = false, ZIndex = 3 })
	shape(f, 0.42, 0.5, 0.16, 0.16, Color3.fromRGB(255, 60, 90), { Radius = UDim.new(0.3, 0), Rotation = 45, ZIndex = 4 })
	shape(f, 0.2, 0.53, 0.11, 0.11, Color3.fromRGB(80, 200, 255), { Radius = UDim.new(1, 0), ZIndex = 4 })
	shape(f, 0.69, 0.53, 0.11, 0.11, Color3.fromRGB(80, 200, 255), { Radius = UDim.new(1, 0), ZIndex = 4 })
end

-- a gold treadmill: belt, rail and console
function draw.Treadmill(f)
	shape(f, 0.06, 0.62, 0.88, 0.2, GOLD[1], { Gradient = GOLD, Radius = UDim.new(0.3, 0) })
	shape(f, 0.12, 0.56, 0.64, 0.1, Color3.fromRGB(50, 52, 66), { Radius = UDim.new(0.4, 0), ZIndex = 2 })
	shape(f, 0.68, 0.14, 0.1, 0.5, GOLD[2], { Gradient = GOLD, Radius = UDim.new(0.4, 0), Rotation = 12, ZIndex = 2 })
	shape(f, 0.56, 0.08, 0.36, 0.16, Color3.fromRGB(60, 62, 80), { Radius = UDim.new(0.25, 0), ZIndex = 3 })
	shape(f, 0.6, 0.11, 0.24, 0.08, Color3.fromRGB(120, 230, 255), { Radius = UDim.new(0.3, 0), Stroke = false, ZIndex = 4 })
	shape(f, 0.2, 0.3, 0.12, 0.12, Color3.fromRGB(255, 250, 200), { Radius = UDim.new(0.2, 0), Rotation = 45, Stroke = false, ZIndex = 4 })
	shape(f, 0.36, 0.18, 0.08, 0.08, Color3.fromRGB(255, 250, 200), { Radius = UDim.new(0.2, 0), Rotation = 45, Stroke = false, ZIndex = 4 })
end

-- the Robux mark on price buttons: a white rounded frame with a little square in the middle
function draw.Robux(f)
	shape(f, 0.06, 0.06, 0.88, 0.88, Color3.new(1, 1, 1), { Radius = UDim.new(0.32, 0), Stroke = 1.5, ZIndex = 2 })
	shape(f, 0.24, 0.24, 0.52, 0.52, Color3.fromRGB(45, 165, 60), { Radius = UDim.new(0.22, 0), Stroke = false, ZIndex = 3 })
	shape(f, 0.37, 0.37, 0.26, 0.26, Color3.new(1, 1, 1), { Radius = UDim.new(0.15, 0), Stroke = false, ZIndex = 4 })
end

function Icons.make(name, props)
	local f = Instance.new("Frame")
	f.Name = name .. "Icon"
	f.BackgroundTransparency = 1
	f.Size = props.Size or UDim2.fromScale(1, 1)
	f.Position = props.Position or UDim2.new()
	f.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	f.Rotation = props.Rotation or 0
	f.ZIndex = props.ZIndex or 1
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = f
	draw[name](f)
	f.Parent = props.Parent
	return f
end

return Icons

