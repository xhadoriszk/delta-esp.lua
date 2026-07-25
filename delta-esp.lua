--[[
    Ember's Cheats — UI Rosa
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
local FOV = 120
local AIM_DIST = 900
local ESP_DIST = 1500
local SPEED_BOOST = 1.05
local AUTO_SHOOT_DELAY = 0.12

-- ====================== STATE ======================
local S = {
	Aim = false,
	ESP = true,
	TeamCheck = true,
	AutoRun = false,
	AutoShoot = true,
	Panel = true,
}

local lastShoot = 0

-- ====================== CORES (Rosa) ======================
local ACCENT = Color3.fromRGB(255, 105, 180)   -- Rosa principal
local BG     = Color3.fromRGB(18, 16, 22)
local SIDE   = Color3.fromRGB(26, 22, 32)
local CARD   = Color3.fromRGB(34, 28, 42)
local TEXT   = Color3.fromRGB(255, 255, 255)   -- Branco
local MUTED  = Color3.fromRGB(180, 160, 175)

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
	return make("UIStroke", {Color = c, Transparency = t or 0.4, Thickness = th or 1}, o)
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
	return LP.Team ~= nil and p.Team == LP.Team
end

-- ====================== AUTO RUN ======================
local function applySpeed()
	local hum = getHum(LP.Character)
	if hum then
		hum.WalkSpeed = S.AutoRun and (16 * SPEED_BOOST) or 16
	end
end

LP.CharacterAdded:Connect(function()
	task.wait(0.4)
	applySpeed()
end)

-- ====================== ESP ======================
local ESPFolder = make("Folder", {Name = "EmberESP"}, Workspace)
local Data = {}

local function remove(p)
	local d = Data[p]
	if d then
		pcall(function() if d.folder then d.folder:Destroy() end end)
		Data[p] = nil
	end
end

local function create(p, char)
	remove(p)
	local root = getRoot(char)
	if not root then return end

	local folder = make("Folder", {Name = tostring(p.UserId)}, ESPFolder)

	local hl = make("Highlight", {
		Adornee = char,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		FillTransparency = 0.6,
		OutlineTransparency = 0,
		FillColor = ACCENT,
		OutlineColor = ACCENT,
	}, folder)

	local bill = make("BillboardGui", {
		Adornee = root,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(200, 42),
		StudsOffset = Vector3.new(0, 3.2, 0),
		MaxDistance = ESP_DIST,
	}, folder)

	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextStrokeTransparency = 0.25,
		TextColor3 = Color3.new(1, 1, 1),
		Text = p.DisplayName,
	}, bill)

	Data[p] = {folder = folder, hl = hl, bill = bill, label = label, char = char}
end

local function update(p)
	if p == LP then return end
	local d = Data[p]
	if not d then return end

	local char = p.Character
	local root = getRoot(char)
	local own = getRoot(LP.Character)
	local hum = getHum(char)

	if not char or not root or not own or not hum or hum.Health <= 0 or d.char ~= char then
		remove(p)
		return
	end

	if not d.hl or not d.hl.Parent then
		create(p, char)
		return
	end

	local dist = (own.Position - root.Position).Magnitude
	local ok = S.ESP and dist <= ESP_DIST and (not S.TeamCheck or not sameTeam(p))

	local visible = true
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {LP.Character, char}
	local hit = Workspace:Raycast(own.Position, root.Position - own.Position, params)
	if hit then visible = false end

	local col = visible and ACCENT or Color3.fromRGB(255, 90, 100)

	d.hl.Enabled = ok
	d.hl.FillColor = col
	d.hl.OutlineColor = col
	d.bill.Enabled = ok
	d.label.Text = string.format("%s\n%d HP  •  %dm", p.DisplayName, math.floor(hum.Health), math.floor(dist))
end

local function track(p)
	if p == LP then return end
	local function onChar(char)
		task.defer(function()
			task.wait(0.25)
			if p.Character == char and isAlive(p) then
				create(p, char)
			end
		end)
		local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 3)
		if hum then
			hum.Died:Connect(function() remove(p) end)
		end
	end
	p.CharacterAdded:Connect(onChar)
	if p.Character then onChar(p.Character) end
end

for _, p in ipairs(Players:GetPlayers()) do track(p) end
Players.PlayerAdded:Connect(track)
Players.PlayerRemoving:Connect(remove)

-- ====================== AIMBOT + AUTO SHOOT ======================
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
	local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	local own = getRoot(LP.Character)
	if not own then return nil end

	for _, p in ipairs(Players:GetPlayers()) do
		if p == LP or not p.Character or not isAlive(p) then continue end
		if S.TeamCheck and sameTeam(p) then continue end

		local head = p.Character:FindFirstChild("Head")
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
	if now - lastShoot < AUTO_SHOOT_DELAY then return end
	lastShoot = now

	pcall(function()
		if mouse1click then
			mouse1click()
		elseif VirtualInputManager then
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			task.wait(0.03)
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end
	end)

	pcall(function()
		local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
		if tool then tool:Activate() end
	end)
end

-- ====================== GUI ======================
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
stroke(ToggleBtn, ACCENT, 0.5)

local Window = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(520, 360),
	BackgroundColor3 = BG,
	Visible = true,
}, Gui)
corner(Window, 14)
stroke(Window, Color3.fromRGB(60, 40, 55), 0.5)

local Sidebar = make("Frame", {
	Size = UDim2.new(0, 140, 1, 0),
	BackgroundColor3 = SIDE,
}, Window)
corner(Sidebar, 14)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 16),
	Size = UDim2.new(1, -24, 0, 28),
	Text = "Ember's",
	TextColor3 = ACCENT,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Sidebar)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 42),
	Size = UDim2.new(1, -24, 0, 16),
	Text = "Cheats",
	TextColor3 = MUTED,
	TextSize = 12,
	Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Sidebar)

make("Frame", {
	Position = UDim2.fromOffset(12, 68),
	Size = UDim2.new(1, -24, 0, 1),
	BackgroundColor3 = Color3.fromRGB(55, 40, 50),
	BorderSizePixel = 0,
}, Sidebar)

local Main = make("Frame", {
	Position = UDim2.new(0, 140, 0, 0),
	Size = UDim2.new(1, -140, 1, 0),
	BackgroundTransparency = 1,
}, Window)

local Header = make("Frame", {
	Size = UDim2.new(1, 0, 0, 50),
	BackgroundTransparency = 1,
}, Main)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(20, 14),
	Size = UDim2.new(1, -60, 0, 24),
	Text = "Combat",
	TextColor3 = TEXT,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Header)

local CloseBtn = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(32, 32),
	BackgroundTransparency = 1,
	Text = "✕",
	TextColor3 = MUTED,
	TextSize = 16,
}, Header)

local Content = make("ScrollingFrame", {
	Position = UDim2.fromOffset(16, 54),
	Size = UDim2.new(1, -32, 1, -70),
	BackgroundTransparency = 1,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = ACCENT,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, Main)

make("UIListLayout", {
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, Content)

local function createToggle(name, desc, default)
	local card = make("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = CARD,
	}, Content)
	corner(card, 10)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -80, 0, 20),
		Text = name,
		TextColor3 = TEXT,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 30),
		Size = UDim2.new(1, -80, 0, 16),
		Text = desc,
		TextColor3 = MUTED,
		TextSize = 11,
		Font = Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	local switch = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(44, 26),
		BackgroundColor3 = default and ACCENT or Color3.fromRGB(55, 45, 60),
	}, card)
	corner(switch, 13)

	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = default and UDim2.new(1, -24, 0.5, 0) or UDim2.fromOffset(2, 0.5),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, switch)
	corner(knob, 11)

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
	local pos = v and UDim2.new(1, -24, 0.5, 0) or UDim2.fromOffset(2, 0.5)
	TweenService:Create(t.switch, TweenInfo.new(0.15), {BackgroundColor3 = col}):Play()
	TweenService:Create(t.knob, TweenInfo.new(0.15), {Position = pos}):Play()
end

local tAim   = createToggle("Aimbot Hard Lock", "Trava a mira na cabeça do inimigo", false)
local tESP   = createToggle("ESP", "Mostra jogadores através das paredes", true)
local tTeam  = createToggle("Team Check", "Ignora jogadores do mesmo time", true)
local tRun   = createToggle("Auto Run", "Anda automaticamente (+5% speed)", false)
local tShoot = createToggle("Auto Shoot", "Atira sozinho quando tem alvo válido", true)

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
RunService.RenderStepped:Connect(function()
	if S.ESP then
		for p in pairs(Data) do
			pcall(update, p)
		end
	end

	if S.Aim then
		local target = getTarget()
		if target then
			Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
			if S.AutoShoot then
				doShoot()
			end
		end
	end

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

print("✅ Ember's Cheats (Rosa) carregado")
