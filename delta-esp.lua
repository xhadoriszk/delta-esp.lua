--[[
    Ember's Cheats — Rosa + Branco | Hitbox Expander
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

-- ====================== CONFIG ======================
local FOV = 140
local AIM_DIST = 1200
local ESP_DIST = 2500
local SPEED_BOOST = 1.05
local SHOOT_DELAY = 0.13
local HITBOX_SIZE = 16 -- tamanho do Hitbox Expander

-- ====================== STATE ======================
local S = {
	Aim = false,
	ESP = true,
	TeamCheck = true,
	AutoRun = false,
	AutoShoot = false,
	Hitbox = false,
	Panel = true,
}

local lastShoot = 0

-- ====================== CORES (Rosa + Branco) ======================
local PINK   = Color3.fromRGB(255, 105, 180)
local PINK2  = Color3.fromRGB(255, 140, 200)
local WHITE  = Color3.fromRGB(255, 255, 255)
local GREEN  = Color3.fromRGB(80, 255, 120)
local RED    = Color3.fromRGB(255, 80, 90)

-- ====================== UTILS ======================
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function corner(o, r)
	return make("UICorner", {CornerRadius = UDim.new(0, r)}, o)
end

local function getRoot(char)
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHum(char)
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function isAlive(p)
	local h = getHum(p.Character)
	return h and h.Health > 0
end

local function sameTeam(p)
	return LP.Team and p.Team == LP.Team
end

-- ====================== AUTO RUN ======================
local function applySpeed()
	local hum = getHum(LP.Character)
	if hum then
		hum.WalkSpeed = S.AutoRun and (16 * SPEED_BOOST) or 16
	end
end

LP.CharacterAdded:Connect(function()
	task.wait(0.3)
	applySpeed()
end)

-- ====================== HITBOX EXPANDER ======================
local originalSizes = {}

local function applyHitbox(p)
	if not S.Hitbox or p == LP or not p.Character then return end
	local root = getRoot(p.Character)
	if not root then return end

	if not originalSizes[p] then
		originalSizes[p] = root.Size
	end
	root.Size = Vector3.new(HITBOX_SIZE, HITBOX_SIZE, HITBOX_SIZE)
	root.Transparency = 0.7
	root.CanCollide = false
	root.Material = Enum.Material.Neon
	root.Color = PINK
end

local function resetHitbox(p)
	local root = p.Character and getRoot(p.Character)
	if root and originalSizes[p] then
		root.Size = originalSizes[p]
		root.Transparency = 1
	end
	originalSizes[p] = nil
end

local function updateAllHitboxes()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			if S.Hitbox then
				applyHitbox(p)
			else
				resetHitbox(p)
			end
		end
	end
end

-- ====================== ESP (DRAWING) ======================
local ESP = {} -- [Player] = drawings

local function clearESP(p)
	local t = ESP[p]
	if t then
		for _, v in pairs(t) do
			pcall(function() v:Remove() end)
		end
		ESP[p] = nil
	end
end

local function createESP(p)
	if p == LP then return end
	clearESP(p)

	local box = Drawing.new("Square")
	box.Thickness = 1.5
	box.Filled = false
	box.Visible = false

	local name = Drawing.new("Text")
	name.Size = 15
	name.Center = true
	name.Outline = true
	name.Color = WHITE
	name.Visible = false

	local info = Drawing.new("Text")
	info.Size = 13
	info.Center = true
	info.Outline = true
	info.Visible = false

	ESP[p] = {box = box, name = name, info = info}
end

local function isVisible(part)
	local own = getRoot(LP.Character)
	if not own then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {LP.Character}
	local hit = Workspace:Raycast(own.Position, part.Position - own.Position, params)
	return not hit or hit.Instance:IsDescendantOf(part.Parent)
end

local function updateESP(p)
	if p == LP then return end
	if not ESP[p] then createESP(p) end

	local d = ESP[p]
	local char = p.Character
	local root = getRoot(char)
	local head = char and char:FindFirstChild("Head")
	local hum = getHum(char)
	local own = getRoot(LP.Character)

	if not S.ESP or not char or not root or not head or not hum or not own or hum.Health <= 0 then
		d.box.Visible = false
		d.name.Visible = false
		d.info.Visible = false
		return
	end

	if S.TeamCheck and sameTeam(p) then
		d.box.Visible = false
		d.name.Visible = false
		d.info.Visible = false
		return
	end

	local dist = (own.Position - root.Position).Magnitude
	if dist > ESP_DIST then
		d.box.Visible = false
		d.name.Visible = false
		d.info.Visible = false
		return
	end

	local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
	if not onScreen or pos.Z < 0 then
		d.box.Visible = false
		d.name.Visible = false
		d.info.Visible = false
		return
	end

	local visible = isVisible(head)
	local col = visible and GREEN or RED

	local scale = math.clamp(900 / dist, 0.5, 4)
	local w, h = 36 * scale, 54 * scale

	d.box.Size = Vector2.new(w, h)
	d.box.Position = Vector2.new(pos.X - w/2, pos.Y - h/2)
	d.box.Color = col
	d.box.Visible = true

	d.name.Text = p.DisplayName
	d.name.Position = Vector2.new(pos.X, pos.Y - h/2 - 18)
	d.name.Color = WHITE
	d.name.Visible = true

	d.info.Text = string.format("%d HP  |  %dm", math.floor(hum.Health), math.floor(dist))
	d.info.Position = Vector2.new(pos.X, pos.Y + h/2 + 4)
	d.info.Color = col
	d.info.Visible = true
end

-- Tracking de jogadores
local function track(p)
	if p == LP then return end
	createESP(p)

	p.CharacterAdded:Connect(function(char)
		task.wait(0.4)
		createESP(p)
		if S.Hitbox then applyHitbox(p) end
	end)

	local function onDied()
		clearESP(p)
		resetHitbox(p)
	end

	if p.Character then
		local hum = getHum(p.Character)
		if hum then hum.Died:Connect(onDied) end
	end
end

for _, p in ipairs(Players:GetPlayers()) do track(p) end
Players.PlayerAdded:Connect(track)
Players.PlayerRemoving:Connect(function(p)
	clearESP(p)
	resetHitbox(p)
	originalSizes[p] = nil
end)

-- ====================== AIMBOT ======================
local function getTarget()
	local best, bestDist = nil, math.huge
	local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
	local own = getRoot(LP.Character)
	if not own then return nil end

	for _, p in ipairs(Players:GetPlayers()) do
		if p == LP or not isAlive(p) then continue end
		if S.TeamCheck and sameTeam(p) then continue end

		local head = p.Character and p.Character:FindFirstChild("Head")
		if not head then continue end

		local dist = (own.Position - head.Position).Magnitude
		if dist > AIM_DIST then continue end

		local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
		if not onScreen or sp.Z < 0 then continue end

		local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
		if screenDist > FOV then continue end
		if not isVisible(head) then continue end

		if screenDist < bestDist then
			bestDist = screenDist
			best = head
		end
	end
	return best
end

local function doShoot()
	local now = tick()
	if now - lastShoot < SHOOT_DELAY then return end
	lastShoot = now
	pcall(function()
		if mouse1click then
			mouse1click()
		elseif mouse1press then
			mouse1press()
			task.delay(0.05, function()
				pcall(mouse1release)
			end)
		end
	end)
end

-- ====================== GUI ROSA + BRANCO ======================
local Gui = make("ScreenGui", {
	Name = "EmbersCheats",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 70,
}, PlayerGui)

local ToggleBtn = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(80, 46),
	BackgroundColor3 = PINK,
	Text = "Ember",
	TextColor3 = WHITE,
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
}, Gui)
corner(ToggleBtn, 12)

local Window = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(460, 380),
	BackgroundColor3 = PINK,
	Visible = true,
}, Gui)
corner(Window, 16)

local Sidebar = make("Frame", {
	Size = UDim2.new(0, 120, 1, 0),
	BackgroundColor3 = PINK2,
}, Window)
corner(Sidebar, 16)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 18),
	Size = UDim2.new(1, -16, 0, 24),
	Text = "Ember's",
	TextColor3 = WHITE,
	TextSize = 17,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Sidebar)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 42),
	Size = UDim2.new(1, -16, 0, 16),
	Text = "Cheats",
	TextColor3 = WHITE,
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Sidebar)

local Main = make("Frame", {
	Position = UDim2.new(0, 120, 0, 0),
	Size = UDim2.new(1, -120, 1, 0),
	BackgroundColor3 = PINK,
}, Window)

local Header = make("Frame", {
	Size = UDim2.new(1, 0, 0, 48),
	BackgroundTransparency = 1,
}, Main)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 14),
	Size = UDim2.new(1, -50, 0, 22),
	Text = "Combat",
	TextColor3 = WHITE,
	TextSize = 17,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Header)

local CloseBtn = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.fromOffset(32, 32),
	BackgroundTransparency = 1,
	Text = "✕",
	TextColor3 = WHITE,
	TextSize = 16,
}, Header)

local Content = make("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 52),
	Size = UDim2.new(1, -24, 1, -64),
	BackgroundTransparency = 1,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = WHITE,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, Main)
make("UIListLayout", {Padding = UDim.new(0, 8)}, Content)

local function createToggle(name, desc, default)
	local card = make("Frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = Color3.fromRGB(255, 150, 200),
	}, Content)
	corner(card, 10)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -70, 0, 18),
		Text = name,
		TextColor3 = WHITE,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -70, 0, 16),
		Text = desc,
		TextColor3 = WHITE,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	local switch = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(42, 24),
		BackgroundColor3 = default and WHITE or Color3.fromRGB(255, 180, 210),
	}, card)
	corner(switch, 12)

	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = default and UDim2.new(1, -22, 0.5, 0) or UDim2.fromOffset(2, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = PINK,
	}, switch)
	corner(knob, 10)

	local btn = make("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
	}, card)

	return {btn = btn, switch = switch, knob = knob, on = default}
end

local function setToggle(t, v)
	t.on = v
	local col = v and WHITE or Color3.fromRGB(255, 180, 210)
	local pos = v and UDim2.new(1, -22, 0.5, 0) or UDim2.fromOffset(2, 0.5)
	TweenService:Create(t.switch, TweenInfo.new(0.14), {BackgroundColor3 = col}):Play()
	TweenService:Create(t.knob, TweenInfo.new(0.14), {Position = pos}):Play()
end

local tAim    = createToggle("Aimbot Hard Lock", "Trava na cabeça", false)
local tESP    = createToggle("ESP", "Verde = visível | Vermelho = parede", true)
local tTeam   = createToggle("Team Check", "Ignora aliados", true)
local tRun    = createToggle("Auto Run", "Anda sozinho (+5%)", false)
local tShoot  = createToggle("Auto Shoot", "Atira com alvo válido", false)
local tHitbox = createToggle("Hitbox Expander", "Aumenta hitbox dos inimigos", false)

-- ====================== CONNECTIONS ======================
tAim.btn.MouseButton1Click:Connect(function()
	S.Aim = not S.Aim
	setToggle(tAim, S.Aim)
end)
tESP.btn.MouseButton1Click:Connect(function()
	S.ESP = not S.ESP
	setToggle(tESP, S.ESP)
end)
tTeam.btn.MouseButton1Click:Connect(function()
	S.TeamCheck = not S.TeamCheck
	setToggle(tTeam, S.TeamCheck)
end)
tRun.btn.MouseButton1Click:Connect(function()
	S.AutoRun = not S.AutoRun
	setToggle(tRun, S.AutoRun)
	applySpeed()
end)
tShoot.btn.MouseButton1Click:Connect(function()
	S.AutoShoot = not S.AutoShoot
	setToggle(tShoot, S.AutoShoot)
end)
tHitbox.btn.MouseButton1Click:Connect(function()
	S.Hitbox = not S.Hitbox
	setToggle(tHitbox, S.Hitbox)
	updateAllHitboxes()
end)

ToggleBtn.MouseButton1Click:Connect(function()
	S.Panel = not S.Panel
	Window.Visible = S.Panel
end)
CloseBtn.MouseButton1Click:Connect(function()
	S.Panel = false
	Window.Visible = false
end)

do
	local drag, start, pos
	Header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = true
			start = i.Position
			pos = Window.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if not drag then return end
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - start
			Window.Position = UDim2.new(pos.X.Scale, pos.X.Offset + d.X, pos.Y.Scale, pos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = false
		end
	end)
end

-- ====================== LOOP ======================
RunService:BindToRenderStep("EmberMain", Enum.RenderPriority.Camera.Value + 1, function()
	-- ESP
	for _, p in ipairs(Players:GetPlayers()) do
		pcall(updateESP, p)
	end

	-- AIMBOT
	if S.Aim then
		local target = getTarget()
		if target then
			Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
			if S.AutoShoot then
				doShoot()
			end
		end
	end

	-- AUTO RUN
	if S.AutoRun then
		local hum = getHum(LP.Character)
		if hum then
			applySpeed()
			local look = Camera.CFrame.LookVector
			local dir = Vector3.new(look.X, 0, look.Z)
			if dir.Magnitude > 0.05 then
				hum:Move(dir.Unit, false)
			end
		end
	end

	-- HITBOX (reaplica)
	if S.Hitbox then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and isAlive(p) then
				applyHitbox(p)
			end
		end
	end
end)

print("✅ Ember's Cheats (Rosa + Hitbox) carregado")
