--[[
    Ember's Cheats — Versão Final com Abas
    Drawing ESP proporcional + Hard Lock + Auto Run + Auto Shoot
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LP = Players.LocalPlayer
local PlayerGui = LP:WaitForChild("PlayerGui")
local Camera = Workspace.CurrentCamera

-- ====================== CONFIG PADRÃO ======================
local CFG = {
	-- ESP
	ESPEnabled = true,
	ESPShowBox = true,
	ESPShowName = true,
	ESPShowHP = true,
	ESPShowDist = true,
	ESPMaxDist = 2000,
	ESPTeamCheck = true,

	-- Aimbot
	AimEnabled = false,
	AimFOV = 140,
	AimMaxDist = 1000,
	AimTeamCheck = true,
	AimVisibleOnly = true,
	AutoShoot = false,
	ShootDelay = 0.13,

	-- Player
	AutoRun = false,
	SpeedBoost = 1.05,
}

-- ====================== CORES ======================
local ACCENT = Color3.fromRGB(255, 105, 180)
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
		hum.WalkSpeed = CFG.AutoRun and (16 * CFG.SpeedBoost) or 16
	end
end

LP.CharacterAdded:Connect(function()
	task.wait(0.4)
	applySpeed()
end)

-- ====================== ESP (DRAWING PROPORCIONAL) ======================
local ESPObjects = {}

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
	if p == LP then return end
	clearESP(p)

	local box = Drawing.new("Square")
	box.Thickness = 1.4
	box.Filled = false
	box.Color = ACCENT
	box.Visible = false

	local name = Drawing.new("Text")
	name.Size = 13
	name.Center = true
	name.Outline = true
	name.Color = Color3.new(1, 1, 1)
	name.Visible = false

	local hp = Drawing.new("Text")
	hp.Size = 12
	hp.Center = true
	hp.Outline = true
	hp.Color = Color3.fromRGB(120, 255, 140)
	hp.Visible = false

	local dist = Drawing.new("Text")
	dist.Size = 11
	dist.Center = true
	dist.Outline = true
	dist.Color = Color3.fromRGB(210, 210, 210)
	dist.Visible = false

	ESPObjects[p] = {box = box, name = name, hp = hp, dist = dist}
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

	local function hide()
		o.box.Visible = false
		o.name.Visible = false
		o.hp.Visible = false
		o.dist.Visible = false
	end

	if not CFG.ESPEnabled or not char or not root or not head or not hum or not own or hum.Health <= 0 then
		hide()
		return
	end

	if CFG.ESPTeamCheck and sameTeam(p) then
		hide()
		return
	end

	local dist3d = (own.Position - root.Position).Magnitude
	if dist3d > CFG.ESPMaxDist then
		hide()
		return
	end

	-- Posições na tela (cabeça e pés aproximados)
	local headPos, headOn = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.3, 0))
	local footPos, footOn = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))

	if not headOn and not footOn then
		hide()
		return
	end

	local topY = math.min(headPos.Y, footPos.Y)
	local botY = math.max(headPos.Y, footPos.Y)
	local height = math.max(botY - topY, 8)
	local width = height * 0.55
	local midX = (headPos.X + footPos.X) / 2

	-- Box proporcional
	if CFG.ESPShowBox then
		o.box.Size = Vector2.new(width, height)
		o.box.Position = Vector2.new(midX - width/2, topY)
		o.box.Color = ACCENT
		o.box.Visible = true
	else
		o.box.Visible = false
	end

	-- Nome
	if CFG.ESPShowName then
		o.name.Text = p.DisplayName
		o.name.Position = Vector2.new(midX, topY - 15)
		o.name.Visible = true
	else
		o.name.Visible = false
	end

	-- HP
	if CFG.ESPShowHP then
		o.hp.Text = math.floor(hum.Health) .. " HP"
		o.hp.Position = Vector2.new(midX, botY + 2)
		o.hp.Visible = true
	else
		o.hp.Visible = false
	end

	-- Distância
	if CFG.ESPShowDist then
		o.dist.Text = math.floor(dist3d) .. "m"
		o.dist.Position = Vector2.new(midX, botY + 15)
		o.dist.Visible = true
	else
		o.dist.Visible = false
	end
end

-- Tracking de jogadores
local function track(p)
	if p == LP then return end
	createESP(p)

	p.CharacterAdded:Connect(function()
		task.wait(0.3)
		createESP(p)
	end)
end

for _, p in ipairs(Players:GetPlayers()) do track(p) end
Players.PlayerAdded:Connect(track)
Players.PlayerRemoving:Connect(clearESP)

-- Atualização forçada a cada 5 segundos
task.spawn(function()
	while true do
		task.wait(5)
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= LP and not ESPObjects[p] then
				createESP(p)
			end
		end
	end
end)

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
		if CFG.AimTeamCheck and sameTeam(p) then continue end

		local head = p.Character and p.Character:FindFirstChild("Head")
		if not head then continue end

		local dist = (own.Position - head.Position).Magnitude
		if dist > CFG.AimMaxDist then continue end

		local sp, onScreen = Camera:WorldToViewportPoint(head.Position)
		if not onScreen then continue end

		local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
		if screenDist > CFG.AimFOV then continue end
		if CFG.AimVisibleOnly and not canSee(head) then continue end

		if screenDist < bestDist then
			bestDist = screenDist
			best = head
		end
	end
	return best
end

local lastShoot = 0
local function doShoot()
	local now = tick()
	if now - lastShoot < CFG.ShootDelay then return end
	lastShoot = now

	pcall(function()
		if mouse1press then
			mouse1press()
			task.wait(0.035)
			mouse1release()
		elseif mouse1click then
			mouse1click()
		end
	end)
end

-- ====================== GUI COM ABAS ======================
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
	Size = UDim2.fromOffset(500, 380),
	BackgroundColor3 = BG,
	Visible = true,
}, Gui)
corner(Window, 14)
stroke(Window, Color3.fromRGB(70, 40, 60), 0.5)

-- Sidebar
local Sidebar = make("Frame", {
	Size = UDim2.new(0, 120, 1, 0),
	BackgroundColor3 = SIDE,
}, Window)
corner(Sidebar, 14)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 16),
	Size = UDim2.new(1, -16, 0, 22),
	Text = "Ember's",
	TextColor3 = ACCENT,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Sidebar)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 38),
	Size = UDim2.new(1, -16, 0, 14),
	Text = "Cheats",
	TextColor3 = MUTED,
	TextSize = 11,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Sidebar)

-- Botões das abas
local tabButtons = {}
local tabContents = {}
local currentTab = "ESP"

local function createTabButton(name, y)
	local btn = make("TextButton", {
		Position = UDim2.fromOffset(8, y),
		Size = UDim2.new(1, -16, 0, 34),
		BackgroundColor3 = Color3.fromRGB(40, 32, 48),
		Text = name,
		TextColor3 = TEXT,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,
	}, Sidebar)
	corner(btn, 8)
	tabButtons[name] = btn
	return btn
end

local btnESP  = createTabButton("ESP", 70)
local btnAim  = createTabButton("Aimbot", 110)
local btnCfg  = createTabButton("Config", 150)

-- Área principal
local Main = make("Frame", {
	Position = UDim2.new(0, 120, 0, 0),
	Size = UDim2.new(1, -120, 1, 0),
	BackgroundTransparency = 1,
}, Window)

local Header = make("Frame", {
	Size = UDim2.new(1, 0, 0, 46),
	BackgroundTransparency = 1,
}, Main)

local Title = make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 12),
	Size = UDim2.new(1, -50, 0, 22),
	Text = "ESP",
	TextColor3 = TEXT,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Header)

local CloseBtn = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.fromOffset(30, 30),
	BackgroundTransparency = 1,
	Text = "✕",
	TextColor3 = MUTED,
	TextSize = 15,
}, Header)

-- Função de conteúdo
local function makeContent()
	local sf = make("ScrollingFrame", {
		Position = UDim2.fromOffset(12, 50),
		Size = UDim2.new(1, -24, 1, -62),
		BackgroundTransparency = 1,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = ACCENT,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, Main)
	make("UIListLayout", {Padding = UDim.new(0, 8)}, sf)
	return sf
end

local contentESP = makeContent()
local contentAim = makeContent()
local contentCfg = makeContent()

tabContents["ESP"] = contentESP
tabContents["Aimbot"] = contentAim
tabContents["Config"] = contentCfg

local function switchTab(name)
	currentTab = name
	Title.Text = name
	for n, c in pairs(tabContents) do
		c.Visible = (n == name)
	end
	for n, b in pairs(tabButtons) do
		b.BackgroundColor3 = (n == name) and ACCENT or Color3.fromRGB(40, 32, 48)
		b.TextColor3 = (n == name) and Color3.new(0,0,0) or TEXT
	end
end

btnESP.MouseButton1Click:Connect(function() switchTab("ESP") end)
btnAim.MouseButton1Click:Connect(function() switchTab("Aimbot") end)
btnCfg.MouseButton1Click:Connect(function() switchTab("Config") end)

-- Toggle helper
local function createToggle(parent, name, desc, key, default)
	local card = make("Frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = CARD,
	}, parent)
	corner(card, 9)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -70, 0, 18),
		Text = name,
		TextColor3 = TEXT,
		TextSize = 13,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -70, 0, 16),
		Text = desc,
		TextColor3 = MUTED,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	local sw = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(40, 22),
		BackgroundColor3 = default and ACCENT or Color3.fromRGB(55, 45, 60),
	}, card)
	corner(sw, 11)

	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = default and UDim2.new(1, -20, 0.5, 0) or UDim2.fromOffset(2, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = Color3.new(1,1,1),
	}, sw)
	corner(knob, 9)

	local btn = make("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
	}, card)

	btn.MouseButton1Click:Connect(function()
		CFG[key] = not CFG[key]
		local on = CFG[key]
		TweenService:Create(sw, TweenInfo.new(0.13), {
			BackgroundColor3 = on and ACCENT or Color3.fromRGB(55, 45, 60)
		}):Play()
		TweenService:Create(knob, TweenInfo.new(0.13), {
			Position = on and UDim2.new(1, -20, 0.5, 0) or UDim2.fromOffset(2, 0.5)
		}):Play()

		if key == "AutoRun" then applySpeed() end
	end)
end

-- Conteúdo ESP
createToggle(contentESP, "ESP Ativado", "Liga/desliga todo o ESP", "ESPEnabled", true)
createToggle(contentESP, "Mostrar Box", "Caixa ao redor do jogador", "ESPShowBox", true)
createToggle(contentESP, "Mostrar Nome", "Nome do jogador", "ESPShowName", true)
createToggle(contentESP, "Mostrar HP", "Vida do jogador", "ESPShowHP", true)
createToggle(contentESP, "Mostrar Distância", "Distância em metros", "ESPShowDist", true)
createToggle(contentESP, "Team Check ESP", "Ignora aliados no ESP", "ESPTeamCheck", true)

-- Conteúdo Aimbot
createToggle(contentAim, "Aimbot Hard Lock", "Trava na cabeça sem smooth", "AimEnabled", false)
createToggle(contentAim, "Team Check Aim", "Ignora aliados no aimbot", "AimTeamCheck", true)
createToggle(contentAim, "Só Visíveis", "Só mira quem não está atrás de parede", "AimVisibleOnly", true)
createToggle(contentAim, "Auto Shoot", "Atira automaticamente no alvo", "AutoShoot", false)

-- Conteúdo Config
createToggle(contentCfg, "Auto Run", "Anda sozinho (+5% speed)", "AutoRun", false)

-- ====================== CONNECTIONS UI ======================
ToggleBtn.MouseButton1Click:Connect(function()
	Window.Visible = not Window.Visible
end)
CloseBtn.MouseButton1Click:Connect(function()
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

switchTab("ESP")

-- ====================== LOOP ======================
RunService:BindToRenderStep("EmberMain", Enum.RenderPriority.Camera.Value + 1, function()
	-- ESP
	for _, p in ipairs(Players:GetPlayers()) do
		pcall(updateESP, p)
	end

	-- Aimbot
	if CFG.AimEnabled then
		local target = getTarget()
		if target then
			Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
			if CFG.AutoShoot then
				doShoot()
			end
		end
	end

	-- Auto Run
	if CFG.AutoRun then
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

print("✅ Ember's Cheats (Abas + Box Proporcional) carregado")
