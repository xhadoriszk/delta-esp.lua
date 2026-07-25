--[[
    Ember's Cheats — Mobile-First
    LocalScript → StarterPlayer > StarterPlayerScripts
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
local CFG = {
	UpdateRate = 0.07,
	MaxDistance = 2000,
	AimSize = 76,
	FlySize = 60,
	ButtonH = 50,
}

local Theme = {
	Dark = {
		bg = Color3.fromRGB(13, 16, 24),
		panel = Color3.fromRGB(20, 25, 36),
		card = Color3.fromRGB(28, 35, 50),
		text = Color3.fromRGB(240, 245, 255),
		muted = Color3.fromRGB(140, 160, 185),
		border = Color3.fromRGB(55, 70, 95),
		accent = Color3.fromRGB(70, 220, 230),
	},
	Light = {
		bg = Color3.fromRGB(245, 248, 252),
		panel = Color3.fromRGB(230, 238, 248),
		card = Color3.fromRGB(215, 225, 240),
		text = Color3.fromRGB(20, 30, 45),
		muted = Color3.fromRGB(80, 100, 125),
		border = Color3.fromRGB(160, 180, 205),
		accent = Color3.fromRGB(0, 160, 175),
	},
}

local Colors = {
	Ciano = Color3.fromRGB(70, 225, 230),
	Vermelho = Color3.fromRGB(255, 80, 100),
	Rosa = Color3.fromRGB(255, 120, 190),
	Verde = Color3.fromRGB(80, 255, 140),
	Amarelo = Color3.fromRGB(255, 220, 70),
}

-- ====================== STATE ======================
local S = {
	ESP = true,
	TeamCheck = false,
	Theme = "Dark",
	Color = "Ciano",
	MaxDist = 1000,
	ShowHP = true,
	ShowDist = true,
	Boxes = false,
	Skeleton = false,
	Tracers = false,

	Aim = false,
	AimMode = "Auto",
	AimActive = false,
	AimPart = "Head",
	AimDist = 600,
	AimFOV = 160,
	AimTeam = true,
	AimVisible = true,
	AimButton = true,

	Speed = 16,
	Jump = 50,
	Fly = false,
	FlySpeed = 55,
	FlyUp = false,
	FlyDown = false,
	AutoRun = false,
	InfJump = false,

	Panel = true,
	Tab = "ESP",
}

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

local function stroke(o, c, t, th)
	return make("UIStroke", {Color = c, Transparency = t or 0, Thickness = th or 1}, o)
end

local function accent()
	return Colors[S.Color]
end

local function theme()
	return Theme[S.Theme]
end

local function getRoot(char)
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHum(char)
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function isAlive(p)
	local hum = getHum(p.Character)
	return hum and hum.Health > 0
end

local function sameTeam(p)
	return LP.Team and p.Team == LP.Team
end

-- ====================== CHARACTER ======================
local flyBV, flyConn

local function applyStats()
	local hum = getHum(LP.Character)
	if not hum then return end
	local spd = S.Speed
	if S.AutoRun then spd = math.min(spd * 1.08, 100) end
	hum.WalkSpeed = spd
	hum.JumpPower = S.Jump
end

local function disableFly()
	S.Fly = false
	S.FlyUp = false
	S.FlyDown = false
	if flyConn then flyConn:Disconnect() flyConn = nil end
	if flyBV then flyBV:Destroy() flyBV = nil end
	local hum = getHum(LP.Character)
	if hum then
		hum.PlatformStand = false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

local function enableFly()
	disableFly()
	local root = getRoot(LP.Character)
	local hum = getHum(LP.Character)
	if not root or not hum then return end

	S.Fly = true
	hum.PlatformStand = true
	flyBV = make("BodyVelocity", {
		MaxForce = Vector3.new(1e9, 1e9, 1e9),
		Velocity = Vector3.zero,
	}, root)

	flyConn = RunService.Heartbeat:Connect(function()
		if not S.Fly then return disableFly() end
		local root = getRoot(LP.Character)
		local hum = getHum(LP.Character)
		if not root or not hum then return disableFly() end

		local cam = Workspace.CurrentCamera
		local move = hum.MoveDirection
		local vel = Vector3.zero
		if move.Magnitude > 0 then
			vel = (cam.CFrame.LookVector * move.Z + cam.CFrame.RightVector * move.X) * S.FlySpeed
		end
		if S.FlyUp then vel += Vector3.yAxis * S.FlySpeed end
		if S.FlyDown then vel -= Vector3.yAxis * S.FlySpeed end
		if flyBV and flyBV.Parent then flyBV.Velocity = vel end
	end)
end

UserInputService.JumpRequest:Connect(function()
	if not S.InfJump then return end
	local hum = getHum(LP.Character)
	if hum and hum.FloorMaterial == Enum.Material.Air then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

LP.CharacterAdded:Connect(function()
	task.defer(function()
		applyStats()
		if S.Fly then enableFly() end
	end)
end)

-- ====================== ESP ======================
local ESPFolder = make("Folder", {Name = "EmberESP"}, Workspace)
local UIESP = make("Folder", {Name = "EmberUIESP"})
local ESPData = {}

local Joints = {
	{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
	{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
	{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
	{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
	{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}

local function clearESP(p)
	local d = ESPData[p]
	if d then
		if d.folder then d.folder:Destroy() end
		if d.ui then d.ui:Destroy() end
		ESPData[p] = nil
	end
end

local function createESP(p, char)
	clearESP(p)
	local root = getRoot(char)
	if not root then return end

	local folder = make("Folder", {Name = tostring(p.UserId)}, ESPFolder)
	local hl = make("Highlight", {
		Adornee = char,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		FillTransparency = 0.75,
		OutlineTransparency = 0.1,
	}, folder)

	local bill = make("BillboardGui", {
		Adornee = root,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(240, 52),
		StudsOffset = Vector3.new(0, 3.5, 0),
		MaxDistance = CFG.MaxDistance,
	}, folder)

	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextStrokeTransparency = 0.4,
		Text = p.DisplayName,
	}, bill)

	local ui = make("Folder", {Name = tostring(p.UserId)}, UIESP)
	local lines = {}
	for _, pair in ipairs(Joints) do
		local line = make("Frame", {
			BackgroundColor3 = accent(),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(2, 2),
			Visible = false,
		}, ui)
		table.insert(lines, {line = line, a = pair[1], b = pair[2]})
	end

	local tracer = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = accent(),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 2, 0, 60),
		Visible = false,
	}, ui)

	ESPData[p] = {
		folder = folder,
		hl = hl,
		bill = bill,
		label = label,
		ui = ui,
		lines = lines,
		tracer = tracer,
	}
end

local function updateESP(p)
	if p == LP then return end
	local d = ESPData[p]
	if not d or not p.Character then return end

	local root = getRoot(p.Character)
	local own = getRoot(LP.Character)
	local hum = getHum(p.Character)
	if not root or not own or not hum or hum.Health <= 0 then
		clearESP(p)
		return
	end

	local dist = (own.Position - root.Position).Magnitude
	local okTeam = not S.TeamCheck or not sameTeam(p)
	local within = dist <= S.MaxDist

	local visible = true
	if within then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {LP.Character, p.Character}
		local hit = Workspace:Raycast(own.Position, root.Position - own.Position, params)
		if hit then visible = false end
	end

	local enabled = S.ESP and within and okTeam
	local col = visible and Colors.Amarelo or Colors.Vermelho

	d.hl.Enabled = enabled
	d.hl.FillColor = col
	d.hl.OutlineColor = col
	d.bill.Enabled = enabled

	local parts = {p.DisplayName}
	if S.ShowDist then table.insert(parts, math.floor(dist) .. "m") end
	if S.ShowHP then table.insert(parts, math.floor(hum.Health) .. " HP") end
	d.label.Text = table.concat(parts, "  •  ")
	d.label.TextColor3 = S.Theme == "Light" and Color3.fromRGB(20, 28, 40) or Color3.new(1, 1, 1)

	d.tracer.Visible = enabled and S.Tracers
	if d.tracer.Visible then
		local sp, on = Camera:WorldToViewportPoint(root.Position)
		if on then
			local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
			local delta = Vector2.new(sp.X, sp.Y) - center
			d.tracer.Size = UDim2.new(0, 2, 0, delta.Magnitude)
			d.tracer.Rotation = math.deg(math.atan2(delta.Y, delta.X)) + 90
			d.tracer.Position = UDim2.fromOffset(center.X, center.Y)
			d.tracer.BackgroundColor3 = col
		else
			d.tracer.Visible = false
		end
	end

	for _, item in ipairs(d.lines) do item.line.Visible = false end
	if enabled and S.Skeleton then
		for _, item in ipairs(d.lines) do
			local a = p.Character:FindFirstChild(item.a)
			local b = p.Character:FindFirstChild(item.b)
			if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
				local pa, ona = Camera:WorldToViewportPoint(a.Position)
				local pb, onb = Camera:WorldToViewportPoint(b.Position)
				if ona and onb then
					local delta = Vector2.new(pb.X - pa.X, pb.Y - pa.Y)
					item.line.Size = UDim2.new(0, delta.Magnitude, 0, 2)
					item.line.Position = UDim2.fromOffset(pa.X, pa.Y)
					item.line.Rotation = math.deg(math.atan2(delta.Y, delta.X))
					item.line.Visible = true
					item.line.BackgroundColor3 = col
				end
			end
		end
	end
end

local function setupPlayer(p)
	if p == LP then return end
	local function onChar(char)
		task.defer(function()
			local hum = getHum(char)
			if hum then
				hum.Died:Connect(function() clearESP(p) end)
			end
			createESP(p, char)
		end)
	end
	p.CharacterAdded:Connect(onChar)
	if p.Character then onChar(p.Character) end
end

for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(clearESP)

-- ====================== AIMBOT (HARD LOCK) ======================
local aimTarget, aimPart
local aimHeld = false

local function getAimPart(char)
	local part = char:FindFirstChild(S.AimPart)
	if part and part:IsA("BasePart") then return part end
	if S.AimPart == "Torso" then
		return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	end
	return getRoot(char)
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

local function findBest()
	local best, bestDist = nil, math.huge
	local own = getRoot(LP.Character)
	if not own then return nil end
	local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

	for _, p in ipairs(Players:GetPlayers()) do
		if p == LP or not p.Character or not isAlive(p) then continue end
		if S.AimTeam and sameTeam(p) then continue end

		local part = getAimPart(p.Character)
		if not part then continue end

		local dist3d = (own.Position - part.Position).Magnitude
		if dist3d > S.AimDist then continue end

		local sp, on = Camera:WorldToViewportPoint(part.Position)
		if not on then continue end

		local screenDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
		if screenDist > S.AimFOV then continue end
		if S.AimVisible and not isVisible(part) then continue end

		if screenDist < bestDist then
			bestDist = screenDist
			best = p
		end
	end
	return best
end

local function isAimOn()
	if not S.Aim then return false end
	if S.AimMode == "Auto" then return true end
	if S.AimMode == "Toggle" then return S.AimActive end
	return aimHeld
end

-- ====================== GUI ======================
local Gui = make("ScreenGui", {
	Name = "EmbersCheats",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 60,
}, PlayerGui)

UIESP.Parent = Gui

local Toggle = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(70, 46),
	BackgroundColor3 = theme().panel,
	Text = "Ember",
	TextColor3 = accent(),
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
}, Gui)
corner(Toggle, 13)
stroke(Toggle, accent(), 0.25)

local Panel = make("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 68),
	Size = UDim2.fromOffset(300, 520),
	BackgroundColor3 = theme().bg,
	Visible = S.Panel,
}, Gui)
corner(Panel, 16)
stroke(Panel, theme().border, 0.25)

local Top = make("Frame", {
	Size = UDim2.new(1, 0, 0, 54),
	BackgroundColor3 = theme().panel,
}, Panel)
corner(Top, 16)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 9),
	Size = UDim2.new(1, -60, 0, 18),
	Text = "Ember's Cheats",
	TextColor3 = theme().text,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Top)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 30),
	Size = UDim2.new(1, -60, 0, 14),
	Text = "Arraste • Toque nas abas",
	TextColor3 = theme().muted,
	TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Top)

local Close = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -6, 0.5, 0),
	Size = UDim2.fromOffset(40, 40),
	BackgroundTransparency = 1,
	Text = "✕",
	TextColor3 = theme().muted,
	TextSize = 18,
}, Top)

local TabBar = make("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 62),
	Size = UDim2.new(1, -24, 0, 36),
}, Panel)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, TabBar)

local Tabs = {}
local function makeTab(name, icon)
	local b = make("TextButton", {
		Size = UDim2.new(1/3, -4, 1, 0),
		BackgroundColor3 = theme().card,
		Text = icon .. " " .. name,
		TextColor3 = theme().text,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,
	}, TabBar)
	corner(b, 10)
	Tabs[name] = b
	return b
end

local TabESP = makeTab("ESP", "◉")
local TabAIM = makeTab("AIM", "◎")
local TabCFG = makeTab("CFG", "✦")

local function makeContent()
	local sf = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 106),
		Size = UDim2.new(1, -24, 1, -118),
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
	}, Panel)
	make("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder}, sf)
	make("UIPadding", {PaddingBottom = UDim.new(0, 10)}, sf)
	return sf
end

local CESP = makeContent()
local CAIM = makeContent()
local CCFG = makeContent()

local function section(parent, text)
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Text = text:upper(),
		TextColor3 = theme().muted,
		TextSize = 10,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, parent)
end

local function makeToggle(parent, text, icon)
	local f = make("Frame", {
		Size = UDim2.new(1, 0, 0, CFG.ButtonH),
		BackgroundColor3 = theme().card,
	}, parent)
	corner(f, 11)
	stroke(f, theme().border, 0.5)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.fromOffset(26, CFG.ButtonH),
		Text = icon,
		TextColor3 = accent(),
		TextSize = 15,
		Font = Enum.Font.GothamBold,
	}, f)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -90, 1, 0),
		Text = text,
		TextColor3 = theme().text,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)

	local sw = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(42, 24),
		BackgroundColor3 = theme().border,
	}, f)
	corner(sw, 12)

	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(2, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, sw)
	corner(knob, 10)

	local btn = make("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
	}, f)

	return {f = f, btn = btn, sw = sw, knob = knob}
end

local function setToggle(t, on)
	local col = on and accent() or theme().border
	local pos = on and UDim2.new(1, -22, 0.5, 0) or UDim2.fromOffset(2, 0.5)
	TweenService:Create(t.sw, TweenInfo.new(0.13), {BackgroundColor3 = col}):Play()
	TweenService:Create(t.knob, TweenInfo.new(0.13), {Position = pos}):Play()
end

local function makeOpt(parent, text, icon)
	local f = make("Frame", {
		Size = UDim2.new(1, 0, 0, CFG.ButtonH),
		BackgroundColor3 = theme().card,
	}, parent)
	corner(f, 11)
	stroke(f, theme().border, 0.5)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.fromOffset(26, CFG.ButtonH),
		Text = icon,
		TextColor3 = accent(),
		TextSize = 15,
		Font = Enum.Font.GothamBold,
	}, f)

	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(40, 0),
		Size = UDim2.new(1, -16, 1, 0),
		Text = text,
		TextColor3 = theme().text,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)

	local btn = make("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
	}, f)

	return {f = f, btn = btn, label = label}
end

-- Conteúdo
section(CESP, "CONTROLES")
local tESP = makeToggle(CESP, "ESP geral", "◉")
local tTeam = makeToggle(CESP, "Ignorar time", "♟")
local oDist = makeOpt(CESP, "Alcance máximo", "↔")

section(CESP, "EXIBIÇÃO")
local tHP = makeToggle(CESP, "Mostrar vida", "♥")
local tDist = makeToggle(CESP, "Mostrar distância", "↔")
local tBox = makeToggle(CESP, "Box ESP", "□")
local tSkel = makeToggle(CESP, "Skeleton", "☠")
local tTracer = makeToggle(CESP, "Tracers", "→")

section(CESP, "APARÊNCIA")
local oTheme = makeOpt(CESP, "Tema", "◐")
local oColor = makeOpt(CESP, "Sub cor", "◆")

section(CAIM, "AIMBOT")
local tAim = makeToggle(CAIM, "Aimbot", "◎")
local oMode = makeOpt(CAIM, "Modo", "⌖")
local tAimBtn = makeToggle(CAIM, "Botão de mira", "◉")
local oPart = makeOpt(CAIM, "Parte do alvo", "◎")
local oAimDist = makeOpt(CAIM, "Alcance", "↔")
local oFOV = makeOpt(CAIM, "FOV", "◯")
local tAimTeam = makeToggle(CAIM, "Ignorar time", "♟")
local tVisible = makeToggle(CAIM, "Só visível", "◉")

section(CCFG, "PERSONAGEM")
local oSpeed = makeOpt(CCFG, "Velocidade", "»")
local oJump = makeOpt(CCFG, "Pulo", "↑")
local tRun = makeToggle(CCFG, "Auto correr", "»")
local tInf = makeToggle(CCFG, "Pulo infinito", "∞")

section(CCFG, "FLY")
local tFly = makeToggle(CCFG, "Fly", "▲")
local oFlySpd = makeOpt(CCFG, "Fly speed", "▲")

-- Botões flutuantes
local AimBtn = make("TextButton", {
	Size = UDim2.fromOffset(CFG.AimSize, CFG.AimSize),
	BackgroundColor3 = theme().panel,
	Text = "◎",
	TextColor3 = accent(),
	TextSize = 24,
	Font = Enum.Font.GothamBold,
	Visible = false,
	AutoButtonColor = false,
}, Gui)
corner(AimBtn, 20)
stroke(AimBtn, accent(), 0.3, 2)

local FlyUp = make("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -18, 1, -170),
	Size = UDim2.fromOffset(CFG.FlySize, CFG.FlySize),
	BackgroundColor3 = theme().panel,
	Text = "▲",
	TextColor3 = accent(),
	TextSize = 20,
	Visible = false,
	AutoButtonColor = false,
}, Gui)
corner(FlyUp, 16)

local FlyDown = make("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -18, 1, -95),
	Size = UDim2.fromOffset(CFG.FlySize, CFG.FlySize),
	BackgroundColor3 = theme().panel,
	Text = "▼",
	TextColor3 = accent(),
	TextSize = 20,
	Visible = false,
	AutoButtonColor = false,
}, Gui)
corner(FlyDown, 16)

local FOV = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	BackgroundTransparency = 1,
	Visible = false,
}, Gui)
corner(FOV, 999)
stroke(FOV, accent(), 0.55, 1.5)

local TargetLbl = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.5, 48),
	Size = UDim2.fromOffset(200, 20),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = accent(),
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	TextStrokeTransparency = 0.5,
	Visible = false,
}, Gui)

-- ====================== REFRESH ======================
local function refresh()
	local th = theme()
	Panel.BackgroundColor3 = th.bg
	Top.BackgroundColor3 = th.panel
	Toggle.BackgroundColor3 = th.panel
	Toggle.TextColor3 = accent()

	setToggle(tESP, S.ESP)
	setToggle(tTeam, S.TeamCheck)
	oDist.label.Text = "Alcance máximo  •  " .. S.MaxDist .. "m"
	setToggle(tHP, S.ShowHP)
	setToggle(tDist, S.ShowDist)
	setToggle(tBox, S.Boxes)
	setToggle(tSkel, S.Skeleton)
	setToggle(tTracer, S.Tracers)
	oTheme.label.Text = "Tema  •  " .. S.Theme
	oColor.label.Text = "Sub cor  •  " .. S.Color

	setToggle(tAim, S.Aim)
	local modes = {Auto = "Automático", Toggle = "Alternar", Hold = "Segurar"}
	oMode.label.Text = "Modo  •  " .. (modes[S.AimMode] or S.AimMode)
	setToggle(tAimBtn, S.AimButton)
	oPart.label.Text = "Alvo  •  " .. S.AimPart
	oAimDist.label.Text = "Alcance  •  " .. S.AimDist .. "m"
	oFOV.label.Text = "FOV  •  " .. S.AimFOV .. "°"
	setToggle(tAimTeam, S.AimTeam)
	setToggle(tVisible, S.AimVisible)

	oSpeed.label.Text = "Velocidade  •  " .. S.Speed
	oJump.label.Text = "Pulo  •  " .. S.Jump
	setToggle(tRun, S.AutoRun)
	setToggle(tInf, S.InfJump)
	setToggle(tFly, S.Fly)
	oFlySpd.label.Text = "Fly speed  •  " .. S.FlySpeed

	for name, b in pairs(Tabs) do
		if name == S.Tab then
			b.BackgroundColor3 = accent()
			b.TextColor3 = th.bg
		else
			b.BackgroundColor3 = th.card
			b.TextColor3 = th.text
		end
	end
	CESP.Visible = S.Tab == "ESP"
	CAIM.Visible = S.Tab == "AIM"
	CCFG.Visible = S.Tab == "CFG"

	AimBtn.Visible = S.Aim and S.AimButton
	if S.AimMode == "Hold" then
		AimBtn.BackgroundColor3 = aimHeld and accent() or th.panel
		AimBtn.TextColor3 = aimHeld and Color3.new(0,0,0) or accent()
	elseif S.AimMode == "Toggle" then
		AimBtn.BackgroundColor3 = S.AimActive and accent() or th.panel
		AimBtn.TextColor3 = S.AimActive and Color3.new(0,0,0) or accent()
	else
		AimBtn.BackgroundColor3 = th.panel
		AimBtn.TextColor3 = accent()
	end

	FlyUp.Visible = S.Fly
	FlyDown.Visible = S.Fly
end

-- ====================== CONNECTIONS ======================
local function click(btn, fn)
	btn.MouseButton1Click:Connect(fn)
end

click(TabESP, function() S.Tab = "ESP" refresh() end)
click(TabAIM, function() S.Tab = "AIM" refresh() end)
click(TabCFG, function() S.Tab = "CFG" refresh() end)

click(tESP.btn, function() S.ESP = not S.ESP refresh() end)
click(tTeam.btn, function() S.TeamCheck = not S.TeamCheck refresh() end)
click(oDist.btn, function()
	S.MaxDist = S.MaxDist >= 2000 and 100 or math.min(S.MaxDist + 100, 2000)
	refresh()
end)
click(tHP.btn, function() S.ShowHP = not S.ShowHP refresh() end)
click(tDist.btn, function() S.ShowDist = not S.ShowDist refresh() end)
click(tBox.btn, function() S.Boxes = not S.Boxes refresh() end)
click(tSkel.btn, function() S.Skeleton = not S.Skeleton refresh() end)
click(tTracer.btn, function() S.Tracers = not S.Tracers refresh() end)
click(oTheme.btn, function() S.Theme = S.Theme == "Dark" and "Light" or "Dark" refresh() end)
click(oColor.btn, function()
	local keys = {}
	for k in pairs(Colors) do table.insert(keys, k) end
	table.sort(keys)
	local i = table.find(keys, S.Color) or 1
	S.Color = keys[i % #keys + 1]
	refresh()
end)

click(tAim.btn, function()
	S.Aim = not S.Aim
	if not S.Aim then S.AimActive = false aimHeld = false end
	refresh()
end)
click(oMode.btn, function()
	local m = {"Auto", "Toggle", "Hold"}
	local i = table.find(m, S.AimMode) or 1
	S.AimMode = m[i % #m + 1]
	S.AimActive = false
	aimHeld = false
	refresh()
end)
click(tAimBtn.btn, function() S.AimButton = not S.AimButton refresh() end)
click(oPart.btn, function()
	local p = {"Head", "Torso", "HumanoidRootPart"}
	local i = table.find(p, S.AimPart) or 1
	S.AimPart = p[i % #p + 1]
	refresh()
end)
click(oAimDist.btn, function()
	S.AimDist = S.AimDist >= 1000 and 100 or S.AimDist + 100
	refresh()
end)
click(oFOV.btn, function()
	S.AimFOV = S.AimFOV >= 360 and 40 or S.AimFOV + 30
	refresh()
end)
click(tAimTeam.btn, function() S.AimTeam = not S.AimTeam refresh() end)
click(tVisible.btn, function() S.AimVisible = not S.AimVisible refresh() end)

click(oSpeed.btn, function()
	local s = {1, 16, 25, 50, 100}
	local i = table.find(s, S.Speed) or 1
	S.Speed = s[i % #s + 1]
	refresh() applyStats()
end)
click(oJump.btn, function()
	local j = {40, 100, 200, 400, 800}
	local i = table.find(j, S.Jump) or 1
	S.Jump = j[i % #j + 1]
	refresh() applyStats()
end)
click(tRun.btn, function() S.AutoRun = not S.AutoRun refresh() applyStats() end)
click(tInf.btn, function() S.InfJump = not S.InfJump refresh() end)
click(tFly.btn, function()
	if S.Fly then disableFly() else enableFly() end
	refresh()
end)
click(oFlySpd.btn, function()
	S.FlySpeed = S.FlySpeed >= 200 and 20 or S.FlySpeed + 20
	refresh()
end)

click(Toggle, function()
	S.Panel = not S.Panel
	Panel.Visible = S.Panel
end)
click(Close, function()
	S.Panel = false
	Panel.Visible = false
end)

AimBtn.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if S.AimMode == "Hold" then aimHeld = true refresh() end
end)
AimBtn.InputEnded:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if S.AimMode == "Hold" then
		aimHeld = false
		refresh()
	elseif S.AimMode == "Toggle" then
		S.AimActive = not S.AimActive
		refresh()
	end
end)

FlyUp.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then S.FlyUp = true end
end)
FlyUp.InputEnded:Connect(function() S.FlyUp = false end)
FlyDown.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then S.FlyDown = true end
end)
FlyDown.InputEnded:Connect(function() S.FlyDown = false end)

do
	local drag, start, pos
	Top.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = true
			start = i.Position
			pos = Panel.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if not drag then return end
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - start
			Panel.Position = UDim2.new(pos.X.Scale, pos.X.Offset + d.X, pos.Y.Scale, pos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			drag = false
		end
	end)
end

-- ====================== LOOP ======================
refresh()

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt

	if S.ESP and acc >= CFG.UpdateRate then
		acc = 0
		for _, p in ipairs(Players:GetPlayers()) do
			updateESP(p)
		end
	end

	if S.Aim then
		local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
		FOV.Visible = true
		FOV.Position = UDim2.fromOffset(center.X, center.Y)
		FOV.Size = UDim2.fromOffset(S.AimFOV * 2, S.AimFOV * 2)

		aimTarget = findBest()
		if aimTarget and aimTarget.Character then
			aimPart = getAimPart(aimTarget.Character)
		else
			aimPart = nil
		end

		if isAimOn() and aimPart then
			Camera.CFrame = CFrame.new(Camera.CFrame.Position, aimPart.Position)
			TargetLbl.Text = "Mirando: " .. aimTarget.DisplayName
			TargetLbl.Visible = true
		else
			TargetLbl.Visible = false
		end
	else
		FOV.Visible = false
		TargetLbl.Visible = false
		AimBtn.Visible = false
	end

	if S.AutoRun and not S.Fly then
		local hum = getHum(LP.Character)
		if hum then hum:Move(Vector3.new(0, 0, -1), true) end
	end

	applyStats()
end)

print("✅ Ember's Cheats carregado")
