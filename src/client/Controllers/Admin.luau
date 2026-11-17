-- Everyone: global messages slide down from the top (and go in chat), running Admin Abuse
-- events show a countdown at the top right, and "An admin has joined the server" fades in.
-- Admins: a gold ADMIN button opens the Admin Panel: drag it by its pink bar, fold it away,
-- search for a tool, star tools into FAVORITES; tabs MAIN, ABUSE, PLAYERS, WORLD, REQUESTS
-- (owner) and TESTING.
-- The server checks everything; this only shows things and sends requests.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Ui = require(script.Parent.Parent.Ui)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local A = Config.Admin

local gui = Ui.new("ScreenGui", { Name = "Admin", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })

local function group(props)
	return Ui.scaled(Ui.new("Frame", { BackgroundTransparency = 1, Name = props.Name, Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, Parent = gui }))
end

local function chatLine(text)
	task.spawn(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			pcall(general.DisplaySystemMessage, general, text)
		end
	end)
end

local function escape(text)
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

---------------------------------------------------------------- global messages (everyone)
-- Kept simple: a thin dark strip near the top that fades out at both ends, with the
-- sender's name in gold and the message in white. It fades in, stays, fades out.
local BANNER_TIME = 5.5
local BOLD = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)
local FADE = TweenInfo.new(0.35, Enum.EasingStyle.Quad)
local STRIP_SEE_THROUGH = 0.45

local bannerGroup = group({ Name = "Announcement", Size = UDim2.fromOffset(860, 34), Position = UDim2.new(0.5, 0, 0, 92), AnchorPoint = Vector2.new(0.5, 0) })
local strip = Ui.new("Frame", { Name = "Strip", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 1), Parent = bannerGroup }, {
	Ui.new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, 0),
			NumberSequenceKeypoint.new(0.85, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}),
	Ui.new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 90), PaddingRight = UDim.new(0, 90) }),
})
local bannerText = Ui.label({ Name = "Message", Text = "", RichText = true, FontFace = BOLD, TextScaled = false, TextSize = 22, TextWrapped = true, TextColor3 = Color3.new(1, 1, 1), TextTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromScale(1, 0), StrokeThickness = 1.5, Parent = strip })
local bannerStroke = bannerText:FindFirstChildOfClass("UIStroke")
bannerStroke.Transparency = 1

local function fadeTo(shown)
	TweenService:Create(strip, FADE, { BackgroundTransparency = if shown then STRIP_SEE_THROUGH else 1 }):Play()
	TweenService:Create(bannerText, FADE, { TextTransparency = if shown then 0 else 1 }):Play()
	local t = TweenService:Create(bannerStroke, FADE, { Transparency = if shown then 0.2 else 1 })
	t:Play()
	return t
end

local bannerQueue = {}
local showingBanner = false
local function nextBanner()
	if showingBanner or #bannerQueue == 0 then
		return
	end
	showingBanner = true
	local m = table.remove(bannerQueue, 1)
	bannerText.Text = `<font color="#FFD23C">{escape(tostring(m.Name))}</font>   {escape(m.Text)}`
	fadeTo(true)
	task.delay(BANNER_TIME, function()
		fadeTo(false).Completed:Wait()
		showingBanner = false
		nextBanner()
	end)
end
remotes:WaitForChild("Announcement").OnClientEvent:Connect(function(m)
	table.insert(bannerQueue, m)
	chatLine(`<font color="#FFC82D">[ANNOUNCEMENT] {escape(m.Name)}:</font> {escape(m.Text)}`)
	nextBanner()
end)

---------------------------------------------------------------- admin joined (everyone)
local joinedLabel = Ui.label({ Text = "", TextTransparency = 1, Size = UDim2.fromOffset(600, 34), Position = UDim2.fromScale(0.5, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 2, Parent = gui })
local joinedStroke = joinedLabel:FindFirstChildOfClass("UIStroke")
joinedStroke.Transparency = 1
remotes:WaitForChild("Notice").OnClientEvent:Connect(function(n)
	if n.Kind ~= "AdminJoined" then
		return
	end
	local text = `An admin has joined the server: {n.Name}`
	chatLine(`<font color="#FFC82D">{escape(text)}</font>`)
	joinedLabel.Text = text
	local fadeIn = TweenInfo.new(0.6)
	TweenService:Create(joinedLabel, fadeIn, { TextTransparency = 0.15 }):Play()
	TweenService:Create(joinedStroke, fadeIn, { Transparency = 0.4 }):Play()
	task.delay(3.5, function()
		local fadeOut = TweenInfo.new(1)
		TweenService:Create(joinedLabel, fadeOut, { TextTransparency = 1 }):Play()
		TweenService:Create(joinedStroke, fadeOut, { Transparency = 1 }):Play()
	end)
end)

---------------------------------------------------------------- running abuses (everyone)
-- one rainbow pill at the top right (left of the ADMIN button for admins), so it never
-- covers the pass offers
local eventGroup = group({ Name = "Events", Size = UDim2.fromOffset(330, 38), Position = UDim2.new(1, -10, 0, 60), AnchorPoint = Vector2.new(1, 0) })
local function placePill()
	eventGroup.Position = UDim2.new(1, if player:GetAttribute("Admin") then -116 else -10, 0, 60)
end
player:GetAttributeChangedSignal("Admin"):Connect(placePill)
placePill()
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 80)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 90)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 80, 255)),
})
local eventPill = Ui.panel({ Name = "Pill", Size = UDim2.fromScale(1, 1), Radius = 10, StrokeThickness = 2.5, Top = Color3.new(1, 1, 1), Visible = false, Parent = eventGroup })
eventPill.UIGradient.Color = RAINBOW
eventPill.UIGradient.Rotation = 0
local eventLabel = Ui.label({ Text = "", Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), StrokeThickness = 2.5, Parent = eventPill })
local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h, m, s = seconds // 3600, seconds // 60 % 60, seconds % 60
	return if h > 0 then string.format("%d:%02d:%02d", h, m, s) else string.format("%d:%02d", m, s)
end
-- where each boost stands right now: nil (off), "soon" (scheduled) or "on", and the seconds to go
local function abuseState(key)
	local now = workspace:GetServerTimeNow()
	local ends = workspace:GetAttribute("Event_" .. key)
	local starts = workspace:GetAttribute("EventStart_" .. key) or 0
	if not ends or ends <= now then
		return nil, 0
	elseif starts > now then
		return "soon", starts - now
	end
	return "on", ends - now
end
-- the boosts running now (or, if none, the ones coming up) and the longest time to go
local function abuseSummary()
	local on, soon, onLeft, soonLeft = {}, {}, 0, 0
	for _, e in A.Events do
		local state, left = abuseState(e.Key)
		if state == "on" then
			table.insert(on, e.Name)
			onLeft = math.max(onLeft, left)
		elseif state == "soon" then
			table.insert(soon, e.Name)
			soonLeft = math.max(soonLeft, left)
		end
	end
	if #on > 0 then
		return "on", table.concat(on, " + "), onLeft
	elseif #soon > 0 then
		return "soon", table.concat(soon, " + "), soonLeft
	end
	return nil, "", 0
end
task.spawn(function()
	while true do
		local state, names, left = abuseSummary()
		eventPill.Visible = state ~= nil
		if state == "soon" then
			eventLabel.Text = `ADMIN ABUSE in {clock(left)}: {names}`
		elseif state == "on" then
			eventLabel.Text = `ADMIN ABUSE! {names} {clock(left)}`
		end
		task.wait(0.25)
	end
end)

---------------------------------------------------------------- the Admin Panel (admins only)
local adminRemote = remotes:WaitForChild("Admin")
local NAVY_TOP, NAVY_BOTTOM = Color3.fromRGB(28, 30, 56), Color3.fromRGB(16, 17, 34)
local PINK = Color3.fromRGB(255, 70, 190)
local PINK_DARK = Color3.fromRGB(200, 40, 160)
local SECTION = Color3.fromRGB(34, 37, 68)
local SECTION_EDGE = Color3.fromRGB(78, 84, 140)
local FIELD = Color3.fromRGB(50, 54, 90)
local SOFT = Color3.fromRGB(170, 176, 205)
local OFF_TOP, OFF_BOTTOM = Color3.fromRGB(62, 67, 108), Color3.fromRGB(46, 50, 86)
local GOLD_TOP, GOLD_BOTTOM = Color3.fromRGB(255, 220, 80), Color3.fromRGB(235, 160, 25)
local BLUE_TOP, BLUE_BOTTOM = Color3.fromRGB(70, 170, 255), Color3.fromRGB(30, 115, 235)
local GREEN_TOP, GREEN_BOTTOM = Color3.fromRGB(120, 235, 90), Color3.fromRGB(40, 170, 50)
local RED_TOP, RED_BOTTOM = Color3.fromRGB(255, 105, 70), Color3.fromRGB(225, 40, 50)
local GREY_TOP, GREY_BOTTOM = Color3.fromRGB(120, 122, 140), Color3.fromRGB(85, 87, 104)
local ORANGE = Color3.fromRGB(255, 170, 60)
local GOOD = Color3.fromRGB(120, 235, 120)
local BAD = Color3.fromRGB(255, 110, 110)

local function eventName(key)
	for _, e in A.Events do
		if e.Key == key then
			return e.Name
		end
	end
	return tostring(key)
end

local function namesOf(keys)
	local names = {}
	for _, key in if type(keys) == "table" then keys else {} do
		table.insert(names, eventName(key))
	end
	return table.concat(names, " + ")
end

local function call(action, ...)
	local ok, a, b = pcall(adminRemote.InvokeServer, adminRemote, action, ...)
	if not ok then
		return false, "Couldn't reach the server"
	end
	return a, b
end

-- small plain text (no outline) for the panel
local function text(props)
	props.TextScaled = false
	props.TextSize = props.TextSize or 14
	props.StrokeThickness = props.StrokeThickness or 0
	return Ui.label(props)
end

-- a chunky panel button
local function button(props)
	local b = Ui.button({ Text = props.Text, Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, Radius = props.Radius or 7, Top = props.Top or OFF_TOP, Bottom = props.Bottom or OFF_BOTTOM, StrokeThickness = props.Stroke or 2, LayoutOrder = props.LayoutOrder, Parent = props.Parent })
	if props.Name then
		b.Name = props.Name
	end
	return b
end

local function row(parent, height, order, gap)
	return Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height), LayoutOrder = order, Parent = parent }, {
		Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, gap or 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
end

local function buildPanel()
	local isOwner = player:GetAttribute("Owner") == true

	local buttonGroup = group({ Name = "AdminButton", Size = UDim2.fromOffset(96, 38), Position = UDim2.new(1, -10, 0, 60), AnchorPoint = Vector2.new(1, 0) })
	local openButton = Ui.button({ Text = "ADMIN", Size = UDim2.fromScale(1, 1), Radius = 9, Top = Color3.fromRGB(255, 220, 70), Bottom = Color3.fromRGB(240, 150, 20), Parent = buttonGroup })
	openButton.Name = "Open"

	------------------------------------------------------------ the frame, title bar and sidebar
	local W, H, BAR = 600, 400, 42
	local panelGroup = group({ Name = "AdminPanel", Size = UDim2.fromOffset(W, H), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	panelGroup.Visible = false
	local panel = Ui.new("Frame", { Name = "Frame", Active = true, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = panelGroup }, {
		Ui.corner(12),
		Ui.stroke(3, PINK),
		Ui.gradient(NAVY_TOP, NAVY_BOTTOM),
	})
	local bar = Ui.new("Frame", { Name = "TitleBar", Active = true, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, BAR), Parent = panel }, {
		Ui.corner(12),
		Ui.gradient(Color3.fromRGB(255, 90, 200), PINK_DARK),
	})
	-- square off the bar's bottom corners
	Ui.new("Frame", { BorderSizePixel = 0, BackgroundColor3 = PINK_DARK, Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12), Parent = bar })
	Ui.label({ Text = "ADMIN PANEL", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(220, 26), Position = UDim2.new(0, 16, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 2, StrokeThickness = 2.5, Parent = bar })
	local search = Ui.new("TextBox", {
		Name = "Search",
		BackgroundColor3 = Color3.fromRGB(40, 20, 50),
		BackgroundTransparency = 0.25,
		Size = UDim2.fromOffset(180, 28),
		Position = UDim2.new(1, -86, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		ZIndex = 2,
		Text = "",
		PlaceholderText = "Find a tool...",
		PlaceholderColor3 = Color3.fromRGB(215, 190, 225),
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bar,
	}, { Ui.corner(7), Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 10) }) })
	local minimize = button({ Name = "Minimize", Text = "—", Size = UDim2.fromOffset(30, 28), Position = UDim2.new(1, -46, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Top = GREY_TOP, Bottom = GREY_BOTTOM, Parent = bar })
	local close = button({ Name = "Close", Text = "X", Size = UDim2.fromOffset(30, 28), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Top = RED_TOP, Bottom = RED_BOTTOM, Parent = bar })
	minimize.ZIndex = 2
	close.ZIndex = 2

	local body = Ui.new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -BAR), Position = UDim2.fromOffset(0, BAR), Parent = panel })
	text({ Text = "Admin tools (only admins can see this)", TextColor3 = SOFT, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(300, 16), Position = UDim2.fromOffset(14, 6), Parent = body })

	-- the tabs down the left
	local SIDE = 128
	local sidebar = Ui.new("Frame", { Name = "Tabs", BackgroundColor3 = Color3.fromRGB(14, 15, 30), BackgroundTransparency = 0.2, Size = UDim2.new(0, SIDE, 1, -60), Position = UDim2.fromOffset(10, 26), Parent = body }, {
		Ui.corner(9),
		Ui.new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
		Ui.new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local serverType = workspace:GetAttribute("ServerType") or "PUBLIC"
	text({ Text = `{serverType} SERVER`, TextColor3 = if serverType == "PUBLIC" then GOOD else ORANGE, TextSize = 12, Size = UDim2.fromOffset(SIDE, 16), Position = UDim2.new(0, 10, 1, -26), Parent = body })

	-- the tools, in a scrolling column on the right
	local content = Ui.new("ScrollingFrame", {
		Name = "Content",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -SIDE - 32, 1, -60),
		Position = UDim2.fromOffset(SIDE + 20, 26),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = PINK,
		Parent = body,
	}, {
		Ui.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Ui.new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 4), PaddingTop = UDim.new(0, 2), PaddingLeft = UDim.new(0, 2) }),
	})
	local emptyNote = text({ Name = "Empty", Text = "", TextColor3 = SOFT, TextWrapped = true, Size = UDim2.new(1, 0, 0, 40), Visible = false, LayoutOrder = -1, Parent = content })
	local status = text({ Name = "Status", Text = "", TextSize = 13, TextColor3 = SOFT, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -SIDE - 32, 0, 20), Position = UDim2.new(0, SIDE + 20, 1, -28), Parent = body })
	local function say(message, good)
		status.Text = message or ""
		status.TextColor3 = if good == false then BAD elseif good then GOOD else SOFT
	end

	------------------------------------------------------------ sections and favorites
	local sections = {} -- in order: { Id, Tab, Title, Keywords, Frame, Star }
	local favorites = {}
	local function saveFavorites()
		local list = {}
		for _, s in sections do
			if favorites[s.Id] then
				table.insert(list, s.Id)
			end
		end
		task.spawn(call, "SetFavorites", list)
	end
	local refreshView -- set below

	-- a foldable tool box with a star: build(inside) fills it
	local function section(id, tab, title, keywords, build)
		local frame = Ui.new("Frame", { Name = id, BackgroundColor3 = SECTION, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Visible = false, Parent = content }, {
			Ui.corner(9),
			Ui.stroke(1.5, SECTION_EDGE),
			Ui.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local header = Ui.new("TextButton", { Name = "Header", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 1, Parent = frame })
		local fold = text({ Text = "-", TextSize = 20, Size = UDim2.fromOffset(24, 34), Position = UDim2.fromOffset(6, 0), Parent = header })
		text({ Text = title, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -74, 1, 0), Position = UDim2.fromOffset(30, 0), Parent = header })
		local star = Ui.new("TextButton", { Name = "Star", Text = "★", Font = Enum.Font.GothamBold, TextSize = 20, BackgroundTransparency = 1, Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -38, 0, 0), Parent = header })
		local inside = Ui.new("Frame", { Name = "Body", BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2, Parent = frame }, {
			Ui.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
			Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10) }),
		})
		local s = { Id = id, Tab = tab, Title = title, Keywords = string.lower(title .. " " .. keywords), Frame = frame, Star = star }
		table.insert(sections, s)
		s.ShowStar = function()
			star.TextColor3 = if favorites[id] then GOLD_TOP else Color3.fromRGB(95, 100, 145)
		end
		s.ShowStar()
		header.Activated:Connect(function()
			inside.Visible = not inside.Visible
			fold.Text = if inside.Visible then "-" else "+"
		end)
		star.Activated:Connect(function()
			favorites[id] = not favorites[id] or nil
			s.ShowStar()
			saveFavorites()
			refreshView()
		end)
		build(inside)
		return s
	end

	------------------------------------------------------------ MAIN: global message
	section("Message", "Main", "GLOBAL MESSAGE (every server)", "announce announcement chat broadcast", function(inside)
		local box = Ui.new("TextBox", {
			Name = "MessageBox",
			BackgroundColor3 = FIELD,
			Size = UDim2.new(1, 0, 0, 70),
			Text = "",
			PlaceholderText = "write your global message here",
			PlaceholderColor3 = SOFT,
			TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextWrapped = true,
			MultiLine = true,
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			LayoutOrder = 1,
			Parent = inside,
		}, { Ui.corner(7), Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6) }) })
		local bottom = Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 2, Parent = inside })
		local note = if isOwner then "" else "   (goes to the owner first)"
		local counter = text({ Text = `0/{A.MaxMessage}{note}`, TextSize = 12, TextColor3 = SOFT, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(240, 32), Parent = bottom })
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if #box.Text > A.MaxMessage then
				box.Text = box.Text:sub(1, A.MaxMessage)
			end
			counter.Text = `{#box.Text}/{A.MaxMessage}{note}`
		end)
		local send = button({ Name = "Send", Text = "SEND", Size = UDim2.fromOffset(110, 30), Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Top = BLUE_TOP, Bottom = BLUE_BOTTOM, Parent = bottom })
		local busy = false
		send.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			say("Sending...")
			local ok, message = call("Announce", box.Text)
			say(message, ok)
			if ok then
				box.Text = ""
			end
			busy = false
		end)
	end)

	------------------------------------------------------------ MAIN: server info
	local infoLines
	section("Server", "Main", "SERVER INFO", "players uptime public private", function(inside)
		infoLines = {
			text({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = inside }),
			text({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = SOFT, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 2, Parent = inside }),
		}
	end)

	------------------------------------------------------------ ABUSE
	local abuseStatus
	section("Abuse", "Abuse", "ADMIN ABUSE (every server, everyone)", "boost event 2x horsepower wins schedule", function(inside)
		abuseStatus = text({ Text = "Not running", TextColor3 = ORANGE, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 1, Parent = inside })

		-- pick any mix: gold = on
		local picked = {}
		text({ Text = "Pick the boosts (gold = on):", TextSize = 12, TextColor3 = SOFT, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 2, Parent = inside })
		local boostRow = row(inside, 30, 3)
		for i, e in A.Events do
			picked[e.Key] = true
			local chip = button({ Name = e.Key, Text = string.upper(e.Name), Size = UDim2.fromOffset(150, 30), LayoutOrder = i, Parent = boostRow })
			local function paint()
				Ui.recolor(chip, if picked[e.Key] then GOLD_TOP else OFF_TOP, if picked[e.Key] then GOLD_BOTTOM else OFF_BOTTOM)
			end
			paint()
			chip.Activated:Connect(function()
				picked[e.Key] = not picked[e.Key] or nil
				paint()
			end)
		end

		-- pick one: blue = chosen
		local function pickOne(label, name, order, options, default)
			text({ Text = label, TextSize = 12, TextColor3 = SOFT, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = order, Parent = inside })
			local holder = row(inside, 28, order + 1, 5)
			local chosen = { Value = default }
			local chips = {}
			local function paint()
				for value, chip in chips do
					local on = value == chosen.Value
					Ui.recolor(chip, if on then BLUE_TOP else OFF_TOP, if on then BLUE_BOTTOM else OFF_BOTTOM)
				end
			end
			for i, option in options do
				local chip = button({ Name = name .. option.Value, Text = option.Text, Size = UDim2.fromOffset(74, 28), LayoutOrder = i, Parent = holder })
				chips[option.Value] = chip
				chip.Activated:Connect(function()
					chosen.Value = option.Value
					paint()
				end)
			end
			paint()
			return chosen
		end
		local howLong = pickOne("How long:", "Minutes", 4, {
			{ Text = "5 MIN", Value = 5 },
			{ Text = "10 MIN", Value = 10 },
			{ Text = "15 MIN", Value = 15 },
			{ Text = "30 MIN", Value = 30 },
			{ Text = "60 MIN", Value = 60 },
		}, 15)
		local when = pickOne("When it starts:", "Delay", 6, {
			{ Text = "NOW", Value = 0 },
			{ Text = "IN 5 MIN", Value = 5 },
			{ Text = "IN 10 MIN", Value = 10 },
			{ Text = "IN 30 MIN", Value = 30 },
			{ Text = "IN 1 HOUR", Value = 60 },
		}, 0)

		-- announce it too?
		local announce = true
		local announceRow = row(inside, 28, 8)
		local announceChip = button({ Name = "Announce", Text = "ALSO ANNOUNCE IT", Size = UDim2.fromOffset(170, 28), LayoutOrder = 1, Parent = announceRow })
		local function paintAnnounce()
			Ui.recolor(announceChip, if announce then GOLD_TOP else OFF_TOP, if announce then GOLD_BOTTOM else OFF_BOTTOM)
		end
		paintAnnounce()
		announceChip.Activated:Connect(function()
			announce = not announce
			paintAnnounce()
		end)
		text({ Text = "sends a global message about it", TextSize = 12, TextColor3 = SOFT, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.fromOffset(220, 28), LayoutOrder = 2, Parent = announceRow })

		local goRow = row(inside, 38, 9, 8)
		local start = button({ Name = "StartAbuse", Text = if isOwner then "START ABUSE" else "REQUEST ABUSE", Size = UDim2.fromOffset(if isOwner then 230 else 410, 38), Radius = 8, Top = RED_TOP, Bottom = RED_BOTTOM, Stroke = 2.5, LayoutOrder = 1, Parent = goRow })
		start.Activated:Connect(function()
			local keys = {}
			for _, e in A.Events do
				if picked[e.Key] then
					table.insert(keys, e.Key)
				end
			end
			say("Sending...")
			local ok, message = call("StartAbuse", keys, howLong.Value, when.Value, announce)
			say(message, ok)
		end)
		if isOwner then
			local stop = button({ Name = "StopAbuse", Text = "STOP", Size = UDim2.fromOffset(172, 38), Radius = 8, Top = GREY_TOP, Bottom = GREY_BOTTOM, Stroke = 2.5, LayoutOrder = 2, Parent = goRow })
			stop.Activated:Connect(function()
				local ok, message = call("StopAbuse")
				say(message, ok)
			end)
		end
		text({
			Text = if isOwner
				then "Runs in every server for everyone and stacks with players' own passes. Starting again replaces what's running."
				else "Your request goes to the owner to approve.",
			TextSize = 11,
			TextWrapped = true,
			TextColor3 = SOFT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Size = UDim2.new(1, 0, 0, 28),
			LayoutOrder = 10,
			Parent = inside,
		})
	end)

	------------------------------------------------------------ PLAYERS
	local playerList
	local playerRows = {}
	section("Players", "Players", "PLAYERS IN THIS SERVER", "teleport go to bring kick stats", function(inside)
		playerList = inside
	end)
	local function rebuildPlayers()
		for _, r in playerRows do
			r.Frame:Destroy()
		end
		playerRows = {}
		for i, p in Players:GetPlayers() do
			local item = Ui.new("Frame", { Name = p.Name, BackgroundColor3 = FIELD, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = i, Parent = playerList }, { Ui.corner(7) })
			text({ Text = p.DisplayName .. (if p == player then " (you)" else ""), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, -200, 0, 18), Position = UDim2.fromOffset(8, 5), Parent = item })
			local stats = text({ Text = "", TextSize = 11, TextColor3 = SOFT, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -200, 0, 16), Position = UDim2.fromOffset(8, 25), Parent = item })
			local buttons = Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(190, 28), Position = UDim2.new(1, -6, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Parent = item }, {
				Ui.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
			})
			if p ~= player then
				local function add(label, action, top, bottom, order)
					local b = button({ Name = action, Text = label, Size = UDim2.fromOffset(60, 28), Top = top, Bottom = bottom, LayoutOrder = order, Parent = buttons })
					b.Activated:Connect(function()
						local ok, message = call(action, p.UserId)
						say(message, ok)
					end)
				end
				add("GO TO", "GoTo", BLUE_TOP, BLUE_BOTTOM, 1)
				if isOwner then
					add("BRING", "Bring", GREEN_TOP, GREEN_BOTTOM, 2)
					if p.UserId ~= A.Owner then
						add("KICK", "Kick", RED_TOP, RED_BOTTOM, 3)
					end
				end
			end
			table.insert(playerRows, { Frame = item, Stats = stats, Player = p })
		end
	end
	local function refreshPlayerStats()
		for _, r in playerRows do
			local p = r.Player
			r.Stats.Text = `HP {Format.short(p:GetAttribute("Energy") or 0)}   Wins {Format.short(p:GetAttribute("Wins") or 0)}   Rebirths {p:GetAttribute("Rebirths") or 0}`
		end
	end
	Players.PlayerAdded:Connect(rebuildPlayers)
	Players.PlayerRemoving:Connect(function()
		task.defer(rebuildPlayers)
	end)
	rebuildPlayers()

	------------------------------------------------------------ WORLD
	section("Teleport", "World", "TELEPORT ME", "stage lobby finish go", function(inside)
		local grid = Ui.new("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Parent = inside }, {
			Ui.new("UIGridLayout", { CellSize = UDim2.fromOffset(78, 30), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local places = { { Text = "LOBBY", Where = "Lobby", Top = GREEN_TOP, Bottom = GREEN_BOTTOM } }
		for stage = 1, #Config.Stages.RequiredLevel do
			table.insert(places, { Text = `STAGE {stage}`, Where = stage })
		end
		table.insert(places, { Text = "FINISH", Where = "Finish", Top = GOLD_TOP, Bottom = GOLD_BOTTOM })
		for i, place in places do
			local b = button({ Name = "Go" .. tostring(place.Where), Text = place.Text, Size = UDim2.fromOffset(78, 30), Top = place.Top or BLUE_TOP, Bottom = place.Bottom or BLUE_BOTTOM, LayoutOrder = i, Parent = grid })
			b.Activated:Connect(function()
				local ok, message = call("GoStage", place.Where)
				say(message, ok)
			end)
		end
	end)

	------------------------------------------------------------ REQUESTS (owner)
	local refreshRequests
	local requestsTab
	if isOwner then
		local list
		local emptyLabel
		section("Requests", "Requests", "REQUESTS FROM ADMINS", "accept decline approve", function(inside)
			emptyLabel = text({ Text = "No requests right now", TextColor3 = SOFT, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0, Parent = inside })
			list = inside
		end)
		refreshRequests = function()
			local ok, requests = call("ListRequests")
			for _, child in list:GetChildren() do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end
			requests = if ok and type(requests) == "table" then requests else {}
			emptyLabel.Visible = #requests == 0
			for i = #requests, 1, -1 do
				local r = requests[i]
				local what
				if r.Kind == "Announce" then
					what = `Message: "{r.Text}"`
				elseif r.Kind == "Abuse" then
					local later = if (r.Delay or 0) > 0 then `, starting {r.Delay} min after asking` else ""
					what = `ADMIN ABUSE: {namesOf(r.Events)} for {r.Minutes} min{later}`
				else
					what = tostring(r.Kind)
				end
				local item = Ui.new("Frame", { BackgroundColor3 = FIELD, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = #requests - i + 1, Parent = list }, { Ui.corner(7) })
				text({ Text = `{r.From} wants:`, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -150, 0, 16), Position = UDim2.fromOffset(8, 6), TextColor3 = GOLD_TOP, Parent = item })
				text({ Text = what, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, -150, 0, 34), Position = UDim2.fromOffset(8, 23), Parent = item })
				local accept = button({ Text = "ACCEPT", Size = UDim2.fromOffset(66, 28), Position = UDim2.new(1, -76, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Top = GREEN_TOP, Bottom = GREEN_BOTTOM, Parent = item })
				local decline = button({ Text = "DECLINE", Size = UDim2.fromOffset(66, 28), Position = UDim2.new(1, -6, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Top = RED_TOP, Bottom = RED_BOTTOM, Parent = item })
				accept.Activated:Connect(function()
					local ok2, message = call("Accept", r.Id)
					say(message, ok2)
					refreshRequests()
				end)
				decline.Activated:Connect(function()
					local ok2, message = call("Decline", r.Id)
					say(message, ok2)
					refreshRequests()
				end)
			end
			if requestsTab then
				requestsTab.Label.Text = if #requests > 0 then `REQUESTS ({#requests})` else "REQUESTS"
			end
		end
		remotes:WaitForChild("RequestsChanged").OnClientEvent:Connect(function()
			refreshRequests()
		end)
	end

	------------------------------------------------------------ FEEDBACK (owner): what players sent from Settings
	local refreshFeedback
	if isOwner then
		local list, emptyLabel, filterRow
		local filterKind = "All"
		local filterButtons = {}
		section("Feedback", "Feedback", "PLAYER FEEDBACK (newest first)", "feedback bug idea report suggestion", function(inside)
			filterRow = row(inside, 28, 0)
			for i, kind in { "All", "Bug", "Idea", "Other" } do
				local b = button({ Text = string.upper(kind), Size = UDim2.fromOffset(62, 26), LayoutOrder = i, Parent = filterRow })
				filterButtons[kind] = b
				b.Activated:Connect(function()
					filterKind = kind
					refreshFeedback()
				end)
			end
			emptyLabel = text({ Text = "No feedback yet", TextColor3 = SOFT, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1, Parent = inside })
			list = inside
		end)
		local KIND_COLOUR = { Bug = BAD, Idea = GOOD, Other = BLUE_TOP }
		refreshFeedback = function()
			for kind, b in filterButtons do
				Ui.recolor(b, if kind == filterKind then PINK else OFF_TOP, if kind == filterKind then PINK_DARK else OFF_BOTTOM)
			end
			local ok, items = call("ListFeedback")
			for _, child in list:GetChildren() do
				if child:IsA("Frame") and child ~= filterRow then
					child:Destroy()
				end
			end
			items = if ok and type(items) == "table" then items else {}
			local shown = 0
			for i, f in items do
				if filterKind == "All" or f.Kind == filterKind then
					shown += 1
					local item = Ui.new("Frame", { BackgroundColor3 = FIELD, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 56), LayoutOrder = 1 + i, Parent = list }, { Ui.corner(7) })
					local when = os.date("!%d %b %H:%M", f.Time or 0)
					text({ Text = `{string.upper(f.Kind or "?")}  from {f.From}  ({when} UTC)`, TextSize = 12, TextColor3 = KIND_COLOUR[f.Kind] or SOFT, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -86, 0, 16), Position = UDim2.fromOffset(8, 6), Parent = item })
					text({ Text = f.Text, TextSize = 13, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Size = UDim2.new(1, -86, 0, 30), Position = UDim2.fromOffset(8, 24), Parent = item })
					local done = button({ Text = "DONE", Size = UDim2.fromOffset(66, 28), Position = UDim2.new(1, -8, 0, 14), AnchorPoint = Vector2.new(1, 0), Top = GREEN_TOP, Bottom = GREEN_BOTTOM, Parent = item })
					done.Activated:Connect(function()
						local ok2, message = call("DoneFeedback", f.Id)
						say(message, ok2)
						refreshFeedback()
					end)
				end
			end
			emptyLabel.Visible = shown == 0
		end
	end

	------------------------------------------------------------ TESTING: your own ALL PASSES
	section("AllPasses", "Testing", "ALL PASSES (just you)", "game pass free products vip testing", function(inside)
		local holder = Ui.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Parent = inside })
		text({ Text = "Every game pass and free products, just for you. Saved until you turn it off.", TextSize = 12, TextWrapped = true, TextColor3 = SOFT, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -100, 1, 0), Parent = holder })
		local switch = button({ Name = "AllPassesSwitch", Text = "OFF", Size = UDim2.fromOffset(84, 34), Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Radius = 17, Top = GREY_TOP, Bottom = GREY_BOTTOM, Parent = holder })
		local function showSwitch()
			local on = player:GetAttribute("AllPasses") == true
			switch.Label.Text = if on then "ON" else "OFF"
			Ui.recolor(switch, if on then GREEN_TOP else GREY_TOP, if on then GREEN_BOTTOM else GREY_BOTTOM)
		end
		player:GetAttributeChangedSignal("AllPasses"):Connect(showSwitch)
		showSwitch()
		switch.Activated:Connect(function()
			local ok, message = call("SetAllPasses", player:GetAttribute("AllPasses") ~= true)
			say(message, ok)
		end)
	end)

	------------------------------------------------------------ the tabs
	local TABS = {
		{ Key = "Favorites", Text = "FAVORITES", Color = GOLD_TOP },
		{ Key = "Main", Text = "MAIN", Color = Color3.fromRGB(120, 200, 255) },
		{ Key = "Abuse", Text = "ABUSE", Color = Color3.fromRGB(255, 110, 80) },
		{ Key = "Players", Text = "PLAYERS", Color = Color3.fromRGB(130, 235, 130) },
		{ Key = "World", Text = "WORLD", Color = Color3.fromRGB(90, 220, 255) },
	}
	if isOwner then
		table.insert(TABS, { Key = "Requests", Text = "REQUESTS", Color = Color3.fromRGB(255, 200, 80) })
		table.insert(TABS, { Key = "Feedback", Text = "FEEDBACK", Color = Color3.fromRGB(120, 235, 120) })
	end
	table.insert(TABS, { Key = "Testing", Text = "TESTING", Color = Color3.fromRGB(200, 140, 255) })
	local tabButtons = {}
	local currentTab = "Abuse"
	for i, tab in TABS do
		local b = button({ Name = tab.Key .. "Tab", Text = tab.Text, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = i, Parent = sidebar })
		b.Label.Size = UDim2.new(1, -34, 0.52, 0)
		b.Label.Position = UDim2.new(0.5, 12, 0.5, 0)
		b.Label.TextXAlignment = Enum.TextXAlignment.Left
		-- a little coloured dot for each tab
		Ui.new("Frame", { BackgroundColor3 = tab.Color, Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 9, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Parent = b }, { Ui.corner(6), Ui.stroke(1.5) })
		tabButtons[tab.Key] = b
		if tab.Key == "Requests" then
			requestsTab = b
		end
		b.Activated:Connect(function()
			search.Text = ""
			currentTab = tab.Key
			refreshView()
			say("")
			if tab.Key == "Requests" and refreshRequests then
				task.spawn(refreshRequests)
			elseif tab.Key == "Feedback" and refreshFeedback then
				task.spawn(refreshFeedback)
			end
		end)
	end

	-- show the current tab's tools, the starred ones, or what matches the search
	refreshView = function()
		local query = string.lower((search.Text:gsub("^%s+", ""):gsub("%s+$", "")))
		local shown = 0
		for i, s in sections do
			local show
			if query ~= "" then
				show = string.find(s.Keywords, query, 1, true) ~= nil
			elseif currentTab == "Favorites" then
				show = favorites[s.Id] == true
			else
				show = s.Tab == currentTab
			end
			s.Frame.Visible = show
			s.Frame.LayoutOrder = i
			if show then
				shown += 1
			end
		end
		emptyNote.Visible = shown == 0
		emptyNote.Text = if query ~= "" then "No tools match that" else "Tap the star on any tool to keep it here."
		for key, b in tabButtons do
			local on = query == "" and key == currentTab
			Ui.recolor(b, if on then PINK else OFF_TOP, if on then PINK_DARK else OFF_BOTTOM)
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(refreshView)
	refreshView()
	if refreshRequests then
		task.spawn(refreshRequests)
	end

	task.spawn(function()
		local ok, list = call("GetFavorites")
		if ok and type(list) == "table" then
			for _, id in list do
				if type(id) == "string" then
					favorites[id] = true
				end
			end
			for _, s in sections do
				s.ShowStar()
			end
			refreshView()
		end
	end)

	------------------------------------------------------------ live text while the panel is open
	task.spawn(function()
		while true do
			if panelGroup.Visible then
				-- the Admin Abuse status
				local state, names, left = abuseSummary()
				local summary
				if state == "on" then
					abuseStatus.Text = `Running: {names} ({clock(left)} left)`
					abuseStatus.TextColor3 = GOOD
					summary = "Admin Abuse running"
				elseif state == "soon" then
					abuseStatus.Text = `Scheduled: {names} starts in {clock(left)}`
					abuseStatus.TextColor3 = BLUE_TOP
					summary = "Admin Abuse scheduled"
				else
					abuseStatus.Text = "Not running"
					abuseStatus.TextColor3 = ORANGE
					summary = "No Admin Abuse"
				end
				-- server info
				local started = workspace:GetAttribute("ServerStart")
				infoLines[1].Text = `Players: {#Players:GetPlayers()}/{Players.MaxPlayers}     {serverType} SERVER`
				infoLines[2].Text = `Up for {if started then clock(workspace:GetServerTimeNow() - started) else "?"}     {summary}`
				refreshPlayerStats()
			end
			task.wait(0.5)
		end
	end)

	------------------------------------------------------------ dragging, minimise, open and close
	local dragging, dragStart, startPos
	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = panelGroup.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			local view = workspace.CurrentCamera.ViewportSize
			-- keep at least part of the bar on the screen
			local x = math.clamp(startPos.X.Offset + delta.X, -view.X * 0.5 + 60, view.X * 0.5 - 60)
			local y = math.clamp(startPos.Y.Offset + delta.Y, -view.Y * 0.5 + 20, view.Y * 0.5 - 20)
			panelGroup.Position = UDim2.new(startPos.X.Scale, x, startPos.Y.Scale, y)
		end
	end)

	local minimized = false
	minimize.Activated:Connect(function()
		minimized = not minimized
		body.Visible = not minimized
		panel.Size = if minimized then UDim2.new(1, 0, 0, BAR) else UDim2.fromScale(1, 1)
		minimize.Label.Text = if minimized then "+" else "—"
	end)
	openButton.Activated:Connect(function()
		panelGroup.Visible = not panelGroup.Visible
		if panelGroup.Visible then
			Ui.pop(panel, 1.04)
			refreshView()
		end
	end)
	close.Activated:Connect(function()
		panelGroup.Visible = false
	end)
end

-- the server marks admins when they join
if player:GetAttribute("Admin") then
	buildPanel()
else
	local connection
	connection = player:GetAttributeChangedSignal("Admin"):Connect(function()
		if player:GetAttribute("Admin") then
			connection:Disconnect()
			buildPanel()
		end
	end)
end

return nil
