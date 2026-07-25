--[[
    CH DEBUG OVERLAY — LocalScript mobile-first para o seu próprio jogo Roblox.

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

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local HapticService = game:GetService("HapticService")

-- Local player
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local playerMouse = localPlayer:GetMouse()

-- Configuration -----------------------------------------------------------

local CONFIG = {
    MIN_DISTANCE = 0,
    MAX_DISTANCE = 2000,
    UPDATE_INTERVAL = 0.1,
    ESP_FOLDER_NAME = "CH_DebugOverlay",
    GUI_NAME = "CH_DebugInterface",
    FADE_TIME = 0.12,
    AIM_INTERVAL = 0.03,
    AIM_SMOOTH_MIN = 0.05,
    AIM_SMOOTH_MAX = 0.95,
    MOBILE_AIM_BUTTON_SIZE = 76,
    MOBILE_AIM_BUTTON_DEFAULT_X = 24,
    MOBILE_AIM_BUTTON_DEFAULT_Y = -104,
    BUTTON_HEIGHT = 48,
    TAB_HEIGHT = 48,
}

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
    Verde = Color3.fromRGB(83, 255, 134),
    Amarelo = Color3.fromRGB(255, 220, 72),
}

local fontOptions = {
    ["Padrão"] = Enum.Font.Gotham,
    ["Cartoon"] = Enum.Font.Cartoon,
    ["Code"] = Enum.Font.Code,
    ["Titulo"] = Enum.Font.GothamBold,
}

local state = {
    -- ESP
    enabled = true,
    teamCheck = false,
    theme = "Dark",
    subColor = "Ciano",
    font = "Padrão",
    maxDistance = 1000,
    showHealth = true,
    showDistance = true,
    showBoxes = false,
    showSkeleton = false,
    showTracers = false,
    -- Aimbot
    aimEnabled = false,
    aimMode = "Hold", -- "Hold" | "Toggle" | "Auto"
    aimActive = false,
    aimButtonVisible = true,
    aimButtonPosition = "default",
    aimButtonX = CONFIG.MOBILE_AIM_BUTTON_DEFAULT_X,
    aimButtonY = CONFIG.MOBILE_AIM_BUTTON_DEFAULT_Y,
    aimSmooth = 0.25,
    aimTargetPart = "Head",
    aimMaxDistance = 500,
    aimTeamCheck = true,
    aimVisibleOnly = true,
    aimFov = 180,
    -- UI
    panelOpen = true,
    activeTab = "ESP",
}

-- State saved in attributes for persistence across respawns
local function saveState()
    for key, value in pairs(state) do
        localPlayer:SetAttribute("CH_" .. key, value)
    end
end

local function loadState()
    for key in pairs(state) do
        local attr = localPlayer:GetAttribute("CH_" .. key)
        if attr ~= nil then
            local expectedType = typeof(state[key])
            if typeof(attr) == expectedType then
                state[key] = attr
            end
        end
    end
end

loadState()

-- Clamp saved values
state.aimSmooth = math.clamp(state.aimSmooth, CONFIG.AIM_SMOOTH_MIN, CONFIG.AIM_SMOOTH_MAX)
state.aimFov = math.clamp(state.aimFov, 10, 360)
state.aimMaxDistance = math.clamp(state.aimMaxDistance, 50, CONFIG.MAX_DISTANCE)

-- Utility -----------------------------------------------------------------

local function make<T>(className: string, properties: {[string]: any}, parent: Instance?): T
    local object = Instance.new(className)
    for property, value in properties do
        object[property] = value
    end
    object.Parent = parent
    return object :: any
end

local function corner(object: Instance, radius: number)
    return make("UICorner", { CornerRadius = UDim.new(0, radius) }, object)
end

local function stroke(object: Instance, color: Color3, transparency: number?, thickness: number?)
    return make("UIStroke", {
        Color = color,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
    }, object)
end

local function pressFeedback(button: GuiObject)
    local originalSize = button.Size
    local shrink = UDim2.new(
        originalSize.X.Scale,
        originalSize.X.Offset - 4,
        originalSize.Y.Scale,
        originalSize.Y.Offset - 4
    )
    local info = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local shrinkTween = TweenService:Create(button, info, { Size = shrink })
    local growTween = TweenService:Create(button, info, { Size = originalSize })

    shrinkTween:Play()
    shrinkTween.Completed:Connect(function()
        growTween:Play()
    end)
end

local function getAccent(): Color3
    return subColors[state.subColor]
end

local function getCurrentTheme()
    return theme[state.theme]
end

-- ESP logic ---------------------------------------------------------------

local espFolder = make("Folder", {
    Name = CONFIG.ESP_FOLDER_NAME,
}, playerGui) :: Folder

local function isSameTeam(player: Player): boolean
    return localPlayer.Team ~= nil and player.Team == localPlayer.Team
end

local function passesTeamCheck(player: Player): boolean
    return not state.teamCheck or not isSameTeam(player)
end

local function getESPFolder(player: Player): Folder?
    return espFolder:FindFirstChild(tostring(player.UserId)) :: Folder?
end

local function removeESP(player: Player)
    local folder = getESPFolder(player)
    if folder then
        folder:Destroy()
    end
end

local function clearAllESP()
    for _, folder in espFolder:GetChildren() do
        folder:Destroy()
    end
end

local function getCharacterRoot(character: Model): BasePart?
    local root = character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root
    end
    root = character:WaitForChild("HumanoidRootPart", 3)
    if root and root:IsA("BasePart") then
        return root
    end
    return nil
end

local function getHumanoid(character: Model): Humanoid?
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return humanoid
end

local skeletonJoints = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local function createESP(player: Player, character: Model)
    removeESP(player)

    local root = getCharacterRoot(character)
    if not root then
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
        MaxDistance = CONFIG.MAX_DISTANCE,
        Size = UDim2.fromOffset(260, 64),
        StudsOffset = Vector3.new(0, 3.5, 0),
    }, folder) :: BillboardGui

    local label = make("TextLabel", {
        Name = "Label",
        BackgroundTransparency = 1,
        Font = fontOptions[state.font],
        Size = UDim2.fromScale(1, 1),
        Text = player.DisplayName,
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 15,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        TextStrokeTransparency = 0.3,
        TextWrapped = true,
    }, billboard) :: TextLabel

    corner(label, 8)

    local boxAdornee = make("Part", {
        Name = "BoxAdornee",
        Anchored = true,
        CanCollide = false,
        CanQuery = false,
        CanTouch = false,
        CastShadow = false,
        Color = getAccent(),
        Material = Enum.Material.Neon,
        Size = Vector3.new(4, 5, 1),
        Transparency = 1,
    }, Workspace) :: BasePart

    local boxBillboard = make("BillboardGui", {
        Name = "BoxBillboard",
        Adornee = boxAdornee,
        AlwaysOnTop = true,
        MaxDistance = CONFIG.MAX_DISTANCE,
        Size = UDim2.fromOffset(100, 140),
    }, folder) :: BillboardGui

    local boxFrame = make("Frame", {
        Name = "BoxFrame",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
    }, boxBillboard) :: Frame

    local boxOutline = make("Frame", {
        Name = "BoxOutline",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.fromScale(1, 1),
    }, boxFrame) :: Frame

    make("UIStroke", {
        Color = getAccent(),
        Thickness = 1.5,
        Transparency = 0.2,
    }, boxOutline)

    local tracer = make("Frame", {
        Name = "Tracer",
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = getAccent(),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 1, -10),
        Size = UDim2.new(0, 2, 0, 100),
        Visible = false,
    }, gui) :: Frame

    local skeletonFolder = make("Folder", {
        Name = "Skeleton",
    }, folder) :: Folder

    local lines = {}
    for _, pair in skeletonJoints do
        local line = make("Frame", {
            Name = pair[1] .. "-" .. pair[2],
            BackgroundColor3 = getAccent(),
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(2, 2),
            Visible = false,
        }, skeletonFolder) :: Frame
        table.insert(lines, {line = line, a = pair[1], b = pair[2]})
    end

    folder:SetAttribute("BoxAdornee", boxAdornee)
    folder:SetAttribute("Tracer", tracer)
    folder:SetAttribute("Lines", lines)
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
    local skeletonFolder = folder:FindFirstChild("Skeleton") :: Folder?
    local boxAdornee = folder:GetAttribute("BoxAdornee") :: BasePart?
    local tracer = folder:GetAttribute("Tracer") :: Frame?
    local lines = folder:GetAttribute("Lines") :: {{line: Frame, a: string, b: string}}?

    local root = getCharacterRoot(player.Character)
    local ownCharacter = localPlayer.Character
    local ownRoot = ownCharacter and getCharacterRoot(ownCharacter)

    if not highlight or not billboard or not label
        or not root or not ownRoot then
        return
    end

    local humanoid = getHumanoid(player.Character)
    local isAlive = humanoid and humanoid.Health > 0

    local distance = (ownRoot.Position - root.Position).Magnitude
    local withinRange = distance >= CONFIG.MIN_DISTANCE and distance <= state.maxDistance

    local visible = true
    if withinRange then
        local direction = root.Position - ownRoot.Position
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {ownCharacter, player.Character}
        rayParams.IgnoreWater = true
        local hit = Workspace:Raycast(ownRoot.Position, direction, rayParams)
        if hit then
            visible = false
        end
    end

    local enabled = state.enabled and withinRange and passesTeamCheck(player) and isAlive ~= false
    local statusColor = visible and subColors.Amarelo or subColors.Vermelho

    highlight.Enabled = enabled
    highlight.FillColor = statusColor
    highlight.OutlineColor = statusColor

    billboard.Enabled = enabled
    label.Font = fontOptions[state.font]
    label.TextColor3 = state.theme == "Light" and Color3.fromRGB(20, 25, 32) or Color3.new(1, 1, 1)

    local textParts = {}
    table.insert(textParts, player.DisplayName)
    if state.showDistance then
        table.insert(textParts, string.format("%dm", math.floor(distance)))
    end
    if state.showHealth and humanoid then
        table.insert(textParts, string.format("%.0f HP", humanoid.Health))
    end
    label.Text = table.concat(textParts, "  •  ")

    if boxAdornee and enabled then
        boxAdornee.Position = root.Position
        local boxBillboard = boxAdornee:FindFirstChild("BoxBillboard") :: BillboardGui?
        if boxBillboard then
            boxBillboard.Enabled = state.showBoxes
        end
    end

    if tracer then
        tracer.Visible = enabled and state.showTracers
        if tracer.Visible then
            local screenPos, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(root.Position)
            if onScreen then
                local screenCenter = Vector2.new(Workspace.CurrentCamera.ViewportSize.X / 2, Workspace.CurrentCamera.ViewportSize.Y)
                local tracerPos = Vector2.new(screenPos.X, screenPos.Y)
                local delta = tracerPos - screenCenter
                local length = delta.Magnitude
                local angle = math.deg(math.atan2(delta.Y, delta.X)) + 90
                tracer.Size = UDim2.new(0, 2, 0, length)
                tracer.Rotation = angle
                tracer.Position = UDim2.new(0, screenCenter.X, 0, screenCenter.Y)
                tracer.BackgroundColor3 = statusColor
            else
                tracer.Visible = false
            end
        end
    end

    if skeletonFolder and enabled and lines then
        for _, item in skeletonFolder:GetChildren() do
            if item:IsA("Frame") then
                item.Visible = false
            end
        end

        if state.showSkeleton then
            for _, lineData in lines do
                local a = player.Character:FindFirstChild(lineData.a)
                local b = player.Character:FindFirstChild(lineData.b)
                if a and a:IsA("BasePart") and b and b:IsA("BasePart") then
                    local posA, onScreenA = Workspace.CurrentCamera:WorldToViewportPoint(a.Position)
                    local posB, onScreenB = Workspace.CurrentCamera:WorldToViewportPoint(b.Position)
                    if onScreenA and onScreenB then
                        local delta = Vector2.new(posB.X - posA.X, posB.Y - posA.Y)
                        local length = delta.Magnitude
                        local angle = math.deg(math.atan2(delta.Y, delta.X))
                        lineData.line.Size = UDim2.new(0, length, 0, 2)
                        lineData.line.Position = UDim2.new(0, posA.X, 0, posA.Y)
                        lineData.line.Rotation = angle
                        lineData.line.Visible = true
                        lineData.line.BackgroundColor3 = statusColor
                    end
                end
            end
        end
    end
end

local function setupPlayer(player: Player)
    local function characterAdded(character: Model)
        task.defer(function()
            local humanoid = getHumanoid(character)
            if humanoid then
                humanoid.Died:Connect(function()
                    removeESP(player)
                end)
            end
            createESP(player, character)
            updateESP(player)
        end)
    end

    local characterAddedConn = player.CharacterAdded:Connect(characterAdded)
    local teamChangedConn = player:GetPropertyChangedSignal("Team"):Connect(function()
        updateESP(player)
    end)

    player:SetAttribute("CH_CharacterAddedConn", characterAddedConn)
    player:SetAttribute("CH_TeamChangedConn", teamChangedConn)

    if player.Character then
        characterAdded(player.Character)
    end
end

for _, player in Players:GetPlayers() do
    if player ~= localPlayer then
        setupPlayer(player)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= localPlayer then
        setupPlayer(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
    local charConn = player:GetAttribute("CH_CharacterAddedConn")
    local teamConn = player:GetAttribute("CH_TeamChangedConn")
    if charConn and typeof(charConn) == "RBXScriptConnection" then
        charConn:Disconnect()
    end
    if teamConn and typeof(teamConn) == "RBXScriptConnection" then
        teamConn:Disconnect()
    end
end)

-- Aimbot logic ------------------------------------------------------------

local aimbotTarget: Player?
local aimbotTargetPart: BasePart?
local aimButtonHeld = false

local function getAimbotPart(character: Model): BasePart?
    local part = character:FindFirstChild(state.aimTargetPart)
    if part and part:IsA("BasePart") then
        return part
    end
    if state.aimTargetPart == "Torso" then
        local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
        if torso and torso:IsA("BasePart") then
            return torso
        end
    end
    return getCharacterRoot(character)
end

local function isVisible(part: BasePart): boolean
    local ownCharacter = localPlayer.Character
    local ownRoot = ownCharacter and getCharacterRoot(ownCharacter)
    if not ownRoot then
        return false
    end

    local direction = part.Position - ownRoot.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {ownCharacter}
    rayParams.IgnoreWater = true
    local hit = Workspace:Raycast(ownRoot.Position, direction, rayParams)
    if hit and hit.Instance then
        return hit.Instance:IsDescendantOf(part.Parent)
    end
    return true
end

local function getScreenCenter(): Vector2
    local viewport = Workspace.CurrentCamera.ViewportSize
    return Vector2.new(viewport.X / 2, viewport.Y / 2)
end

local function getDistanceFromCenter(part: BasePart): number
    local screenPos, onScreen = Workspace.CurrentCamera:WorldToViewportPoint(part.Position)
    if not onScreen then
        return math.huge
    end
    return (Vector2.new(screenPos.X, screenPos.Y) - getScreenCenter()).Magnitude
end

local function findAimbotTarget(): Player?
    local camera = Workspace.CurrentCamera
    local center = getScreenCenter()
    local fovRadius = state.aimFov
    local bestTarget: Player?
    local bestDistance = math.huge

    local ownCharacter = localPlayer.Character
    local ownRoot = ownCharacter and getCharacterRoot(ownCharacter)
    if not ownRoot then
        return nil
    end

    for _, player in Players:GetPlayers() do
        if player == localPlayer then
            continue
        end

        local character = player.Character
        if not character then
            continue
        end

        local humanoid = getHumanoid(character)
        if not humanoid or humanoid.Health <= 0 then
            continue
        end

        if state.aimTeamCheck and isSameTeam(player) then
            continue
        end

        local part = getAimbotPart(character)
        if not part then
            continue
        end

        local distance3D = (ownRoot.Position - part.Position).Magnitude
        if distance3D > state.aimMaxDistance then
            continue
        end

        local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
        if not onScreen then
            continue
        end

        local screenDistance = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
        if screenDistance > fovRadius then
            continue
        end

        if state.aimVisibleOnly and not isVisible(part) then
            continue
        end

        if screenDistance < bestDistance then
            bestDistance = screenDistance
            bestTarget = player
        end
    end

    return bestTarget
end

local function aimAt(part: BasePart)
    local camera = Workspace.CurrentCamera
    local targetCFrame = CFrame.new(camera.CFrame.Position, part.Position)
    local smooth = math.clamp(state.aimSmooth, CONFIG.AIM_SMOOTH_MIN, CONFIG.AIM_SMOOTH_MAX)
    camera.CFrame = camera.CFrame:Lerp(targetCFrame, smooth)
end

local function isAimActivated(): boolean
    if not state.aimEnabled then
        return false
    end

    if state.aimMode == "Auto" then
        return true
    elseif state.aimMode == "Toggle" then
        return state.aimActive
    elseif state.aimMode == "Hold" then
        return aimButtonHeld
    end

    return false
end

local function updateAimbotTarget()
    if not state.aimEnabled then
        aimbotTarget = nil
        aimbotTargetPart = nil
        return
    end

    if not aimbotTarget or not aimbotTarget.Parent or not aimbotTarget.Character then
        aimbotTarget = findAimbotTarget()
    elseif aimbotTarget.Character then
        local part = getAimbotPart(aimbotTarget.Character)
        if not part or getDistanceFromCenter(part) > state.aimFov then
            aimbotTarget = findAimbotTarget()
        else
            aimbotTargetPart = part
        end
    end

    if aimbotTarget and aimbotTarget.Character then
        aimbotTargetPart = getAimbotPart(aimbotTarget.Character)
    else
        aimbotTargetPart = nil
    end
end

-- Interface ---------------------------------------------------------------

local gui = make("ScreenGui", {
    Name = CONFIG.GUI_NAME,
    DisplayOrder = 50,
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui

local toggleButton = make("TextButton", {
    AnchorPoint = Vector2.new(1, 0),
    AutoButtonColor = false,
    BackgroundColor3 = getCurrentTheme().panel,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -18, 0, 18),
    Size = UDim2.fromOffset(64, 48),
    Text = "CH",
    TextColor3 = getAccent(),
    TextSize = 16,
    Font = Enum.Font.GothamBold,
}, gui) :: TextButton
corner(toggleButton, 14)
local toggleStroke = stroke(toggleButton, getAccent(), 0.15)

local panel = make("Frame", {
    AnchorPoint = Vector2.new(1, 0),
    BackgroundColor3 = getCurrentTheme().panel,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -18, 0, 78),
    Size = UDim2.fromOffset(300, 540),
    Visible = state.panelOpen,
}, gui) :: Frame
corner(panel, 16)
local panelStroke = stroke(panel, getCurrentTheme().border, 0.15)

local topBar = make("Frame", {
    BackgroundColor3 = getCurrentTheme().panelAlt,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 64),
}, panel) :: Frame
corner(topBar, 16)

local title = make("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Position = UDim2.fromOffset(17, 10),
    Size = UDim2.new(1, -72, 0, 22),
    Text = "CH  /  DEBUG",
    TextColor3 = getCurrentTheme().text,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, topBar) :: TextLabel

local subtitle = make("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Position = UDim2.fromOffset(17, 34),
    Size = UDim2.new(1, -72, 0, 16),
    Text = "Toque e arraste para mover",
    TextColor3 = getCurrentTheme().muted,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, topBar) :: TextLabel

local closeButton = make("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.fromOffset(44, 44),
    Text = "×",
    TextColor3 = getCurrentTheme().muted,
    TextSize = 28,
    Font = Enum.Font.Gotham,
}, topBar) :: TextButton

-- Tab bar
local tabBar = make("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(15, 68),
    Size = UDim2.new(1, -30, 0, CONFIG.TAB_HEIGHT),
}, panel) :: Frame

make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
}, tabBar)

local tabButtons = {}

local function createTabButton(name: string): TextButton
    local button = make("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = getCurrentTheme().surface,
        BorderSizePixel = 0,
        Size = UDim2.new(0.5, -4, 1, 0),
        Text = name,
        TextColor3 = getCurrentTheme().text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
    }, tabBar) :: TextButton
    corner(button, 10)
    stroke(button, getCurrentTheme().border, 0.55)
    tabButtons[name] = button
    return button
end

local espTabButton = createTabButton("ESP")
local aimbotTabButton = createTabButton("Aimbot")

-- Tab content containers
local function createTabContent(): ScrollingFrame
    local frame = make("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(15, 120),
        Size = UDim2.new(1, -30, 1, -136),
        CanvasSize = UDim2.new(1, 0, 0, 0),
        ScrollBarThickness = 4,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
    }, panel) :: ScrollingFrame

    make("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, frame)

    make("UIPadding", {
        PaddingBottom = UDim.new(0, 8),
    }, frame)

    return frame
end

local contentESP = createTabContent()
local contentAimbot = createTabContent()

-- UI Builder helpers
local function optionButton(parent: Instance, text: string): TextButton
    local button = make("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = getCurrentTheme().surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, CONFIG.BUTTON_HEIGHT),
        Text = text,
        TextColor3 = getCurrentTheme().text,
        TextSize = 14,
        Font = Enum.Font.GothamMedium,
    }, parent) :: TextButton
    corner(button, 12)
    stroke(button, getCurrentTheme().border, 0.55)
    return button
end

local function sectionLabel(parent: Instance, text: string)
    local label = make("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Size = UDim2.new(1, 0, 0, 26),
        Text = text,
        TextColor3 = getCurrentTheme().muted,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent) :: TextLabel
    return label
end

-- ESP tab content
sectionLabel(contentESP, "CONTROLES PRINCIPAIS")
local espButton = optionButton(contentESP, "")
local teamButton = optionButton(contentESP, "")
local distanceButton = optionButton(contentESP, "")

sectionLabel(contentESP, "EXIBIÇÃO")
local healthButton = optionButton(contentESP, "")
local distLabelButton = optionButton(contentESP, "")
local boxesButton = optionButton(contentESP, "")
local skeletonButton = optionButton(contentESP, "")
local tracersButton = optionButton(contentESP, "")

sectionLabel(contentESP, "APARÊNCIA")
local themeButton = optionButton(contentESP, "")
local subColorButton = optionButton(contentESP, "")
local fontButton = optionButton(contentESP, "")
local rangeButton = optionButton(contentESP, "")

local hint = make("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Size = UDim2.new(1, 0, 0, 40),
    Text = "Amarelo = visível  •  Vermelho = atrás da parede\nBranco = informações extras ligadas",
    TextColor3 = getCurrentTheme().muted,
    TextSize = 10,
    TextWrapped = true,
}, contentESP) :: TextLabel

-- Aimbot tab content
sectionLabel(contentAimbot, "AIMBOT")
local aimbotButton = optionButton(contentAimbot, "")
local aimModeButton = optionButton(contentAimbot, "")
local aimButtonVisibleButton = optionButton(contentAimbot, "")
local aimPartButton = optionButton(contentAimbot, "")
local aimDistanceButton = optionButton(contentAimbot, "")
local aimFovButton = optionButton(contentAimbot, "")
local aimSmoothButton = optionButton(contentAimbot, "")
local aimTeamButton = optionButton(contentAimbot, "")
local aimVisibleButton = optionButton(contentAimbot, "")
local aimResetPositionButton = optionButton(contentAimbot, "")

local aimbotHint = make("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Size = UDim2.new(1, 0, 0, 64),
    Text = "Modos: Segurar (segura o botão), Alternar (toque liga/desliga), Automático (sempre ativo).\nArraste o botão de mira para reposicioná-lo. Toque para usar.",
    TextColor3 = getCurrentTheme().muted,
    TextSize = 10,
    TextWrapped = true,
}, contentAimbot) :: TextLabel

-- Mobile aim button (floating on-screen)
local aimButton = make("TextButton", {
    Name = "MobileAimButton",
    AnchorPoint = Vector2.new(0, 1),
    AutoButtonColor = false,
    BackgroundColor3 = getCurrentTheme().panel,
    BorderSizePixel = 0,
    Position = UDim2.new(0, state.aimButtonX, 0, state.aimButtonY),
    Size = UDim2.fromOffset(CONFIG.MOBILE_AIM_BUTTON_SIZE, CONFIG.MOBILE_AIM_BUTTON_SIZE),
    Text = "AIM",
    TextColor3 = getAccent(),
    TextSize = 15,
    Font = Enum.Font.GothamBold,
    Visible = false,
}, gui) :: TextButton
aimButton.Active = true
corner(aimButton, 22)
local aimButtonStroke = stroke(aimButton, getAccent(), 0.2, 2)

-- FOV Circle visualization (actual circle)
local fovCircle = make("Frame", {
    Name = "FOVCircle",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromOffset(1, 1),
    Visible = false,
    ZIndex = 0,
}, gui) :: Frame

local fovCircleInner = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromScale(1, 1),
}, fovCircle) :: Frame

corner(fovCircleInner, 999) -- fully circular
make("UIStroke", {
    Color = getAccent(),
    Thickness = 1,
    Transparency = 0.6,
}, fovCircleInner)

local targetIndicator = make("TextLabel", {
    Name = "TargetIndicator",
    AnchorPoint = Vector2.new(0.5, 0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Position = UDim2.new(0.5, 0, 0.5, 40),
    Size = UDim2.fromOffset(200, 22),
    Text = "",
    TextColor3 = getAccent(),
    TextSize = 13,
    TextStrokeColor3 = Color3.new(0, 0, 0),
    TextStrokeTransparency = 0.5,
    Visible = false,
}, gui) :: TextLabel

-- Apply theme to all UI elements
local function applyTheme()
    local current = getCurrentTheme()
    panel.BackgroundColor3 = current.panel
    topBar.BackgroundColor3 = current.panelAlt
    toggleButton.BackgroundColor3 = current.panel
    toggleButton.TextColor3 = getAccent()
    title.TextColor3 = current.text
    subtitle.TextColor3 = current.muted
    closeButton.TextColor3 = current.muted
    hint.TextColor3 = current.muted
    aimbotHint.TextColor3 = current.muted

    toggleStroke.Color = getAccent()
    panelStroke.Color = current.border
    aimButtonStroke.Color = getAccent()

    for _, content in {contentESP, contentAimbot} do
        for _, child in content:GetChildren() do
            if child:IsA("TextButton") then
                child.BackgroundColor3 = current.surface
                child.TextColor3 = current.text
            elseif child:IsA("TextLabel") and child ~= hint and child ~= aimbotHint then
                child.TextColor3 = current.muted
            end
        end
    end
end

local function updateAimButtonVisual()
    if not state.aimEnabled then
        aimButton.Visible = false
        return
    end

    aimButton.Visible = state.aimButtonVisible

    if state.aimMode == "Hold" then
        aimButton.Text = aimButtonHeld and "MIRANDO" or "MIRA"
        aimButton.BackgroundColor3 = aimButtonHeld and getAccent() or getCurrentTheme().panel
        aimButton.TextColor3 = aimButtonHeld and Color3.new(0, 0, 0) or getAccent()
    elseif state.aimMode == "Toggle" then
        aimButton.Text = state.aimActive and "MIRANDO" or "MIRA"
        aimButton.BackgroundColor3 = state.aimActive and getAccent() or getCurrentTheme().panel
        aimButton.TextColor3 = state.aimActive and Color3.new(0, 0, 0) or getAccent()
    else
        aimButton.Text = "MIRA"
        aimButton.BackgroundColor3 = getCurrentTheme().panel
        aimButton.TextColor3 = getAccent()
    end

    aimButtonStroke.Color = getAccent()
end

local function refreshUI()
    -- ESP tab
    espButton.Text = state.enabled and "ESP  •  ligado" or "ESP  •  desligado"
    teamButton.Text = state.teamCheck and "Team Check  •  ligado" or "Team Check  •  desligado"
    distanceButton.Text = string.format("Distância máxima  •  %dm", state.maxDistance)
    healthButton.Text = state.showHealth and "Mostrar vida  •  ligado" or "Mostrar vida  •  desligado"
    distLabelButton.Text = state.showDistance and "Mostrar distância  •  ligado" or "Mostrar distância  •  desligado"
    boxesButton.Text = state.showBoxes and "Box ESP  •  ligado" or "Box ESP  •  desligado"
    skeletonButton.Text = state.showSkeleton and "Skeleton ESP  •  ligado" or "Skeleton ESP  •  desligado"
    tracersButton.Text = state.showTracers and "Tracers  •  ligado" or "Tracers  •  desligado"
    themeButton.Text = "Tema  •  " .. state.theme
    subColorButton.Text = "Sub cor  •  " .. state.subColor
    fontButton.Text = "Fonte  •  " .. state.font
    rangeButton.Text = "Alcance rápido  •  50m / 1000m"

    -- Aimbot tab
    local modeLabels = {
        Hold = "Segurar",
        Toggle = "Alternar",
        Auto = "Automático",
    }
    aimbotButton.Text = state.aimEnabled and "Aimbot  •  ligado" or "Aimbot  •  desligado"
    aimModeButton.Text = "Modo  •  " .. (modeLabels[state.aimMode] or state.aimMode)
    aimButtonVisibleButton.Text = state.aimButtonVisible and "Botão de mira  •  visível" or "Botão de mira  •  escondido"
    aimPartButton.Text = "Alvo  •  " .. state.aimTargetPart
    aimDistanceButton.Text = string.format("Alcance máx.  •  %dm", state.aimMaxDistance)
    aimFovButton.Text = string.format("FOV  •  %d°", state.aimFov)
    aimSmoothButton.Text = string.format("Suavização  •  %.2f", state.aimSmooth)
    aimTeamButton.Text = state.aimTeamCheck and "Ignorar time  •  ligado" or "Ignorar time  •  desligado"
    aimVisibleButton.Text = state.aimVisibleOnly and "Só visível  •  ligado" or "Só visível  •  desligado"
    aimResetPositionButton.Text = "Resetar posição do botão"

    applyTheme()
    updateAimButtonVisual()

    -- Tab selection visuals (must be after applyTheme)
    local current = getCurrentTheme()
    for name, button in tabButtons do
        if name == state.activeTab then
            button.BackgroundColor3 = current.accent
            button.TextColor3 = current.panel
        else
            button.BackgroundColor3 = current.surface
            button.TextColor3 = current.text
        end
    end

    contentESP.Visible = state.activeTab == "ESP"
    contentAimbot.Visible = state.activeTab == "Aimbot"
end

local function refreshAll()
    for _, player in Players:GetPlayers() do
        updateESP(player)
    end
end

local function switchTab(tabName: string)
    state.activeTab = tabName
    saveState()
    refreshUI()
end

espTabButton.Activated:Connect(function()
    pressFeedback(espTabButton)
    switchTab("ESP")
end)

aimbotTabButton.Activated:Connect(function()
    pressFeedback(aimbotTabButton)
    switchTab("Aimbot")
end)

-- ESP button connections
local function connectOptionButton(button: TextButton, callback: () -> ())
    button.Activated:Connect(function()
        pressFeedback(button)
        callback()
    end)
end

connectOptionButton(espButton, function()
    state.enabled = not state.enabled
    saveState()
    refreshUI()
    refreshAll()
end)

connectOptionButton(teamButton, function()
    state.teamCheck = not state.teamCheck
    saveState()
    refreshUI()
    refreshAll()
end)

connectOptionButton(distanceButton, function()
    if state.maxDistance >= CONFIG.MAX_DISTANCE then
        state.maxDistance = 100
    else
        state.maxDistance = math.min(state.maxDistance + 100, CONFIG.MAX_DISTANCE)
    end
    saveState()
    refreshUI()
    refreshAll()
end)

connectOptionButton(healthButton, function()
    state.showHealth = not state.showHealth
    saveState()
    refreshUI()
    refreshAll()
end)

connectOptionButton(distLabelButton, function()
    state.showDistance = not state.showDistance
    saveState()
    refreshUI()
    refreshAll()
end)

connectOptionButton(boxesButton, function()
    state.showBoxes = not state.showBoxes
    saveState()
    refreshUI()
    refreshAll()
end)

connectOptionButton(skeletonButton, function()
    state.showSkeleton = not state.showSkeleton
    saveState()
    refreshUI()
    refreshAll()
end)

connectOptionButton(tracersButton, function()
    state.showTracers = not state.showTracers
    saveState()
    refreshUI()
    refreshAll()
end)

connectOptionButton(themeButton, function()
    state.theme = state.theme == "Dark" and "Light" or "Dark"
    saveState()
    refreshUI()
end)

connectOptionButton(subColorButton, function()
    local keys = {}
    for key in subColors do
        table.insert(keys, key)
    end
    table.sort(keys)
    local currentIndex = table.find(keys, state.subColor) or 1
    state.subColor = keys[currentIndex % #keys + 1]
    saveState()
    refreshUI()
    refreshAll()
end)

connectOptionButton(fontButton, function()
    local keys = {}
    for key in fontOptions do
        table.insert(keys, key)
    end
    table.sort(keys)
    local currentIndex = table.find(keys, state.font) or 1
    state.font = keys[currentIndex % #keys + 1]
    saveState()
    refreshUI()
    refreshAll()
end)

connectOptionButton(rangeButton, function()
    state.maxDistance = state.maxDistance >= CONFIG.MAX_DISTANCE and 50 or CONFIG.MAX_DISTANCE
    saveState()
    refreshUI()
    refreshAll()
end)

-- Aimbot button connections
connectOptionButton(aimbotButton, function()
    state.aimEnabled = not state.aimEnabled
    if not state.aimEnabled then
        state.aimActive = false
        aimButtonHeld = false
    end
    saveState()
    refreshUI()
end)

connectOptionButton(aimModeButton, function()
    local modes = {"Hold", "Toggle", "Auto"}
    local currentIndex = table.find(modes, state.aimMode) or 1
    state.aimMode = modes[currentIndex % #modes + 1]
    state.aimActive = false
    aimButtonHeld = false
    saveState()
    refreshUI()
end)

connectOptionButton(aimButtonVisibleButton, function()
    state.aimButtonVisible = not state.aimButtonVisible
    saveState()
    refreshUI()
end)

connectOptionButton(aimPartButton, function()
    local parts = {"Head", "Torso", "HumanoidRootPart"}
    local currentIndex = table.find(parts, state.aimTargetPart) or 1
    state.aimTargetPart = parts[currentIndex % #parts + 1]
    saveState()
    refreshUI()
    updateAimbotTarget()
end)

connectOptionButton(aimDistanceButton, function()
    if state.aimMaxDistance >= 1000 then
        state.aimMaxDistance = 100
    else
        state.aimMaxDistance = math.min(state.aimMaxDistance + 100, 1000)
    end
    saveState()
    refreshUI()
end)

connectOptionButton(aimFovButton, function()
    if state.aimFov >= 360 then
        state.aimFov = 30
    else
        state.aimFov = math.min(state.aimFov + 30, 360)
    end
    saveState()
    refreshUI()
end)

connectOptionButton(aimSmoothButton, function()
    local step = 0.05
    if state.aimSmooth >= CONFIG.AIM_SMOOTH_MAX - 0.01 then
        state.aimSmooth = CONFIG.AIM_SMOOTH_MIN
    else
        state.aimSmooth = math.min(state.aimSmooth + step, CONFIG.AIM_SMOOTH_MAX)
    end
    saveState()
    refreshUI()
end)

connectOptionButton(aimTeamButton, function()
    state.aimTeamCheck = not state.aimTeamCheck
    saveState()
    refreshUI()
end)

connectOptionButton(aimVisibleButton, function()
    state.aimVisibleOnly = not state.aimVisibleOnly
    saveState()
    refreshUI()
end)

connectOptionButton(aimResetPositionButton, function()
    state.aimButtonPosition = "default"
    state.aimButtonX = CONFIG.MOBILE_AIM_BUTTON_DEFAULT_X
    state.aimButtonY = CONFIG.MOBILE_AIM_BUTTON_DEFAULT_Y
    saveState()
    refreshUI()
end)

-- Mobile aim button interactions
local aimButtonDragging = false
local aimDragStart: Vector2
local aimButtonStart: UDim2
local aimButtonDragConn: RBXScriptConnection?
local aimButtonCurrentInput: InputObject?

aimButton.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    aimButtonCurrentInput = input
    aimButtonDragging = false
    aimDragStart = input.Position
    aimButtonStart = aimButton.Position

    if state.aimMode == "Hold" then
        aimButtonHeld = true
    end

    updateAimButtonVisual()

    aimButtonDragConn = input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            aimButtonCurrentInput = nil
            if aimButtonDragConn then
                aimButtonDragConn:Disconnect()
                aimButtonDragConn = nil
            end

            local dragDelta = (input.Position - aimDragStart).Magnitude
            local wasTap = dragDelta < 16 and not aimButtonDragging

            if state.aimMode == "Hold" then
                aimButtonHeld = false
            elseif state.aimMode == "Toggle" and wasTap then
                state.aimActive = not state.aimActive
                saveState()
            end

            updateAimButtonVisual()
        end
    end)
end)

UserInputService.InputChanged:Connect(function(input)
    if input ~= aimButtonCurrentInput then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        local dragDelta = (input.Position - aimDragStart).Magnitude
        if dragDelta > 16 then
            aimButtonDragging = true
            if state.aimMode == "Hold" then
                aimButtonHeld = false
            end
            local newX = math.clamp(aimButtonStart.X.Offset + (input.Position.X - aimDragStart.X), 0, math.huge)
            local newY = math.clamp(aimButtonStart.Y.Offset + (input.Position.Y - aimDragStart.Y), 0, math.huge)
            aimButton.Position = UDim2.new(0, newX, 0, newY)
            state.aimButtonPosition = "custom"
            state.aimButtonX = newX
            state.aimButtonY = newY
        end
    end
end)

local function setPanelVisible(visible: boolean)
    state.panelOpen = visible
    panel.Visible = visible
    saveState()
end

toggleButton.Activated:Connect(function()
    pressFeedback(toggleButton)
    setPanelVisible(not panel.Visible)
end)

closeButton.Activated:Connect(function()
    pressFeedback(closeButton)
    setPanelVisible(false)
end)

-- Panel drag support (mouse + touch)
local dragging = false
local dragStart: Vector2
local panelStart: UDim2
local dragConn: RBXScriptConnection?

local function stopDrag()
    dragging = false
    if dragConn then
        dragConn:Disconnect()
        dragConn = nil
    end
end

topBar.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    dragging = true
    dragStart = input.Position
    panelStart = panel.Position

    dragConn = input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            stopDrag()
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

-- Main update loop --------------------------------------------------------

refreshUI()

local elapsedUpdate = 0
local elapsedAimbot = 0
local lastAimButtonSave = 0

RunService.Heartbeat:Connect(function(deltaTime)
    elapsedUpdate += deltaTime
    elapsedAimbot += deltaTime
    lastAimButtonSave += deltaTime

    if state.enabled then
        if elapsedUpdate >= CONFIG.UPDATE_INTERVAL then
            elapsedUpdate = 0
            for _, player in Players:GetPlayers() do
                updateESP(player)
            end
        end
    end

    if state.aimEnabled then
        fovCircle.Visible = true
        local center = getScreenCenter()
        local diameter = state.aimFov * 2
        fovCircle.Position = UDim2.new(0, center.X, 0, center.Y)
        fovCircle.Size = UDim2.new(0, diameter, 0, diameter)

        updateAimButtonVisual()

        -- Save aim button position periodically during drag
        if aimButtonDragging and lastAimButtonSave >= 0.5 then
            lastAimButtonSave = 0
            saveState()
        end

        if elapsedAimbot >= CONFIG.AIM_INTERVAL then
            elapsedAimbot = 0
            updateAimbotTarget()

            if isAimActivated() and aimbotTargetPart then
                aimAt(aimbotTargetPart)
                targetIndicator.Text = aimbotTarget and "Mirando: " .. aimbotTarget.DisplayName or ""
                targetIndicator.Visible = true
            else
                targetIndicator.Visible = false
            end
        end
    else
        fovCircle.Visible = false
        targetIndicator.Visible = false
        aimButton.Visible = false
        aimButtonHeld = false
        state.aimActive = false
    end
end)

-- Cleanup on script destroy
local function cleanup()
    clearAllESP()
    gui:Destroy()
    espFolder:Destroy()
end

gui.Destroying:Connect(cleanup)
