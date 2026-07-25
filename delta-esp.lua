--[[
    Ember's Cheats — Versão Corrigida (Drawing ESP + Hard Lock)
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

-- ====================== CONFIG ======================
local FOV = 130
local AIM_DIST = 1000
local ESP_DIST = 2000
local SPEED_BOOST = 1.05
local SHOOT_DELAY = 0.14

-- ====================== STATE ======================
local S = {
	Aim = false,
	ESP = true,
	TeamCheck = true,
	AutoRun = false,
	AutoShoot = false, -- começa desligado pra não atrapalhar
	Panel = true,
}

local lastShoot = 0

-- ====================== CORES ======================
local ACCENT = Color3.fromRGB(255, 105, 180) -- Rosa
local BG     = Color3.fromRGB(18, 16, 22)
local SIDE   = Color3.fromRGB(26, 22, 32)
local CARD   = Color3.fromRGB(34, 28, 42)
local TEXT   = Color3.fromRGB(255, 255, 255)
local MUTED  = Color3.fromRGB(190, 170, 185)

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

local function stroke(o, c, t)
	return make("UIStroke", {Color = c, Transparency = t or 0.4, Thickness = 1}, o)
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
	task.wait(0.35)
	applySpeed()
end)

-- ====================== ESP (DRAWING - mais confiável) ======================
local ESPObjects = {} -- [Player] = {box, name, hp, dist}

local function clearESP(p)
	local t = ESPObjects[p]
	if t then
		for _, v in pairs(t) do
			pcall(function() v:Remove() end)
		end
		ESPObjects[p] = nil
	end
end

local function createESP(p)
	clearESP(p)
	ESPObjects[p] = {
		box  = Drawing.new("Square"),
		name = Drawing.new("Text"),
		hp   = Drawing.new("Text"),
		dist = Drawing.new("Text"),
	}

	local o = ESPObjects[p]
	o.box.Thickness = 1.5
	o.box.Filled = false
	o.box.Color = ACCENT
	o.box.Visible = false

	o.name.Size = 14
	o.name.Center = true
	o.name.Outline = true
	o.name.Color = Color3.new(1, 1, 1)
	o.name.Visible = false

	o.hp.Size = 12
	o.hp.Center = true
	o.hp.Outline = true
	o.hp.Color = Color3.fromRGB(100, 255, 130)
	o.hp.Visible = false

	o.dist.Size = 12
	o.dist.Center = true
	o.dist.Outline = true
	o.dist.Color = Color3.fromRGB(200, 200, 200)
	o.dist.Visible = false
end

local function updateESP(p)
	if p == LP then return end
	if not ESPObjects[p] then createESP(p) end

	local o = ESPObjects[p]
	local char = p.Character
	local root = getRoot(char)
	local head = char and char:FindFirstChild("Head")
	local hum = getHum(char)
	local own = getRoot(LP.Character)

	if not char or not root or not head or not hum or not own or hum.Health <= 0 then
		o.box.Visible = false
		o.name.Visible = false
		o.hp.Visible = false
		o.dist.Visible = false
		return
	end

	if S.TeamCheck and sameTeam(p) then
		o.box.Visible = false
		o.name.Visible = false
		o.hp.Visible = false
		o.dist.Visible = false
		return
	end

	local dist = (own.Position - root.Position).Magnitude
	if dist > ESP_DIST or not S.ESP then
		o.box.Visible = false
		o.name.Visible = false
		o.hp.Visible = false
		o.dist.Visible = false
		return
	end

	local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
	if not onScreen then
		o.box.Visible = false
		o.name.Visible = false
		o.hp.Visible = false
		o.dist.Visible = false
		return
	end

	-- Tamanho da box baseado na distância
	local scale = math.clamp(1000 / dist, 0.4, 3)
	local w, h = 40 * scale, 60 * scale

	o.box.Size = Vector2.new(w, h)
	o.box.Position = Vector2.new(pos.X - w/2, pos.Y - h/2)
	o.box.Color = ACCENT
	o.box.Visible = true

	o.name.Text = p.DisplayName
	o.name.Position = Vector2.new(pos.X, pos.Y - h/2 - 16)
	o.name.Visible = true

	o.hp.Text = math.floor(hum.Health) .. " HP"
	o.hp.Position = Vector2.new(pos.X, pos.Y + h/2 + 2)
	o.hp.Visible = true

	o.dist.Text = math.floor(dist) .. "m"
	o.dist.Position = Vector2.new(pos.X, pos.Y + h/2 + 16)
	o.dist.Visible = true
end

-- Manter ESP atualizado
Players.PlayerAdded:Connect(function(p)
	task.wait(0.5)
	createESP(p)
end)
Players.PlayerRemoving:Connect(clearESP)

for _, p in ipairs(Players:GetPlayers()) do
	if p ~= LP then createESP(p) end
end

-- ====================== AIMBOT ======================
local function canSee(part)
	local own = getRoot(LP.Character)
	if not own then return false end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {LP.Character}
	local hit = Workspace:Raycast(own.Position, part.Position - own.Position, params)
	return not hit or hit.Instance:IsDescendantOf(part.Parent)
end

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
		if not onScreen then continue end

		local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
		if screenDist > FOV then continue end
		if not canSee(head) then continue end

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

	-- Só tenta atirar, não segura o botão
	pcall(function()
		if mouse1press then
			mouse1press()
			task.wait(0.04)
			mouse1release()
		elseif mouse1click then
			mouse1click()
		end
	end)
end

-- ====================== GUI ROSA ======================
local Gui = make("ScreenGui", {
	Name = "EmbersCheats",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 60,
}, PlayerGui)

local ToggleBtn = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.fromOffset(78, 48),
	BackgroundColor3 = SIDE,
	Text = "Ember",
	TextColor3 = ACCENT,
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
}, Gui)
corner(ToggleBtn, 12)
stroke(ToggleBtn, ACCENT, 0.4)

local Window = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(480, 340),
	BackgroundColor3 = BG,
	Visible = true,
}, Gui)
corner(Window, 14)
stroke(Window, Color3.fromRGB(70, 40, 60), 0.5)

local Sidebar = make("Frame", {
	Size = UDim2.new(0, 130, 1, 0),
	BackgroundColor3 = SIDE,
}, Window)
corner(Sidebar, 14)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 18),
	Size = UDim2.new(1, -20, 0, 24),
	Text = "Ember's",
	TextColor3 = ACCENT,
	TextSize = 17,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Sidebar)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 42),
	Size = UDim2.new(1, -20, 0, 16),
	Text = "Cheats",
	TextColor3 = MUTED,
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Sidebar)

local Main = make("Frame", {
	Position = UDim2.new(0, 130, 0, 0),
	Size = UDim2.new(1, -130, 1, 0),
	BackgroundTransparency = 1,
}, Window)

local Header = make("Frame", {
	Size = UDim2.new(1, 0, 0, 48),
	BackgroundTransparency = 1,
}, Main)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(18, 14),
	Size = UDim2.new(1, -50, 0, 22),
	Text = "Combat",
	TextColor3 = TEXT,
	TextSize = 17,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Header)

local CloseBtn = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(30, 30),
	BackgroundTransparency = 1,
	Text = "✕",
	TextColor3 = MUTED,
	TextSize = 16,
}, Header)

local Content = make("ScrollingFrame", {
	Position = UDim2.fromOffset(14, 52),
	Size = UDim2.new(1, -28, 1, -66),
	BackgroundTransparency = 1,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = ACCENT,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, Main)
make("UIListLayout", {Padding = UDim.new(0, 9)}, Content)

local function createToggle(name, desc, default)
	local card = make("Frame", {
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = CARD,
	}, Content)
	corner(card, 10)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 9),
		Size = UDim2.new(1, -70, 0, 18),
		Text = name,
		TextColor3 = TEXT,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 29),
		Size = UDim2.new(1, -70, 0, 16),
		Text = desc,
		TextColor3 = MUTED,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	local switch = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(42, 24),
		BackgroundColor3 = default and ACCENT or Color3.fromRGB(55, 45, 60),
	}, card)
	corner(switch, 12)

	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = default and UDim2.new(1, -22, 0.5, 0) or UDim2.fromOffset(2, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.new(1, 1, 1),
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
	local col = v and ACCENT or Color3.fromRGB(55, 45, 60)
	local pos = v and UDim2.new(1, -22, 0.5, 0) or UDim2.fromOffset(2, 0.5)
	TweenService:Create(t.switch, TweenInfo.new(0.14), {BackgroundColor3 = col}):Play()
	TweenService:Create(t.knob, TweenInfo.new(0.14), {Position = pos}):Play()
end

local tAim   = createToggle("Aimbot Hard Lock", "Trava na cabeça (sem smooth)", false)
local tESP   = createToggle("ESP", "Box + Nome + HP + Distância", true)
local tTeam  = createToggle("Team Check", "Ignora aliados", true)
local tRun   = createToggle("Auto Run", "Anda sozinho (+5%)", false)
local tShoot = createToggle("Auto Shoot", "Atira quando tem alvo", false)

-- ====================== CONNECTIONS ======================
tAim.btn.MouseButton1Click:Connect(function() S.Aim = not S.Aim setToggle(tAim, S.Aim) end)
tESP.btn.MouseButton1Click:Connect(function() S.ESP = not S.ESP setToggle(tESP, S.ESP) end)
tTeam.btn.MouseButton1Click:Connect(function() S.TeamCheck = not S.TeamCheck setToggle(tTeam, S.TeamCheck) end)
tRun.btn.MouseButton1Click:Connect(function()
	S.AutoRun = not S.AutoRun
	setToggle(tRun, S.AutoRun)
	applySpeed()
end)
tShoot.btn.MouseButton1Click:Connect(function() S.AutoShoot = not S.AutoShoot setToggle(tShoot, S.AutoShoot) end)

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
			drag = true start = i.Position pos = Window.Position
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

-- ====================== LOOP (prioridade alta) ======================
RunService:BindToRenderStep("EmberAim", Enum.RenderPriority.Camera.Value + 1, function()
	-- ESP
	if S.ESP then
		for _, p in ipairs(Players:GetPlayers()) do
			pcall(updateESP, p)
		end
	else
		for p, o in pairs(ESPObjects) do
			o.box.Visible = false
			o.name.Visible = false
			o.hp.Visible = false
			o.dist.Visible = false
		end
	end

	-- AIMBOT HARD LOCK
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
end)

print("✅ Ember's Cheats (Drawing + Hard Lock) carregado")
