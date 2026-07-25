--[[
    Ember's Cheats — Clean Version
    Mobile-First | Hard Lock Aimbot + ESP + Auto Run
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
local FOV_RADIUS = 90          -- FOV do aimbot em pixels (aprox 90°)
local AIM_MAX_DIST = 800
local ESP_MAX_DIST = 1200
local AUTO_RUN_BOOST = 1.05    -- +5%

-- ====================== STATE ======================
local S = {
	Aim = false,
	ESP = true,
	TeamCheck = true,
	AutoRun = false,
	Panel = true,
}

-- ====================== UTILS ======================
local function make(class, props, parent)
	local obj = Instance.new(class)
	for k, v in pairs(props) do
		obj[k] = v
	end
	if parent then obj.Parent = parent end
	return obj
end

local function corner(obj, r)
	return make("UICorner", {CornerRadius = UDim.new(0, r)}, obj)
end

local function stroke(obj, color, transparency)
	return make("UIStroke", {
		Color = color,
		Transparency = transparency or 0.3,
		Thickness = 1.2,
	}, obj)
end

local function getRoot(char)
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHum(char)
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function isAlive(player)
	local hum = getHum(player.Character)
	return hum and hum.Health > 0
end

local function sameTeam(player)
	return LP.Team and player.Team == LP.Team
end

-- ====================== CHARACTER ======================
local function applySpeed()
	local hum = getHum(LP.Character)
	if not hum then return end
	local base = 16
	hum.WalkSpeed = S.AutoRun and (base * AUTO_RUN_BOOST) or base
end

LP.CharacterAdded:Connect(function()
	task.wait(0.3)
	applySpeed()
end)

-- ====================== ESP ======================
local ESPFolder = make("Folder", {Name = "EmberESP"}, Workspace)
local ESPData = {}

local function clearESP(player)
	local data = ESPData[player]
	if data then
		if data.folder then data.folder:Destroy() end
		ESPData[player] = nil
	end
end

local function createESP(player, character)
	clearESP(player)

	local root = getRoot(character)
	if not root then return end

	local folder = make("Folder", {Name = tostring(player.UserId)}, ESPFolder)

	local highlight = make("Highlight", {
		Adornee = character,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		FillTransparency = 0.72,
		OutlineTransparency = 0.15,
		FillColor = Color3.fromRGB(80, 220, 255),
		OutlineColor = Color3.fromRGB(80, 220, 255),
	}, folder)

	local billboard = make("BillboardGui", {
		Adornee = root,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(200, 40),
		StudsOffset = Vector3.new(0, 3.2, 0),
		MaxDistance = ESP_MAX_DIST,
	}, folder)

	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextStrokeTransparency = 0.4,
		TextColor3 = Color3.new(1, 1, 1),
		Text = player.DisplayName,
	}, billboard)

	ESPData[player] = {
		folder = folder,
		highlight = highlight,
		billboard = billboard,
		label = label,
	}
end

local function updateESP(player)
	if player == LP then return end
	local data = ESPData[player]
	if not data or not player.Character then return end

	local root = getRoot(player.Character)
	local ownRoot = getRoot(LP.Character)
	local hum = getHum(player.Character)

	if not root or not ownRoot or not hum or hum.Health <= 0 then
		clearESP(player)
		return
	end

	local dist = (ownRoot.Position - root.Position).Magnitude
	local within = dist <= ESP_MAX_DIST
	local teamOk = not S.TeamCheck or not sameTeam(player)
	local enabled = S.ESP and within and teamOk

	-- Visibility check
	local visible = true
	if within then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {LP.Character, player.Character}
		local hit = Workspace:Raycast(ownRoot.Position, root.Position - ownRoot.Position, params)
		if hit then visible = false end
	end

	local color = visible and Color3.fromRGB(80, 220, 255) or Color3.fromRGB(255, 90, 110)

	data.highlight.Enabled = enabled
	data.highlight.FillColor = color
	data.highlight.OutlineColor = color
	data.billboard.Enabled = enabled

	data.label.Text = string.format("%s  •  %dm", player.DisplayName, math.floor(dist))
end

local function setupPlayer(player)
	if player == LP then return end

	local function onCharacter(char)
		task.defer(function()
			local hum = getHum(char)
			if hum then
				hum.Died:Connect(function()
					clearESP(player)
				end)
			end
			createESP(player, char)
		end)
	end

	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	setupPlayer(p)
end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(clearESP)

-- ====================== AIMBOT (HARD LOCK) ======================
local currentTarget = nil

local function isVisibleToCamera(part)
	local ownRoot = getRoot(LP.Character)
	if not ownRoot then return false end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {LP.Character}
	local hit = Workspace:Raycast(ownRoot.Position, part.Position - ownRoot.Position, params)

	if hit and not hit.Instance:IsDescendantOf(part.Parent) then
		return false
	end
	return true
end

local function findBestTarget()
	local best = nil
	local bestDist = math.huge
	local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	local ownRoot = getRoot(LP.Character)
	if not ownRoot then return nil end

	for _, player in ipairs(Players:GetPlayers()) do
		if player == LP then continue end
		if not player.Character or not isAlive(player) then continue end
		if S.TeamCheck and sameTeam(player) then continue end

		local head = player.Character:FindFirstChild("Head")
		if not head then continue end

		local dist3d = (ownRoot.Position - head.Position).Magnitude
		if dist3d > AIM_MAX_DIST then continue end

		local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
		if not onScreen then continue end

		local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
		if screenDist > FOV_RADIUS then continue end

		if not isVisibleToCamera(head) then continue end

		if screenDist < bestDist then
			bestDist = screenDist
			best = player
		end
	end

	return best
end

-- ====================== GUI ======================
local Gui = make("ScreenGui", {
	Name = "EmbersCheats",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 50,
}, PlayerGui)

-- Botão principal
local ToggleBtn = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.fromOffset(72, 48),
	BackgroundColor3 = Color3.fromRGB(18, 22, 32),
	Text = "Ember",
	TextColor3 = Color3.fromRGB(80, 220, 255),
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
}, Gui)
corner(ToggleBtn, 14)
stroke(ToggleBtn, Color3.fromRGB(80, 220, 255), 0.4)

-- Painel
local Panel = make("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 74),
	Size = UDim2.fromOffset(260, 280),
	BackgroundColor3 = Color3.fromRGB(14, 17, 26),
	Visible = true,
}, Gui)
corner(Panel, 16)
stroke(Panel, Color3.fromRGB(50, 60, 80), 0.4)

-- Header
local Header = make("Frame", {
	Size = UDim2.new(1, 0, 0, 50),
	BackgroundColor3 = Color3.fromRGB(20, 25, 38),
}, Panel)
corner(Header, 16)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(16, 14),
	Size = UDim2.new(1, -50, 0, 22),
	Text = "Ember's Cheats",
	TextColor3 = Color3.fromRGB(240, 245, 255),
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Header)

local CloseBtn = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -8, 0.5, 0),
	Size = UDim2.fromOffset(36, 36),
	BackgroundTransparency = 1,
	Text = "✕",
	TextColor3 = Color3.fromRGB(150, 160, 180),
	TextSize = 18,
}, Header)

-- Conteúdo
local Content = make("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 60),
	Size = UDim2.new(1, -28, 1, -74),
}, Panel)

make("UIListLayout", {
	Padding = UDim.new(0, 10),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, Content)

local function createToggle(text, default)
	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = Color3.fromRGB(24, 30, 44),
	}, Content)
	corner(frame, 12)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -70, 1, 0),
		Text = text,
		TextColor3 = Color3.fromRGB(235, 240, 250),
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, frame)

	local switch = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(44, 26),
		BackgroundColor3 = default and Color3.fromRGB(80, 220, 255) or Color3.fromRGB(55, 65, 85),
	}, frame)
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
	}, frame)

	return {
		btn = btn,
		switch = switch,
		knob = knob,
		value = default,
	}
end

local tAim = createToggle("Aimbot Hard Lock", false)
local tESP = createToggle("ESP", true)
local tTeam = createToggle("Ignorar Time", true)
local tRun = createToggle("Auto Run (+5%)", false)

local function setToggle(t, value)
	t.value = value
	local color = value and Color3.fromRGB(80, 220, 255) or Color3.fromRGB(55, 65, 85)
	local pos = value and UDim2.new(1, -24, 0.5, 0) or UDim2.fromOffset(2, 0.5)

	TweenService:Create(t.switch, TweenInfo.new(0.15), {BackgroundColor3 = color}):Play()
	TweenService:Create(t.knob, TweenInfo.new(0.15), {Position = pos}):Play()
end

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

ToggleBtn.MouseButton1Click:Connect(function()
	S.Panel = not S.Panel
	Panel.Visible = S.Panel
end)

CloseBtn.MouseButton1Click:Connect(function()
	S.Panel = false
	Panel.Visible = false
end)

-- Arrastar painel
do
	local dragging, startPos, panelPos
	Header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			startPos = input.Position
			panelPos = Panel.Position
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - startPos
			Panel.Position = UDim2.new(panelPos.X.Scale, panelPos.X.Offset + delta.X, panelPos.Y.Scale, panelPos.Y.Offset + delta.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)
end

-- ====================== MAIN LOOP ======================
local espTimer = 0

RunService.Heartbeat:Connect(function(dt)
	-- ESP update
	espTimer += dt
	if S.ESP and espTimer >= 0.08 then
		espTimer = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pcall(updateESP, player)
		end
	end

	-- Aimbot Hard Lock
	if S.Aim then
		currentTarget = findBestTarget()
		if currentTarget and currentTarget.Character then
			local head = currentTarget.Character:FindFirstChild("Head")
			if head then
				Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
			end
		end
	end

	-- Auto Run
	if S.AutoRun then
		local hum = getHum(LP.Character)
		if hum then
			hum:Move(Vector3.new(0, 0, -1), true)
		end
	end
end)

print("✅ Ember's Cheats carregado")
