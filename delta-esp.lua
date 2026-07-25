--[[
    Ember's Cheats — Versão Corrigida
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
local FOV = 110
local AIM_DIST = 900
local ESP_DIST = 1500
local SPEED_BOOST = 1.05

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
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function corner(o, r)
	return make("UICorner", {CornerRadius = UDim.new(0, r)}, o)
end

local function stroke(o, c, t)
	return make("UIStroke", {Color = c, Transparency = t or 0.35, Thickness = 1.2}, o)
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
		pcall(function()
			if d.folder then d.folder:Destroy() end
		end)
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
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, -- atravessa parede
		FillTransparency = 0.65,
		OutlineTransparency = 0.05,
		FillColor = Color3.fromRGB(70, 210, 255),
		OutlineColor = Color3.fromRGB(70, 210, 255),
	}, folder)

	local bill = make("BillboardGui", {
		Adornee = root,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(180, 36),
		StudsOffset = Vector3.new(0, 3.1, 0),
		MaxDistance = ESP_DIST,
	}, folder)

	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextStrokeTransparency = 0.3,
		TextColor3 = Color3.new(1, 1, 1),
		Text = p.DisplayName,
	}, bill)

	Data[p] = {
		folder = folder,
		hl = hl,
		bill = bill,
		label = label,
		char = char,
	}
end

local function update(p)
	if p == LP then return end
	local d = Data[p]
	if not d then return end

	local char = p.Character
	local root = getRoot(char)
	local own = getRoot(LP.Character)
	local hum = getHum(char)

	-- Se o personagem mudou ou morreu, limpa
	if not char or not root or not own or not hum or hum.Health <= 0 or d.char ~= char then
		remove(p)
		return
	end

	-- Se o Highlight sumiu (jogo apagou), recria
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

	local col = visible and Color3.fromRGB(70, 210, 255) or Color3.fromRGB(255, 85, 100)

	d.hl.Enabled = ok
	d.hl.FillColor = col
	d.hl.OutlineColor = col
	d.bill.Enabled = ok
	d.label.Text = string.format("%s  •  %dm", p.DisplayName, math.floor(dist))
end

local function track(p)
	if p == LP then return end

	local function onChar(char)
		task.defer(function()
			task.wait(0.3)
			if p.Character == char and isAlive(p) then
				create(p, char)
			end
		end)

		local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 3)
		if hum then
			hum.Died:Connect(function()
				remove(p)
			end)
		end
	end

	p.CharacterAdded:Connect(onChar)
	if p.Character then
		onChar(p.Character)
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	track(p)
end
Players.PlayerAdded:Connect(track)
Players.PlayerRemoving:Connect(remove)

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

-- ====================== GUI ======================
local Gui = make("ScreenGui", {
	Name = "EmbersCheats",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 60,
}, PlayerGui)

local Toggle = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(74, 46),
	BackgroundColor3 = Color3.fromRGB(16, 20, 30),
	Text = "Ember",
	TextColor3 = Color3.fromRGB(70, 210, 255),
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
}, Gui)
corner(Toggle, 13)
stroke(Toggle, Color3.fromRGB(70, 210, 255))

local Panel = make("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 70),
	Size = UDim2.fromOffset(250, 270),
	BackgroundColor3 = Color3.fromRGB(12, 15, 24),
	Visible = true,
}, Gui)
corner(Panel, 15)
stroke(Panel, Color3.fromRGB(45, 55, 75))

local Header = make("Frame", {
	Size = UDim2.new(1, 0, 0, 48),
	BackgroundColor3 = Color3.fromRGB(18, 23, 35),
}, Panel)
corner(Header, 15)

make("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(14, 13),
	Size = UDim2.new(1, -50, 0, 22),
	Text = "Ember's Cheats",
	TextColor3 = Color3.fromRGB(240, 245, 255),
	TextSize = 15,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, Header)

local Close = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -6, 0.5, 0),
	Size = UDim2.fromOffset(36, 36),
	BackgroundTransparency = 1,
	Text = "✕",
	TextColor3 = Color3.fromRGB(140, 150, 170),
	TextSize = 17,
}, Header)

local Content = make("Frame", {
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 58),
	Size = UDim2.new(1, -24, 1, -70),
}, Panel)
make("UIListLayout", {Padding = UDim.new(0, 9)}, Content)

local function makeToggle(name, default)
	local f = make("Frame", {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = Color3.fromRGB(22, 28, 42),
	}, Content)
	corner(f, 11)

	make("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -70, 1, 0),
		Text = name,
		TextColor3 = Color3.fromRGB(230, 235, 245),
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, f)

	local sw = make("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(42, 24),
		BackgroundColor3 = default and Color3.fromRGB(70, 210, 255) or Color3.fromRGB(50, 58, 75),
	}, f)
	corner(sw, 12)

	local knob = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = default and UDim2.new(1, -22, 0.5, 0) or UDim2.fromOffset(2, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, sw)
	corner(knob, 10)

	local btn = make("TextButton", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = "",
	}, f)

	return {btn = btn, sw = sw, knob = knob, on = default}
end

local function setT(t, v)
	t.on = v
	local col = v and Color3.fromRGB(70, 210, 255) or Color3.fromRGB(50, 58, 75)
	local pos = v and UDim2.new(1, -22, 0.5, 0) or UDim2.fromOffset(2, 0.5)
	TweenService:Create(t.sw, TweenInfo.new(0.14), {BackgroundColor3 = col}):Play()
	TweenService:Create(t.knob, TweenInfo.new(0.14), {Position = pos}):Play()
end

local tAim  = makeToggle("Aimbot Hard Lock", false)
local tESP  = makeToggle("ESP", true)
local tTeam = makeToggle("Ignorar Time", true)
local tRun  = makeToggle("Auto Run (+5%)", false)

-- ====================== CONNECTIONS ======================
tAim.btn.MouseButton1Click:Connect(function()
	S.Aim = not S.Aim
	setT(tAim, S.Aim)
end)
tESP.btn.MouseButton1Click:Connect(function()
	S.ESP = not S.ESP
	setT(tESP, S.ESP)
end)
tTeam.btn.MouseButton1Click:Connect(function()
	S.TeamCheck = not S.TeamCheck
	setT(tTeam, S.TeamCheck)
end)
tRun.btn.MouseButton1Click:Connect(function()
	S.AutoRun = not S.AutoRun
	setT(tRun, S.AutoRun)
	applySpeed()
end)

Toggle.MouseButton1Click:Connect(function()
	S.Panel = not S.Panel
	Panel.Visible = S.Panel
end)
Close.MouseButton1Click:Connect(function()
	S.Panel = false
	Panel.Visible = false
end)

do
	local drag, start, pos
	Header.InputBegan:Connect(function(i)
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
RunService.RenderStepped:Connect(function()
	-- ESP (tempo real, só nos que já existem)
	if S.ESP then
		for p in pairs(Data) do
			pcall(update, p)
		end
	end

	-- AIMBOT HARD LOCK (prioridade máxima)
	if S.Aim then
		local target = getTarget()
		if target then
			-- Força a câmera direto (sem smooth)
			Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
		end
	end

	-- AUTO RUN (só move o personagem, NÃO mexe na câmera)
	if S.AutoRun then
		local hum = getHum(LP.Character)
		if hum then
			applySpeed()
			local look = Camera.CFrame.LookVector
			local dir = Vector3.new(look.X, 0, look.Z)
			if dir.Magnitude > 0.05 then
				hum:Move(dir.Unit, false) -- false = mundo, não relativo à câmera de forma que gire ela
			end
		end
	end
end)

print("✅ Ember's Cheats carregado")
