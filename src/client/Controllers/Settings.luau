-- Settings (the button under the menu grid): volume sliders and mute buttons for the music and
-- the sound effects, saved with the player's progress, and a feedback box (Bug / Idea / Other)
-- that lands in the owner's Admin Panel. Also plays the background music: a few calm, light
-- tracks (licensed APM Music, free for every Roblox game) in a shuffled order.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local saveRemote = remotes:WaitForChild("SaveSettings")
local feedbackRemote = remotes:WaitForChild("SendFeedback")

local TRACKS = {
	1839884820, -- Somehow Somewhere: light, positive guitar
	1841004403, -- Feels Easy
	1839821641, -- Pleased Day
}
local MUSIC_LOUDNESS = 0.4 -- the music at full slider; the default slider (0.5) plays it at 0.2
local FEEDBACK_LENGTH = 300

---------------------------------------------------------------- sound groups
-- every sound but the music goes in Effects, so one slider turns them all up or down
local musicGroup = Ui.new("SoundGroup", { Name = "MusicGroup", Parent = SoundService })
local effectsGroup = Ui.new("SoundGroup", { Name = "EffectsGroup", Parent = SoundService })
local music = Ui.new("Sound", { Name = "Music", Volume = MUSIC_LOUDNESS, SoundGroup = musicGroup, Parent = SoundService })
local function sortSound(sound)
	if sound:IsA("Sound") and sound ~= music and not sound.SoundGroup then
		sound.SoundGroup = effectsGroup
	end
end
for _, d in SoundService:GetDescendants() do
	sortSound(d)
end
SoundService.DescendantAdded:Connect(sortSound)
workspace.DescendantAdded:Connect(sortSound)

-- the current settings (from the save once it's loaded)
local settings = { MusicVolume = 0.5, EffectsVolume = 1, MusicMuted = false, EffectsMuted = false }
local function apply()
	musicGroup.Volume = if settings.MusicMuted then 0 else settings.MusicVolume
	effectsGroup.Volume = if settings.EffectsMuted then 0 else settings.EffectsVolume
end
local function readSaved()
	for key in settings do
		local v = player:GetAttribute(key)
		if v ~= nil then
			settings[key] = v
		end
	end
	apply()
end
readSaved()

-- changes are sent once the player stops fiddling, not on every slider step
local saveQueued = false
local function save()
	apply()
	if saveQueued then
		return
	end
	saveQueued = true
	task.delay(1, function()
		saveQueued = false
		saveRemote:FireServer(settings)
	end)
end

---------------------------------------------------------------- the music
local order, at = {}, 0
local function nextTrack()
	at += 1
	if at > #order then
		order = table.clone(TRACKS)
		for i = #order, 2, -1 do
			local j = math.random(i)
			order[i], order[j] = order[j], order[i]
		end
		at = 1
	end
	music.SoundId = "rbxassetid://" .. order[at]
	music:Play()
end
music.Ended:Connect(nextTrack)
task.delay(2, nextTrack) -- a moment after joining, so it doesn't start over the loading

---------------------------------------------------------------- the Settings button
local gui = Ui.new("ScreenGui", { Name = "Settings", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5, Parent = player:WaitForChild("PlayerGui") })
local function group(props)
	return Ui.scaled(Ui.new("Frame", { BackgroundTransparency = 1, Name = props.Name, Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, Parent = gui }))
end
local openGroup = group({ Name = "SettingsButton", Size = UDim2.fromOffset(158, 32), Position = UDim2.fromOffset(4, 418) })
local openButton = Ui.button({ Text = "Settings", Size = UDim2.fromScale(1, 1), Radius = 8, Top = Color3.fromRGB(120, 128, 160), Bottom = Color3.fromRGB(70, 76, 104), Parent = openGroup })
openButton.Name = "Open"

---------------------------------------------------------------- the menu
local DARK = Color3.fromRGB(24, 26, 36)
local SOFT = Color3.fromRGB(190, 196, 215)
local GREEN_TOP, GREEN_BOTTOM = Color3.fromRGB(120, 240, 100), Color3.fromRGB(40, 175, 60)
local GREY_TOP, GREY_BOTTOM = Color3.fromRGB(110, 116, 140), Color3.fromRGB(70, 76, 100)
local RED_TOP, RED_BOTTOM = Color3.fromRGB(255, 80, 90), Color3.fromRGB(210, 30, 50)
local BLUE_TOP, BLUE_BOTTOM = Color3.fromRGB(110, 200, 255), Color3.fromRGB(40, 120, 220)

local menuGroup = group({ Name = "SettingsMenu", Size = UDim2.fromOffset(440, 380), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5) })
menuGroup.Visible = false
local panel = Ui.new("Frame", { Active = true, BackgroundColor3 = DARK, BackgroundTransparency = 0.05, Size = UDim2.fromScale(1, 1), Parent = menuGroup }, { Ui.corner(12), Ui.stroke(3, Color3.fromRGB(10, 10, 16)) })
Ui.label({ Text = "Settings", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(200, 30), Position = UDim2.fromOffset(18, 12), StrokeThickness = 2.5, Parent = panel })
local close = Ui.button({ Text = "X", Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -10, 0, 10), AnchorPoint = Vector2.new(1, 0), Radius = 8, Top = RED_TOP, Bottom = RED_BOTTOM, Parent = panel })

-- one row: name, a slider and a mute button
local function volumeRow(y, title, volumeKey, mutedKey)
	Ui.label({ Text = title, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(150, 22), Position = UDim2.fromOffset(18, y), StrokeThickness = 2, Parent = panel })
	local percent = Ui.label({ Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = SOFT, Size = UDim2.fromOffset(60, 18), Position = UDim2.fromOffset(250, y + 2), StrokeThickness = 1.5, Parent = panel })
	-- the bar you drag along (a taller invisible strip makes it easy to grab on a phone)
	local hit = Ui.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(292, 34), Position = UDim2.fromOffset(18, y + 26), Parent = panel })
	local track = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(60, 64, 84), Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromScale(0, 0.5), AnchorPoint = Vector2.new(0, 0.5), Parent = hit }, { Ui.corner(6), Ui.stroke(2, Color3.fromRGB(10, 10, 16)) })
	local fill = Ui.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0.5, 1), Parent = track }, { Ui.corner(6), Ui.gradient(BLUE_TOP, BLUE_BOTTOM) })
	local knob = Ui.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(24, 24), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2, Parent = track }, { Ui.corner(12), Ui.stroke(2.5, Color3.fromRGB(10, 10, 16)) })
	local mute = Ui.button({ Text = "", Size = UDim2.fromOffset(96, 34), Position = UDim2.fromOffset(326, y + 26), Radius = 8, Top = GREEN_TOP, Bottom = GREEN_BOTTOM, Parent = panel })

	local function show()
		local v = settings[volumeKey]
		local muted = settings[mutedKey]
		fill.Size = UDim2.fromScale(v, 1)
		knob.Position = UDim2.fromScale(v, 0.5)
		percent.Text = if muted then "MUTED" else `{math.round(v * 100)}%`
		fill.Visible = v > 0.01
		mute.Label.Text = if muted then "UNMUTE" else "MUTE"
		Ui.recolor(mute, if muted then RED_TOP else GREY_TOP, if muted then RED_BOTTOM else GREY_BOTTOM)
		knob.BackgroundColor3 = if muted then Color3.fromRGB(150, 150, 160) else Color3.new(1, 1, 1)
	end

	local dragging = false
	local function setFrom(x)
		local v = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		settings[volumeKey] = math.round(v * 100) / 100
		settings[mutedKey] = false -- moving the slider unmutes it
		show()
		save()
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			setFrom(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	mute.Activated:Connect(function()
		settings[mutedKey] = not settings[mutedKey]
		show()
		save()
	end)
	return show
end

local showMusic = volumeRow(58, "Music", "MusicVolume", "MusicMuted")
local showEffects = volumeRow(128, "Sound Effects", "EffectsVolume", "EffectsMuted")
local function showAll()
	showMusic()
	showEffects()
end
showAll()
for key in settings do
	player:GetAttributeChangedSignal(key):Connect(function()
		if not saveQueued then -- the save arriving: don't fight a slider being dragged
			readSaved()
			showAll()
		end
	end)
end

---------------------------------------------------------------- feedback
Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(60, 64, 84), BorderSizePixel = 0, Size = UDim2.new(1, -36, 0, 2), Position = UDim2.fromOffset(18, 198), Parent = panel })
Ui.label({ Text = "Feedback", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(200, 22), Position = UDim2.fromOffset(18, 208), StrokeThickness = 2, Parent = panel })
local kind = nil
local kindButtons = {}
local KINDS = { { "Bug", RED_TOP, RED_BOTTOM }, { "Idea", GREEN_TOP, GREEN_BOTTOM }, { "Other", BLUE_TOP, BLUE_BOTTOM } }
local function showKinds()
	for _, k in KINDS do
		local on = kind == k[1]
		Ui.recolor(kindButtons[k[1]], if on then k[2] else GREY_TOP, if on then k[3] else GREY_BOTTOM)
	end
end
for i, k in KINDS do
	local b = Ui.button({ Text = string.upper(k[1]), Size = UDim2.fromOffset(72, 28), Position = UDim2.fromOffset(196 + (i - 1) * 76, 205), Radius = 7, Parent = panel, Top = GREY_TOP, Bottom = GREY_BOTTOM })
	kindButtons[k[1]] = b
	b.Activated:Connect(function()
		kind = k[1]
		showKinds()
	end)
end
showKinds()
local box = Ui.new("TextBox", {
	BackgroundColor3 = Color3.fromRGB(44, 48, 66),
	Size = UDim2.new(1, -36, 0, 70),
	Position = UDim2.fromOffset(18, 242),
	Text = "",
	PlaceholderText = "Found a bug or have an idea? Tell us here!",
	PlaceholderColor3 = Color3.fromRGB(140, 146, 170),
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	TextWrapped = true,
	MultiLine = true,
	ClearTextOnFocus = false,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = panel,
}, { Ui.corner(8), Ui.stroke(2, Color3.fromRGB(10, 10, 16)), Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) }) })
local count = Ui.label({ Text = `0/{FEEDBACK_LENGTH}`, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = SOFT, Size = UDim2.fromOffset(80, 16), Position = UDim2.fromOffset(18, 324), StrokeThickness = 1.5, Parent = panel })
local status = Ui.label({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = SOFT, TextScaled = false, TextSize = 13, Size = UDim2.fromOffset(200, 34), Position = UDim2.fromOffset(100, 324), StrokeThickness = 1.5, TextWrapped = true, Parent = panel })
local send = Ui.button({ Text = "SEND", Size = UDim2.fromOffset(110, 38), Position = UDim2.new(1, -18, 1, -14), AnchorPoint = Vector2.new(1, 1), Radius = 9, Top = GREEN_TOP, Bottom = GREEN_BOTTOM, Parent = panel })
box:GetPropertyChangedSignal("Text"):Connect(function()
	if #box.Text > FEEDBACK_LENGTH then
		box.Text = string.sub(box.Text, 1, FEEDBACK_LENGTH)
	end
	count.Text = `{#box.Text}/{FEEDBACK_LENGTH}`
end)
local sending = false
send.Activated:Connect(function()
	if sending then
		return
	end
	if not kind then
		status.Text = "Pick Bug, Idea or Other first"
		status.TextColor3 = Color3.fromRGB(255, 120, 120)
		return
	end
	sending = true
	status.Text = "Sending..."
	status.TextColor3 = SOFT
	local ok, okSent, message = pcall(feedbackRemote.InvokeServer, feedbackRemote, kind, box.Text)
	sending = false
	if not ok then
		okSent, message = false, "Couldn't send it, try again soon"
	end
	status.Text = message or ""
	status.TextColor3 = if okSent then Color3.fromRGB(120, 235, 120) else Color3.fromRGB(255, 120, 120)
	if okSent then
		box.Text = ""
		kind = nil
		showKinds()
	end
end)

---------------------------------------------------------------- open and close
local function setOpen(open)
	if open then
		-- one menu at a time: close the HUD's menus first
		local hud = player.PlayerGui:FindFirstChild("Hud")
		for _, child in if hud then hud:GetChildren() else {} do
			if child:IsA("Frame") and (string.find(child.Name, "Menu$") or child.Name == "Shop") then
				child.Visible = false
			end
		end
		readSaved()
		showAll()
		status.Text = ""
		Ui.pop(panel, 1.06)
	end
	menuGroup.Visible = open
end
openButton.Activated:Connect(function()
	setOpen(not menuGroup.Visible)
end)
close.Activated:Connect(function()
	setOpen(false)
end)

return {}
