--[[
	Gaze Emotes | Dreamville-style GUI
	Roblox (Luau) | single file | executor, mobile + PC
	Logic is unchanged from the original: same emote playback, settings, catalog search,
	saved list and save file. Only the GUI was rebuilt to match GenX Dreamville.
]]

-- ============================================================================
-- SERVICES
-- ============================================================================
local cloneref_ = (typeof(cloneref) == "function") and cloneref or function(...) return ... end
local Svc = setmetatable({}, { __index = function(_, n) return cloneref_(game:GetService(n)) end })
local Players, RunService, UIS, TweenService = Svc.Players, Svc.RunService, Svc.UserInputService, Svc.TweenService
local AES, HttpService, CoreGui = Svc.AvatarEditorService, Svc.HttpService, Svc.CoreGui

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local isR6 = humanoid.RigType == Enum.HumanoidRigType.R6
local lastPos = character.PrimaryPart and character.PrimaryPart.Position or Vector3.new()

local applyRigUI -- filled in once the GUI exists

player.CharacterAdded:Connect(function(c)
	character = c
	humanoid = c:WaitForChild("Humanoid")
	isR6 = humanoid.RigType == Enum.HumanoidRigType.R6
	if applyRigUI then applyRigUI() end
	lastPos = character.PrimaryPart and character.PrimaryPart.Position or Vector3.new()
end)

-- ============================================================================
-- EMOTE SETTINGS (same keys and defaults as before)
-- ============================================================================
local S = {}
S["Stop Emote When Moving"] = true
S["Fade In"] = 0.1
S["Fade Out"] = 0.1
S["Weight"] = 1
S["Speed"] = 1
S["Time Position"] = 0
S["Freeze On Finish"] = false
S["Looped"] = true
S["Stop Other Animations On Play"] = true
S["High Priority"] = true

-- ============================================================================
-- SAVED EMOTES (same file name, so old saves still load)
-- ============================================================================
local Saved = {}
local SAVE_FILE = "GazeEmotes_NewNEWN3WSaved.json"

local function loadSaved()
	local ok, data = pcall(function()
		if readfile and isfile and isfile(SAVE_FILE) then
			return HttpService:JSONDecode(readfile(SAVE_FILE))
		end
		return {}
	end)
	if ok and type(data) == "table" then Saved = data else Saved = {} end
	for _, e in ipairs(Saved) do
		if not e.AnimationId then
			if e.AssetId then e.AnimationId = "rbxassetid://" .. tostring(e.AssetId)
			else e.AnimationId = "rbxassetid://" .. tostring(e.Id) end
		end
		if e.Favorite == nil then e.Favorite = false end
	end
end

local function writeSaved()
	pcall(function()
		if writefile then writefile(SAVE_FILE, HttpService:JSONEncode(Saved)) end
	end)
end
loadSaved()

-- ============================================================================
-- EMOTE PLAYBACK (unchanged)
-- ============================================================================
local track = nil

local function playEmote(assetId)
	if track then track:Stop(S["Fade Out"]) end
	local animId
	local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(assetId)) end)
	if ok and objs and #objs > 0 then
		local o = objs[1]
		if o:IsA("Animation") then animId = o.AnimationId else animId = "rbxassetid://" .. tostring(assetId) end
	else
		animId = "rbxassetid://" .. tostring(assetId)
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local t = humanoid:LoadAnimation(anim)
	local prio = S["High Priority"] and Enum.AnimationPriority.Action4 or Enum.AnimationPriority.Action
	t.Priority = prio
	local weight = S["Weight"]
	if weight == 0 then weight = 0.001 end
	if S["Stop Other Animations On Play"] then
		for _, other in pairs(humanoid.Animator:GetPlayingAnimationTracks()) do
			if other.Priority ~= prio then other:Stop() end
		end
	end
	t:Play(S["Fade In"], weight, S["Speed"])
	track = t
	track.TimePosition = math.clamp(S["Time Position"], 0, 1) * (track.Length or 1)
	track.Priority = prio
	track.Looped = S["Looped"]
	return t
end

RunService.RenderStepped:Connect(function()
	if S["Looped"] and track and track.IsPlaying then track.Looped = S["Looped"] end
	if character:FindFirstChild("HumanoidRootPart") then
		local root = character.HumanoidRootPart
		if S["Stop Emote When Moving"] and track and track.IsPlaying then
			local moved = (root.Position - lastPos).Magnitude > 0.1
			local jumping = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Jumping
			if moved or jumping then
				track:Stop(S["Fade Out"])
				track = nil
			end
		end
		lastPos = root.Position
	end
end)

-- resolves a catalog id to the real animation id (unchanged)
function GetReal(id)
	local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(id)) end)
	if ok and objs and #objs > 0 then
		local o = objs[1]
		if o:IsA("Animation") and o.AnimationId ~= "" then
			return tonumber(o.AnimationId:match("%d+"))
		elseif o:FindFirstChildOfClass("Animation") then
			local a = o:FindFirstChildOfClass("Animation")
			return tonumber(a.AnimationId:match("%d+"))
		end
	end
end

-- ============================================================================
-- GUI KIT (Dreamville "Midnight" look, ultra compact)
-- ============================================================================
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local TH = {
	bg = rgb(10, 12, 20), card = rgb(20, 24, 38), stroke = rgb(46, 54, 80),
	text = rgb(236, 240, 252), muted = rgb(130, 140, 168),
	accent = rgb(96, 140, 255), accent2 = rgb(150, 110, 255),
	ok = rgb(90, 220, 150), err = rgb(255, 110, 120), star = rgb(255, 205, 80),
}
local WHITE = Color3.new(1, 1, 1)

local function mk(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function tw(inst, t, props, style, dir)
	if not inst or not inst.Parent then return end
	local tween = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

local function round(p, r) return mk("UICorner", { CornerRadius = UDim.new(0, r or 12) }, p) end
local function stroke(p, color, thick, tr)
	return mk("UIStroke", { Color = color or TH.stroke, Thickness = thick or 1, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end

local function label(parent, text, size, color, props)
	local l = mk("TextLabel", {
		BackgroundTransparency = 1, Text = text, TextSize = size or 14, Font = Enum.Font.Gotham,
		TextColor3 = color or TH.text, TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end

-- ============================================================================
-- VECTOR ICONS (built from frames, no emoji, crisp at any size)
-- ============================================================================
local DEFS = {}
local function starPts(ro, ri)
	local pts = {}
	for i = 0, 9 do
		local r = (i % 2 == 0) and ro or ri
		local a = -math.pi / 2 + i * math.pi / 5
		pts[#pts + 1] = { 12 + math.cos(a) * r, 12.6 + math.sin(a) * r }
	end
	return pts
end
DEFS.search = function(b) b.ring(2.5, 2.5, 14, 14, 7) b.bar(15, 15, 21, 21) end
DEFS.cross = function(b) b.bar(6, 6, 18, 18) b.bar(18, 6, 6, 18) end
DEFS.check = function(b) b.bar(5, 12.5, 10, 17.5) b.bar(10, 17.5, 19, 7) end
DEFS.plus = function(b) b.bar(12, 5, 12, 19) b.bar(5, 12, 19, 12) end
DEFS.link = function(b) b.ring(2, 8, 12, 8, 4) b.ring(10, 8, 12, 8, 4) end
DEFS.copy = function(b) b.ring(8, 8, 13, 13, 3) b.bar(5, 15, 5, 5) b.bar(5, 5, 15, 5) end
DEFS.bookmark = function(b) b.bar(6, 3, 18, 3) b.bar(6, 3, 6, 21) b.bar(18, 3, 18, 21) b.bar(6, 21, 12, 16) b.bar(18, 21, 12, 16) end
DEFS.trash = function(b) b.bar(4, 7, 20, 7) b.bar(9, 4, 15, 4) b.ring(6, 9, 12, 12, 2) b.bar(10, 12, 10, 18) b.bar(14, 12, 14, 18) end
DEFS.play = function(b) b.bar(8, 5, 8, 19) b.bar(8, 5, 19, 12) b.bar(8, 19, 19, 12) end
DEFS.wave = function(b) b.bar(4, 10, 4, 14) b.bar(8, 7, 8, 17) b.bar(12, 4, 12, 20) b.bar(16, 7, 16, 17) b.bar(20, 10, 20, 14) end
DEFS.star = function(b)
	local p = starPts(10, 4.4)
	for i = 1, 10 do local q = p[i % 10 + 1] b.bar(p[i][1], p[i][2], q[1], q[2]) end
end
DEFS.starFill = function(b)
	DEFS.star(b)
	local p = starPts(10, 4.4)
	for i = 1, 10, 2 do b.bar(12, 12.6, p[i][1], p[i][2]) end
	b.dot(12, 12.6, 6)
end

-- dancing figure with sparkles: the saved-emote icon
DEFS.dancer = function(b)
	b.dot(12, 5.5, 5)
	b.bar(12, 9, 12, 15.5)
	b.bar(12, 10.5, 6, 5.5)
	b.bar(12, 10.5, 18, 13.5)
	b.bar(12, 15.5, 8, 21.5)
	b.bar(12, 15.5, 17.5, 20.5)
	b.bar(19.5, 3, 19.5, 7) b.bar(17.5, 5, 21.5, 5)
	b.dot(4.5, 15, 2.2)
end

-- newIcon(parent, name, px, color) -> { frame, color(c), set(name) }
local function newIcon(parent, name, px, color)
	local s = px / 24
	local thk = math.max(1.4, 2 * s)
	local root = mk("Frame", { Size = UDim2.fromOffset(px, px), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0 }, parent)
	local parts, cur = {}, color or TH.text
	local b = {}
	function b.bar(x1, y1, x2, y2)
		local dx, dy = x2 - x1, y2 - y1
		local f = mk("Frame", {
			Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) * s + thk, thk), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((x1 + x2) / 2 * s, (y1 + y2) / 2 * s), Rotation = math.deg(math.atan2(dy, dx)), BorderSizePixel = 0,
		}, root)
		mk("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
		parts[#parts + 1] = { f = f }
	end
	function b.dot(x, y, d)
		local f = mk("Frame", { Size = UDim2.fromOffset(d * s, d * s), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x * s, y * s), BorderSizePixel = 0 }, root)
		mk("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
		parts[#parts + 1] = { f = f }
	end
	function b.ring(x, y, w, h, r)
		local f = mk("Frame", { Size = UDim2.fromOffset(w * s - thk, h * s - thk), Position = UDim2.fromOffset(x * s + thk / 2, y * s + thk / 2), BackgroundTransparency = 1, BorderSizePixel = 0 }, root)
		mk("UICorner", { CornerRadius = UDim.new(0, (r or 0) * s) }, f)
		parts[#parts + 1] = { st = mk("UIStroke", { Thickness = thk, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f) }
	end
	local obj = { frame = root }
	function obj.color(c)
		cur = c
		for _, p in ipairs(parts) do
			if p.f then p.f.BackgroundColor3 = c end
			if p.st then p.st.Color = c end
		end
	end
	function obj.set(n)
		root:ClearAllChildren()
		parts = {}
		;(DEFS[n] or DEFS.cross)(b)
		obj.color(cur)
	end
	obj.set(name)
	return obj
end

-- ============================================================================
-- WIDGETS
-- ============================================================================
local spinners, eqList = {}, {} -- driven by the single render loop at the bottom

-- tap ripple that expands from where you touched
local function ripple(b, input)
	local w, h = b.AbsoluteSize.X, b.AbsoluteSize.Y
	if w <= 0 or h <= 0 then return end
	local fx = math.clamp((input.Position.X - b.AbsolutePosition.X) / w, 0, 1)
	local fy = math.clamp((input.Position.Y - b.AbsolutePosition.Y) / h, 0, 1)
	local r = mk("Frame", { Size = UDim2.fromOffset(0, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(fx, fy), BackgroundColor3 = WHITE, BackgroundTransparency = 0.72, BorderSizePixel = 0 }, b)
	round(r, 100)
	tw(r, 0.5, { Size = UDim2.fromOffset(100, 100), BackgroundTransparency = 1 })
	task.delay(0.55, function() r:Destroy() end)
end

-- primary = accent fill, otherwise ghost. Hover glows, press squishes, tap ripples.
local function button(parent, text, primary, size, pos, onClick, textSize, iconName)
	local base = primary and TH.accent or TH.bg
	local b = mk("TextButton", {
		Size = size, Position = pos or UDim2.new(), AutoButtonColor = false, Text = iconName and "" or text,
		Font = Enum.Font.GothamBold, TextSize = textSize or 12, BorderSizePixel = 0, ClipsDescendants = true,
		BackgroundColor3 = base, TextColor3 = primary and WHITE or TH.text,
	}, parent)
	round(b, 9)
	local st = stroke(b, primary and TH.accent2 or TH.stroke, 1)
	local ic
	if iconName then ic = newIcon(b, iconName, 14, primary and WHITE or TH.text) end
	b.MouseEnter:Connect(function()
		tw(st, 0.15, { Color = primary and WHITE or TH.accent })
		tw(b, 0.15, { BackgroundColor3 = primary and TH.accent:Lerp(WHITE, 0.15) or TH.card })
		if ic then tw(ic.frame, 0.2, { Rotation = 90 }, Enum.EasingStyle.Back) end
	end)
	b.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then ripple(b, i) end
	end)
	b.MouseButton1Down:Connect(function() tw(b, 0.08, { Size = size - UDim2.fromOffset(0, 3) }) end)
	b.MouseButton1Up:Connect(function() tw(b, 0.25, { Size = size }, Enum.EasingStyle.Back) end)
	b.MouseLeave:Connect(function()
		tw(b, 0.2, { Size = size }, Enum.EasingStyle.Back)
		tw(st, 0.2, { Color = primary and TH.accent2 or TH.stroke })
		tw(b, 0.2, { BackgroundColor3 = base })
		if ic then tw(ic.frame, 0.2, { Rotation = 0 }) end
	end)
	if onClick then b.Activated:Connect(onClick) end
	return b
end

local function textBox(parent, placeholder, size, pos)
	local t = mk("TextBox", {
		Size = size, Position = pos, PlaceholderText = placeholder, PlaceholderColor3 = TH.muted, Text = "",
		BackgroundColor3 = TH.bg, TextColor3 = TH.text, Font = Enum.Font.Gotham, TextSize = 12,
		ClearTextOnFocus = false, BorderSizePixel = 0,
	}, parent)
	round(t, 9)
	local st = stroke(t, TH.stroke, 1)
	t.Focused:Connect(function() tw(st, 0.2, { Color = TH.accent, Thickness = 1.5 }) end)
	t.FocusLost:Connect(function() tw(st, 0.2, { Color = TH.stroke, Thickness = 1 }) end)
	return t
end

-- upgraded search bar: vector magnifier that tilts and glows on focus, bounces while you type,
-- an underline that grows out from the centre, a clear button, and an orbiting spinner while loading
local function searchBar(parent, placeholder, size, pos)
	local f = mk("Frame", { Size = size, Position = pos, BackgroundColor3 = TH.bg, BorderSizePixel = 0, ClipsDescendants = true }, parent)
	round(f, 9)
	local st = stroke(f, TH.stroke, 1)
	local glow = mk("Frame", { Size = UDim2.new(0, 0, 0, 2), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = TH.accent, BorderSizePixel = 0 }, f)
	mk("UIGradient", { Color = ColorSequence.new(TH.accent, TH.accent2) }, glow)

	local iconHolder = mk("Frame", { Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), BackgroundTransparency = 1 }, f)
	local ic = newIcon(iconHolder, "search", 14, TH.muted)

	local spin = mk("Frame", { Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Visible = false }, iconHolder)
	round(spin, 8)
	local spinStroke = stroke(spin, WHITE, 2)
	local spinGrad = mk("UIGradient", { Color = ColorSequence.new(TH.accent, TH.accent2), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.2), NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 1) }) }, spinStroke)
	spinners[#spinners + 1] = { grad = spinGrad, frame = spin }

	local box = mk("TextBox", {
		Size = UDim2.new(1, -52, 1, 0), Position = UDim2.fromOffset(28, 0), BackgroundTransparency = 1, PlaceholderText = placeholder,
		PlaceholderColor3 = TH.muted, Text = "", TextColor3 = TH.text, Font = Enum.Font.Gotham, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, BorderSizePixel = 0,
	}, f)
	local clear = mk("TextButton", { Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), BackgroundColor3 = TH.stroke, Text = "", AutoButtonColor = false, BorderSizePixel = 0, Visible = false }, f)
	round(clear, 9)
	local cscale = mk("UIScale", { Scale = 0 }, clear)
	newIcon(clear, "cross", 10, TH.text)

	box.Focused:Connect(function()
		tw(st, 0.2, { Color = TH.accent, Thickness = 1.5 })
		tw(glow, 0.4, { Size = UDim2.new(1, 0, 0, 2) })
		ic.color(TH.accent)
		tw(iconHolder, 0.35, { Rotation = -18, Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Back)
	end)
	box.FocusLost:Connect(function()
		tw(st, 0.2, { Color = TH.stroke, Thickness = 1 })
		tw(glow, 0.3, { Size = UDim2.new(0, 0, 0, 2) })
		ic.color(TH.muted)
		tw(iconHolder, 0.3, { Rotation = 0, Size = UDim2.fromOffset(16, 16) }, Enum.EasingStyle.Back)
	end)
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local has = box.Text ~= ""
		if has and not clear.Visible then
			clear.Visible = true
			tw(cscale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		elseif not has and clear.Visible then
			tw(cscale, 0.15, { Scale = 0 })
			task.delay(0.16, function() if box.Text == "" then clear.Visible = false end end)
		end
		if box:IsFocused() then
			iconHolder.Rotation = -30
			tw(iconHolder, 0.25, { Rotation = -18 }, Enum.EasingStyle.Back)
		end
	end)
	clear.Activated:Connect(function() box.Text = "" box:CaptureFocus() end)

	local obj = { frame = f, box = box }
	function obj.setLoading(on)
		spin.Visible = on
		ic.frame.Visible = not on
	end
	return obj
end

-- ============================================================================
-- ROOT + WINDOW (ultra compact)
-- ============================================================================
local WIN_W, WIN_H = 430, 338
local PANE_W, PANE_H = 232, 244
local PANE_BASE = UDim2.fromOffset(14, 84)
local CW, CH = 106, 152 -- emote card size

local gui = mk("ScreenGui", { Name = "GazeEmoteGUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
do
	local parent
	if typeof(gethui) == "function" then
		local ok, h = pcall(gethui)
		if ok and h then parent = h end
	end
	gui.Parent = parent or CoreGui
end

local function viewport() return (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1920, 1080) end
local function fitScale()
	local vp = viewport()
	return math.clamp(math.min(vp.X * 0.95 / WIN_W, vp.Y * 0.92 / WIN_H), 0.45, 1.1) * 0.95
end

local holder = mk("Frame", {
	Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundTransparency = 1,
}, gui)
local winScale = mk("UIScale", { Scale = fitScale() }, holder)
do
	local function refit() winScale.Scale = fitScale() end
	local cam = workspace.CurrentCamera
	if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(refit) end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local c = workspace.CurrentCamera
		if c then c:GetPropertyChangedSignal("ViewportSize"):Connect(refit) end
		refit()
	end)
end

local openFrame = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) }, holder)
local openScale = mk("UIScale", { Scale = 0.8 }, openFrame)
local fade = mk("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1 }, openFrame)

local winBg = mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = TH.bg, BackgroundTransparency = 0.04, BorderSizePixel = 0, ClipsDescendants = true }, fade)
round(winBg, 16)
stroke(winBg, TH.stroke, 1.2)
mk("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.12) }) }, winBg)

-- two soft orbs drifting behind everything
local function orb(color, size)
	local o = mk("Frame", { Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color, BackgroundTransparency = 0.9, BorderSizePixel = 0 }, winBg)
	round(o, size)
	return o
end
local orbA, orbB = orb(TH.accent, 190), orb(TH.accent2, 160)

-- LED edge: a dim rail plus two bright comets circling the border
local function ledStroke(thick, tr)
	return mk("UIStroke", { Thickness = thick, Color = WHITE, Transparency = tr, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round }, winBg)
end
local cometTr = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 1),
})
local hotA, hotB = TH.accent:Lerp(WHITE, 0.7), TH.accent2:Lerp(WHITE, 0.5)
local seqA = ColorSequence.new({ ColorSequenceKeypoint.new(0, TH.accent2), ColorSequenceKeypoint.new(0.5, hotA), ColorSequenceKeypoint.new(1, TH.accent) })
local seqB = ColorSequence.new({ ColorSequenceKeypoint.new(0, TH.accent), ColorSequenceKeypoint.new(0.5, hotB), ColorSequenceKeypoint.new(1, TH.accent2) })
local ledRail = mk("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, TH.accent), ColorSequenceKeypoint.new(0.5, TH.accent2), ColorSequenceKeypoint.new(1, TH.accent) }) }, ledStroke(2, 0.4))
local ledA1 = mk("UIGradient", { Transparency = cometTr, Color = seqA }, ledStroke(4, 0))
local ledA2 = mk("UIGradient", { Transparency = cometTr, Color = seqA }, ledStroke(12, 0.6))
local ledB1 = mk("UIGradient", { Transparency = cometTr, Color = seqB }, ledStroke(3, 0))

-- ---------------------------------------------------------------- top bar
local topBar = mk("Frame", { Size = UDim2.new(1, -28, 0, 38), Position = UDim2.fromOffset(14, 6), BackgroundTransparency = 1 }, winBg)
local titleLbl = label(topBar, isR6 and "Gaze Emotes (R6)" or "Gaze Emotes", 17, TH.text, { Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(2, 1), Size = UDim2.fromOffset(170, 20) })
label(topBar, "Pick it, tune it, play it", 10, TH.muted, { Position = UDim2.fromOffset(3, 21), Size = UDim2.fromOffset(170, 12) })

local wordmark = mk("Frame", { Size = UDim2.fromOffset(58, 24), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -38, 0, 7), BackgroundColor3 = TH.accent, BorderSizePixel = 0 }, topBar)
round(wordmark, 12)
local wordGrad = mk("UIGradient", { Rotation = 20, Color = ColorSequence.new(TH.accent, TH.accent2) }, wordmark)
mk("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "Gaze", Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = WHITE }, wordmark)

local closeBtn = mk("TextButton", { Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), AutoButtonColor = false, Text = "", BackgroundColor3 = TH.card, BorderSizePixel = 0 }, topBar)
round(closeBtn, 15)
local closeStroke = stroke(closeBtn, TH.stroke, 1)
local closeIcon = newIcon(closeBtn, "cross", 14, TH.text)
closeBtn.MouseEnter:Connect(function()
	tw(closeBtn, 0.25, { Rotation = 90, BackgroundColor3 = TH.err }, Enum.EasingStyle.Back)
	tw(closeStroke, 0.2, { Color = TH.err })
end)
closeBtn.MouseLeave:Connect(function()
	tw(closeBtn, 0.25, { Rotation = 0, BackgroundColor3 = TH.card }, Enum.EasingStyle.Back)
	tw(closeStroke, 0.2, { Color = TH.stroke })
end)

-- drag the window by the top bar
do
	local dragging, startIn, startPos, active = false, nil, nil, nil
	topBar.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, active, startIn, startPos = true, i, i.Position, holder.Position
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i == active or i.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = i.Position - startIn
			holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if i == active or i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
end

-- ---------------------------------------------------------------- tab pill with a stretchy sliding indicator
local nav = mk("Frame", { Size = UDim2.fromOffset(160, 30), Position = UDim2.fromOffset(14, 48), BackgroundColor3 = TH.card, BorderSizePixel = 0 }, winBg)
round(nav, 15)
stroke(nav, TH.stroke, 1.2)
local indicator = mk("Frame", { Size = UDim2.fromOffset(76, 24), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = TH.accent, BorderSizePixel = 0 }, nav)
round(indicator, 12)
mk("UIGradient", { Rotation = 20, Color = ColorSequence.new(TH.accent, TH.accent2) }, indicator)

local function navButton(text, x)
	return mk("TextButton", { Size = UDim2.fromOffset(76, 24), Position = UDim2.fromOffset(x, 3), AutoButtonColor = false, Text = text, Font = Enum.Font.GothamBold, TextSize = 12, BorderSizePixel = 0, BackgroundTransparency = 1, TextColor3 = WHITE }, nav)
end
local catalogTab = navButton(isR6 and "Animation" or "Catalog", 3)
local savedTab = navButton("Saved", 81)
savedTab.Visible = not isR6

-- ---------------------------------------------------------------- panes (CanvasGroups so they can fade)
local function pane(visible)
	return mk("CanvasGroup", { Size = UDim2.fromOffset(PANE_W, PANE_H), Position = PANE_BASE, BackgroundTransparency = 1, Visible = visible, GroupTransparency = visible and 0 or 1 }, winBg)
end
local catalogPane = pane(true)
local savedPane = pane(false)

local function gridScroll(parent, size, pos)
	local sf = mk("ScrollingFrame", {
		Size = size, Position = pos, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
		ScrollBarImageColor3 = TH.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
	mk("UIGridLayout", { CellSize = UDim2.fromOffset(CW, CH), CellPadding = UDim2.fromOffset(8, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, sf)
	mk("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6) }, sf)
	return sf
end

-- empty state: a vector icon that gently floats above a caption
local floaters = {}
local function emptyState(parent, text, iconName, pos, size)
	local f = mk("Frame", { Position = pos, Size = size, BackgroundTransparency = 1, Visible = false }, parent)
	local holderI = mk("Frame", { Size = UDim2.fromOffset(34, 34), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), BackgroundTransparency = 1 }, f)
	newIcon(holderI, iconName, 30, TH.muted)
	floaters[#floaters + 1] = { f = holderI, base = 20 }
	label(f, text, 12, TH.muted, { Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true })
	return f
end

-- catalog pane widgets
local catalogSearch = searchBar(catalogPane, "Search...", UDim2.fromOffset(112, 28), UDim2.fromOffset(0, 0))
local searchBox = catalogSearch.box
local refreshBtn, sortBtn
local catalogGrid = gridScroll(catalogPane, UDim2.fromOffset(PANE_W, 176), UDim2.fromOffset(0, 34))
local emptyCatalog = emptyState(catalogPane, "Nothing Silly Here :3 (except me)", "search", UDim2.fromOffset(0, 40), UDim2.fromOffset(PANE_W, 110))
local pageErr = label(catalogPane, "", 10, TH.err, { Position = UDim2.fromOffset(0, 196), Size = UDim2.fromOffset(PANE_W, 14), TextXAlignment = Enum.TextXAlignment.Center, Visible = false })
local prevBtn, nextBtn
local pageBox = textBox(catalogPane, "", UDim2.fromOffset(100, 28), UDim2.fromOffset(66, 214))
pageBox.Text = "1 / Enter page"
pageBox.TextXAlignment = Enum.TextXAlignment.Center

-- saved pane widgets
local savedSearchBar = searchBar(savedPane, "Search Saved...", UDim2.fromOffset(120, 28), UDim2.fromOffset(0, 0))
local savedSearch = savedSearchBar.box
local idBox = textBox(savedPane, "Emote ID", UDim2.fromOffset(70, 28), UDim2.fromOffset(124, 0))
local savedGrid = gridScroll(savedPane, UDim2.fromOffset(PANE_W, 208), UDim2.fromOffset(0, 34))
local emptySaved = emptyState(savedPane, "Sorry I Was Changing Save Files Again", "bookmark", UDim2.fromOffset(0, 50), UDim2.fromOffset(PANE_W, 110))

-- ---------------------------------------------------------------- settings column
local setCard = mk("Frame", { Size = UDim2.fromOffset(162, 280), Position = UDim2.fromOffset(254, 48), BackgroundColor3 = TH.card, BackgroundTransparency = 0.12, BorderSizePixel = 0 }, winBg)
round(setCard, 12)
stroke(setCard, TH.stroke, 1, 0.2)
label(setCard, "Settings", 13, TH.text, { Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18) })
local setList = mk("ScrollingFrame", {
	Size = UDim2.new(1, -10, 1, -30), Position = UDim2.fromOffset(5, 26), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 2, ScrollBarImageColor3 = TH.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, setCard)
mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, setList)
mk("UIPadding", { PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 6), PaddingTop = UDim.new(0, 2) }, setList)

local sliders, toggles, rowScales = {}, {}, {}

local function rowFrame(h)
	local r = mk("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = TH.bg, BackgroundTransparency = 0.2, BorderSizePixel = 0 }, setList)
	round(r, 9)
	stroke(r, TH.stroke, 1)
	rowScales[#rowScales + 1] = mk("UIScale", { Scale = 0.85 }, r)
	return r
end

local function addButtonRow(text, fn)
	local r = mk("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1 }, setList)
	rowScales[#rowScales + 1] = mk("UIScale", { Scale = 0.85 }, r)
	button(r, text, true, UDim2.new(1, 0, 1, 0), UDim2.new(), fn, 12)
end

-- iOS-style switch row (knob stretches as it flips)
local function addToggle(name)
	S[name] = S[name] or false
	local r = rowFrame(36)
	label(r, name, 11, TH.text, { Position = UDim2.fromOffset(8, 0), Size = UDim2.new(1, -52, 1, 0), TextWrapped = true })
	local sw = mk("TextButton", { Size = UDim2.fromOffset(36, 20), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0), Text = "", AutoButtonColor = false, BorderSizePixel = 0 }, r)
	round(sw, 10)
	local knob = mk("Frame", { Size = UDim2.fromOffset(14, 14), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, sw)
	round(knob, 7)
	local function paint(on, animate)
		local col = on and TH.accent or TH.stroke
		local pos = on and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
		if animate then
			tw(sw, 0.18, { BackgroundColor3 = col })
			tw(knob, 0.1, { Size = UDim2.fromOffset(20, 14) })
			tw(knob, 0.25, { Position = on and UDim2.new(1, -23, 0.5, -7) or UDim2.new(0, 3, 0.5, -7) }, Enum.EasingStyle.Back)
			task.delay(0.12, function()
				tw(knob, 0.2, { Size = UDim2.fromOffset(14, 14) })
				tw(knob, 0.2, { Position = pos })
			end)
		else
			sw.BackgroundColor3, knob.Position = col, pos
		end
	end
	sw.Activated:Connect(function() S[name] = not S[name] paint(S[name], true) end)
	paint(S[name], false)
	toggles[name] = function(v) S[name] = v paint(v, true) end
end

-- slider row with a typed value box; knob grows while dragging
local function addSlider(name, min, max)
	local r = rowFrame(48)
	label(r, name, 11, TH.text, { Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -56, 0, 18) })
	local box = mk("TextBox", { Size = UDim2.fromOffset(40, 18), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 4), BackgroundColor3 = TH.card, TextColor3 = TH.text, Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false, BorderSizePixel = 0, Text = "" }, r)
	round(box, 5)
	local bar = mk("Frame", { Size = UDim2.new(1, -22, 0, 6), Position = UDim2.fromOffset(11, 33), BackgroundColor3 = TH.stroke, BorderSizePixel = 0 }, r)
	round(bar, 3)
	local fill = mk("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = TH.accent, BorderSizePixel = 0 }, bar)
	round(fill, 3)
	mk("UIGradient", { Color = ColorSequence.new(TH.accent, TH.accent2) }, fill)
	local knob = mk("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = TH.text, BorderSizePixel = 0 }, bar)
	round(knob, 7)
	local hit = mk("TextButton", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 24), BackgroundTransparency = 1, Text = "" }, r)

	local function apply(v)
		S[name] = math.clamp(v, min, max)
		box.Text = tostring(S[name])
		local f = (S[name] - min) / (max - min)
		tw(fill, 0.15, { Size = UDim2.fromScale(f, 1) })
		tw(knob, 0.15, { Position = UDim2.fromScale(f, 0.5) })
		if track and track.IsPlaying then
			if name == "Speed" then
				track:AdjustSpeed(S["Speed"])
			elseif name == "Weight" then
				local w = S["Weight"]
				if w == 0 then w = 0.001 end
				track:AdjustWeight(w)
			elseif name == "Time Position" then
				if track.Length > 0 then track.TimePosition = math.clamp(v, 0, 1) * track.Length end
			end
		end
	end

	local dragging = false
	local function fromInput(inp)
		local f = math.clamp((inp.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		apply(math.floor((min + (max - min) * f) * 100) / 100)
	end
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			tw(knob, 0.15, { Size = UDim2.fromOffset(20, 20) }, Enum.EasingStyle.Back)
			fromInput(i)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromInput(i) end
	end)
	UIS.InputEnded:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			tw(knob, 0.2, { Size = UDim2.fromOffset(14, 14) }, Enum.EasingStyle.Back)
		end
	end)
	box.FocusLost:Connect(function(enter)
		if enter then
			local n = tonumber(box.Text)
			if n then apply(n) else box.Text = tostring(S[name]) end
		end
	end)
	sliders[name] = apply
	apply(S[name])
end

addButtonRow("Reset Settings", function()
	for _, n in ipairs({ "Stop Emote When Moving", "Stop Other Animations On Play", "High Priority", "Looped" }) do
		if toggles[n] then toggles[n](true) end
	end
	local defaults = { ["Fade In"] = 0.1, ["Fade Out"] = 0.1, Weight = 1, Speed = 1, ["Time Position"] = 0 }
	for n, v in pairs(defaults) do if sliders[n] then sliders[n](v) end end
	S["Freeze On Finish"] = false
end)
addToggle("Stop Emote When Moving")
addToggle("Looped")
addSlider("Speed", 0, 5)
addSlider("Time Position", 0, 1)
addSlider("Weight", 0, 1)
addSlider("Fade In", 0, 2)
addSlider("Fade Out", 0, 2)
addToggle("Stop Other Animations On Play")
addToggle("High Priority")

-- ---------------------------------------------------------------- equalizer art (animated bars used on saved cards + now-playing)
local function eqArt(parent, w, h, n, color, pos, anchor)
	local f = mk("Frame", { Size = UDim2.fromOffset(w, h), Position = pos or UDim2.fromScale(0.5, 0.5), AnchorPoint = anchor or Vector2.new(0.5, 0.5), BackgroundTransparency = 1 }, parent)
	for i = 1, n do
		local bar = mk("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new((i - 0.5) / n, 0, 1, 0), Size = UDim2.new(1 / n, -3, 0.3, 0), BackgroundColor3 = color, BorderSizePixel = 0 }, f)
		round(bar, 3)
		eqList[#eqList + 1] = { bar = bar, ph = i * 1.3, sp = 2.2 + i * 0.45 }
	end
	return f
end

-- "now playing" pill (slides up from the bottom)
local nowPill = mk("Frame", { Size = UDim2.fromOffset(190, 26), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 40), BackgroundColor3 = TH.card, BorderSizePixel = 0 }, winBg)
round(nowPill, 13)
stroke(nowPill, TH.accent, 1.2)
eqArt(nowPill, 14, 12, 4, TH.accent, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
local nowLbl = label(nowPill, "", 11, TH.text, { Font = Enum.Font.GothamBold, Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(30, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
local nowToken = 0
local function showNow(name)
	nowToken += 1
	local my = nowToken
	nowLbl.Text = "Playing: " .. tostring(name or "Emote")
	nowPill.Position = UDim2.new(0.5, 0, 1, 40)
	tw(nowPill, 0.4, { Position = UDim2.new(0.5, 0, 1, -8) }, Enum.EasingStyle.Back)
	task.delay(2.2, function()
		if my == nowToken then tw(nowPill, 0.3, { Position = UDim2.new(0.5, 0, 1, 40) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In) end
	end)
end

-- ============================================================================
-- EMOTE CARDS
-- ============================================================================
local function popIn(f)
	local s = mk("UIScale", { Scale = 0.4 }, f)
	tw(s, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- icon-only overlay button (tints accent on hover)
local function iconBtn(parent, iconName, size, pos, color)
	local b = mk("TextButton", { Size = size, Position = pos, Text = "", BackgroundColor3 = TH.bg, BackgroundTransparency = 0.2, AutoButtonColor = false, BorderSizePixel = 0 }, parent)
	round(b, 6)
	local ic = newIcon(b, iconName, 13, color or TH.text)
	local base = color or TH.text
	b.MouseEnter:Connect(function() ic.color(TH.accent) tw(b, 0.15, { BackgroundTransparency = 0 }) end)
	b.MouseLeave:Connect(function() ic.color(base) tw(b, 0.2, { BackgroundTransparency = 0.2 }) end)
	b.MouseButton1Down:Connect(function() tw(b, 0.08, { Size = size - UDim2.fromOffset(3, 3) }) end)
	b.MouseButton1Up:Connect(function() tw(b, 0.25, { Size = size }, Enum.EasingStyle.Back) end)
	return b, ic
end

local function cardBase(name)
	local f = mk("Frame", { Size = UDim2.fromOffset(CW, CH), BackgroundColor3 = TH.card, BackgroundTransparency = 0.1, BorderSizePixel = 0 })
	round(f, 11)
	local st = stroke(f, TH.stroke, 1)
	local art = mk("Frame", { Size = UDim2.new(1, -10, 0, 66), Position = UDim2.fromOffset(5, 5), BackgroundColor3 = TH.bg, BorderSizePixel = 0, ClipsDescendants = true }, f)
	round(art, 8)
	-- diagonal shine sweeps across the art on hover
	local shine = mk("Frame", { Size = UDim2.new(0, 22, 1.8, 0), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(-0.3, 0, 0.5, 0), Rotation = 20, BackgroundColor3 = WHITE, BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 5 }, art)
	f.MouseEnter:Connect(function()
		tw(st, 0.15, { Color = TH.accent, Thickness = 1.6 })
		shine.Position = UDim2.new(-0.3, 0, 0.5, 0)
		tw(shine, 0.6, { Position = UDim2.new(1.3, 0, 0.5, 0) }, Enum.EasingStyle.Quad)
	end)
	f.MouseLeave:Connect(function() tw(st, 0.2, { Color = TH.stroke, Thickness = 1 }) end)
	label(f, name or "Unknown", 11, TH.text, { Font = Enum.Font.GothamBold, Position = UDim2.fromOffset(6, 75), Size = UDim2.new(1, -12, 0, 38), TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Top })
	return f, art
end

local savedRefresh -- forward declaration

local function catalogCard(item)
	local assetId = item.AssetId or item.Id
	local f, art = cardBase(item.Name)
	local img = mk("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit }, art)
	pcall(function() img.Image = "rbxthumb://type=Asset&id=" .. tonumber(assetId) .. "&w=150&h=150" end)

	local link = "https://www.roblox.com/catalog/" .. tonumber(item.Id)
	local linkBtn, linkIc = iconBtn(f, "link", UDim2.fromOffset(24, 22), UDim2.new(1, -31, 0, 9))
	linkBtn.ZIndex = 6
	linkBtn.Activated:Connect(function()
		if setclipboard then setclipboard(link) end
		linkIc.set("check")
		linkIc.color(TH.ok)
		task.wait(0.8)
		linkIc.set("link")
		linkIc.color(TH.text)
	end)

	button(f, "Play", true, UDim2.fromOffset(46, 26), UDim2.fromOffset(5, 120), function() playEmote(assetId) showNow(item.Name) end, 11)
	local saveBtn = button(f, "Save", false, UDim2.fromOffset(46, 26), UDim2.fromOffset(55, 120), nil, 11)
	saveBtn.Activated:Connect(function()
		local exists = false
		for _, e in ipairs(Saved) do if e.Id == item.Id then exists = true break end end
		if not exists then
			local real = GetReal(assetId)
			table.insert(Saved, { Id = item.Id, AssetId = assetId, Name = item.Name or "Unknown", AnimationId = "rbxassetid://" .. tostring(real or assetId), Favorite = false })
			writeSaved()
			saveBtn.Text = "Saved!"
			tw(saveBtn, 0.15, { BackgroundColor3 = TH.ok })
			task.wait(1)
			saveBtn.Text = "Save"
			tw(saveBtn, 0.2, { BackgroundColor3 = TH.bg })
		else
			saveBtn.Text = "Already"
			task.wait(0.7)
			saveBtn.Text = "Save"
		end
	end)
	popIn(f)
	return f
end

-- saved cards get a custom art tile: shifting gradient, animated equalizer bars, bookmark badge
local artGrads = {}
local function savedCard(item)
	local f, art = cardBase(item.Name)
	-- same emote picture as in the catalog, drawn with a Roblox-style highlight (red fill + outline + glow)
	local HL = Color3.fromRGB(255, 40, 50)
	local assetId = item.AssetId or item.Id
	local img = mk("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit }, art)
	pcall(function() img.Image = "rbxthumb://type=Asset&id=" .. tonumber(assetId) .. "&w=150&h=150" end)
	mk("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = HL, BackgroundTransparency = 0.78, BorderSizePixel = 0 }, art)
	stroke(art, HL, 2)
	local glow = mk("Frame", { Size = UDim2.new(1, -4, 0, 72), Position = UDim2.fromOffset(2, 2), BackgroundTransparency = 1, BorderSizePixel = 0 }, f)
	round(glow, 11)
	stroke(glow, HL, 4, 0.7)
	local badge = mk("Frame", { Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = TH.bg, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 6 }, art)
	round(badge, 10)
	newIcon(badge, "bookmark", 11, WHITE)

	button(f, "Play", true, UDim2.fromOffset(46, 26), UDim2.fromOffset(5, 120), function() playEmote(item.Id) showNow(item.Name) end, 11)
	local rem = button(f, "Remove", false, UDim2.fromOffset(46, 26), UDim2.fromOffset(55, 120), nil, 10)
	rem.TextColor3 = TH.err

	local copy, copyIc = iconBtn(art, "copy", UDim2.fromOffset(22, 20), UDim2.new(1, -52, 0, 6))
	copy.ZIndex = 6
	copy.Activated:Connect(function()
		if setclipboard then setclipboard((item.AnimationId:gsub("rbxassetid://", ""))) end
		copyIc.set("check")
		copyIc.color(TH.ok)
		task.wait(0.8)
		copyIc.set("copy")
		copyIc.color(TH.text)
	end)

	local star, starIc = iconBtn(art, item.Favorite and "starFill" or "star", UDim2.fromOffset(22, 20), UDim2.new(1, -28, 0, 6), item.Favorite and TH.star or TH.text)
	star.ZIndex = 6
	star.Activated:Connect(function()
		item.Favorite = not item.Favorite
		starIc.set(item.Favorite and "starFill" or "star")
		starIc.color(item.Favorite and TH.star or TH.text)
		tw(starIc.frame, 0.25, { Rotation = 144, Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Back)
		writeSaved()
		task.wait(0.3)
		savedRefresh()
	end)
	rem.Activated:Connect(function()
		for i, e in ipairs(Saved) do
			if e.Id == item.Id then
				table.remove(Saved, i)
				writeSaved()
				tw(f, 0.2, { BackgroundTransparency = 1 })
				task.wait(0.15)
				savedRefresh()
				break
			end
		end
	end)
	popIn(f)
	return f
end

-- ============================================================================
-- CATALOG SEARCH + PAGING (unchanged logic)
-- ============================================================================
local SORTS = {
	{ Enum.CatalogSortType.Relevance, "Relevance" },
	{ Enum.CatalogSortType.PriceHighToLow, "Price High" },
	{ Enum.CatalogSortType.PriceLowToHigh, "Price Low" },
	{ Enum.CatalogSortType.MostFavorited, "Favorited" },
	{ Enum.CatalogSortType.RecentlyCreated, "Newest" },
	{ Enum.CatalogSortType.Bestselling, "Top Sell" },
}
local sortIdx, keyword, pager, pageNum, tabIndex = 1, "", nil, 1, 1

local function newSearch(kw)
	if isR6 then
		return {
			IsFinished = true,
			GetCurrentPage = function() return { { Id = 115314801778772, Name = "Dance If Youre The Best", AssetId = 115314801778772 } } end,
			AdvanceToNextPageAsync = function() end,
		}
	end
	local p = CatalogSearchParams.new()
	p.SearchKeyword = kw or ""
	p.CategoryFilter = Enum.CatalogCategoryFilter.None
	p.SalesTypeFilter = Enum.SalesTypeFilter.All
	p.AssetTypes = { Enum.AvatarAssetType.EmoteAnimation }
	p.IncludeOffSale = true
	p.SortType = SORTS[sortIdx][1]
	p.Limit = 10
	local ok, res = pcall(function() return AES:SearchCatalog(p) end)
	if not ok then return nil end
	return res
end

local function updatePager()
	prevBtn.Visible = pageNum > 1
	if pager and typeof(pager.IsFinished) == "boolean" then nextBtn.Visible = not pager.IsFinished else nextBtn.Visible = true end
end

local loadToken, dotsToken = 0, 0
local function loadingDots()
	dotsToken += 1
	local my = dotsToken
	task.spawn(function()
		local n = 0
		while my == dotsToken and pageBox.Text:sub(1, 7) == "Loading" do
			n = n % 3 + 1
			pageBox.Text = "Loading" .. string.rep(".", n)
			task.wait(0.25)
		end
	end)
end

local function loadPage(p)
	loadToken += 1
	local myId = loadToken
	pageBox.Text = "Loading..."
	loadingDots()
	catalogSearch.setLoading(true)
	for _, c in ipairs(catalogGrid:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	local ok, items = pcall(function() return p:GetCurrentPage() end)
	if not ok then dotsToken += 1 catalogSearch.setLoading(false) pageBox.Text = "ERROR" return end
	if myId ~= loadToken then return end
	if items and #items > 0 then
		emptyCatalog.Visible = false
		local myTab, n = tabIndex, 0
		for _, item in ipairs(items) do
			if tabIndex ~= myTab or myId ~= loadToken then break end
			catalogCard(item).Parent = catalogGrid
			n += 1
			if n % 2 == 0 then RunService.RenderStepped:Wait() end
		end
	else
		emptyCatalog.Visible = true
	end
	if myId == loadToken then
		dotsToken += 1
		catalogSearch.setLoading(false)
		pageBox.Text = tostring(pageNum) .. " / Enter page"
		updatePager()
	end
end

local function pagerAt(n)
	local p = newSearch(keyword)
	if not p then return nil end
	for _ = 2, n do
		if p.IsFinished then break end
		local ok = pcall(function() p:AdvanceToNextPageAsync() end)
		if not ok then break end
	end
	return p
end

local function runSearch(kw)
	keyword = kw or ""
	pageNum = 1
	pager = newSearch(keyword)
	if pager then loadPage(pager) end
end

local function nextPage()
	if not pager or pager.IsFinished then return end
	local ok = pcall(function() pager:AdvanceToNextPageAsync() end)
	if ok then
		pageNum += 1
		loadPage(pager)
	else
		local target = pageNum + 1
		local p = pagerAt(target)
		if p then pager = p pageNum = math.min(target, pageNum + 1) loadPage(pager) end
	end
end

local function prevPage()
	if not pager or pageNum <= 1 then return end
	local ok = pcall(function() pager:AdvanceToPreviousPageAsync() end)
	if ok then
		pageNum = math.max(1, pageNum - 1)
		loadPage(pager)
	else
		local target = math.max(1, pageNum - 1)
		local p = pagerAt(target)
		if p then pager = p pageNum = target loadPage(pager) end
	end
end

refreshBtn = button(catalogPane, "Refresh", true, UDim2.fromOffset(54, 28), UDim2.fromOffset(116, 0), function() runSearch(searchBox.Text) end, 11)
sortBtn = button(catalogPane, "Relevance", false, UDim2.fromOffset(58, 28), UDim2.fromOffset(174, 0), function()
	sortIdx = sortIdx % #SORTS + 1
	sortBtn.Text = SORTS[sortIdx][2]
	runSearch(keyword)
end, 11)
sortBtn.TextScaled = true
mk("UITextSizeConstraint", { MaxTextSize = 11, MinTextSize = 7 }, sortBtn)
prevBtn = button(catalogPane, "Prev", false, UDim2.fromOffset(60, 28), UDim2.fromOffset(0, 214), prevPage, 11)
nextBtn = button(catalogPane, "Next", false, UDim2.fromOffset(60, 28), UDim2.fromOffset(172, 214), nextPage, 11)

searchBox.FocusLost:Connect(function(enter) if enter then runSearch(searchBox.Text) end end)

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Right then
		nextPage()
	elseif input.KeyCode == Enum.KeyCode.Left then
		prevPage()
	end
end)

local function flashErr(msg)
	pageErr.Text = msg
	pageErr.Visible = true
	task.delay(2, function() pageErr.Visible = false end)
end

pageBox.FocusLost:Connect(function(enter)
	if not enter then return end
	local cleaned = pageBox.Text:gsub("%s+", "")
	local n = tonumber(cleaned:match("%d+"))
	if not n or n < 1 then
		flashErr("Invalid page number")
		pageBox.Text = "Page " .. tostring(pageNum)
		return
	end
	n = math.floor(n)
	if n == pageNum then pageBox.Text = "Page " .. tostring(pageNum) return end
	pageBox.Text = "Loading..."
	local ok, p = pcall(function() return pagerAt(n) end)
	if not ok or not p then
		flashErr("Unable to fetch page")
		pageBox.Text = "Page " .. tostring(pageNum)
		return
	end
	pager = p
	pageNum = math.max(1, n)
	loadPage(pager)
end)

-- ============================================================================
-- SAVED TAB (unchanged logic)
-- ============================================================================
local savedToken = 0
function savedRefresh()
	savedToken += 1
	local myId = savedToken
	for _, c in ipairs(savedGrid:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
	local q = (savedSearch.Text or ""):lower()
	local list = {}
	for _, e in ipairs(Saved) do
		if q == "" or (e.Name and e.Name:lower():find(q)) then table.insert(list, e) end
	end
	table.sort(list, function(a, b)
		if a.Favorite ~= b.Favorite then return a.Favorite else return false end
	end)
	if #list > 0 then
		emptySaved.Visible = false
		local myTab, n = tabIndex, 0
		for _, e in ipairs(list) do
			if tabIndex ~= myTab or myId ~= savedToken then break end
			savedCard(e).Parent = savedGrid
			n += 1
			if n % 25 == 0 then RunService.RenderStepped:Wait() end
		end
	else
		emptySaved.Visible = true
	end
end

button(savedPane, "", true, UDim2.fromOffset(34, 28), UDim2.fromOffset(198, 0), function()
	local id = tonumber(idBox.Text)
	if not id then return end
	for _, e in ipairs(Saved) do if e.Id == id then return end end
	local real = GetReal(id)
	table.insert(Saved, { Id = id, AssetId = id, Name = "Custom ID: " .. id, AnimationId = "rbxassetid://" .. tostring(real or id), Favorite = false })
	writeSaved()
	savedRefresh()
end, 12, "plus")
savedSearch:GetPropertyChangedSignal("Text"):Connect(savedRefresh)

-- ============================================================================
-- TAB SWITCHING (stretchy indicator, panes slide and fade) + R6 HANDLING
-- ============================================================================
local function showTab(n, instant)
	tabIndex += 1
	local on = (n == 1) and catalogPane or savedPane
	local off = (n == 1) and savedPane or catalogPane
	off.Visible = false
	off.GroupTransparency = 1
	on.Visible = true
	if instant then
		on.GroupTransparency = 0
		on.Position = PANE_BASE
	else
		on.GroupTransparency = 1
		on.Position = PANE_BASE + UDim2.fromOffset(n == 1 and -28 or 28, 0)
		tw(on, 0.4, { Position = PANE_BASE, GroupTransparency = 0 })
		-- stretch the indicator mid-move, then settle
		tw(indicator, 0.12, { Size = UDim2.fromOffset(110, 24) })
		task.delay(0.12, function() tw(indicator, 0.3, { Size = UDim2.fromOffset(76, 24) }, Enum.EasingStyle.Back) end)
	end
	tw(indicator, 0.35, { Position = UDim2.fromOffset(n == 1 and 3 or 81, 3) }, Enum.EasingStyle.Back)
	catalogTab.TextColor3 = n == 1 and WHITE or TH.muted
	savedTab.TextColor3 = n == 2 and WHITE or TH.muted
	if n == 2 then savedRefresh() end
end

catalogTab.Activated:Connect(function() showTab(1) end)
savedTab.Activated:Connect(function() showTab(2) end)

function applyRigUI()
	titleLbl.Text = isR6 and "Gaze Emotes (R6)" or "Gaze Emotes"
	catalogTab.Text = isR6 and "Animation" or "Catalog"
	savedTab.Visible = not isR6
	if isR6 then showTab(1) end
end

-- ============================================================================
-- INTRO / OPEN / CLOSE
-- ============================================================================
local function intro()
	openScale.Scale = 0.8
	openFrame.Rotation = -4
	fade.GroupTransparency = 1
	tw(openScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	tw(openFrame, 0.55, { Rotation = 0 }, Enum.EasingStyle.Back)
	tw(fade, 0.3, { GroupTransparency = 0 })
	local blocks = { { topBar, UDim2.fromOffset(14, 6) }, { nav, UDim2.fromOffset(14, 48) }, { setCard, UDim2.fromOffset(254, 48) } }
	blocks[#blocks + 1] = { catalogPane.Visible and catalogPane or savedPane, PANE_BASE }
	for i, b in ipairs(blocks) do
		b[1].Position = b[2] + UDim2.fromOffset(0, 20)
		task.delay(0.05 * i, function() tw(b[1], 0.5, { Position = b[2] }) end)
	end
	for i, s in ipairs(rowScales) do
		s.Scale = 0.85
		task.delay(0.2 + 0.04 * i, function() tw(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back) end)
	end
end

local isOpen = true
local function setOpen(open)
	if open == isOpen then return end
	isOpen = open
	if open then
		holder.Visible = true
		intro()
	else
		tw(openScale, 0.22, { Scale = 0.8 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
		tw(fade, 0.2, { GroupTransparency = 1 })
		task.delay(0.24, function() if not isOpen then holder.Visible = false end end)
	end
end
closeBtn.Activated:Connect(function() setOpen(false) end)

-- ---------------------------------------------------------------- floating button (breathing glow)
local btnGui = mk("ScreenGui", { Name = "ToggleButtonGui", ResetOnSpawn = false, DisplayOrder = 1000 })
do
	local parent
	if typeof(gethui) == "function" then
		local ok, h = pcall(gethui)
		if ok and h then parent = h end
	end
	btnGui.Parent = parent or CoreGui
end
local floatBtn = mk("TextButton", {
	Size = UDim2.fromOffset(42, 42), Position = UDim2.new(0, 20, 0.5, -21), Text = "G", Font = Enum.Font.GothamBlack, TextSize = 18,
	TextColor3 = WHITE, AutoButtonColor = false, BackgroundColor3 = TH.accent, BorderSizePixel = 0, Active = true,
}, btnGui)
round(floatBtn, 21)
local floatStroke = stroke(floatBtn, TH.accent2, 2)
local floatGrad = mk("UIGradient", { Rotation = 20, Color = ColorSequence.new(TH.accent, TH.accent2) }, floatBtn)

do -- drag the button, tap to toggle
	local dragging, startIn, startPos, moved, active = false, nil, nil, 0, nil
	floatBtn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, moved, active, startIn = true, 0, i, i.Position
			startPos = floatBtn.AbsolutePosition
			tw(floatBtn, 0.1, { Size = UDim2.fromOffset(36, 36) })
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i == active or i.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = i.Position - startIn
			moved = math.max(moved, d.Magnitude)
			if moved > 6 then
				local vp = viewport()
				floatBtn.Position = UDim2.fromOffset(math.clamp(startPos.X + d.X, 0, vp.X - 42), math.clamp(startPos.Y + d.Y, 0, vp.Y - 42))
			end
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if dragging and (i == active or i.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = false
			tw(floatBtn, 0.3, { Size = UDim2.fromOffset(42, 42) }, Enum.EasingStyle.Back)
			if moved <= 6 then setOpen(not isOpen) end
		end
	end)
end

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.G then setOpen(not isOpen) end
end)

-- one render loop drives every ambient animation
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	floatStroke.Thickness = 2 + 1.4 * math.sin(t * 3)
	floatGrad.Rotation = (t * 60) % 360
	if not holder.Visible then return end
	local ra = (t * 150) % 360
	ledA1.Rotation, ledA2.Rotation = ra, ra
	ledB1.Rotation = (90 - t * 95) % 360
	ledRail.Rotation = (t * 25) % 360
	wordGrad.Rotation = (t * 50) % 360
	orbA.Position = UDim2.new(0.25 + 0.12 * math.sin(t * 0.6), 0, 0.3 + 0.1 * math.cos(t * 0.5), 0)
	orbB.Position = UDim2.new(0.8 + 0.1 * math.cos(t * 0.45), 0, 0.75 + 0.1 * math.sin(t * 0.7), 0)
	for _, s in ipairs(spinners) do
		if s.frame.Visible then s.grad.Rotation = (t * 420) % 360 end
	end
	for i = #eqList, 1, -1 do
		local e = eqList[i]
		if not e.bar:IsDescendantOf(game) then
			table.remove(eqList, i)
		else
			local h = 0.25 + 0.7 * (0.5 + 0.5 * math.sin(t * e.sp + e.ph))
			e.bar.Size = UDim2.new(e.bar.Size.X.Scale, e.bar.Size.X.Offset, h, 0)
		end
	end
	for i = #artGrads, 1, -1 do
		local g = artGrads[i]
		if not g.Parent then table.remove(artGrads, i) else g.Rotation = 135 + 25 * math.sin(t * 0.8) end
	end
	for _, fl in ipairs(floaters) do
		if fl.f.Parent then fl.f.Position = UDim2.new(0.5, 0, 0, fl.base + 3 * math.sin(t * 2)) end
	end
end)

-- ============================================================================
-- BOOT
-- ============================================================================
showTab(1, true)
runSearch("")
savedRefresh()
intro()

-- ============================================================================
-- BODY COLLISION (unchanged from the original script)
-- ============================================================================
task.spawn(function()
	local rs = game:GetService("RunService")
	local plr = game.Players.LocalPlayer
	local function setupCollision(char)
		local hrp = char:WaitForChild("HumanoidRootPart")
		local bodyParts = {}
		hrp.CanCollide = true
		local function addPart(part)
			if part:IsA("BasePart") and part ~= hrp then table.insert(bodyParts, part) end
		end
		for _, part in pairs(char:GetDescendants()) do addPart(part) end
		local descConn = char.DescendantAdded:Connect(addPart)
		local hbConn
		hbConn = rs.Heartbeat:Connect(function()
			if not char or not char.Parent then
				hbConn:Disconnect()
				descConn:Disconnect()
				return
			end
			for i = 1, #bodyParts do
				local p = bodyParts[i]
				if p and p.Parent then p.CanCollide = false end
			end
		end)
	end
	if plr.Character then setupCollision(plr.Character) end
	plr.CharacterAdded:Connect(setupCollision)
end)
