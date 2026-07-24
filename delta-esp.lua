--[[
    CH DEBUG OVERLAY — LocalScript para o seu próprio jogo.

    Coloque em:
    StarterPlayer > StarterPlayerScripts

    Trava de segurança:
    - No Studio, o painel fica disponível para testes.
    - Em jogo publicado, o PlaceId precisa estar na lista abaixo E o
      jogador precisa ter o atributo "CanUseCHDebug" definido como true
      pelo seu próprio sistema de administração.

    Exemplo no servidor, para um moderador autorizado:
        player:SetAttribute("CanUseCHDebug", true)

    Um LocalScript não consegue oferecer autorização realmente inviolável;
    a permissão publicada deve ser concedida pelo servidor.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Trava de segurança /

-- Troque pelos PlaceIds das suas próprias experiências.
local ALLOWED_PLACE_IDS = {
    [0] = true, -- 0 mantém o script bloqueado até você configurar seu PlaceId.
}

local function isAuthorized(): boolean
    if RunService:IsStudio() then
        return true
    end

    return ALLOWED_PLACE_IDS[game.PlaceId] == true
        and localPlayer:GetAttribute("CanUseCHDebug") == true
end

if not isAuthorized() then
    warn("CH Debug Overlay bloqueado: experiência ou jogador não autorizado.")
    return
end

-- Trava de segurança \

local function make<T>(className: string, properties: {[string]: any}, parent: Instance?): T
    local object = Instance.new(className)

    for property, value in properties do
        object[property] = value
    end

    object.Parent = parent
    return object :: any
end

local MIN_DISTANCE = 50
local MAX_DISTANCE = 1000
local UPDATE_INTERVAL = 0.12
local ESP_FOLDER_NAME = "CH_DebugOverlay"
local GUI_NAME = "CH_DebugInterface"

local theme = {
    Dark = {
        panel = Color3.fromRGB(14, 18, 27),
        panelAlt = Color3.fromRGB(22, 29, 42),
        surface = Color3.fromRGB(28, 37, 54),
        text = Color3.fromRGB(239, 246, 255),
        muted = Color3.fromRGB(151, 171, 194),
        border = Color3.fromRGB(65, 89, 117),
        accent = Color3.fromRGB(77, 220, 224),
    },
    Light = {
        panel = Color3.fromRGB(245, 248, 252),
        panelAlt = Color3.fromRGB(225, 234, 244),
        surface = Color3.fromRGB(211, 224, 238),
        text = Color3.fromRGB(19, 31, 47),
        muted = Color3.fromRGB(78, 101, 126),
        border = Color3.fromRGB(160, 182, 204),
        accent = Color3.fromRGB(0, 151, 164),
    },
}

local subColors = {
    Ciano = Color3.fromRGB(74, 226, 226),
    Vermelho = Color3.fromRGB(255, 83, 104),
    Rosa = Color3.fromRGB(255, 117, 190),
}

local fontOptions = {
    ["Padrão"] = Enum.Font.Gotham,
    ["ᥴᥙ𝗍ᥱ"] = Enum.Font.Cartoon,
}

local state = {
    enabled = true,
    teamCheck = false,
    theme = "Dark",
    subColor = "Ciano",
    font = "Padrão",
    maxDistance = 1000,
}

local espFolder = make("Folder", {
    Name = ESP_FOLDER_NAME,
}, playerGui) :: Folder

local function corner(object: Instance, radius: number)
    make("UICorner", { CornerRadius = UDim.new(0, radius) }, object)
end

local function stroke(object: Instance, color: Color3, transparency: number?)
    make("UIStroke", {
        Color = color,
        Transparency = transparency or 0,
        Thickness = 1,
    }, object)
end

local function isSameTeam(player: Player): boolean
    return localPlayer.Team ~= nil and player.Team == localPlayer.Team
end

local function passesTeamCheck(player: Player): boolean
    return not state.teamCheck or not isSameTeam(player)
end

local function getAccent(): Color3
    return subColors[state.subColor]
end

local function getESPFolder(player: Player): Folder?
    local folder = espFolder:FindFirstChild(tostring(player.UserId))
    return folder :: Folder?
end

local function removeESP(player: Player)
    local folder = getESPFolder(player)
    if folder then
        folder:Destroy()
    end
end

local function createESP(player: Player, character: Model)
    removeESP(player)

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root or not root:IsA("BasePart") then
        root = character:WaitForChild("HumanoidRootPart", 5)
    end
    if not root or not root:IsA("BasePart") then
        return
    end

    local folder = make("Folder", {
        Name = tostring(player.UserId),
    }, espFolder) :: Folder

    local highlight = make("Highlight", {
        Name = "Highlight",
        Adornee = character,
        DepthMode = Enum.HighlightDepthMode.Occluded,
        FillTransparency = 0.78,
        OutlineTransparency = 0.05,
    }, folder) :: Highlight

    local billboard = make("BillboardGui", {
        Name = "Billboard",
        Adornee = root,
        AlwaysOnTop = false,
        MaxDistance = MAX_DISTANCE,
        Size = UDim2.fromOffset(220, 48),
        StudsOffset = Vector3.new(0, 3.25, 0),
    }, folder) :: BillboardGui

    local label = make("TextLabel", {
        Name = "Label",
        BackgroundTransparency = 1,
        Font = fontOptions[state.font],
        Size = UDim2.fromScale(1, 1),
        Text = player.DisplayName,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 14,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        TextStrokeTransparency = 0.3,
    }, billboard) :: TextLabel

    corner(label, 8)
end

local function updateESP(player: Player)
    if player == localPlayer or not player.Character then
        return
    end

    local folder = getESPFolder(player)
    if not folder then
        return
    end

    local highlight = folder:FindFirstChild("Highlight") :: Highlight?
    local billboard = folder:FindFirstChild("Billboard") :: BillboardGui?
    local label = billboard and billboard:FindFirstChild("Label") :: TextLabel?
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    local ownRoot = localPlayer.Character
        and localPlayer.Character:FindFirstChild("HumanoidRootPart")

    if not highlight or not billboard or not label
        or not root or not root:IsA("BasePart")
        or not ownRoot or not ownRoot:IsA("BasePart") then
        return
    end

    local distance = (ownRoot.Position - root.Position).Magnitude
    local withinRange = distance >= MIN_DISTANCE and distance <= state.maxDistance
    local visible = true

    -- Raycast respeita paredes e outros objetos sólidos do mapa.
    local direction = root.Position - ownRoot.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {
        localPlayer.Character,
        player.Character,
    }
    rayParams.IgnoreWater = true

    local hit = workspace:Raycast(ownRoot.Position, direction, rayParams)
    if hit then
        visible = false
    end

    local enabled = state.enabled and withinRange and passesTeamCheck(player)
    local statusColor = visible and Color3.fromRGB(255, 220, 72)
        or Color3.fromRGB(255, 72, 72)

    highlight.Enabled = enabled
    highlight.FillColor = statusColor
    highlight.OutlineColor = statusColor
    label.Font = fontOptions[state.font]
    label.TextColor3 = state.theme == "Light" and Color3.fromRGB(20, 25, 32) or Color3.new(1, 1, 1)
    label.Text = string.format("%s  •  %dm", player.DisplayName, math.floor(distance))
    billboard.Enabled = enabled
end

local function setupPlayer(player: Player)
    local function characterAdded(character: Model)
        task.defer(function()
            createESP(player, character)
            updateESP(player)
        end)
    end

    player.CharacterAdded:Connect(characterAdded)
    player:GetPropertyChangedSignal("Team"):Connect(function()
        updateESP(player)
    end)

    if player.Character then
        characterAdded(player.Character)
    end
end

for _, player in Players:GetPlayers() do
    setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(removeESP)

-- Interface ---------------------------------------------------------------

local gui = make("ScreenGui", {
    Name = GUI_NAME,
    DisplayOrder = 50,
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui

local toggleButton = make("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    AutoButtonColor = false,
    BackgroundColor3 = theme[state.theme].panel,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -18, 0, 18),
    Size = UDim2.fromOffset(58, 44),
    Text = "CH",
    TextColor3 = getAccent(),
    TextSize = 15,
    Font = Enum.Font.GothamBold,
}, gui) :: TextButton
corner(toggleButton, 13)
stroke(toggleButton, getAccent(), 0.15)

local panel = make("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    BackgroundColor3 = theme[state.theme].panel,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -18, 0, 72),
    Size = UDim2.fromOffset(280, 416),
}, gui) :: Frame
corner(panel, 16)
stroke(panel, theme[state.theme].border, 0.15)

local topBar = make("TextButton", {
    AutoButtonColor = false,
    BackgroundColor3 = theme[state.theme].panelAlt,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 64),
    Text = "",
}, panel) :: TextButton
corner(topBar, 16)

local title = make("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Position = UDim2.fromOffset(17, 10),
    Size = UDim2.new(1, -72, 0, 22),
    Text = "CH  /  PLAYER VIEW",
    TextColor3 = theme[state.theme].text,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, topBar) :: TextLabel

local subtitle = make("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Position = UDim2.fromOffset(17, 34),
    Size = UDim2.new(1, -72, 0, 16),
    Text = "Toque e arraste para mover",
    TextColor3 = theme[state.theme].muted,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, topBar) :: TextLabel

local closeButton = make("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -13, 0.5, 0),
    Size = UDim2.fromOffset(30, 30),
    Text = "×",
    TextColor3 = theme[state.theme].muted,
    TextSize = 25,
    Font = Enum.Font.Gotham,
}, topBar) :: TextButton

local content = make("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(15, 78),
    Size = UDim2.new(1, -30, 1, -92),
}, panel) :: Frame

make("UIListLayout", {
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, content)

local function optionButton(): TextButton
    local button = make("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = theme[state.theme].surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 40),
        TextColor3 = theme[state.theme].text,
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
    }, content) :: TextButton
    corner(button, 10)
    stroke(button, theme[state.theme].border, 0.55)
    return button
end

local espButton = optionButton()
local teamButton = optionButton()
local distanceButton = optionButton()
local themeButton = optionButton()
local subColorButton = optionButton()
local fontButton = optionButton()

local rangeButton = optionButton()

local hint = make("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Size = UDim2.new(1, 0, 0, 30),
    Text = "Vermelho = atrás da parede   •   Amarelo = visível",
    TextColor3 = theme[state.theme].muted,
    TextSize = 10,
    TextWrapped = true,
}, content) :: TextLabel

local function applyTheme()
    local current = theme[state.theme]
    panel.BackgroundColor3 = current.panel
    topBar.BackgroundColor3 = current.panelAlt
    toggleButton.BackgroundColor3 = current.panel
    toggleButton.TextColor3 = getAccent()
    title.TextColor3 = current.text
    subtitle.TextColor3 = current.muted
    closeButton.TextColor3 = current.muted
    hint.TextColor3 = current.muted
    stroke(toggleButton, getAccent(), 0.15)

    for _, child in content:GetChildren() do
        if child:IsA("TextButton") then
            child.BackgroundColor3 = current.surface
            child.TextColor3 = current.text
        end
    end
end

local function refreshUI()
    espButton.Text = state.enabled and "ESP  •  ligado" or "ESP  •  desligado"
    teamButton.Text = state.teamCheck and "Team Check  •  ligado" or "Team Check  •  desligado"
    distanceButton.Text = string.format("Distância  •  %dm–%dm", MIN_DISTANCE, state.maxDistance)
    themeButton.Text = "Tema  •  " .. state.theme
    subColorButton.Text = "Sub cor  •  " .. state.subColor
    fontButton.Text = "Fonte  •  " .. state.font
    rangeButton.Text = "Toque aqui para aumentar o alcance"
    applyTheme()
end

local function refreshAll()
    for _, player in Players:GetPlayers() do
        updateESP(player)
    end
end

espButton.Activated:Connect(function()
    state.enabled = not state.enabled
    refreshUI()
    refreshAll()
end)

teamButton.Activated:Connect(function()
    state.teamCheck = not state.teamCheck
    refreshUI()
    refreshAll()
end)

distanceButton.Activated:Connect(function()
    if state.maxDistance >= MAX_DISTANCE then
        state.maxDistance = 100
    else
        state.maxDistance += 100
    end
    refreshUI()
    refreshAll()
end)

themeButton.Activated:Connect(function()
    state.theme = state.theme == "Dark" and "Light" or "Dark"
    refreshUI()
end)

subColorButton.Activated:Connect(function()
    if state.subColor == "Ciano" then
        state.subColor = "Vermelho"
    elseif state.subColor == "Vermelho" then
        state.subColor = "Rosa"
    else
        state.subColor = "Ciano"
    end
    refreshUI()
end)

fontButton.Activated:Connect(function()
    state.font = state.font == "Padrão" and "ᥴᥙ𝗍ᥱ" or "Padrão"
    refreshUI()
    refreshAll()
end)

rangeButton.Activated:Connect(function()
    state.maxDistance = state.maxDistance >= MAX_DISTANCE and 50 or math.min(state.maxDistance + 50, MAX_DISTANCE)
    refreshUI()
    refreshAll()
end)

local function setPanelVisible(visible: boolean)
    panel.Visible = visible
end

toggleButton.Activated:Connect(function()
    setPanelVisible(not panel.Visible)
end)

closeButton.Activated:Connect(function()
    setPanelVisible(false)
end)

-- Arraste pela barra superior: mouse e toque.
local dragging = false
local dragStart: Vector2
local panelStart: UDim2

topBar.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    dragging = true
    dragStart = input.Position
    panelStart = panel.Position

    input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            dragging = false
        end
    end)
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        panel.Position = UDim2.new(
            panelStart.X.Scale,
            panelStart.X.Offset + delta.X,
            panelStart.Y.Scale,
            panelStart.Y.Offset + delta.Y
        )
    end
end)

refreshUI()

local elapsed = 0
RunService.Heartbeat:Connect(function(deltaTime)
    elapsed += deltaTime
    if elapsed < UPDATE_INTERVAL then
        return
    end

    elapsed = 0
    for _, player in Players:GetPlayers() do
        updateESP(player)
    end
end)
