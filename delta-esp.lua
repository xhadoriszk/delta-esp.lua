--[[
    CH DEBUG OVERLAY - LocalScript mobile-first para o seu proprio jogo Roblox.

    Coloque em:
    StarterPlayer > StarterPlayerScripts

    Trava de seguranca:
    - No Studio, o painel fica disponivel para testes.
    - Em jogo publicado, o PlaceId precisa estar na lista abaixo E o
      jogador precisa ter o atributo "CanUseCHDebug" definido como true
      pelo seu proprio sistema de administracao.

    Exemplo no servidor, para um moderador autorizado:
        player:SetAttribute("CanUseCHDebug", true)

    Um LocalScript nao consegue oferecer autorizacao realmente inviolavel;
    a permissao publicada deve ser concedida pelo servidor.
]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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
    MOBILE_AIM_BUTTON_SIZE = 80,
    MOBILE_AIM_BUTTON_DEFAULT_X = 24,
    MOBILE_AIM_BUTTON_DEFAULT_Y = 120,
    MOBILE_PADDING = 18,
    MOBILE_FLY_BUTTON_SIZE = 64,
    BUTTON_HEIGHT = 54,
    TAB_HEIGHT = 44,
    DEFAULT_WALK_SPEED = 16,
    DEFAULT_JUMP_POWER = 50,
    MAX_WALK_SPEED = 100,
    MAX_JUMP_POWER = 800,
    FLY_SPEED_MIN = 20,
    FLY_SPEED_MAX = 200,
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
        on = Color3.fromRGB(83, 255, 134),
        off = Color3.fromRGB(255, 83, 104),
    },
    Light = {
        panel = Color3.fromRGB(245, 248, 252),
        panelAlt = Color3.fromRGB(225, 234, 244),
        surface = Color3.fromRGB(211, 224, 238),
        text = Color3.fromRGB(19, 31, 47),
        muted = Color3.fromRGB(78, 101, 126),
        border = Color3.fromRGB(160, 182, 204),
        accent = Color3.fromRGB(0, 151, 164),
        on = Color3.fromRGB(0, 180, 80),
        off = Color3.fromRGB(220, 50, 70),
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
    ["Padrao"] = Enum.Font.Gotham,
    ["Cartoon"] = Enum.Font.Cartoon,
    ["Code"] = Enum.Font.Code,
    ["Titulo"] = Enum.Font.GothamBold,
}

local labels = {
    esp = "",
    aim = "",
    config = "",
    on = "",
    off = "",
    speed = "",
    jump = "",
    fly = "",
    run = "",
    infinite = "",
    theme = "",
    color = "",
    font = "",
    distance = "",
    team = "",
    health = "",
    box = "",
    skeleton = "",
    tracer = "",
    visible = "",
    reset = "",
    aimPart = "",
    fov = "",
    mode = "",
    close = "",
    menu = "",
    up = "",
    down = "",
    plus = "",
    minus = "",
}

local state = {
    -- ESP
    enabled = true,
    teamCheck = false,
    theme = "Dark",
    subColor = "Ciano",
    font = "Padrao",
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
    aimTargetPart = "Head",
    aimMaxDistance = 500,
    aimTeamCheck = true,
    aimVisibleOnly = true,
    aimFov = 360,
    -- Configs (character)
    walkSpeed = CONFIG.DEFAULT_WALK_SPEED,
    jumpPower = CONFIG.DEFAULT_JUMP_POWER,
    flyEnabled = false,
    flySpeed = 50,
    flyUp = false,
    flyDown = false,
    autoRun = false,
    infiniteJump = false,
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

-- Legacy compatibility
if state.activeTab == "Aimbot" then
    state.activeTab = "AIM"
end

-- Clamp saved values
state.aimFov = math.clamp(state.aimFov, 10, 360)
state.aimMaxDistance = math.clamp(state.aimMaxDistance, 50, CONFIG.MAX_DISTANCE)
state.walkSpeed = math.clamp(state.walkSpeed, 1, CONFIG.MAX_WALK_SPEED)
state.jumpPower = math.clamp(state.jumpPower, 40, CONFIG.MAX_JUMP_POWER)
state.flySpeed = math.clamp(state.flySpeed, CONFIG.FLY_SPEED_MIN, CONFIG.FLY_SPEED_MAX)
state.maxDistance = math.clamp(state.maxDistance, CONFIG.MIN_DISTANCE, CONFIG.MAX_DISTANCE)

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
        math.max(0, originalSize.X.Offset - 4),
        originalSize.Y.Scale,
        math.max(0, originalSize.Y.Offset - 4)
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

local function hapticFeedback()
    if HapticService then
        pcall(function()
            HapticService:SetMotor("Vibration", Enum.UserInputType.Gamepad1, 0.3)
            task.delay(0.05, function()
                HapticService:SetMotor("Vibration", Enum.UserInputType.Gamepad1, 0)
            end)
        end)
    end
end

-- Early GUI (used by ESP tracers) ----------------------------------------

local gui = make("ScreenGui", {
    Name = CONFIG.GUI_NAME,
    DisplayOrder = 50,
    IgnoreGuiInset = true,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui) :: ScreenGui

local uiESPFolder = make("Folder", {
    Name = "UIESP",
}, gui) :: Folder

-- Character helpers -------------------------------------------------------

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

local function applyCharacterStats(character: Model?)
    local char = character or localPlayer.Character
    if not char then
        return
    end

    local humanoid = getHumanoid(char)
    if not humanoid then
        return
    end

    local finalSpeed = state.walkSpeed
    if state.autoRun then
        finalSpeed = math.min(finalSpeed * 1.07, CONFIG.MAX_WALK_SPEED)
    end

    humanoid.WalkSpeed = finalSpeed
    humanoid.JumpPower = state.jumpPower
end

-- Fly logic
local flyBodyVelocity: BodyVelocity?
local flyConnection: RBXScriptConnection?

local function disableFly()
    state.flyEnabled = false
    state.flyUp = false
    state.flyDown = false

    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end

    if flyBodyVelocity then
        flyBodyVelocity:Destroy()
        flyBodyVelocity = nil
    end

    local char = localPlayer.Character
    local humanoid = char and getHumanoid(char)
    if humanoid then
        humanoid.PlatformStand = false
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end

local function enableFly()
    if flyConnection then
        disableFly()
    end

    local char = localPlayer.Character
    local humanoid = char and getHumanoid(char)
    local root = char and getCharacterRoot(char)
    if not char or not humanoid or not root then
        return
    end

    state.flyEnabled = true

    flyBodyVelocity = make("BodyVelocity", {
        MaxForce = Vector3.new(1e9, 1e9, 1e9),
        Velocity = Vector3.zero,
    }, root) :: BodyVelocity

    humanoid.PlatformStand = true

    flyConnection = RunService.Heartbeat:Connect(function()
        if not state.flyEnabled then
            disableFly()
            return
        end

        local currentChar = localPlayer.Character
        local currentHum = currentChar and getHumanoid(currentChar)
        local currentRoot = currentChar and getCharacterRoot(currentChar)
        if not currentChar or not currentHum or not currentRoot then
            disableFly()
            return
        end

        local camera = Workspace.CurrentCamera
        local moveDir = currentHum.MoveDirection
        local velocity = Vector3.zero

        if moveDir.Magnitude > 0 then
            local forward = camera.CFrame.LookVector * moveDir.Z
            local right = camera.CFrame.RightVector * moveDir.X
            velocity = (forward + right) * state.flySpeed
        end

        if state.flyUp then
            velocity = velocity + Vector3.new(0, state.flySpeed, 0)
        elseif state.flyDown then
            velocity = velocity - Vector3.new(0, state.flySpeed, 0)
        end

        if flyBodyVelocity and flyBodyVelocity.Parent then
            flyBodyVelocity.Velocity = velocity
        end
    end)
end

local function toggleFly(enabled: boolean)
    if enabled then
        enableFly()
    else
        disableFly()
    end
    saveState()
end

-- Infinite jump
UserInputService.JumpRequest:Connect(function()
    if not state.infiniteJump then
        return
    end

    local char = localPlayer.Character
    local humanoid = char and getHumanoid(char)
    if not humanoid then
        return
    end

    if not humanoid.FloorMaterial or humanoid.FloorMaterial == Enum.Material.Air then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- Apply stats when character spawns/respawns
local function setupCharacter(character: Model)
    task.defer(function()
        applyCharacterStats(character)
        if state.flyEnabled then
            enableFly()
        end
    end)
end

localPlayer.CharacterAdded:Connect(setupCharacter)
if localPlayer.Character then
    setupCharacter(localPlayer.Character)
end

-- ESP logic ---------------------------------------------------------------

local espFolder = make("Folder", {
    Name = CONFIG.ESP_FOLDER_NAME,
}, Workspace) :: Folder

local playerConnections: {[Player]: {characterAdded: RBXScriptConnection?, teamChanged: RBXScriptConnection?}} = {}
local playerESPUI: {[Player]: {uiFolder: Folder?, tracer: Frame?, lines: {{line: Frame, a: string, b: string}}?}} = {}

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

    local uiData = playerESPUI[player]
    if uiData and uiData.uiFolder then
        uiData.uiFolder:Destroy()
    end
    playerESPUI[player] = nil
end

local function clearAllESP()
    for _, folder in espFolder:GetChildren() do
        folder:Destroy()
    end
    for _, folder in uiESPFolder:GetChildren() do
        folder:Destroy()
    end
    table.clear(playerESPUI)
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
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        FillTransparency = 0.78,
        OutlineTransparency = 0.05,
    }, folder) :: Highlight

    local billboard = make("BillboardGui", {
        Name = "Billboard",
        Adornee = root,
        AlwaysOnTop = true,
        MaxDistance = CONFIG.MAX_DISTANCE,
        Size = UDim2.fromOffset(280, 72),
        StudsOffset = Vector3.new(0, 3.8, 0),
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
    }, folder) :: BasePart

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

    local playerUIFolder = make("Folder", {
        Name = tostring(player.UserId),
    }, uiESPFolder) :: Folder

    local tracer = make("Frame", {
        Name = "Tracer",
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = getAccent(),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 1, -10),
        Size = UDim2.new(0, 2, 0, 100),
        Visible = false,
    }, playerUIFolder) :: Frame

    local skeletonFolder = make("Folder", {
        Name = "Skeleton",
    }, playerUIFolder) :: Folder

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

    playerESPUI[player] = {
        uiFolder = playerUIFolder,
        tracer = tracer,
        lines = lines,
    }
end

local function updateESP(player: Player)
    if player == localPlayer or not player.Character then
        return
    end

    local folder = getESPFolder(player)
    if not folder then
        return
    end

    local uiData = playerESPUI[player]

    local highlight = folder:FindFirstChild("Highlight") :: Highlight?
    local billboard = folder:FindFirstChild("Billboard") :: BillboardGui?
    local label = billboard and billboard:FindFirstChild("Label") :: TextLabel?
    local boxAdornee = folder:FindFirstChild("BoxAdornee") :: BasePart?
    local tracer = uiData and uiData.tracer :: Frame?
    local lines = uiData and uiData.lines :: {{line: Frame, a: string, b: string}}?

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
    label.Text = table.concat(textParts, " | ")

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

    playerConnections[player] = {
        characterAdded = characterAddedConn,
        teamChanged = teamChangedConn,
    }

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
    local conns = playerConnections[player]
    if conns then
        if conns.characterAdded then
            conns.characterAdded:Disconnect()
        end
        if conns.teamChanged then
            conns.teamChanged:Disconnect()
        end
        playerConnections[player] = nil
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

        local screenDistance = (Vector2.new(screenPos.X, screenPos.Y) - getScreenCenter()).Magnitude
        if screenDistance > state.aimFov then
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
    camera.CFrame = targetCFrame
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
        local onScreen = false
        if part then
            local _, screenVisible = Workspace.CurrentCamera:WorldToViewportPoint(part.Position)
            onScreen = screenVisible
        end
        if not part or not onScreen then
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

local toggleButton = make("TextButton", {
    Name = "ToggleButton",
    AnchorPoint = Vector2.new(1, 0),
    Active = true,
    AutoButtonColor = false,
    BackgroundColor3 = getCurrentTheme().panel,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -18, 0, 18),
    Size = UDim2.fromOffset(68, 52),
    Text = "CH",
    TextColor3 = getAccent(),
    TextSize = 17,
    Font = Enum.Font.GothamBold,
}, gui) :: TextButton
corner(toggleButton, 16)
local toggleStroke = stroke(toggleButton, getAccent(), 0.15)

local panel = make("Frame", {
    Name = "Panel",
    AnchorPoint = Vector2.new(1, 0),
    Active = true,
    BackgroundColor3 = getCurrentTheme().panel,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -18, 0, 78),
    Size = UDim2.fromOffset(320, 560),
    Visible = state.panelOpen,
}, gui) :: Frame
corner(panel, 18)
local panelStroke = stroke(panel, getCurrentTheme().border, 0.15)

local topBar = make("Frame", {
    Name = "TopBar",
    Active = true,
    BackgroundColor3 = getCurrentTheme().panelAlt,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 66),
}, panel) :: Frame
corner(topBar, 18)

local title = make("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Position = UDim2.fromOffset(17, 10),
    Size = UDim2.new(1, -72, 0, 22),
    Text = "CH / DEBUG",
    TextColor3 = getCurrentTheme().text,
    TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left,
}, topBar) :: TextLabel

local subtitle = make("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Position = UDim2.fromOffset(17, 34),
    Size = UDim2.new(1, -72, 0, 16),
    Text = "Arraste para mover | Toque nas abas",
    TextColor3 = getCurrentTheme().muted,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
}, topBar) :: TextLabel

local closeButton = make("TextButton", {
    Name = "CloseButton",
    AnchorPoint = Vector2.new(1, 0.5),
    Active = true,
    AutoButtonColor = false,
    BackgroundTransparency = 1,
    Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.fromOffset(48, 48),
    Text = labels.close,
    TextColor3 = getCurrentTheme().muted,
    TextSize = 22,
    Font = Enum.Font.Gotham,
}, topBar) :: TextButton

-- Tab bar
local tabBar = make("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(15, 74),
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

local function createTabButton(name: string, icon: string): TextButton
    local button = make("TextButton", {
        Active = true,
        AutoButtonColor = false,
        BackgroundColor3 = getCurrentTheme().surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1 / 3, -6, 1, 0),
        Text = name,
        TextColor3 = getCurrentTheme().text,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
    }, tabBar) :: TextButton
    corner(button, 12)
    stroke(button, getCurrentTheme().border, 0.55)
    tabButtons[name] = button
    return button
end

local espTabButton = createTabButton("ESP", labels.esp)
local aimbotTabButton = createTabButton("AIM", labels.aim)
local configsTabButton = createTabButton("CFG", labels.config)

-- Tab content containers
local function createTabContent(): ScrollingFrame
    local frame = make("ScrollingFrame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(15, 124),
        Size = UDim2.new(1, -30, 1, -142),
        CanvasSize = UDim2.new(1, 0, 0, 0),
        ScrollBarThickness = 5,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
    }, panel) :: ScrollingFrame

    make("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, frame)

    make("UIPadding", {
        PaddingBottom = UDim.new(0, 10),
    }, frame)

    return frame
end

local contentESP = createTabContent()
local contentAimbot = createTabContent()
local contentConfigs = createTabContent()

-- UI Builder helpers
local function sectionLabel(parent: Instance, icon: string, text: string)
    local label = make("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Size = UDim2.new(1, 0, 0, 28),
        Text = text:upper(),
        TextColor3 = getCurrentTheme().muted,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent) :: TextLabel
    return label
end

local function optionButton(parent: Instance, icon: string, text: string): TextButton
    local container = make("Frame", {
        BackgroundColor3 = getCurrentTheme().surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, CONFIG.BUTTON_HEIGHT),
    }, parent) :: Frame
    corner(container, 14)
    stroke(container, getCurrentTheme().border, 0.55)

    local iconLabel = make("TextLabel", {
        Name = "Icon",
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.fromOffset(30, CONFIG.BUTTON_HEIGHT),
        Text = icon,
        TextColor3 = getAccent(),
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, container) :: TextLabel

    local textLabel = make("TextLabel", {
        Name = "Text",
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Position = UDim2.fromOffset(46, 0),
        Size = UDim2.new(1, -110, 1, 0),
        Text = text,
        TextColor3 = getCurrentTheme().text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, container) :: TextLabel

    local button = make("TextButton", {
        Active = true,
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
    }, container) :: TextButton

    return button
end

local function createToggle(parent: Instance, icon: string, text: string): {container: Frame, button: TextButton, text: TextLabel, status: Frame, knob: Frame}
    local container = make("Frame", {
        BackgroundColor3 = getCurrentTheme().surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, CONFIG.BUTTON_HEIGHT),
    }, parent) :: Frame
    corner(container, 14)
    stroke(container, getCurrentTheme().border, 0.55)

    local iconLabel = make("TextLabel", {
        Name = "Icon",
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.fromOffset(30, CONFIG.BUTTON_HEIGHT),
        Text = icon,
        TextColor3 = getAccent(),
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, container) :: TextLabel

    local textLabel = make("TextLabel", {
        Name = "Text",
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Position = UDim2.fromOffset(46, 0),
        Size = UDim2.new(1, -110, 1, 0),
        Text = text,
        TextColor3 = getCurrentTheme().text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, container) :: TextLabel

    local switchFrame = make("Frame", {
        Name = "SwitchFrame",
        AnchorPoint = Vector2.new(1, 0.5),
        BackgroundColor3 = getCurrentTheme().border,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(48, 28),
    }, container) :: Frame
    corner(switchFrame, 14)

    local switchKnob = make("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(24, 24),
    }, switchFrame) :: Frame
    corner(switchKnob, 12)

    local button = make("TextButton", {
        Active = true,
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
    }, container) :: TextButton

    return {
        container = container,
        button = button,
        text = textLabel,
        status = switchFrame,
        knob = switchKnob,
    }
end

local function updateToggle(toggle, enabled: boolean)
    local current = getCurrentTheme()
    local targetColor = enabled and getAccent() or current.off
    local targetPos = enabled and UDim2.new(1, -26, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)

    TweenService:Create(toggle.status, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = targetColor,
    }):Play()
    TweenService:Create(toggle.knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = targetPos,
    }):Play()
end

local function createSlider(parent: Instance, min: number, max: number, icon: string, labelText: string)
    local container = make("Frame", {
        BackgroundColor3 = getCurrentTheme().surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 70),
    }, parent) :: Frame
    corner(container, 14)
    stroke(container, getCurrentTheme().border, 0.55)

    local iconLabel = make("TextLabel", {
        Name = "Icon",
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Position = UDim2.fromOffset(14, 8),
        Size = UDim2.fromOffset(30, 22),
        Text = icon,
        TextColor3 = getAccent(),
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, container) :: TextLabel

    local title = make("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        Position = UDim2.fromOffset(46, 8),
        Size = UDim2.new(1, -110, 0, 22),
        Text = labelText,
        TextColor3 = getCurrentTheme().text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, container) :: TextLabel

    local valueLabel = make("TextLabel", {
        Name = "Value",
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Position = UDim2.new(1, -70, 0, 8),
        Size = UDim2.fromOffset(56, 22),
        Text = "0",
        TextColor3 = getAccent(),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, container) :: TextLabel

    local track = make("Frame", {
        BackgroundColor3 = getCurrentTheme().border,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 14, 0, 40),
        Size = UDim2.new(1, -28, 0, 8),
    }, container) :: Frame
    corner(track, 4)

    local fill = make("Frame", {
        BackgroundColor3 = getAccent(),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0, 0),
        Size = UDim2.fromScale(0, 1),
    }, track) :: Frame
    corner(fill, 4)

    local knob = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(20, 20),
        ZIndex = 2,
    }, track) :: Frame
    corner(knob, 10)

    return {
        container = container,
        title = title,
        valueLabel = valueLabel,
        track = track,
        fill = fill,
        knob = knob,
        min = min,
        max = max,
    }
end

local function updateSlider(slider, value: number)
    local pct = (value - slider.min) / (slider.max - slider.min)
    pct = math.clamp(pct, 0, 1)
    slider.fill.Size = UDim2.fromScale(pct, 1)
    slider.knob.Position = UDim2.fromScale(pct, 0.5)
    slider.valueLabel.Text = tostring(math.round(value))
end

local function getSliderValueFromInput(slider, inputX: number): number
    local trackAbs = slider.track.AbsolutePosition
    local trackSize = slider.track.AbsoluteSize
    local pct = (inputX - trackAbs.X) / trackSize.X
    pct = math.clamp(pct, 0, 1)
    return math.round(slider.min + pct * (slider.max - slider.min))
end

local sliders = {}

-- ESP tab content
sectionLabel(contentESP, labels.esp, "CONTROLES")
local espToggle = createToggle(contentESP, labels.esp, "ESP geral")
local teamToggle = createToggle(contentESP, labels.team, "Ignorar time")
local maxDistanceSlider = createSlider(contentESP, CONFIG.MIN_DISTANCE, CONFIG.MAX_DISTANCE, labels.distance, "Alcance maximo")
table.insert(sliders, maxDistanceSlider)

sectionLabel(contentESP, labels.visible, "EXIBICAO")
local healthToggle = createToggle(contentESP, labels.health, "Mostrar vida")
local distLabelToggle = createToggle(contentESP, labels.distance, "Mostrar distancia")
local boxesToggle = createToggle(contentESP, labels.box, "Box ESP")
local skeletonToggle = createToggle(contentESP, labels.skeleton, "Skeleton ESP")
local tracersToggle = createToggle(contentESP, labels.tracer, "Tracers")

sectionLabel(contentESP, labels.color, "APARENCIA")
local themeButton = optionButton(contentESP, labels.theme, "Tema")
local subColorButton = optionButton(contentESP, labels.color, "Sub cor")
local fontButton = optionButton(contentESP, labels.font, "Fonte")

local espHint = make("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Size = UDim2.new(1, 0, 0, 44),
    Text = "Amarelo = visivel | Vermelho = atras da parede\nToque em qualquer botao para alternar",
    TextColor3 = getCurrentTheme().muted,
    TextSize = 10,
    TextWrapped = true,
}, contentESP) :: TextLabel

-- Aimbot tab content
sectionLabel(contentAimbot, labels.aim, "AIMBOT")
local aimbotToggle = createToggle(contentAimbot, labels.aim, "Aimbot")
local aimModeButton = optionButton(contentAimbot, labels.mode, "Modo de ativacao")
local aimButtonVisibleToggle = createToggle(contentAimbot, labels.visible, "Botao de mira")
local aimPartButton = optionButton(contentAimbot, labels.aimPart, "Parte do alvo")
local aimMaxDistanceSlider = createSlider(contentAimbot, 50, 2000, labels.distance, "Alcance maximo")
table.insert(sliders, aimMaxDistanceSlider)
local aimFovSlider = createSlider(contentAimbot, 10, 360, labels.fov, "FOV")
table.insert(sliders, aimFovSlider)
local aimTeamToggle = createToggle(contentAimbot, labels.team, "Ignorar time")
local aimVisibleToggle = createToggle(contentAimbot, labels.visible, "So visivel")
local aimResetPositionButton = optionButton(contentAimbot, labels.reset, "Resetar botao de mira")

local aimbotHint = make("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Size = UDim2.new(1, 0, 0, 64),
    Text = "Modos: Segurar (segura o botao), Alternar (toque liga/desliga), Automatico (sempre ativo).\nArraste o botao de mira para reposiciona-lo. Toque para usar.",
    TextColor3 = getCurrentTheme().muted,
    TextSize = 10,
    TextWrapped = true,
}, contentAimbot) :: TextLabel

-- Configs tab content
sectionLabel(contentConfigs, labels.speed, "PERSONAGEM")
local walkSpeedSlider = createSlider(contentConfigs, 1, CONFIG.MAX_WALK_SPEED, labels.speed, "Velocidade")
table.insert(sliders, walkSpeedSlider)
local jumpPowerSlider = createSlider(contentConfigs, 40, CONFIG.MAX_JUMP_POWER, labels.jump, "Pulo")
table.insert(sliders, jumpPowerSlider)
local autoRunToggle = createToggle(contentConfigs, labels.run, "Auto correr")
local infiniteJumpToggle = createToggle(contentConfigs, labels.infinite, "Pulo infinito")

sectionLabel(contentConfigs, labels.fly, "FLY")
local flyToggle = createToggle(contentConfigs, labels.fly, "Fly")
local flySpeedSlider = createSlider(contentConfigs, CONFIG.FLY_SPEED_MIN, CONFIG.FLY_SPEED_MAX, labels.fly, "Fly speed")
table.insert(sliders, flySpeedSlider)

local resetConfigsButton = optionButton(contentConfigs, labels.reset, "Resetar configuracoes")

local configsHint = make("TextLabel", {
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Size = UDim2.new(1, 0, 0, 64),
    Text = "Use o botao pular para subir no fly. Botoes flutuantes de subir/descer aparecem quando o fly esta ligado.\nAuto correr move o personagem para frente sozinho (+7%).",
    TextColor3 = getCurrentTheme().muted,
    TextSize = 10,
    TextWrapped = true,
}, contentConfigs) :: TextLabel

-- Mobile aim button (floating on-screen)
local function getDefaultAimButtonPosition(): (number, number)
    local viewport = Workspace.CurrentCamera.ViewportSize
    local x = viewport.X - CONFIG.MOBILE_AIM_BUTTON_SIZE - CONFIG.MOBILE_PADDING
    local y = viewport.Y - CONFIG.MOBILE_AIM_BUTTON_SIZE - CONFIG.MOBILE_PADDING - 120
    return x, y
end

local initialAimX, initialAimY = getDefaultAimButtonPosition()
if state.aimButtonPosition == "default" then
    state.aimButtonX = initialAimX
    state.aimButtonY = initialAimY
else
    local viewport = Workspace.CurrentCamera.ViewportSize
    local buttonSize = CONFIG.MOBILE_AIM_BUTTON_SIZE
    state.aimButtonX = math.clamp(state.aimButtonX, CONFIG.MOBILE_PADDING, viewport.X - buttonSize - CONFIG.MOBILE_PADDING)
    state.aimButtonY = math.clamp(state.aimButtonY, CONFIG.MOBILE_PADDING + 40, viewport.Y - buttonSize - CONFIG.MOBILE_PADDING)
end

local aimButton = make("TextButton", {
    Name = "MobileAimButton",
    AnchorPoint = Vector2.new(0, 1),
    Active = true,
    AutoButtonColor = false,
    BackgroundColor3 = getCurrentTheme().panel,
    BorderSizePixel = 0,
    Position = UDim2.new(0, state.aimButtonX, 0, state.aimButtonY),
    Size = UDim2.fromOffset(CONFIG.MOBILE_AIM_BUTTON_SIZE, CONFIG.MOBILE_AIM_BUTTON_SIZE),
    Text = labels.aim,
    TextColor3 = getAccent(),
    TextSize = 28,
    Font = Enum.Font.GothamBold,
    Visible = false,
}, gui) :: TextButton
aimButton.Active = true
corner(aimButton, 24)
local aimButtonStroke = stroke(aimButton, getAccent(), 0.2, 2)

-- Fly control buttons (floating on-screen)
local flyUpButton = make("TextButton", {
    Name = "FlyUpButton",
    AnchorPoint = Vector2.new(1, 1),
    Active = true,
    AutoButtonColor = false,
    BackgroundColor3 = getCurrentTheme().panel,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -24, 1, -188),
    Size = UDim2.fromOffset(CONFIG.MOBILE_FLY_BUTTON_SIZE, CONFIG.MOBILE_FLY_BUTTON_SIZE),
    Text = labels.up,
    TextColor3 = getAccent(),
    TextSize = 24,
    Font = Enum.Font.GothamBold,
    Visible = false,
}, gui) :: TextButton
corner(flyUpButton, 20)
local flyUpButtonStroke = stroke(flyUpButton, getAccent(), 0.2, 2)

local flyDownButton = make("TextButton", {
    Name = "FlyDownButton",
    AnchorPoint = Vector2.new(1, 1),
    Active = true,
    AutoButtonColor = false,
    BackgroundColor3 = getCurrentTheme().panel,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -24, 1, -108),
    Size = UDim2.fromOffset(CONFIG.MOBILE_FLY_BUTTON_SIZE, CONFIG.MOBILE_FLY_BUTTON_SIZE),
    Text = labels.down,
    TextColor3 = getAccent(),
    TextSize = 24,
    Font = Enum.Font.GothamBold,
    Visible = false,
}, gui) :: TextButton
corner(flyDownButton, 20)
local flyDownButtonStroke = stroke(flyDownButton, getAccent(), 0.2, 2)

-- FOV Circle visualization
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

corner(fovCircleInner, 999)
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
    Position = UDim2.new(0.5, 0, 0.5, 44),
    Size = UDim2.fromOffset(220, 24),
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
    espHint.TextColor3 = current.muted
    aimbotHint.TextColor3 = current.muted
    configsHint.TextColor3 = current.muted

    toggleStroke.Color = getAccent()
    panelStroke.Color = current.border
    aimButtonStroke.Color = getAccent()
    flyUpButtonStroke.Color = getAccent()
    flyDownButtonStroke.Color = getAccent()

    for _, content in {contentESP, contentAimbot, contentConfigs} do
        for _, child in content:GetChildren() do
            if child:IsA("Frame") then
                child.BackgroundColor3 = current.surface
                for _, grandChild in child:GetChildren() do
                    if grandChild:IsA("TextLabel") then
                        if grandChild.Name == "Icon" then
                            grandChild.TextColor3 = getAccent()
                        elseif grandChild.Name == "Value" then
                            grandChild.TextColor3 = getAccent()
                        else
                            grandChild.TextColor3 = current.text
                        end
                    elseif grandChild:IsA("Frame") and grandChild.Name == "SwitchFrame" then
                        grandChild.BackgroundColor3 = current.border
                    end
                end
            elseif child:IsA("TextLabel") then
                child.TextColor3 = current.muted
            end
        end
    end

    for _, slider in sliders do
        slider.container.BackgroundColor3 = current.surface
        slider.title.TextColor3 = current.text
        slider.valueLabel.TextColor3 = getAccent()
        slider.track.BackgroundColor3 = current.border
        slider.fill.BackgroundColor3 = getAccent()
        slider.knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end
end

local function updateAimButtonVisual()
    if not state.aimEnabled then
        aimButton.Visible = false
        return
    end

    if state.aimButtonPosition == "default" then
        local x, y = getDefaultAimButtonPosition()
        aimButton.Position = UDim2.new(0, x, 0, y)
    end

    aimButton.Visible = state.aimButtonVisible

    if state.aimMode == "Hold" then
        aimButton.Text = aimButtonHeld and labels.on or labels.aim
        aimButton.BackgroundColor3 = aimButtonHeld and getAccent() or getCurrentTheme().panel
        aimButton.TextColor3 = aimButtonHeld and Color3.new(0, 0, 0) or getAccent()
    elseif state.aimMode == "Toggle" then
        aimButton.Text = state.aimActive and labels.on or labels.aim
        aimButton.BackgroundColor3 = state.aimActive and getAccent() or getCurrentTheme().panel
        aimButton.TextColor3 = state.aimActive and Color3.new(0, 0, 0) or getAccent()
    else
        aimButton.Text = labels.aim
        aimButton.BackgroundColor3 = getCurrentTheme().panel
        aimButton.TextColor3 = getAccent()
    end
end

local function updateFlyButtons()
    flyUpButton.Visible = state.flyEnabled
    flyDownButton.Visible = state.flyEnabled

    if state.flyEnabled then
        flyUpButton.BackgroundColor3 = state.flyUp and getAccent() or getCurrentTheme().panel
        flyUpButton.TextColor3 = state.flyUp and Color3.new(0, 0, 0) or getAccent()
        flyDownButton.BackgroundColor3 = state.flyDown and getAccent() or getCurrentTheme().panel
        flyDownButton.TextColor3 = state.flyDown and Color3.new(0, 0, 0) or getAccent()
    end
end

local function refreshUI()
    -- ESP tab
    updateToggle(espToggle, state.enabled)
    updateToggle(teamToggle, state.teamCheck)
    updateSlider(maxDistanceSlider, state.maxDistance)
    updateToggle(healthToggle, state.showHealth)
    updateToggle(distLabelToggle, state.showDistance)
    updateToggle(boxesToggle, state.showBoxes)
    updateToggle(skeletonToggle, state.showSkeleton)
    updateToggle(tracersToggle, state.showTracers)
    themeButton:FindFirstChild("Text").Text = "Tema | " .. state.theme
    subColorButton:FindFirstChild("Text").Text = "Sub cor | " .. state.subColor
    fontButton:FindFirstChild("Text").Text = "Fonte | " .. state.font

    -- Aimbot tab
    local modeLabels = {
        Hold = "Segurar",
        Toggle = "Alternar",
        Auto = "Automatico",
    }
    updateToggle(aimbotToggle, state.aimEnabled)
    aimModeButton:FindFirstChild("Text").Text = "Modo | " .. (modeLabels[state.aimMode] or state.aimMode)
    updateToggle(aimButtonVisibleToggle, state.aimButtonVisible)
    aimPartButton:FindFirstChild("Text").Text = "Alvo | " .. state.aimTargetPart
    updateSlider(aimMaxDistanceSlider, state.aimMaxDistance)
    updateSlider(aimFovSlider, state.aimFov)
    updateToggle(aimTeamToggle, state.aimTeamCheck)
    updateToggle(aimVisibleToggle, state.aimVisibleOnly)
    aimResetPositionButton:FindFirstChild("Text").Text = "Resetar posicao do botao"

    -- Configs tab
    updateSlider(walkSpeedSlider, state.walkSpeed)
    updateSlider(jumpPowerSlider, state.jumpPower)
    updateToggle(autoRunToggle, state.autoRun)
    updateToggle(infiniteJumpToggle, state.infiniteJump)
    updateToggle(flyToggle, state.flyEnabled)
    updateSlider(flySpeedSlider, state.flySpeed)
    resetConfigsButton:FindFirstChild("Text").Text = "Resetar configuracoes"

    applyTheme()
    updateAimButtonVisual()
    updateFlyButtons()

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
    contentAimbot.Visible = state.activeTab == "AIM"
    contentConfigs.Visible = state.activeTab == "CFG"
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

-- Button connections ------------------------------------------------------

local function connectButton(button: TextButton, callback: () -> ())
    button.Active = true
    local currentInput: InputObject?

    button.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        currentInput = input
        local startPos = input.Position

        local conn: RBXScriptConnection?
        conn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                currentInput = nil
                if conn then
                    conn:Disconnect()
                end
                local dragDelta = (input.Position - startPos).Magnitude
                if dragDelta < 24 then
                    pressFeedback(button)
                    hapticFeedback()
                    callback()
                end
            end
        end)
    end)
end

connectButton(espTabButton, function()
    switchTab("ESP")
end)

connectButton(aimbotTabButton, function()
    switchTab("AIM")
end)

connectButton(configsTabButton, function()
    switchTab("CFG")
end)

-- Draggable toggle switch
local function setupToggle(toggle, stateKey, onChange)
    local currentInput: InputObject?
    local startX: number
    local knobStartX: number
    local dragging = false

    toggle.button.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        currentInput = input
        startX = input.Position.X
        knobStartX = toggle.knob.AbsolutePosition.X
        dragging = false

        local conn: RBXScriptConnection?
        conn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                currentInput = nil
                if conn then
                    conn:Disconnect()
                end

                if dragging then
                    local frameAbs = toggle.status.AbsolutePosition
                    local frameSize = toggle.status.AbsoluteSize
                    local knobCenter = toggle.knob.AbsolutePosition.X + toggle.knob.AbsoluteSize.X / 2
                    local mid = frameAbs.X + frameSize.X / 2
                    local desired = knobCenter > mid
                    if desired ~= state[stateKey] then
                        state[stateKey] = desired
                        onChange()
                    else
                        refreshUI()
                    end
                else
                    state[stateKey] = not state[stateKey]
                    onChange()
                end
            end
        end)
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input ~= currentInput then
            return
        end

        local delta = input.Position.X - startX
        if math.abs(delta) > 5 then
            dragging = true
        end

        if dragging then
            local frameAbs = toggle.status.AbsolutePosition
            local frameSize = toggle.status.AbsoluteSize
            local knobSize = toggle.knob.AbsoluteSize.X
            local minX = frameAbs.X + 2
            local maxX = frameAbs.X + frameSize.X - knobSize - 2
            local newX = math.clamp(knobStartX + delta, minX, maxX)
            toggle.knob.Position = UDim2.new(0, newX - frameAbs.X, 0.5, 0)

            local pct = (newX - minX) / (maxX - minX)
            local isOn = pct > 0.5
            toggle.status.BackgroundColor3 = isOn and getAccent() or getCurrentTheme().off
        end
    end)
end

setupToggle(espToggle, "enabled", function()
    saveState()
    refreshUI()
    refreshAll()
end)

setupToggle(teamToggle, "teamCheck", function()
    saveState()
    refreshUI()
    refreshAll()
end)

setupToggle(healthToggle, "showHealth", function()
    saveState()
    refreshUI()
    refreshAll()
end)

setupToggle(distLabelToggle, "showDistance", function()
    saveState()
    refreshUI()
    refreshAll()
end)

setupToggle(boxesToggle, "showBoxes", function()
    saveState()
    refreshUI()
    refreshAll()
end)

setupToggle(skeletonToggle, "showSkeleton", function()
    saveState()
    refreshUI()
    refreshAll()
end)

setupToggle(tracersToggle, "showTracers", function()
    saveState()
    refreshUI()
    refreshAll()
end)

setupToggle(aimbotToggle, "aimEnabled", function()
    if not state.aimEnabled then
        state.aimActive = false
        aimButtonHeld = false
    end
    saveState()
    refreshUI()
end)

setupToggle(aimButtonVisibleToggle, "aimButtonVisible", function()
    saveState()
    refreshUI()
end)

setupToggle(aimTeamToggle, "aimTeamCheck", function()
    saveState()
    refreshUI()
end)

setupToggle(aimVisibleToggle, "aimVisibleOnly", function()
    saveState()
    refreshUI()
end)

setupToggle(autoRunToggle, "autoRun", function()
    saveState()
    refreshUI()
    applyCharacterStats()
end)

setupToggle(infiniteJumpToggle, "infiniteJump", function()
    saveState()
    refreshUI()
end)

setupToggle(flyToggle, "flyEnabled", function()
    toggleFly(state.flyEnabled)
    refreshUI()
end)

connectButton(themeButton, function()
    state.theme = state.theme == "Dark" and "Light" or "Dark"
    saveState()
    refreshUI()
end)

connectButton(subColorButton, function()
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

connectButton(fontButton, function()
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

connectButton(aimModeButton, function()
    local modes = {"Hold", "Toggle", "Auto"}
    local currentIndex = table.find(modes, state.aimMode) or 1
    state.aimMode = modes[currentIndex % #modes + 1]
    state.aimActive = false
    aimButtonHeld = false
    saveState()
    refreshUI()
end)

connectButton(aimPartButton, function()
    local parts = {"Head", "Torso", "HumanoidRootPart"}
    local currentIndex = table.find(parts, state.aimTargetPart) or 1
    state.aimTargetPart = parts[currentIndex % #parts + 1]
    saveState()
    refreshUI()
    updateAimbotTarget()
end)

connectButton(aimResetPositionButton, function()
    state.aimButtonPosition = "default"
    local x, y = getDefaultAimButtonPosition()
    state.aimButtonX = x
    state.aimButtonY = y
    saveState()
    refreshUI()
end)

connectButton(resetConfigsButton, function()
    state.walkSpeed = CONFIG.DEFAULT_WALK_SPEED
    state.jumpPower = CONFIG.DEFAULT_JUMP_POWER
    state.autoRun = false
    state.infiniteJump = false
    toggleFly(false)
    state.flySpeed = 50
    saveState()
    refreshUI()
    applyCharacterStats()
end)

-- Slider interaction
local function setupSliderInteraction(slider, callback: (number) -> ())
    local currentInput: InputObject?
    local dragging = false

    local function updateFromInput(input: InputObject)
        local value = getSliderValueFromInput(slider, input.Position.X)
        callback(value)
        updateSlider(slider, value)
    end

    slider.container.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        currentInput = input
        dragging = true
        updateFromInput(input)

        local conn: RBXScriptConnection?
        conn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                currentInput = nil
                dragging = false
                if conn then
                    conn:Disconnect()
                end
                saveState()
            end
        end)
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == currentInput and dragging then
            updateFromInput(input)
        end
    end)
end

setupSliderInteraction(maxDistanceSlider, function(value: number)
    state.maxDistance = value
    refreshAll()
end)

setupSliderInteraction(aimMaxDistanceSlider, function(value: number)
    state.aimMaxDistance = value
end)

setupSliderInteraction(aimFovSlider, function(value: number)
    state.aimFov = value
end)

setupSliderInteraction(walkSpeedSlider, function(value: number)
    state.walkSpeed = value
    applyCharacterStats()
end)

setupSliderInteraction(jumpPowerSlider, function(value: number)
    state.jumpPower = value
    applyCharacterStats()
end)

setupSliderInteraction(flySpeedSlider, function(value: number)
    state.flySpeed = value
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
            local wasTap = dragDelta < 24 and not aimButtonDragging

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
        if dragDelta > 24 then
            aimButtonDragging = true
            if state.aimMode == "Hold" then
                aimButtonHeld = false
            end
            local viewport = Workspace.CurrentCamera.ViewportSize
            local buttonSize = CONFIG.MOBILE_AIM_BUTTON_SIZE
            local newX = math.clamp(aimButtonStart.X.Offset + (input.Position.X - aimDragStart.X), CONFIG.MOBILE_PADDING, viewport.X - buttonSize - CONFIG.MOBILE_PADDING)
            local newY = math.clamp(aimButtonStart.Y.Offset + (input.Position.Y - aimDragStart.Y), CONFIG.MOBILE_PADDING + 40, viewport.Y - buttonSize - CONFIG.MOBILE_PADDING)
            aimButton.Position = UDim2.new(0, newX, 0, newY)
            state.aimButtonPosition = "custom"
            state.aimButtonX = newX
            state.aimButtonY = newY
        end
    end
end)

-- Fly button interactions (hold to go up/down)
local function setupFlyHoldButton(button: TextButton, flagName: string)
    local currentInput: InputObject?

    button.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        currentInput = input
        state[flagName] = true
        updateFlyButtons()

        local conn: RBXScriptConnection?
        conn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                currentInput = nil
                if conn then
                    conn:Disconnect()
                end
                state[flagName] = false
                updateFlyButtons()
            end
        end)
    end)
end

setupFlyHoldButton(flyUpButton, "flyUp")
setupFlyHoldButton(flyDownButton, "flyDown")

local function fitPanelToViewport()
    local viewport = Workspace.CurrentCamera.ViewportSize
    local width = math.min(320, viewport.X - 2 * CONFIG.MOBILE_PADDING)
    local height = math.min(560, viewport.Y - 120)
    panel.Size = UDim2.fromOffset(width, height)
end

local function setPanelVisible(visible: boolean)
    state.panelOpen = visible
    saveState()

    if visible then
        fitPanelToViewport()
        local targetSize = panel.Size
        panel.Visible = true
        panel.BackgroundTransparency = 1
        panel.Size = UDim2.fromOffset(0, 0)
        local tween = TweenService:Create(panel, TweenInfo.new(CONFIG.FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0,
            Size = targetSize,
        })
        tween:Play()
    else
        fitPanelToViewport()
        local tween = TweenService:Create(panel, TweenInfo.new(CONFIG.FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(0, 0),
        })
        tween:Play()
        tween.Completed:Connect(function()
            panel.Visible = false
        end)
    end
end

Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    fitPanelToViewport()
    if panel.Visible then
        local panelSize = panel.AbsoluteSize
        local viewport = Workspace.CurrentCamera.ViewportSize
        panel.Position = UDim2.new(
            panel.Position.X.Scale,
            math.clamp(panel.Position.X.Offset, panelSize.X - viewport.X + CONFIG.MOBILE_PADDING, viewport.X - CONFIG.MOBILE_PADDING),
            panel.Position.Y.Scale,
            math.clamp(panel.Position.Y.Offset, 0, viewport.Y - panelSize.Y - CONFIG.MOBILE_PADDING)
        )
    end
end)

fitPanelToViewport()

connectButton(toggleButton, function()
    setPanelVisible(not panel.Visible)
end)

connectButton(closeButton, function()
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
        local viewport = Workspace.CurrentCamera.ViewportSize
        local panelSize = panel.AbsoluteSize
        local newX = math.clamp(panelStart.X.Offset + delta.X, panelSize.X - viewport.X + CONFIG.MOBILE_PADDING, viewport.X - CONFIG.MOBILE_PADDING)
        local newY = math.clamp(panelStart.Y.Offset + delta.Y, 0, viewport.Y - panelSize.Y - CONFIG.MOBILE_PADDING)
        panel.Position = UDim2.new(
            panelStart.X.Scale,
            newX,
            panelStart.Y.Scale,
            newY
        )
    end
end)

-- Main update loop --------------------------------------------------------

refreshUI()

local elapsedUpdate = 0
local lastAimButtonSave = 0
local statsReapplyTimer = 0

RunService.Heartbeat:Connect(function(deltaTime)
    elapsedUpdate += deltaTime
    lastAimButtonSave += deltaTime
    statsReapplyTimer += deltaTime

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

        if aimButtonDragging and lastAimButtonSave >= 0.5 then
            lastAimButtonSave = 0
            saveState()
        end

        updateAimbotTarget()

        if isAimActivated() and aimbotTargetPart then
            aimAt(aimbotTargetPart)
            targetIndicator.Text = aimbotTarget and "Mirando: " .. aimbotTarget.DisplayName or ""
            targetIndicator.Visible = true
        else
            targetIndicator.Visible = false
        end
    else
        fovCircle.Visible = false
        targetIndicator.Visible = false
        aimButton.Visible = false
        aimButtonHeld = false
        state.aimActive = false
    end

    -- Auto-run: move forward automatically when enabled
    if state.autoRun and not state.flyEnabled then
        local autoRunChar = localPlayer.Character
        local autoRunHum = autoRunChar and getHumanoid(autoRunChar)
        if autoRunHum then
            autoRunHum:Move(Vector3.new(0, 0, -1), true)
        end
    end

    -- Re-apply character stats periodically in case the game resets them
    if statsReapplyTimer >= 0.1 then
        statsReapplyTimer = 0
        applyCharacterStats()
    end
end)

-- Cleanup on script destroy
local function cleanup()
    clearAllESP()
    disableFly()
    if gui then
        gui:Destroy()
    end
    espFolder:Destroy()
end

gui.Destroying:Connect(cleanup)
