-- The on-screen HUD, laid out like a classic simulator:
--   top left: Wins; left: a 2x2 grid of square buttons (Index, Rebirth, Shop, Daily)
--   top middle: the tutorial step card; right: pass offers (x2 Wins, x2 Horsepower, Fast Training)
--   bottom: "Horsepower: N" over the level bar, with the Horsepower pack buttons under it.
-- Sizes are pixels for a 650-pixel-tall screen; Ui.scaled resizes each group to the real screen.
-- Index is the car collection. Purchases go to the server (Server.Store), which checks them.
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CarLooks = require(ReplicatedStorage.Shared.CarLooks)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Icons = require(script.Parent.Parent.Icons)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local gui = Ui.new("ScreenGui", { Name = "Hud", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

local clickSound = Ui.new("Sound", { SoundId = "rbxassetid://17779566040", Volume = 0.5, Parent = SoundService })
local critSound = Ui.new("Sound", { SoundId = "rbxassetid://6586979979", Volume = 0.8, Parent = SoundService })
local winSound = Ui.new("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, PlaybackSpeed = 1.6, Parent = SoundService })
-- soft extras: an airy whoosh as the car sets off (and, lower, when it falls) and a light thump on landing
local whooshSound = Ui.new("Sound", { SoundId = "rbxassetid://9113840530", Volume = 0.35, Parent = SoundService })
local fallSound = Ui.new("Sound", { SoundId = "rbxassetid://9113840096", Volume = 0.3, PlaybackSpeed = 0.75, Parent = SoundService })
local landSound = Ui.new("Sound", { SoundId = "rbxassetid://9113551773", Volume = 0.3, PlaybackSpeed = 1.15, Parent = SoundService })

local CYAN = "#46CDFF"

local function group(props)
	return Ui.scaled(Ui.new("Frame", { BackgroundTransparency = 1, Name = props.Name, Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, Parent = gui }))
end

-- Faint lighter studs in a row, for that toy-brick texture on bars and buttons
local function studRow(parent, count, y)
	local row = Ui.new("Frame", { Name = "Studs", BackgroundTransparency = 1, Size = UDim2.new(1, -14, 0, 6), Position = UDim2.fromOffset(7, y or 5), Parent = parent }, {
		Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 12), VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
	for _ = 1, count do
		Ui.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.78, Size = UDim2.fromOffset(8, 5), Parent = row }, { Ui.corner(2) })
	end
	return row
end

---------------------------------------------------------------- Wins, top left
local winsGroup = group({ Name = "Wins", Size = UDim2.fromOffset(156, 60), Position = UDim2.fromOffset(6, 160) })
Ui.new("Frame", { Name = "Pill", BackgroundColor3 = Color3.fromRGB(16, 40, 24), BackgroundTransparency = 0.3, Size = UDim2.fromOffset(128, 42), Position = UDim2.fromOffset(26, 9), Parent = winsGroup }, { Ui.corner(10) })
Icons.make("Trophy", { Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(0, 0), ZIndex = 2, Parent = winsGroup })
local winsLabel = Ui.label({ Text = "0", TextColor3 = Ui.Yellow, Size = UDim2.fromOffset(84, 30), Position = UDim2.fromOffset(64, 15), StrokeThickness = 2.5, Parent = winsGroup })

---------------------------------------------------------------- left grid of square buttons
local grid = group({ Name = "Menu", Size = UDim2.fromOffset(160, 160), Position = UDim2.fromOffset(4, 250) })
local MENU = {
	{ Name = "Index", Icon = "Book", Colors = { Color3.fromRGB(70, 200, 255), Color3.fromRGB(30, 130, 230) } },
	{ Name = "Rebirth", Icon = "Rebirth", Colors = { Color3.fromRGB(230, 90, 255), Color3.fromRGB(150, 40, 210) } },
	{ Name = "Shop", Icon = "Cart", Colors = { Color3.fromRGB(120, 240, 100), Color3.fromRGB(40, 175, 60) } },
	{ Name = "Daily", Icon = "Calendar", Colors = { Color3.fromRGB(255, 220, 70), Color3.fromRGB(245, 160, 20) }, Badge = true },
}
local menuButtons = {}
for i, item in MENU do
	local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
	local button = Ui.button({ Size = UDim2.fromOffset(76, 76), Position = UDim2.fromOffset(col * 82, row * 82), Radius = 8, Top = item.Colors[1], Bottom = item.Colors[2], Parent = grid })
	Icons.make(item.Icon, { Size = UDim2.fromScale(0.74, 0.74), Position = UDim2.fromScale(0.5, 0.4), AnchorPoint = Vector2.new(0.5, 0.5), Parent = button })
	Ui.label({ Text = item.Name, Size = UDim2.new(1, 4, 0, 19), Position = UDim2.new(0.5, 0, 1, -2), AnchorPoint = Vector2.new(0.5, 1), StrokeThickness = 2, Parent = button })
	if item.Badge then
		local badge = Ui.new("Frame", { Name = "Badge", BackgroundColor3 = Color3.fromRGB(240, 40, 50), Size = UDim2.fromOffset(12, 22), Position = UDim2.new(1, 0, 0, -6), AnchorPoint = Vector2.new(0.5, 0), Parent = button }, { Ui.corner(4), Ui.stroke(2) })
		Ui.label({ Text = "!", Size = UDim2.fromScale(1, 1), StrokeThickness = 1.5, Parent = badge })
	end
	menuButtons[item.Name] = button
end

---------------------------------------------------------------- tutorial card, top middle
local tutorial = group({ Name = "Tutorial", Size = UDim2.fromOffset(300, 92), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0) })
local card = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(14, 16, 22), BackgroundTransparency = 0.12, Size = UDim2.fromScale(1, 1), Parent = tutorial }, { Ui.corner(8), Ui.stroke(2, Color3.fromRGB(40, 44, 56)) })
Ui.label({ Text = "Build 3 roads!", TextColor3 = Ui.Yellow, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(200, 22), Position = UDim2.fromOffset(12, 7), StrokeThickness = 0, Parent = card })
local tutorialText = Ui.label({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextScaled = false, TextSize = 13, Size = UDim2.fromOffset(276, 36), Position = UDim2.fromOffset(12, 31), StrokeThickness = 0, Parent = card })
tutorialText.Text = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	then "Go through the Stage 1 wall, then tap ROAD to build a road. Drag to steer."
	else "Go through the Stage 1 wall, then click ROAD or press Space. Mouse steers."
local stepBar = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(200, 204, 212), Size = UDim2.fromOffset(276, 16), Position = UDim2.fromOffset(12, 68), Parent = card }, { Ui.corner(4), Ui.stroke(1.5, Color3.fromRGB(30, 30, 40)) })
local stepFill = Ui.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0, 1), Parent = stepBar }, { Ui.corner(4), Ui.gradient(Color3.fromRGB(190, 255, 40), Color3.fromRGB(110, 210, 20)) })
local stepCount = Ui.label({ Text = "0/3", TextColor3 = Color3.fromRGB(30, 30, 40), Size = UDim2.fromScale(1, 0.85), Position = UDim2.fromScale(0, 0.08), StrokeThickness = 0, ZIndex = 2, Parent = stepBar })

---------------------------------------------------------------- pass offers, right
local passes = group({ Name = "Passes", Size = UDim2.fromOffset(214, 212), Position = UDim2.new(1, -10, 0.5, -20), AnchorPoint = Vector2.new(1, 0.5) })
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 80)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 90)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 80, 255)),
})
local OFFERS = {
	{ Key = "DoubleWins", Text = "x2 Wins", Icon = "Trophy", Top = Color3.fromRGB(255, 232, 80), Bottom = Color3.fromRGB(245, 175, 20) },
	{ Key = "DoubleHorsepower", Text = "x2 Horsepower", Icon = "Gauge", Rainbow = true },
	{ Key = "FastTraining", Text = "Fast Training", Icon = "Bolt", Top = Color3.fromRGB(80, 215, 255), Bottom = Color3.fromRGB(30, 140, 235) },
}
local offerButtons = {}
for i, offer in OFFERS do
	local button = Ui.button({ Size = UDim2.fromOffset(196, 54), Position = UDim2.fromOffset(18, (i - 1) * 72 + 6), Radius = 8, Top = offer.Top or Color3.new(1, 1, 1), Bottom = offer.Bottom, Parent = passes })
	if offer.Rainbow then
		button.UIGradient.Color = RAINBOW
		button.UIGradient.Rotation = 0
	end
	studRow(button, 9, 4)
	Icons.make(offer.Icon, { Size = UDim2.fromOffset(62, 62), Position = UDim2.fromOffset(-20, -4), ZIndex = 2, Parent = button })
	Ui.label({ Text = offer.Text, Size = UDim2.fromOffset(140, 30), Position = UDim2.fromOffset(48, 12), StrokeThickness = 2.5, Parent = button })
	button.Name = offer.Key
	offerButtons[offer.Key] = button
end

---------------------------------------------------------------- level bar
local BAR_W, BAR_H = 456, 43
local bottom = group({ Name = "Bottom", Size = UDim2.fromOffset(BAR_W, 74), Position = UDim2.new(0.5, 0, 1, -58), AnchorPoint = Vector2.new(0.5, 1) })
local powerLabel = Ui.label({ Text = "", RichText = true, Size = UDim2.fromOffset(BAR_W, 26), StrokeThickness = 2.5, Parent = bottom })
local BAR_INK = Color3.fromRGB(20, 32, 48)
local bar = Ui.new("Frame", { Name = "LevelBar", BackgroundColor3 = Color3.fromRGB(196, 201, 209), Size = UDim2.fromOffset(BAR_W, BAR_H), Position = UDim2.fromOffset(0, 31), Parent = bottom }, { Ui.corner(6), Ui.stroke(3, BAR_INK) })
local barStuds = studRow(bar, 20, 6)
for _, stud in barStuds:GetChildren() do
	if stud:IsA("Frame") then
		stud.BackgroundTransparency = 0.55
	end
end
local fill = Ui.new("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0, 1), ZIndex = 2, Parent = bar }, {
	Ui.corner(6),
	Ui.gradient(Color3.fromRGB(60, 205, 250), Color3.fromRGB(30, 170, 235)),
})
Ui.new("Frame", { Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.75, Size = UDim2.new(1, -6, 0.32, 0), Position = UDim2.new(0, 3, 0, 3), ZIndex = 2, Parent = fill }, { Ui.corner(4) })
local levelText = Ui.label({ Text = "Level 1", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(200, 30), Position = UDim2.fromOffset(12, 6), ZIndex = 3, StrokeThickness = 2.5, Parent = bar })
local progressText = Ui.label({ Text = "0 / 10", TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(200, 30), Position = UDim2.new(1, -212, 0, 6), ZIndex = 3, StrokeThickness = 2.5, Parent = bar })

---------------------------------------------------------------- Horsepower product buttons, bottom
local PRODUCTS = {
	-- each shows what its Horsepower pack gives you right now (it grows with your boosts)
	{ Key = "PackSmall", Width = 108, Top = Color3.fromRGB(255, 220, 60), Bottom = Color3.fromRGB(250, 160, 20) },
	{ Key = "PackMedium", Width = 124, Top = Color3.fromRGB(70, 200, 255), Bottom = Color3.fromRGB(25, 130, 235) },
	{ Key = "PackBig", Width = 140, Top = Color3.fromRGB(255, 80, 140), Bottom = Color3.fromRGB(220, 30, 80) },
	{ Key = "PackHuge", Width = 156, Top = Color3.fromRGB(200, 90, 255), Bottom = Color3.fromRGB(130, 40, 220) },
}
local rowWidth = -6
for _, p in PRODUCTS do
	rowWidth += p.Width + 6
end
local productRow = group({ Name = "Products", Size = UDim2.fromOffset(rowWidth, 44), Position = UDim2.new(0.5, 0, 1, -9), AnchorPoint = Vector2.new(0.5, 1) })
local productButtons = {}
local x = 0
for _, p in PRODUCTS do
	local button = Ui.button({ Size = UDim2.fromOffset(p.Width, 44), Position = UDim2.fromOffset(x, 0), Radius = 7, Top = p.Top, Bottom = p.Bottom, Parent = productRow })
	studRow(button, math.floor(p.Width / 22), 4)
	Ui.label({ Name = "Amount", Text = "+0 HP", Size = UDim2.new(1, -14, 0, 26), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 2.5, Parent = button })
	button.Name = p.Key
	productButtons[p.Key] = button
	x += p.Width + 6
end

---------------------------------------------------------------- building roads (click anywhere, Space or E)
local lastClickAt = Vector2.new(0, 0)

local function floatText(text, at, color, size, rise)
	local label = Ui.label({ Text = text, TextColor3 = color or Ui.Yellow, Size = size or UDim2.fromOffset(110, 34), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y), ZIndex = 5, Parent = gui })
	local time = if rise then 1.1 else 0.8
	TweenService:Create(label, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(at.X + math.random(-40, 40), at.Y - (rise or 90)), TextTransparency = 1 }):Play()
	TweenService:Create(label.UIStroke, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	task.delay(time, label.Destroy, label)
	return label
end

local function ripple(at)
	local ring = Ui.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y), Size = UDim2.fromOffset(20, 20), Parent = gui }, {
		Ui.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		Ui.new("UIStroke", { Thickness = 4, Color = Ui.Yellow }),
	})
	TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(90, 90) }):Play()
	TweenService:Create(ring.UIStroke, TweenInfo.new(0.4), { Transparency = 1, Thickness = 1 }):Play()
	task.delay(0.4, ring.Destroy, ring)
end

-- The tutorial: build 3 roads. Counts up on the card's bar, then the card slides away.
local TUTORIAL_CLICKS = 3
local tutorialClicks = 0
local function countTutorialClick()
	if tutorialClicks >= TUTORIAL_CLICKS then
		return
	end
	tutorialClicks += 1
	local text = tutorialClicks .. "/" .. TUTORIAL_CLICKS
	stepCount.Text = text
	TweenService:Create(stepFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(tutorialClicks / TUTORIAL_CLICKS, 1) }):Play()
	if tutorialClicks == TUTORIAL_CLICKS then
		-- the card says well done, then slides away (it never sat there finished forever)
		tutorialText.Text = "Nice driving! Reach the Wins pads at the end of each stage."
		task.delay(4, function()
			local away = TweenService:Create(tutorial.ScreenScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
			away.Completed:Connect(function()
				tutorial.Visible = false
			end)
			away:Play()
		end)
	end
end

local showToast -- the toast popup, set further down
local dailyCards = {} -- [day] = the Daily menu's card parts, built further down

-- Road mode: the ROAD button (or Space, or a click/tap) starts it, in two phases.
--   Build: the camera rides on the road's tip, which shoots forward toward wherever the
--     camera points (move the mouse or drag a finger to steer left/right and up/down),
--     using up the Road meter. The car waits.
--   Drive: once the tip meets solid ground (or the meter runs out) the camera drops back
--     behind the car, which drives itself along the road's curves. The meter still shows the
--     road left to build, and fills back up on landing. On solid ground at the end it lands (flip, burst, road gone); otherwise it
--     drives off the end and falls.
-- Space again while building finishes the road and drives; STOP ends road mode. Clicks and
-- taps while driving do nothing (a tap is also how phones steer).
local buildRemote = remotes:WaitForChild("BuildRoad")
-- Roblox's own movement controls, switched off while driving (if this place has them)
local controls
task.spawn(function()
	local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
	if module then
		local ok, result = pcall(function()
			return require(module):GetControls()
		end)
		controls = if ok then result else nil
	end
end)
local SEND_EVERY = Config.Road.BuildEvery -- seconds between tile requests while building
local STALL_TIME = 0.6 -- the tip hasn't moved for this long (a wall, or out of road): drive
local CAM_DISTANCE = 18 -- the chase camera while driving: aimed just under the car, so it rides above the HUD
local TIP_BACK, TIP_UP = 7, 3.5 -- the camera on the road's tip: just behind and above it
local CAM_SENSITIVITY = 0.0035 -- radians per pixel of mouse / finger movement
local LEVEL_PITCH = math.rad(Config.Road.LevelPitch)
local landedRemote = remotes:WaitForChild("RoadLanded")
local driving = false
local phase = nil -- "build" or "drive" while driving
local roadStarted = false -- true once the server has laid this drive's first piece
local roadReached = false -- true once the road has reached solid ground
local roadEmpty = false -- true once the Road meter has run out
local camYaw, camPitch = 0, LEVEL_PITCH
local lastSend = 0
local lastTipMove = 0 -- os.clock() when the road's tip last moved
local tipCam -- where the build camera is (it glides after the tip)
local path = {} -- the drive: points along the road's middle, in order
local nextPoint = 1
local freshTries = 0
local stuckSince -- os.clock() when the car stopped moving past the end of its road
player:GetAttributeChangedSignal("RoadEnd"):Connect(function()
	if driving and player:GetAttribute("RoadEnd") then
		roadStarted = true
		lastTipMove = os.clock()
	end
end)
local lastRootPos

-- the round ROAD button, bottom right: tap to start road mode, tap again (it says STOP) to end it
-- (on phones it sits higher up, well clear of Roblox's jump button in the corner)
local onPhone = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local roadGroup = group({ Name = "RoadButton", Size = UDim2.fromOffset(78, 78), Position = if onPhone then UDim2.new(1, -30, 1, -235) else UDim2.new(1, -22, 1, -70), AnchorPoint = Vector2.new(1, 1) })
local stopButton = Ui.button({ Size = UDim2.fromScale(1, 1), Radius = 39, Top = Color3.fromRGB(255, 170, 40), Bottom = Color3.fromRGB(245, 110, 20), Parent = roadGroup })
local roadButtonText = Ui.label({ Text = "ROAD", Size = UDim2.new(1, -14, 0, 26), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 2.5, Parent = stopButton })
local function setDrivingLook(on)
	roadButtonText.Text = if on then "STOP" else "ROAD"
	Ui.recolor(stopButton, if on then Color3.fromRGB(255, 90, 90) else Color3.fromRGB(255, 170, 40), if on then Color3.fromRGB(210, 40, 50) else Color3.fromRGB(245, 110, 20))
end

-- the pink Road meter over the level bar, shown while driving: how much road this build has left
local roadMeterGroup = group({ Name = "RoadMeter", Size = UDim2.fromOffset(220, 22), Position = UDim2.new(0.5, 0, 1, -186), AnchorPoint = Vector2.new(0.5, 1) })
local roadMeter = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(196, 201, 209), Size = UDim2.fromScale(1, 1), Parent = roadMeterGroup }, { Ui.corner(5), Ui.stroke(2, Color3.fromRGB(20, 32, 48)) })
local roadMeterFill = Ui.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = roadMeter }, { Ui.corner(5), Ui.gradient(Color3.fromRGB(255, 110, 230), Color3.fromRGB(215, 40, 190)) })
Ui.label({ Text = "Road", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.5, 0, 0.8, 0), Position = UDim2.new(0, 6, 0.1, 0), ZIndex = 2, StrokeThickness = 1.5, Parent = roadMeter })
local roadMeterText = Ui.label({ Text = "", TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0.5, 0, 0.8, 0), Position = UDim2.new(0.5, -6, 0.1, 0), ZIndex = 2, StrokeThickness = 1.5, Parent = roadMeter })
roadMeterGroup.Visible = false
local function updateRoadMeter()
	local meter = Config.Road.Meter
	local left = math.clamp(player:GetAttribute("RoadLeft") or meter, 0, meter)
	roadMeterText.Text = `{math.floor(left)}/{meter}`
	TweenService:Create(roadMeterFill, TweenInfo.new(0.12), { Size = UDim2.fromScale(left / meter, 1) }):Play()
	roadMeterFill.Visible = left > 0
end
player:GetAttributeChangedSignal("RoadLeft"):Connect(updateRoadMeter)
updateRoadMeter()

local tileCount = 0
local function requestTile(fresh)
	lastSend = os.clock()
	tileCount += 1
	if fresh or tileCount % 3 == 0 then
		clickSound.PlaybackSpeed = 0.9 + math.random() * 0.3
		clickSound:Play()
	end
	buildRemote:FireServer(workspace.CurrentCamera.CFrame.LookVector, fresh)
end

-- the middle of this player's road, tile by tile in the order it was built
local function roadPath()
	local tiles = {}
	local roads = workspace:FindFirstChild("Roads")
	for _, model in if roads then roads:GetChildren() else {} do
		if model:GetAttribute("Owner") == player.UserId and model:GetAttribute("Index") and model.PrimaryPart then
			table.insert(tiles, model)
		end
	end
	table.sort(tiles, function(a, b)
		return a:GetAttribute("Index") < b:GetAttribute("Index")
	end)
	local points = {}
	for _, model in tiles do
		-- each tile's far end, on its top
		local tile = model.PrimaryPart
		table.insert(points, (tile.CFrame * CFrame.new(0, tile.Size.Y / 2, -(tile.Size.Z - 0.6) / 2)).Position)
	end
	return points
end

-- building is over: drop the camera back behind the car and drive it along the road
local function beginDrive()
	if phase ~= "build" then
		return
	end
	phase = "drive"
	whooshSound:Play()
	path = roadPath()
	nextPoint = 1
	countTutorialClick()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	-- skip the points already behind the car (the road starts a little behind it)
	if root then
		while nextPoint <= #path and ((path[nextPoint] - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 4 do
			nextPoint += 1
		end
	end
end

local groundStart = nil -- where the car first touched ground past the end of the road
local LAND_HOLD = 0.7 -- after landing, the car stays put this long (while it flips) before you can drive
local MOVE_KEYS = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right }
local holdToken = 0
-- stop the car dead where it is (it keeps any fall, so it never hangs in the air)
local function brake()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid then
		humanoid:Move(Vector3.zero, false)
	end
	if root then
		root.AssemblyLinearVelocity = Vector3.new(0, math.min(root.AssemblyLinearVelocity.Y, 0), 0)
	end
end
-- landed: true when the road just landed on the ground. The car then stays still for its
-- flip, and the controls come back after, so a held key or joystick can't push it off the edge.
local function stopDriving(landed)
	groundStart = nil
	if not driving then
		return
	end
	driving = false
	phase = nil
	setDrivingLook(false)
	roadMeterGroup.Visible = false
	brake()
	holdToken += 1
	local token = holdToken
	RunService:UnbindFromRenderStep("LandHold")
	if landed == true then
		-- Roblox's controls switch themselves back on when a key is pressed, so the brake runs
		-- every frame right after them (and after the drive loop), where it always wins. After
		-- the flip the controls come back, but a key or joystick still held from the drive is
		-- ignored until it's let go, so it can't roll the car off the end of a short platform.
		local started = os.clock()
		local enabled = false
		RunService:BindToRenderStep("LandHold", Enum.RenderPriority.Character.Value + 2, function()
			if token ~= holdToken or driving then
				RunService:UnbindFromRenderStep("LandHold")
				return
			end
			if os.clock() - started >= LAND_HOLD then
				if not enabled and controls then
					enabled = true
					controls:Enable()
				end
				-- (the controls take a few frames to notice a key that's already down, so the
				-- keys are checked directly too, and the joystick/gamepad after a short moment)
				local held = false
				for _, key in MOVE_KEYS do
					if UserInputService:IsKeyDown(key) then
						held = true
						break
					end
				end
				if not held and os.clock() - started < LAND_HOLD + 0.2 then
					held = true
				end
				if not held then
					local ok, vector = pcall(function()
						return controls and controls:GetMoveVector()
					end)
					held = ok and vector ~= nil and vector.Magnitude > 0.05
				end
				if not held then
					RunService:UnbindFromRenderStep("LandHold") -- let go: driving as normal
					return
				end
			end
			brake()
		end)
	elseif controls then
		controls:Enable()
	end
	-- hand the camera back to Roblox, where it was
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

local function startDriving(at)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if driving or not humanoid or humanoid.Health <= 0 then
		return
	end
	if player:GetAttribute("Treadmill") then
		-- on a treadmill: ROAD gets you off it first
		remotes:WaitForChild("LeaveTreadmill"):FireServer()
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local roadsFrom = workspace:GetAttribute("RoadsFrom")
	if root and roadsFrom and root.Position.Z < roadsFrom then
		showToast("Go through the Stage 1 wall first!", Color3.fromRGB(255, 90, 90))
		return
	end
	driving = true
	phase = "build"
	roadStarted = false
	roadReached = false
	roadEmpty = false
	freshTries = 0
	stuckSince = nil
	tipCam = nil
	lastTipMove = os.clock()
	lastRootPos = nil
	setDrivingLook(true)
	roadMeterGroup.Visible = true
	updateRoadMeter()
	if controls then
		controls:Disable()
	end
	-- start the chase camera facing the way the camera already faced, at its usual tilt
	local look = workspace.CurrentCamera.CFrame.LookVector
	camYaw = math.atan2(-look.X, -look.Z)
	camPitch = LEVEL_PITCH
	workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
	ripple(at or workspace.CurrentCamera.ViewportSize / 2)
	requestTile(true) -- a new road starts under the car
end

-- steering: mouse movement (the pointer is locked while driving) or a finger dragged on the screen
UserInputService.InputChanged:Connect(function(input, processed)
	if not driving then
		return
	end
	local delta
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		delta = input.Delta
	elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
		delta = input.Delta
	end
	if delta then
		camYaw -= delta.X * CAM_SENSITIVITY
		camPitch = math.clamp(camPitch - delta.Y * CAM_SENSITIVITY, math.rad(-70), math.rad(35))
	end
end)

stopButton.Activated:Connect(function()
	if driving then
		stopDriving()
	else
		startDriving()
	end
end)

-- every frame while driving: roll forward the way the camera faces, and ask for more road
-- whenever the car gets close to the end of it
RunService:BindToRenderStep("DriveRoad", Enum.RenderPriority.Character.Value + 1, function(dt)
	if not driving then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		stopDriving()
		return
	end
	-- sent back to a start (a pit) or to base: stop
	if lastRootPos and (root.Position - lastRootPos).Magnitude > 25 then
		stopDriving()
		return
	end
	local moved = if lastRootPos then (root.Position - lastRootPos).Magnitude else math.huge
	lastRootPos = root.Position

	local camera = workspace.CurrentCamera
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	local turn = CFrame.fromEulerAnglesYXZ(camPitch, camYaw, 0)
	local roadEnd = player:GetAttribute("RoadEnd")
	local now = os.clock()

	if phase == "build" then
		-- the car waits while the road's tip shoots ahead, with the camera riding on it
		humanoid:Move(Vector3.zero, false)
		local target = (if roadStarted and roadEnd then roadEnd else root.Position) + Vector3.new(0, TIP_UP, 0)
		tipCam = if tipCam then tipCam:Lerp(target, math.min(1, dt * 14)) else root.Position + Vector3.new(0, 3, 0)
		camera.CFrame = CFrame.new(tipCam) * turn * CFrame.new(0, 0, TIP_BACK)
		if not roadStarted then
			if now - lastSend >= 0.5 then
				freshTries += 1
				if freshTries > 4 then
					stopDriving() -- can't start a road here (in the air, or no Horsepower)
					return
				end
				requestTile(true) -- the first request got lost: ask again
			end
		elseif roadReached or roadEmpty or now - lastTipMove > STALL_TIME then
			beginDrive()
		elseif now - lastSend >= SEND_EVERY then
			requestTile(false)
		end
		updateRoadMeter()
		return
	end

	-- drive: follow the road's points one after another
	local target = path[nextPoint]
	while target and ((target - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 3 do
		nextPoint += 1
		target = path[nextPoint]
	end
	local heading
	if target then
		heading = (target - root.Position) * Vector3.new(1, 0, 1)
	else
		-- past the last point: carry straight on (onto the ground, or off the end)
		local last, before = path[#path], path[#path - 1]
		heading = if last and before then (last - before) * Vector3.new(1, 0, 1) else camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	end
	if heading.Magnitude > 0.01 then
		heading = heading.Unit
		humanoid:Move(heading, false)
		-- the chase camera swings round behind the way the car is going
		local wantYaw = math.atan2(-heading.X, -heading.Z)
		local delta = (wantYaw - camYaw + math.pi) % (2 * math.pi) - math.pi
		camYaw += delta * math.min(1, dt * 6)
		camPitch += (LEVEL_PITCH - camPitch) * math.min(1, dt * 4)
		turn = CFrame.fromEulerAnglesYXZ(camPitch, camYaw, 0)
	end
	camera.CFrame = CFrame.new(root.Position + Vector3.new(0, -0.5, 0)) * turn * CFrame.new(0, 0, CAM_DISTANCE)
	-- (the Road meter keeps showing how much road is left to build; it fills back up on landing)

	-- off the end of the road: onto solid ground it lands (or just stops, for a road that
	-- never crossed a gap); over the gap it falls
	if not target then
		-- pushing against something past the end of the road (a wall): stop driving
		if moved > dt * 2 then
			stuckSince = nil
		else
			stuckSince = stuckSince or now
			if now - stuckSince > 1 then
				stopDriving()
				return
			end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character }
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -8, 0), params)
		local roads = workspace:FindFirstChild("Roads")
		local function isGround(result)
			return result and not (roads and result.Instance:IsDescendantOf(roads))
		end
		if isGround(hit) then
			-- keep rolling a few studs onto the ground so the car never stops right at the
			-- edge (and falls off it when the road disappears); stop early if the ground ends
			groundStart = groundStart or root.Position
			-- (looks 8 studs ahead: at speed the car needs a moment to come off the road)
			local ahead = workspace:Raycast(root.Position + (heading or Vector3.zero) * 8, Vector3.new(0, -8, 0), params)
			local onFar = ((root.Position - groundStart) * Vector3.new(1, 0, 1)).Magnitude
			if onFar >= 6 or not isGround(ahead) then
				if roadReached then
					landedRemote:FireServer()
					landSound:Play()
				end
				stopDriving(roadReached)
			end
		end
	end
end)
player.CharacterAdded:Connect(stopDriving)
-- the normal camera aims a little under the car too, so the bottom bar never hides it
local function lowerCamera(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.CameraOffset = Vector3.new(0, -2.5, 0)
	end
end
player.CharacterAdded:Connect(lowerCamera)
if player.Character then
	task.spawn(lowerCamera, player.Character)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return -- the press landed on a button or a text box
	end
	-- a click anywhere starts road mode on a computer. On phones only the ROAD button does: the
	-- joystick's touches don't count as "on a button", so a tap could start a road by mistake
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		startDriving(Vector2.new(input.Position.X, input.Position.Y))
	end
end)

-- Space starts road mode instead of jumping (cars don't jump). Pressed again while the road is
-- being built it finishes the road and drives; while driving it does nothing (STOP ends it).
ContextActionService:BindActionAtPriority("BuildRoad", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		if not driving then
			startDriving()
		elseif phase == "build" and roadStarted then
			beginDrive()
		end
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

---------------------------------------------------------------- messages
local toastGroup = group({ Name = "Toast", Size = UDim2.fromOffset(640, 36), Position = UDim2.new(0.5, 0, 0, 116), AnchorPoint = Vector2.new(0.5, 0) })
toastGroup.ZIndex = 20 -- messages show over menus like the Shop
local toast = Ui.label({ Text = "", Visible = false, Size = UDim2.fromScale(1, 1), StrokeThickness = 2.5, Parent = toastGroup })
local toastToken = 0
function showToast(text, color)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.TextColor3 = color
	toast.Visible = true
	Ui.pop(toast, 1.15)
	task.delay(2, function()
		if token == toastToken then
			toast.Visible = false
		end
	end)
end

-- while the save is still loading (another server may be finishing with it), say so, so
-- the zeros on screen never look like lost progress
local loadingGroup = group({ Name = "Loading", Size = UDim2.fromOffset(400, 28), Position = UDim2.new(0.5, 0, 0, 156), AnchorPoint = Vector2.new(0.5, 0) })
Ui.label({ Text = "Loading your progress...", TextColor3 = Ui.Yellow, Size = UDim2.fromScale(1, 1), StrokeThickness = 2, Parent = loadingGroup })
loadingGroup.Visible = false
task.delay(2, function()
	loadingGroup.Visible = player:GetAttribute("Loaded") ~= true
end)
player:GetAttributeChangedSignal("Loaded"):Connect(function()
	loadingGroup.Visible = player:GetAttribute("Loaded") ~= true
end)

local showRespawn -- the "RESPAWN AT STAGE N?" popup, made further down
local openShop -- the Shop, made further down

remotes.Notice.OnClientEvent:Connect(function(notice)
	if notice.Kind == "Fell" then
		fallSound:Play()
		stopDriving()
		showRespawn(notice.Stage)
	elseif notice.Kind == "Crit" then
		critSound:Play()
		local label = floatText("Critical! +" .. Format.short(notice.Amount), lastClickAt - Vector2.new(0, 50), Color3.fromRGB(255, 140, 40), UDim2.fromOffset(240, 46), 130)
		Ui.pop(label, 1.5)
		Ui.pop(powerLabel, 1.2)
	elseif notice.Kind == "LevelUp" then
		winSound:Play()
		if notice.Max then
			showToast(`Level {notice.Level} - that's the MAX! Rebirth to go higher`, Ui.Yellow)
		else
			showToast(`Level {notice.Level - 1} > Level {notice.Level}   Speed {Config.stageSpeed(notice.Level - 1)} > {Config.stageSpeed(notice.Level)}`, Color3.fromRGB(120, 255, 130))
		end
		Ui.pop(levelText, 1.3)
	elseif notice.Kind == "RoadWall" then
		roadEmpty = true -- the road ran into a wall: drive what was built
	elseif notice.Kind == "RoadLobby" then
		stopDriving()
		showToast("Go through the Stage 1 wall first!", Color3.fromRGB(255, 90, 90))
	elseif notice.Kind == "RoadEmpty" then
		roadEmpty = true
		showToast("Out of road!", Color3.fromRGB(255, 110, 230))
	elseif notice.Kind == "CanTaken" then
		-- "+N HP" off the can, then hide it (for this player only) until it comes back
		local can = notice.Can
		if can and can.PrimaryPart then
			local at, onScreen = workspace.CurrentCamera:WorldToViewportPoint(can.PrimaryPart.Position)
			if onScreen and (notice.Amount or 0) > 0 then
				local label = floatText("+" .. Format.short(notice.Amount) .. " HP", Vector2.new(at.X, at.Y), Color3.fromRGB(70, 205, 255), UDim2.fromOffset(200, 44), 110)
				Ui.pop(label, 1.4)
			end
			critSound:Play()
			can:SetAttribute("HiddenUntil", os.clock() + (notice.Respawn or 30))
		end
	elseif notice.Kind == "NeedLevel" then
		showToast(`Reach Level {notice.Level} to rebirth!`, Color3.fromRGB(255, 110, 110))
	elseif notice.Kind == "Rebirthed" then
		winSound:Play()
		showToast(`Rebirth {notice.Rebirths}! Max level is now {Config.levelCap(notice.Rebirths)}`, Color3.fromRGB(230, 120, 255))
	elseif notice.Kind == "PadLocked" then
		local needs = if notice.Rebirths == 1 then "1 Rebirth" else `{notice.Rebirths} Rebirths`
		showToast(`You don't own the {notice.Name} Treadmill! It needs {needs}`, Color3.fromRGB(255, 70, 70))
	elseif notice.Kind == "PadNeedsPass" then
		showToast(`You don't own the {notice.Name} Treadmill!`, Color3.fromRGB(255, 70, 70))
		if (Config.GamePasses[notice.Pass] or { Id = 0 }).Id == 0 then
			openShop() -- not made on the dashboard yet, so there's no prompt: show the Shop instead
		end
	elseif notice.Kind == "PassOwned" then
		winSound:Play()
		local pass = Config.GamePasses[notice.Key]
		showToast(`{pass and pass.Name or "Pass"} unlocked! Thank you!`, Color3.fromRGB(120, 255, 130))
	elseif notice.Kind == "PackGiven" then
		winSound:Play()
		showToast(`+{Format.short(notice.Amount or 0)} Horsepower!`, Color3.fromRGB(70, 205, 255))
		Ui.pop(powerLabel, 1.3)
	elseif notice.Kind == "DailyClaimed" then
		winSound:Play()
		local got = {}
		if (notice.Wins or 0) > 0 then
			table.insert(got, `+{Format.short(notice.Wins)} Wins`)
		end
		if (notice.Horsepower or 0) > 0 then
			table.insert(got, `+{Format.short(notice.Horsepower)} Horsepower`)
		elseif notice.WantedHorsepower then
			table.insert(got, "Horsepower full: rebirth to go higher")
		end
		if notice.Boost then
			table.insert(got, `x2 {if notice.Boost == "DoubleWins" then "Wins" else "Horsepower"} for {notice.Minutes} min`)
		end
		showToast(`Day {notice.Day} gift: {table.concat(got, ", ")}!`, Color3.fromRGB(255, 222, 50))
		local c = dailyCards[notice.Day]
		if c then
			Ui.pop(c.Card, 1.15)
		end
	elseif notice.Kind == "AtCap" then
		showToast("You're at your max level! Rebirth to go higher", Color3.fromRGB(255, 110, 110))
	elseif notice.Kind == "RoadReached" then
		roadReached = true
	elseif notice.Kind == "RoadNeedPower" then
		stopDriving()
		showToast(`You need {Format.short(notice.Need)} more Horsepower to build on Stage {notice.Stage}!`, Color3.fromRGB(255, 110, 110))
	elseif notice.Kind == "StageComplete" then
		winSound:Play()
		if notice.Double then
			showToast(`2x WINS! Stage {notice.Stage} complete! +{Format.short(notice.Wins)} Wins`, Color3.fromRGB(215, 150, 255))
		else
			showToast(`Stage {notice.Stage} complete! +{Format.short(notice.Wins)} Wins`, Ui.Yellow)
		end
	elseif notice.Kind == "BackToLobby" then
		-- sent back to the lobby: stop any road, and swing the camera round behind the car,
		-- looking out towards the stages
		stopDriving()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local camera = workspace.CurrentCamera
			camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 8, -18), root.Position + Vector3.new(0, 2, 0))
		end
	elseif notice.Kind == "NeedEnergy" then
		showToast(`You need {Format.short(notice.Need)} more Horsepower!`, Color3.fromRGB(255, 110, 110))
	elseif notice.Kind == "NeedWins" then
		showToast(`You need {Format.short(notice.Need)} more Wins!`, Color3.fromRGB(255, 110, 110))
	elseif notice.Kind == "NeedCar" then
		showToast(`Unlock Car {notice.Tier} first!`, Color3.fromRGB(255, 110, 110))
	elseif notice.Kind == "CarUnlocked" then
		winSound:Play()
		showToast(`{(CarLooks.info(notice.Tier) or { Name = "New car" }).Name} unlocked!`, Color3.fromRGB(120, 255, 130))
	elseif notice.Kind == "GatePassed" then
		winSound:Play()
		showToast(`Stage {notice.Gate} smashed! +{Format.short(notice.Wins)} Wins`, Color3.fromRGB(120, 255, 130))
	elseif notice.Kind == "LevelComplete" then
		winSound:Play()
		showToast(`Level {notice.Level} complete! +{Format.short(notice.Wins)} Wins`, Ui.Yellow)
	end
end)

---------------------------------------------------------------- live values
local shownPower = Instance.new("NumberValue")
shownPower.Value = player:GetAttribute("Energy") or 0
local function setPowerText(value)
	powerLabel.Text = `Horsepower: <font color="{CYAN}">{Format.short(value)}</font>`
end
shownPower.Changed:Connect(setPowerText)
setPowerText(shownPower.Value)

local powerTween
local function refresh()
	local power = player:GetAttribute("Energy") or 0
	if powerTween then
		powerTween:Cancel()
	end
	if power < shownPower.Value then
		shownPower.Value = power
	else
		powerTween = TweenService:Create(shownPower, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = power })
		powerTween:Play()
	end
	winsLabel.Text = Format.short(player:GetAttribute("Wins") or 0)
	-- level progress: Horsepower so far toward the next level
	local level = Config.levelFor(power)
	local from, to = Config.levelNeed(level), Config.levelNeed(level + 1)
	local share = math.clamp((power - from) / math.max(1, to - from), 0, 1)
	if level >= Config.levelCap(player:GetAttribute("Rebirths") or 0) then
		-- at the cap: only a rebirth goes higher
		share = 1
		levelText.Text = `Level {level} (MAX)`
		progressText.Text = "MAX - Rebirth!"
	else
		levelText.Text = `Level {level}`
		progressText.Text = `{Format.short(power)} / {Format.short(to)}`
	end
	TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(share, 1) }):Play()
	fill.Visible = share > 0.01
end
local lastWins = player:GetAttribute("Wins") or 0
local lastPower = player:GetAttribute("Energy") or 0
player.AttributeChanged:Connect(function(name)
	if name == "Energy" then
		-- "+N HP" rises off the car while training
		local power = player:GetAttribute("Energy") or 0
		local gained = power - lastPower
		lastPower = power
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if gained > 0 and root and player:GetAttribute("Training") then
			local at, onScreen = workspace.CurrentCamera:WorldToViewportPoint(root.Position + Vector3.new(0, 5, 0))
			if onScreen then
				local jitter = Vector2.new(math.random(-40, 40), math.random(-10, 10))
				floatText("+" .. Format.short(gained) .. " HP", Vector2.new(at.X, at.Y) + jitter, Color3.fromRGB(70, 205, 255), UDim2.fromOffset(160, 34), 90)
			end
		end
	elseif name == "Wins" then
		local wins = player:GetAttribute("Wins") or 0
		if wins > lastWins then
			Ui.pop(winsLabel, 1.2)
		end
		lastWins = wins
	end
	refresh()
end)
refresh()

---------------------------------------------------------------- rebirth menu
-- Before / After cards (Horsepower boost and max level), a bar of your level toward the cap,
-- and REBIRTH (the server checks you're at the cap).
local rebirthGroup = group({ Name = "RebirthMenu", Size = UDim2.fromOffset(360, 250), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
rebirthGroup.Visible = false
local rebirthPanel = Ui.new("Frame", { Active = true, BackgroundColor3 = Color3.fromRGB(24, 26, 36), BackgroundTransparency = 0.05, Size = UDim2.fromScale(1, 1), Parent = rebirthGroup }, { Ui.corner(10), Ui.stroke(3, Color3.fromRGB(10, 10, 16)) })
Icons.make("Rebirth", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(10, 6), Parent = rebirthPanel })
Ui.label({ Text = "Rebirth", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(200, 28), Position = UDim2.fromOffset(56, 12), StrokeThickness = 2.5, Parent = rebirthPanel })
local closeRebirth = Ui.button({ Text = "X", Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -10, 0, 10), AnchorPoint = Vector2.new(1, 0), Radius = 8, Top = Color3.fromRGB(255, 80, 90), Bottom = Color3.fromRGB(210, 30, 50), Parent = rebirthPanel })
Ui.label({ Text = "Before", Size = UDim2.fromOffset(140, 20), Position = UDim2.fromOffset(20, 52), StrokeThickness = 1.5, Parent = rebirthPanel })
Ui.label({ Text = "After", Size = UDim2.fromOffset(140, 20), Position = UDim2.fromOffset(200, 52), StrokeThickness = 1.5, Parent = rebirthPanel })
local function statCard(x, y, top, bottom)
	local card = Ui.panel({ Size = UDim2.fromOffset(140, 34), Position = UDim2.fromOffset(x, y), Radius = 7, StrokeThickness = 2, Top = top, Bottom = bottom, Parent = rebirthPanel })
	return Ui.label({ Text = "", Size = UDim2.new(1, -12, 0, 24), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 2, Parent = card })
end
local BLUE_TOP, BLUE_BOTTOM = Color3.fromRGB(80, 200, 255), Color3.fromRGB(30, 140, 235)
local ORANGE_TOP, ORANGE_BOTTOM = Color3.fromRGB(255, 190, 60), Color3.fromRGB(245, 130, 20)
local boostBefore = statCard(20, 76, BLUE_TOP, BLUE_BOTTOM)
local boostAfter = statCard(200, 76, BLUE_TOP, BLUE_BOTTOM)
local capBefore = statCard(20, 118, ORANGE_TOP, ORANGE_BOTTOM)
local capAfter = statCard(200, 118, ORANGE_TOP, ORANGE_BOTTOM)
for _, y in { 93, 135 } do
	Ui.label({ Text = ">", Size = UDim2.fromOffset(30, 24), Position = UDim2.fromOffset(165, y - 12), StrokeThickness = 2, Parent = rebirthPanel })
end
Ui.label({ Text = "Rebirth resets your Horsepower!", TextColor3 = Color3.fromRGB(255, 110, 110), Size = UDim2.fromOffset(320, 18), Position = UDim2.fromOffset(20, 158), StrokeThickness = 1.5, Parent = rebirthPanel })
local rebirthBar = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(196, 201, 209), Size = UDim2.fromOffset(240, 20), Position = UDim2.fromOffset(60, 180), Parent = rebirthPanel }, { Ui.corner(5), Ui.stroke(2) })
local rebirthFill = Ui.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0, 1), Parent = rebirthBar }, { Ui.corner(5), Ui.gradient(Color3.fromRGB(150, 255, 90), Color3.fromRGB(60, 200, 60)) })
local rebirthBarText = Ui.label({ Text = "", Size = UDim2.fromScale(1, 0.85), Position = UDim2.fromScale(0, 0.08), ZIndex = 2, StrokeThickness = 1.5, Parent = rebirthBar })
local rebirthButton = Ui.button({ Text = "REBIRTH", Size = UDim2.fromOffset(150, 36), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), Radius = 8, Top = Color3.fromRGB(230, 110, 255), Bottom = Color3.fromRGB(150, 50, 215), Parent = rebirthPanel })
rebirthButton.Name = "RebirthButton"
-- gold SKIP beside it while you still need levels: rebirth now for Robux
local skipButton = Ui.button({ Text = "SKIP", Size = UDim2.fromOffset(150, 36), Position = UDim2.new(0.5, 6, 1, -8), AnchorPoint = Vector2.new(0, 1), Radius = 8, Top = Color3.fromRGB(255, 226, 80), Bottom = Color3.fromRGB(240, 150, 20), Parent = rebirthPanel })
skipButton.Name = "SkipButton"
local productPrices = {} -- [product key] = Robux price Roblox reported

local function refreshRebirth()
	local rebirths = player:GetAttribute("Rebirths") or 0
	local level = Config.levelFor(player:GetAttribute("Energy") or 0)
	local cap = Config.levelCap(rebirths)
	boostBefore.Text = `Horsepower x{Config.rebirthBoost(rebirths)}`
	capBefore.Text = `Max Level {cap}`
	if rebirths >= Config.Rebirths.Max then
		boostAfter.Text = "MAXED"
		capAfter.Text = "MAXED"
		rebirthButton.Label.Text = "MAXED"
	else
		boostAfter.Text = `Horsepower x{Config.rebirthBoost(rebirths + 1)}`
		capAfter.Text = `Max Level {Config.levelCap(rebirths + 1)}`
		rebirthButton.Label.Text = "REBIRTH"
	end
	rebirthBarText.Text = `Level {math.min(level, cap)}/{cap}`
	rebirthFill.Size = UDim2.fromScale(math.clamp(level / cap, 0, 1), 1)
	local canSkip = rebirths < Config.Rebirths.Max and level < cap
	skipButton.Visible = canSkip
	rebirthButton.Position = if canSkip then UDim2.new(0.5, -6, 1, -8) else UDim2.new(0.5, 0, 1, -8)
	rebirthButton.AnchorPoint = if canSkip then Vector2.new(1, 1) else Vector2.new(0.5, 1)
	local price = productPrices.SkipRebirth or Config.Products.SkipRebirth.Price
	skipButton.Label.Text = `SKIP (R${price})`
end
skipButton.Activated:Connect(function()
	remotes.Purchase:FireServer("Product", "SkipRebirth")
end)
player.AttributeChanged:Connect(function(name)
	if rebirthGroup.Visible and (name == "Energy" or name == "Rebirths") then
		refreshRebirth()
	end
end)
closeRebirth.Activated:Connect(function()
	rebirthGroup.Visible = false
end)
rebirthButton.Activated:Connect(function()
	remotes.Rebirth:FireServer()
end)

---------------------------------------------------------------- respawn popup
-- After falling off a stage you're back in the lobby; this offers a paid trip straight back
-- to the start of that stage. The price comes from Roblox, so a dashboard change shows up.
local respawnGroup = group({ Name = "RespawnPopup", Size = UDim2.fromOffset(320, 150), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5) })
respawnGroup.Visible = false
local respawnPanel = Ui.new("Frame", { Active = true, BackgroundColor3 = Color3.fromRGB(24, 26, 36), BackgroundTransparency = 0.05, Size = UDim2.fromScale(1, 1), Parent = respawnGroup }, { Ui.corner(10), Ui.stroke(3, Color3.fromRGB(10, 10, 16)) })
local respawnTitle = Ui.label({ Text = "RESPAWN AT STAGE 1?", Size = UDim2.new(1, -60, 0, 30), Position = UDim2.fromOffset(16, 22), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2.5, Parent = respawnPanel })
local closeRespawn = Ui.button({ Text = "X", Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -10, 0, 10), AnchorPoint = Vector2.new(1, 0), Radius = 8, Top = Color3.fromRGB(255, 80, 90), Bottom = Color3.fromRGB(210, 30, 50), Parent = respawnPanel })
local respawnButton = Ui.button({ Text = "RESPAWN", Size = UDim2.fromOffset(200, 48), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 1), Radius = 8, Top = Color3.fromRGB(120, 245, 110), Bottom = Color3.fromRGB(40, 180, 60), Parent = respawnPanel })
respawnButton.Name = "RespawnButton"
closeRespawn.Name = "Close"
local respawnToken = 0
local function hideRespawn()
	respawnToken += 1
	respawnGroup.Visible = false
end
showRespawn = function(stage)
	local id = Config.Products.Respawn.Id
	if id == 0 and not RunService:IsStudio() then
		return -- the product isn't made yet: don't offer a button that can't do anything
	end
	respawnTitle.Text = `RESPAWN AT STAGE {stage}?`
	local price = productPrices.Respawn or Config.Products.Respawn.Price
	respawnButton.Label.Text = if id == 0 then "RESPAWN (FREE TEST)" else `RESPAWN (R${price})`
	respawnGroup.Visible = true
	Ui.pop(respawnPanel, 1.08)
	-- the offer goes away by itself after a while
	respawnToken += 1
	local token = respawnToken
	task.delay(12, function()
		if token == respawnToken then
			respawnGroup.Visible = false
		end
	end)
end
closeRespawn.Activated:Connect(hideRespawn)
respawnButton.Activated:Connect(function()
	remotes.Purchase:FireServer("Product", "Respawn")
	hideRespawn()
end)

---------------------------------------------------------------- shop
-- HORSEPOWER packs on top: tall bright cards with light rays behind a pile of cans, a
-- "Good / Great / Most Value" badge, a dark pill with what you'll get and a green Robux
-- price button. Then GAMEPASSES as wide cards (title, icon in a soft circle, a little chip,
-- the description and the price button) and EXTRAS. Owned passes say OWNED. Prices come from
-- Roblox once a pass or product has its real Id, so a dashboard change shows up by itself.
local GREEN_TOP, GREEN_BOTTOM = Color3.fromRGB(130, 250, 70), Color3.fromRGB(45, 185, 35)
local GREY_TOP, GREY_BOTTOM = Color3.fromRGB(160, 165, 178), Color3.fromRGB(110, 115, 130)
local PASS_LOOKS = {
	DoubleWins = { Icon = "Trophy", Chip = "x2", Top = Color3.fromRGB(255, 215, 70), Bottom = Color3.fromRGB(245, 150, 20) },
	DoubleHorsepower = { Icon = "Gauge", Chip = "x2", Top = Color3.fromRGB(80, 200, 255), Bottom = Color3.fromRGB(25, 115, 230) },
	FastTraining = { Icon = "Bolt", Chip = "x2", Top = Color3.fromRGB(180, 110, 255), Bottom = Color3.fromRGB(110, 50, 215) },
	StarterPack = { Icon = "Gift", Chip = "NEW", Top = Color3.fromRGB(120, 235, 110), Bottom = Color3.fromRGB(30, 160, 70) },
	Vip = { Icon = "Crown", Chip = "VIP", Top = Color3.fromRGB(255, 110, 190), Bottom = Color3.fromRGB(200, 40, 130) },
	GoldenTreadmill = { Icon = "Treadmill", Chip = "x25", Top = Color3.fromRGB(255, 160, 70), Bottom = Color3.fromRGB(225, 85, 25) },
}
local PACK_TOP, PACK_BOTTOM = Color3.fromRGB(90, 215, 255), Color3.fromRGB(25, 120, 230)
local PACK_LOOKS = {
	PackSmall = { Cans = 1 },
	PackMedium = { Cans = 2, Badge = "Good Value", BadgeTop = Color3.fromRGB(90, 190, 255), BadgeBottom = Color3.fromRGB(30, 110, 235) },
	PackBig = { Cans = 3, Badge = "Great Value", BadgeTop = Color3.fromRGB(255, 200, 60), BadgeBottom = Color3.fromRGB(245, 130, 20) },
	PackHuge = { Cans = 5, Badge = "Most Value", Rainbow = true },
}

local shopGroup = group({ Name = "Shop", Size = UDim2.fromOffset(660, 440), Position = UDim2.fromScale(0.5, 0.56), AnchorPoint = Vector2.new(0.5, 0.5) })
shopGroup.Visible = false
local shopPanel = Ui.new("Frame", { Active = true, BackgroundColor3 = Color3.fromRGB(30, 34, 48), BackgroundTransparency = 0.04, Size = UDim2.fromScale(1, 1), Parent = shopGroup }, { Ui.corner(14), Ui.stroke(3, Color3.fromRGB(10, 10, 16)) })
Icons.make("Cart", { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(12, 4), Parent = shopPanel })
Ui.label({ Text = "Shop", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(200, 32), Position = UDim2.fromOffset(64, 11), StrokeThickness = 2.5, Parent = shopPanel })
local closeShop = Ui.button({ Text = "X", Size = UDim2.fromOffset(36, 36), Position = UDim2.new(1, -10, 0, 10), AnchorPoint = Vector2.new(1, 0), Radius = 8, Top = Color3.fromRGB(255, 80, 90), Bottom = Color3.fromRGB(210, 30, 50), Parent = shopPanel })
closeShop.Name = "Close"
local shopList = Ui.new("ScrollingFrame", {
	Name = "List",
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Size = UDim2.new(1, -16, 1, -62),
	Position = UDim2.fromOffset(8, 54),
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Color3.fromRGB(120, 125, 145),
	Parent = shopPanel,
}, {
	Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	Ui.new("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 10), PaddingRight = UDim.new(0, 8) }),
})
local CONTENT_W = 620
local order = 0
local function nextOrder()
	order += 1
	return order
end

-- a dark pill title with a line out to each side
local function sectionTitle(text)
	local row = Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(CONTENT_W, 34), LayoutOrder = nextOrder(), Parent = shopList })
	for _, side in { -1, 1 } do
		Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(90, 96, 120), BorderSizePixel = 0, Size = UDim2.new(0.5, -110, 0, 3), Position = UDim2.new(0.5, side * 110, 0.5, 0), AnchorPoint = Vector2.new(if side < 0 then 1 else 0, 0.5), Parent = row }, { Ui.corner(2) })
	end
	local pill = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(44, 50, 70), Size = UDim2.fromOffset(200, 32), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = row }, { Ui.corner(16), Ui.stroke(2.5, Color3.fromRGB(14, 16, 24)) })
	Ui.label({ Text = text, Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 2, Parent = pill })
end

-- a green price button with the Robux mark and the price (or OWNED)
local function priceButton(parent, size, position, anchor)
	local b = Ui.button({ Size = size, Position = position, AnchorPoint = anchor, Radius = 9, Top = GREEN_TOP, Bottom = GREEN_BOTTOM, Parent = parent })
	b.Name = "Buy"
	local content = Ui.new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = b }, {
		Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local icon = Icons.make("Robux", { Size = UDim2.new(0, 0, 0.62, 0), Parent = content })
	icon.Name = "Robux"
	icon.LayoutOrder = 1
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.Size = UDim2.fromScale(0.7, 0.7)
	local price = Ui.label({ Name = "Price", Text = "", AutomaticSize = Enum.AutomaticSize.X, TextScaled = false, TextSize = math.floor(size.Y.Offset * 0.62), Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2, StrokeThickness = 2.5, Parent = content })
	return b, price, icon
end
local function setPrice(button, price, icon, text, owned)
	price.Text = text
	icon.Visible = not owned
	if owned then
		Ui.recolor(button, GREY_TOP, GREY_BOTTOM)
	else
		Ui.recolor(button, GREEN_TOP, GREEN_BOTTOM)
	end
end

-- soft white rays fanning out from a point on a card (clipped to the card)
local function rays(card, center)
	local clip = Ui.new("Frame", { Name = "Rays", BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), Parent = card })
	for i = 0, 11 do
		Ui.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.74, BorderSizePixel = 0, Size = UDim2.fromOffset(16, 260), Position = center, AnchorPoint = Vector2.new(0.5, 0.5), Rotation = i * 15, Parent = clip })
	end
	-- a soft glow in the middle
	Ui.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, Size = UDim2.fromOffset(70, 70), Position = center, AnchorPoint = Vector2.new(0.5, 0.5), Parent = clip }, { Ui.corner(35) })
	return clip
end

-- HORSEPOWER packs
sectionTitle("Horsepower")
local packCards = {} -- [key] = { Amount, Buy, Price, Robux }
local PACK_W, PACK_H = 146, 196
local packRow = Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(CONTENT_W, PACK_H + 14), LayoutOrder = nextOrder(), Parent = shopList }, {
	Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
})
-- where the cans sit in each pile, in 0-1 of the pile area
local PILES = {
	{ { 0.5, 0.55, 0.62 } },
	{ { 0.34, 0.58, 0.5 }, { 0.66, 0.52, 0.56 } },
	{ { 0.26, 0.62, 0.44 }, { 0.74, 0.62, 0.44 }, { 0.5, 0.48, 0.52 } },
	{ { 0.18, 0.68, 0.36 }, { 0.82, 0.68, 0.36 }, { 0.38, 0.6, 0.42 }, { 0.62, 0.6, 0.42 }, { 0.5, 0.42, 0.46 } },
}
for i, key in Config.PackOrder do
	local look = PACK_LOOKS[key]
	local c = Ui.panel({ Name = key, Size = UDim2.fromOffset(PACK_W, PACK_H), Radius = 12, StrokeThickness = 3, Top = PACK_TOP, Bottom = PACK_BOTTOM, LayoutOrder = i, Parent = packRow })
	rays(c, UDim2.fromOffset(PACK_W / 2, 66))
	local pile = Ui.new("Frame", { Name = "Pile", BackgroundTransparency = 1, Size = UDim2.fromOffset(PACK_W - 16, 100), Position = UDim2.fromOffset(8, 16), Parent = c })
	local spots = PILES[math.min(#PILES, if look.Cans >= 5 then 4 else look.Cans)]
	for n, spot in spots do
		Icons.make("Can", { Size = UDim2.fromScale(spot[3], spot[3] * 1.3), Position = UDim2.fromScale(spot[1], spot[2]), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = (n % 2 * 2 - 1) * 8, ZIndex = 2 + n, Parent = pile })
	end
	-- dark pill: a little can and what you'll get
	local pill = Ui.new("Frame", { Name = "Pill", BackgroundColor3 = Color3.fromRGB(10, 40, 80), BackgroundTransparency = 0.45, Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0.5, 0, 0, 120), AnchorPoint = Vector2.new(0.5, 0), Parent = c }, { Ui.corner(14) })
	Icons.make("Can", { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = pill })
	local amount = Ui.label({ Name = "Amount", Text = "+0 HP", Size = UDim2.new(1, -40, 0, 20), Position = UDim2.new(0, 34, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), StrokeThickness = 2, Parent = pill })
	local buy, price, robux = priceButton(c, UDim2.fromOffset(PACK_W - 14, 38), UDim2.new(0.5, 0, 1, -7), Vector2.new(0.5, 1))
	buy.Activated:Connect(function()
		remotes.Purchase:FireServer("Product", key)
	end)
	if look.Badge then
		local badge = Ui.panel({ Name = "Badge", Size = UDim2.fromOffset(PACK_W - 18, 28), Position = UDim2.new(0.5, 0, 0, -12), AnchorPoint = Vector2.new(0.5, 0), Radius = 14, StrokeThickness = 2.5, Top = look.BadgeTop or Color3.new(1, 1, 1), Bottom = look.BadgeBottom, ZIndex = 10, Parent = c })
		if look.Rainbow then
			badge.UIGradient.Color = RAINBOW
			badge.UIGradient.Rotation = 0
		end
		Ui.label({ Text = look.Badge, Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 11, StrokeThickness = 2, Parent = badge })
	end
	packCards[key] = { Amount = amount, Buy = buy, Price = price, Robux = robux }
end

-- GAMEPASSES: wide cards, two across
sectionTitle("Gamepasses")
local passCards = {} -- [key] = { Buy, Price, Robux }
local PASS_W, PASS_H = 304, 130
local function passGrid(rows)
	return Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(CONTENT_W, rows * PASS_H + (rows - 1) * 12), LayoutOrder = nextOrder(), Parent = shopList }, {
		Ui.new("UIGridLayout", { CellSize = UDim2.fromOffset(PASS_W, PASS_H), CellPadding = UDim2.fromOffset(12, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end
-- one wide card: title top left, icon in a soft circle with a chip under it, text and price on the right
local function wideCard(parent, layoutOrder, title, text, iconName, chip, top, bottom)
	local c = Ui.panel({ Size = UDim2.fromOffset(PASS_W, PASS_H), Radius = 12, StrokeThickness = 3, Top = top, Bottom = bottom, LayoutOrder = layoutOrder, Parent = parent })
	Ui.new("Frame", { Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, Size = UDim2.new(1, -10, 0, 16), Position = UDim2.fromOffset(5, 4), Parent = c }, { Ui.corner(8) })
	Ui.label({ Text = title, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(PASS_W - 24, 26), Position = UDim2.fromOffset(12, 6), StrokeThickness = 2.5, Parent = c })
	local circle = Ui.new("Frame", { Name = "Circle", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72, Size = UDim2.fromOffset(88, 88), Position = UDim2.fromOffset(12, 36), Parent = c }, { Ui.corner(44) })
	Icons.make(iconName, { Size = UDim2.fromOffset(70, 70), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2, Parent = circle })
	if chip then
		local chipFrame = Ui.new("Frame", { Name = "Chip", BackgroundColor3 = Color3.fromRGB(20, 22, 34), BackgroundTransparency = 0.35, Size = UDim2.fromOffset(46, 22), Position = UDim2.fromOffset(8, PASS_H - 30), ZIndex = 3, Parent = c }, { Ui.corner(11) })
		Ui.label({ Text = chip, Size = UDim2.new(1, -10, 0, 15), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4, StrokeThickness = 1.5, Parent = chipFrame })
	end
	Ui.label({ Name = "Text", Text = text, TextScaled = false, TextSize = 18, TextWrapped = true, Size = UDim2.fromOffset(188, 50), Position = UDim2.fromOffset(108, 32), StrokeThickness = 2, Parent = c })
	local buy, price, robux = priceButton(c, UDim2.fromOffset(182, 38), UDim2.new(1, -10, 1, -8), Vector2.new(1, 1))
	return c, buy, price, robux
end
local passGridFrame = passGrid(math.ceil(#Config.PassOrder / 2))
for i, key in Config.PassOrder do
	local pass, look = Config.GamePasses[key], PASS_LOOKS[key]
	local c, buy, price, robux = wideCard(passGridFrame, i, pass.Name, pass.Text, look.Icon, look.Chip, look.Top, look.Bottom)
	c.Name = key
	buy.Activated:Connect(function()
		remotes.Purchase:FireServer("Pass", key)
	end)
	passCards[key] = { Buy = buy, Price = price, Robux = robux }
end

-- EXTRAS
sectionTitle("Extras")
local extrasGrid = passGrid(1)
local skipCardFrame, skipShopButton, skipShopPrice, skipShopRobux = wideCard(extrasGrid, 1, "Skip Rebirth", "Rebirth right now, without the levels!", "Rebirth", nil, Color3.fromRGB(240, 120, 255), Color3.fromRGB(150, 50, 215))
skipCardFrame.Name = "SkipRebirth"
skipShopButton.Activated:Connect(function()
	remotes.Purchase:FireServer("Product", "SkipRebirth")
end)

-- prices from Roblox (once a pass or product has its Id); until then the ones in Config
local passPrices = {}
local function ownedPasses()
	local ok, owned = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Passes") or "{}")
	return if ok and type(owned) == "table" then owned else {}
end

local function refreshShop()
	local owned = ownedPasses()
	for key, cardInfo in passCards do
		if owned[key] then
			setPrice(cardInfo.Buy, cardInfo.Price, cardInfo.Robux, "OWNED", true)
		else
			setPrice(cardInfo.Buy, cardInfo.Price, cardInfo.Robux, tostring(passPrices[key] or Config.GamePasses[key].Price), false)
		end
	end
	-- a pack fills you up to your max level and no further, so show what really fits
	local power = player:GetAttribute("Energy") or 0
	local room = math.max(0, Config.levelNeed(Config.levelCap(player:GetAttribute("Rebirths") or 0)) - power)
	for key, cardInfo in packCards do
		local gives = Config.packAmount(key, power, owned.DoubleHorsepower == true)
		local amount = if room <= 0 then "MAX LEVEL" else "+" .. Format.short(math.min(gives, room)) .. " HP"
		cardInfo.Amount.Text = amount
		setPrice(cardInfo.Buy, cardInfo.Price, cardInfo.Robux, tostring(productPrices[key] or Config.Products[key].Price), false)
		local bottomButton = productButtons[key]
		if bottomButton then
			bottomButton.Amount.Text = amount
		end
	end
	if (player:GetAttribute("Rebirths") or 0) >= Config.Rebirths.Max then
		setPrice(skipShopButton, skipShopPrice, skipShopRobux, "MAXED", true)
	else
		setPrice(skipShopButton, skipShopPrice, skipShopRobux, tostring(productPrices.SkipRebirth or Config.Products.SkipRebirth.Price), false)
	end
	-- the side offers go away once owned
	for key, button in offerButtons do
		button.Visible = not owned[key]
	end
end

task.spawn(function()
	for key, pass in Config.GamePasses do
		if pass.Id ~= 0 then
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, pass.Id, Enum.InfoType.GamePass)
			passPrices[key] = ok and info and info.PriceInRobux or nil
		end
	end
	for key, product in Config.Products do
		if product.Id ~= 0 then
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, product.Id, Enum.InfoType.Product)
			productPrices[key] = ok and info and info.PriceInRobux or nil
		end
	end
	refreshShop()
end)
player.AttributeChanged:Connect(function(name)
	if name == "Passes" or name == "Rebirths" or name == "Energy" then
		refreshShop()
	end
end)
refreshShop()

---------------------------------------------------------------- daily rewards
-- Seven day cards (day 7 the big gold one): claimed days dimmed, today's glowing, and a
-- CLAIM button, or a countdown to the next gift at midnight UTC. The server (Server.Game)
-- decides the streak and hands out the gift; this only shows it.
local dailyGroup = group({ Name = "DailyMenu", Size = UDim2.fromOffset(600, 290), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5) })
dailyGroup.Visible = false
local dailyPanel = Ui.new("Frame", { Active = true, BackgroundColor3 = Color3.fromRGB(24, 26, 36), BackgroundTransparency = 0.05, Size = UDim2.fromScale(1, 1), Parent = dailyGroup }, { Ui.corner(12), Ui.stroke(3, Color3.fromRGB(10, 10, 16)) })
Icons.make("Calendar", { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(12, 6), Parent = dailyPanel })
Ui.label({ Text = "Daily Rewards", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(260, 30), Position = UDim2.fromOffset(60, 12), StrokeThickness = 2.5, Parent = dailyPanel })
local closeDaily = Ui.button({ Text = "X", Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -10, 0, 10), AnchorPoint = Vector2.new(1, 0), Radius = 8, Top = Color3.fromRGB(255, 80, 90), Bottom = Color3.fromRGB(210, 30, 50), Parent = dailyPanel })
Ui.label({ Text = "Come back every day for a better gift! Miss a day and it starts again.", TextColor3 = Color3.fromRGB(190, 196, 215), Size = UDim2.fromOffset(560, 16), Position = UDim2.fromOffset(20, 48), StrokeThickness = 1.5, Parent = dailyPanel })

local DAY_W, BIG_W, DAY_GAP = 66, 120, 8
for day, reward in Config.Daily do
	local big = day == #Config.Daily
	local x = 18 + (day - 1) * (DAY_W + DAY_GAP)
	local card = Ui.panel({ Size = UDim2.fromOffset(if big then BIG_W else DAY_W, 140), Position = UDim2.fromOffset(x, 74), Radius = 9, StrokeThickness = 2.5,
		Top = if big then Color3.fromRGB(255, 214, 70) else Color3.fromRGB(70, 82, 120),
		Bottom = if big then Color3.fromRGB(240, 140, 20) else Color3.fromRGB(44, 52, 82), Parent = dailyPanel })
	Ui.label({ Text = `DAY {day}`, Size = UDim2.new(1, -10, 0, 18), Position = UDim2.new(0.5, 0, 0, 6), AnchorPoint = Vector2.new(0.5, 0), StrokeThickness = 2, Parent = card })
	local iconName = if big then "Gift" elseif reward.Wins or reward.Boost == "DoubleWins" then "Trophy" else "Bolt"
	Icons.make(iconName, { Size = UDim2.fromOffset(if big then 56 else 44, if big then 56 else 44), Position = UDim2.new(0.5, 0, 0, if big then 54 else 58), AnchorPoint = Vector2.new(0.5, 0.5), Parent = card })
	if reward.Boost then
		Ui.label({ Text = "x2", TextColor3 = Ui.Yellow, Size = UDim2.fromOffset(30, 20), Position = UDim2.new(1, -4, 0, 30), AnchorPoint = Vector2.new(1, 0), ZIndex = 3, StrokeThickness = 2, Parent = card })
	end
	local amount = Ui.label({ Text = "", TextWrapped = true, Size = UDim2.new(1, -8, 0, 36), Position = UDim2.new(0.5, 0, 1, -30), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 1.5, Parent = card })
	-- claimed: darkened, with CLAIMED across it
	local shade = Ui.new("Frame", { Name = "Claimed", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 4, Visible = false, Parent = card }, { Ui.corner(9) })
	Ui.label({ Text = "CLAIMED", TextColor3 = Color3.fromRGB(120, 255, 120), Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = -12, ZIndex = 5, StrokeThickness = 2, Parent = shade })
	-- today: a thick glowing outline and a TODAY tag on top
	local glow = Ui.new("UIStroke", { Thickness = 0, Color = Color3.fromRGB(255, 240, 90), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
	local tag = Ui.panel({ Size = UDim2.fromOffset(58, 20), Position = UDim2.new(0.5, 0, 1, 10), AnchorPoint = Vector2.new(0.5, 1), Radius = 6, StrokeThickness = 2, Top = Color3.fromRGB(120, 240, 100), Bottom = Color3.fromRGB(40, 175, 60), ZIndex = 6, Visible = false, Parent = card })
	Ui.label({ Text = "TODAY", Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 7, StrokeThickness = 1.5, Parent = tag })
	dailyCards[day] = { Card = card, Amount = amount, Shade = shade, Glow = glow, Tag = tag }
end
local claimDaily = Ui.button({ Text = "CLAIM!", Size = UDim2.fromOffset(200, 44), Position = UDim2.new(0.5, 0, 1, -14), AnchorPoint = Vector2.new(0.5, 1), Radius = 10, Top = Color3.fromRGB(120, 240, 100), Bottom = Color3.fromRGB(40, 175, 60), Parent = dailyPanel })
claimDaily.Name = "ClaimDaily"
local dailyWait = Ui.label({ Text = "", TextColor3 = Color3.fromRGB(200, 205, 225), Size = UDim2.fromOffset(360, 24), Position = UDim2.new(0.5, 0, 1, -24), AnchorPoint = Vector2.new(0.5, 1), StrokeThickness = 2, Parent = dailyPanel })

-- where the streak stands: claimedUpTo days done, today = the day you can claim now (nil if
-- you already have), and the seconds until the next UTC day
local function dailyState()
	local now = workspace:GetServerTimeNow()
	local today = now // 86400
	local last = player:GetAttribute("DailyLast") or -1
	local done = player:GetAttribute("DailyDay") or 0
	local claimedUpTo, todayDay = 0, 1
	if last >= today then
		claimedUpTo, todayDay = done, nil
	elseif last == today - 1 and done < #Config.Daily then
		claimedUpTo, todayDay = done, done + 1
	end
	return claimedUpTo, todayDay, 86400 - now % 86400
end

local function rewardText(day)
	local reward = Config.Daily[day]
	local lines = {}
	if reward.Wins then
		table.insert(lines, `{Format.short(Config.dailyWins(day, player:GetAttribute("Level") or 1))} Wins`)
	end
	if reward.Horsepower then
		table.insert(lines, `{reward.Horsepower} min of HP`)
	end
	if reward.Boost then
		table.insert(lines, `{if reward.Boost == "DoubleWins" then "Wins" else "HP"} for {reward.Minutes} min`)
	end
	return table.concat(lines, "\n")
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
end

local function refreshDaily()
	local claimedUpTo, todayDay, untilNext = dailyState()
	for day, c in dailyCards do
		c.Amount.Text = rewardText(day)
		c.Shade.Visible = day <= claimedUpTo
		c.Glow.Thickness = if day == todayDay then 4 else 0
		c.Tag.Visible = day == todayDay
	end
	claimDaily.Visible = todayDay ~= nil
	dailyWait.Visible = todayDay == nil
	dailyWait.Text = `Next gift in {clock(untilNext)}`
	local badge = menuButtons.Daily and menuButtons.Daily:FindFirstChild("Badge")
	if badge then
		badge.Visible = todayDay ~= nil
	end
end
claimDaily.Activated:Connect(function()
	remotes.ClaimDaily:FireServer()
end)
closeDaily.Activated:Connect(function()
	dailyGroup.Visible = false
end)
player.AttributeChanged:Connect(function(name)
	if name == "DailyDay" or name == "DailyLast" or name == "Level" then
		refreshDaily()
	end
end)

-- running x2 boosts from daily gifts: little timer pills beside Wins
local boostGroup = group({ Name = "Boosts", Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(166, 174) })
Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = boostGroup })
local boostPills = {}
for _, key in { "DoubleWins", "DoubleHorsepower" } do
	local pill = Ui.panel({ Size = UDim2.fromOffset(118, 28), Radius = 8, StrokeThickness = 2, Visible = false,
		Top = if key == "DoubleWins" then Color3.fromRGB(255, 214, 70) else Color3.fromRGB(90, 210, 255),
		Bottom = if key == "DoubleWins" then Color3.fromRGB(240, 140, 20) else Color3.fromRGB(30, 130, 235), Parent = boostGroup })
	boostPills[key] = Ui.label({ Text = "", Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 2, Parent = pill })
end
local function refreshBoosts()
	local now = workspace:GetServerTimeNow()
	for key, label in boostPills do
		local left = (player:GetAttribute("Boost_" .. key) or 0) - now
		label.Parent.Visible = left > 0
		if left > 0 then
			local m = math.floor(left)
			label.Text = `x2 {if key == "DoubleWins" then "Wins" else "HP"} {m // 60}:{string.format("%02d", m % 60)}`
		end
	end
end

task.spawn(function()
	while true do
		refreshDaily()
		refreshBoosts()
		task.wait(1)
	end
end)

---------------------------------------------------------------- car index
-- Every car as a card with a turning 3D preview: cars you've unlocked in full colour with
-- their Horsepower boost (EQUIPPED on the one you drive), the next one with its Wins price,
-- later ones as dark silhouettes with ???. The VIP Cruiser comes with the VIP pass.
local indexGroup = group({ Name = "IndexMenu", Size = UDim2.fromOffset(620, 400), Position = UDim2.fromScale(0.5, 0.53), AnchorPoint = Vector2.new(0.5, 0.5) })
indexGroup.Visible = false
local indexPanel = Ui.new("Frame", { Active = true, BackgroundColor3 = Color3.fromRGB(24, 26, 36), BackgroundTransparency = 0.05, Size = UDim2.fromScale(1, 1), Parent = indexGroup }, { Ui.corner(12), Ui.stroke(3, Color3.fromRGB(10, 10, 16)) })
Icons.make("Book", { Size = UDim2.fromOffset(42, 42), Position = UDim2.fromOffset(12, 6), Parent = indexPanel })
Ui.label({ Text = "Car Index", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(200, 30), Position = UDim2.fromOffset(60, 12), StrokeThickness = 2.5, Parent = indexPanel })
local indexCount = Ui.label({ Text = "", TextColor3 = Ui.Yellow, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.fromOffset(160, 24), Position = UDim2.new(1, -56, 0, 15), AnchorPoint = Vector2.new(1, 0), StrokeThickness = 2, Parent = indexPanel })
local closeIndex = Ui.button({ Text = "X", Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -10, 0, 10), AnchorPoint = Vector2.new(1, 0), Radius = 8, Top = Color3.fromRGB(255, 80, 90), Bottom = Color3.fromRGB(210, 30, 50), Parent = indexPanel })
local indexList = Ui.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -24, 1, -62), Position = UDim2.fromOffset(12, 54), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = indexPanel }, {
	Ui.new("UIGridLayout", { CellSize = UDim2.fromOffset(136, 160), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	Ui.new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6) }),
})

local CAR_TIERS = CarLooks.Count + 1 -- the stand cars, then the VIP Cruiser
local indexCards = {}
for tier = 1, CAR_TIERS do
	local vip = tier == CarLooks.VipTier
	local card = Ui.panel({ Size = UDim2.fromOffset(136, 160), Radius = 9, StrokeThickness = 2.5, LayoutOrder = tier,
		Top = if vip then Color3.fromRGB(255, 214, 70) else Color3.fromRGB(70, 82, 120),
		Bottom = if vip then Color3.fromRGB(240, 140, 20) else Color3.fromRGB(44, 52, 82), Parent = indexList })
	local view = Ui.new("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 90), Position = UDim2.fromOffset(4, 24), Ambient = Color3.fromRGB(170, 170, 180), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-1, -2, -1), Parent = card })
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera
	local model = CarLooks.build(tier, CFrame.identity)
	model.Parent = view
	local info = CarLooks.info(tier) or { Name = `Car {tier}`, Length = 8 }
	local name = Ui.label({ Text = info.Name, Size = UDim2.new(1, -10, 0, 18), Position = UDim2.new(0.5, 0, 0, 5), AnchorPoint = Vector2.new(0.5, 0), StrokeThickness = 2, Parent = card })
	local line = Ui.label({ Text = "", Size = UDim2.new(1, -10, 0, 16), Position = UDim2.new(0.5, 0, 1, -32), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 1.5, Parent = card })
	local tag = Ui.panel({ Size = UDim2.fromOffset(86, 20), Position = UDim2.new(0.5, 0, 1, -6), AnchorPoint = Vector2.new(0.5, 1), Radius = 6, StrokeThickness = 2, Top = Color3.fromRGB(120, 240, 100), Bottom = Color3.fromRGB(40, 175, 60), Visible = false, Parent = card })
	local tagText = Ui.label({ Text = "EQUIPPED", Size = UDim2.new(1, -8, 0, 14), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 1.5, Parent = tag })
	indexCards[tier] = { View = view, Camera = camera, Name = name, RealName = info.Name, Line = line, Tag = tag, TagText = tagText, Distance = math.max(info.Length or 8, 6) * 2.4 }
end

local function refreshIndex()
	local unlocked = player:GetAttribute("Cars") or 1
	local equipped = player:GetAttribute("EquippedCar") or 1
	local ok, passes = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Passes") or "{}")
	local hasVip = ok and type(passes) == "table" and passes.Vip == true
	local found = 0
	for tier, c in indexCards do
		local vip = tier == CarLooks.VipTier
		local owned = if vip then hasVip else tier <= unlocked
		local nextUp = not vip and tier == unlocked + 1
		if owned then
			found += 1
		end
		local known = owned or nextUp or vip -- the next car and the VIP car are shown, the rest stay a mystery
		c.View.ImageColor3 = if known then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
		c.View.ImageTransparency = if known then 0 else 0.25
		c.Name.Text = if known then c.RealName else "???"
		local boost = Config.Cars.Boosts[tier] or 1
		if owned then
			c.Line.Text = `x{boost} Horsepower`
			c.Line.TextColor3 = Color3.fromRGB(110, 220, 255)
		elseif vip then
			c.Line.Text = "VIP pass"
			c.Line.TextColor3 = Ui.Yellow
		elseif nextUp then
			c.Line.Text = `{Format.short(Config.Cars.Prices[tier] or 0)} Wins`
			c.Line.TextColor3 = Ui.Yellow
		else
			c.Line.Text = "Locked"
			c.Line.TextColor3 = Color3.fromRGB(170, 175, 190)
		end
		c.Tag.Visible = owned and tier == equipped
	end
	indexCount.Text = `{found}/{CAR_TIERS} cars`
end
closeIndex.Activated:Connect(function()
	indexGroup.Visible = false
end)
player.AttributeChanged:Connect(function(name)
	if name == "Cars" or name == "EquippedCar" or name == "Passes" then
		refreshIndex()
	end
end)
refreshIndex()
-- the previews turn slowly while the Index is open
RunService.RenderStepped:Connect(function()
	if not indexGroup.Visible then
		return
	end
	local angle = os.clock() * 0.6
	for _, c in indexCards do
		local d = c.Distance
		c.Camera.CFrame = CFrame.lookAt(Vector3.new(math.sin(angle) * d, d * 0.45, math.cos(angle) * d), Vector3.new(0, 1.2, 0))
	end
end)

local function closeMenus()
	shopGroup.Visible = false
	rebirthGroup.Visible = false
	dailyGroup.Visible = false
	indexGroup.Visible = false
end
openShop = function()
	if shopGroup.Visible then
		return
	end
	closeMenus()
	refreshShop()
	shopGroup.Visible = true
	Ui.pop(shopPanel, 1.06)
end
closeShop.Activated:Connect(function()
	shopGroup.Visible = false
end)

---------------------------------------------------------------- hooking up the buttons
local function comingSoon(name)
	return function()
		showToast(`{name} is coming soon!`, Color3.new(1, 1, 1))
	end
end
for name, button in menuButtons do
	if name == "Rebirth" then
		button.Activated:Connect(function()
			local show = not rebirthGroup.Visible
			closeMenus()
			rebirthGroup.Visible = show
			if show then
				refreshRebirth()
				Ui.pop(rebirthPanel, 1.08)
			end
		end)
	elseif name == "Shop" then
		button.Activated:Connect(function()
			if shopGroup.Visible then
				shopGroup.Visible = false
			else
				openShop()
			end
		end)
	elseif name == "Index" then
		button.Activated:Connect(function()
			local show = not indexGroup.Visible
			closeMenus()
			indexGroup.Visible = show
			if show then
				refreshIndex()
				Ui.pop(indexPanel, 1.06)
			end
		end)
	elseif name == "Daily" then
		button.Activated:Connect(function()
			local show = not dailyGroup.Visible
			closeMenus()
			dailyGroup.Visible = show
			if show then
				refreshDaily()
				Ui.pop(dailyPanel, 1.06)
			end
		end)
	else
		button.Activated:Connect(comingSoon(name))
	end
end
for key, button in offerButtons do
	button.Activated:Connect(function()
		remotes.Purchase:FireServer("Pass", key)
	end)
end
for key, button in productButtons do
	button.Activated:Connect(function()
		remotes.Purchase:FireServer("Product", key)
	end)
end

return {}


