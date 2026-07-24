--[[
╔══════════════════════════════════════════════════╗
║          DELTA MOD MENU — ESP EDITION            ║
║         Mobile-First • Delta Executor            ║
╚══════════════════════════════════════════════════╝
--]]

-- ═══════════════════════════════════════════════
--  SERVIÇOS
-- ═══════════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Camera           = workspace.CurrentCamera

local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════════
--  CONFIGURAÇÕES GLOBAIS
-- ═══════════════════════════════════════════════
local CFG = {
    -- Master
    ESPEnabled    = true,
    TeamCheck     = false,
    MaxDistance   = 500,

    -- Visuais
    Box2D         = true,
    Chams         = true,
    HeadDot       = true,
    Tracers       = true,
    TracerOrigin  = "Bottom",   -- "Bottom" | "Center"
    FillBox       = false,

    -- Informações
    NameTag       = true,
    HealthBar     = true,
    HealthText    = true,
    DistanceTag   = true,

    -- Cores predefinidas
    ColorPreset   = "Red",   -- Red | Blue | Green | Purple | White

    -- Câmera
    FOV           = 70,     -- 30 → 120

    -- Chams
    ChamTransparency = 0.55,
}

-- Paleta de cores
local PRESETS = {
    Red    = { Color3.fromRGB(255,  60,  60),  Color3.fromRGB(255,  60,  60) },
    Blue   = { Color3.fromRGB( 60, 120, 255),  Color3.fromRGB( 60, 120, 255) },
    Green  = { Color3.fromRGB( 60, 220,  80),  Color3.fromRGB( 60, 220,  80) },
    Purple = { Color3.fromRGB(180,  60, 255),  Color3.fromRGB(180,  60, 255) },
    White  = { Color3.fromRGB(240, 240, 240),  Color3.fromRGB(240, 240, 240) },
}

local function GetColor()   return PRESETS[CFG.ColorPreset][1] end
local function GetColor2()  return PRESETS[CFG.ColorPreset][2] end

-- ═══════════════════════════════════════════════
--  UTILIDADES
-- ═══════════════════════════════════════════════
local function IsAlive(p)
    if not p.Character then return false end
    local h = p.Character:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function GetDist(p)
    local c  = p.Character
    local mc = LP.Character
    if not c or not mc then return math.huge end
    local r  = c:FindFirstChild("HumanoidRootPart")
    local mr = mc:FindFirstChild("HumanoidRootPart")
    if not r or not mr then return math.huge end
    return (r.Position - mr.Position).Magnitude
end

local function W2S(pos)
    local sp, on = Camera:WorldToScreenPoint(pos)
    return Vector2.new(sp.X, sp.Y), on
end

local function GetBounds(char)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local hits = 0
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            local s = p.Size
            for _, cf in ipairs({
                p.CFrame*CFrame.new( s.X/2, s.Y/2, s.Z/2),
                p.CFrame*CFrame.new(-s.X/2, s.Y/2, s.Z/2),
                p.CFrame*CFrame.new( s.X/2,-s.Y/2, s.Z/2),
                p.CFrame*CFrame.new(-s.X/2,-s.Y/2, s.Z/2),
                p.CFrame*CFrame.new( s.X/2, s.Y/2,-s.Z/2),
                p.CFrame*CFrame.new(-s.X/2, s.Y/2,-s.Z/2),
                p.CFrame*CFrame.new( s.X/2,-s.Y/2,-s.Z/2),
                p.CFrame*CFrame.new(-s.X/2,-s.Y/2,-s.Z/2),
            }) do
                local sp, on = W2S(cf.Position)
                if on then
                    hits += 1
                    minX = math.min(minX, sp.X)
                    minY = math.min(minY, sp.Y)
                    maxX = math.max(maxX, sp.X)
                    maxY = math.max(maxY, sp.Y)
                end
            end
        end
    end
    if hits == 0 then return nil end
    return minX, minY, maxX, maxY
end

-- ═══════════════════════════════════════════════
--  DRAWING HELPERS
-- ═══════════════════════════════════════════════
local function DLine(c,t)
    local d = Drawing.new("Line")
    d.Visible = false; d.Color = c or Color3.new(1,1,1); d.Thickness = t or 1; d.ZIndex = 5
    return d
end
local function DSquare(c,t,f)
    local d = Drawing.new("Square")
    d.Visible = false; d.Color = c or Color3.new(1,1,1); d.Thickness = t or 1; d.Filled = f or false; d.ZIndex = 5
    return d
end
local function DCircle(c,t,f)
    local d = Drawing.new("Circle")
    d.Visible = false; d.Color = c or Color3.new(1,1,1); d.Thickness = t or 1; d.Filled = f or false; d.ZIndex = 5
    return d
end
local function DText(c,sz)
    local d = Drawing.new("Text")
    d.Visible = false; d.Color = c or Color3.new(1,1,1); d.Size = sz or 13
    d.Font = Drawing.Fonts.Plex; d.Outline = true; d.ZIndex = 6
    return d
end

-- ═══════════════════════════════════════════════
--  CHAMS
-- ═══════════════════════════════════════════════
local function ApplyChams(char)
    local old = char:FindFirstChild("_DESP_HL")
    if old then old:Destroy() end
    local hl = Instance.new("Highlight")
    hl.Name                = "_DESP_HL"
    hl.FillColor           = GetColor()
    hl.OutlineColor        = GetColor2()
    hl.FillTransparency    = CFG.ChamTransparency
    hl.OutlineTransparency = 0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent              = char
    return hl
end

local function RefreshAllChams()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hl = p.Character:FindFirstChild("_DESP_HL")
            if hl then
                hl.FillColor  = GetColor()
                hl.OutlineColor = GetColor2()
                hl.FillTransparency = CFG.ChamTransparency
            end
        end
    end
end

local function RemoveChams(char)
    local hl = char and char:FindFirstChild("_DESP_HL")
    if hl then hl:Destroy() end
end

-- ═══════════════════════════════════════════════
--  OBJETOS ESP POR PLAYER
-- ═══════════════════════════════════════════════
local Objects = {}

local function Make(p)
    if p == LP then return end
    Objects[p] = {
        BT = DLine(Color3.new(0,0,0), 2.5), BB = DLine(Color3.new(0,0,0), 2.5),
        BL = DLine(Color3.new(0,0,0), 2.5), BR = DLine(Color3.new(0,0,0), 2.5),
        CT = DLine(GetColor(), 1.5), CB = DLine(GetColor(), 1.5),
        CL = DLine(GetColor(), 1.5), CR = DLine(GetColor(), 1.5),
        BoxFill  = DSquare(GetColor(), 0, true),
        HPBack   = DSquare(Color3.new(0,0,0), 1, true),
        HPFront  = DSquare(Color3.fromRGB(0,255,0), 0, true),
        HPTxt    = DText(Color3.new(1,1,1), 11),
        Name     = DText(Color3.new(1,1,1), 13),
        Dist     = DText(Color3.fromRGB(200,200,200), 11),
        Tracer   = DLine(GetColor(), 1.5),
        HDot     = DCircle(GetColor(), 1, true),
        HRing    = DCircle(Color3.new(0,0,0), 2, false),
    }
end

local function Kill(p)
    local o = Objects[p]
    if not o then return end
    for _, v in pairs(o) do
        pcall(function() v:Remove() end)
    end
    if p.Character then RemoveChams(p.Character) end
    Objects[p] = nil
end

local function HideAll(o)
    for _, v in pairs(o) do v.Visible = false end
end

-- ═══════════════════════════════════════════════
--  RENDER
-- ═══════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    -- FOV da câmera
    Camera.FieldOfView = CFG.FOV

    for p, o in pairs(Objects) do
        if not CFG.ESPEnabled or not p or p == LP or not IsAlive(p) then
            HideAll(o); RemoveChams(p.Character); continue
        end
        if CFG.TeamCheck and p.Team == LP.Team then
            HideAll(o); RemoveChams(p.Character); continue
        end

        local char = p.Character
        local hum  = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        if not hum or not root then HideAll(o); continue end

        local dist = GetDist(p)
        if dist > CFG.MaxDistance then HideAll(o); continue end

        local minX, minY, maxX, maxY = GetBounds(char)
        if not minX then HideAll(o); continue end

        local pad = 4
        minX -= pad; minY -= pad; maxX += pad; maxY += pad
        local bW = maxX - minX
        local bH = maxY - minY
        local col = GetColor()

        -- Atualiza cor dos desenhos
        for _, k in ipairs({"CT","CB","CL","CR","Tracer","HDot"}) do
            o[k].Color = col
        end
        o.BoxFill.Color = col

        -- ── BOX ─────────────────────────────────
        if CFG.Box2D then
            local shadow = {
                {o.BT, minX, minY, maxX, minY},
                {o.BB, minX, maxY, maxX, maxY},
                {o.BL, minX, minY, minX, maxY},
                {o.BR, maxX, minY, maxX, maxY},
            }
            local color = {
                {o.CT, minX, minY, maxX, minY},
                {o.CB, minX, maxY, maxX, maxY},
                {o.CL, minX, minY, minX, maxY},
                {o.CR, maxX, minY, maxX, maxY},
            }
            for _, t in ipairs(shadow) do
                t[1].From = Vector2.new(t[2], t[3])
                t[1].To   = Vector2.new(t[4], t[5])
                t[1].Visible = true
            end
            for _, t in ipairs(color) do
                t[1].From = Vector2.new(t[2], t[3])
                t[1].To   = Vector2.new(t[4], t[5])
                t[1].Visible = true
            end

            if CFG.FillBox then
                o.BoxFill.Position   = Vector2.new(minX, minY)
                o.BoxFill.Size       = Vector2.new(bW, bH)
                o.BoxFill.Transparency = 0.75
                o.BoxFill.Visible    = true
            else
                o.BoxFill.Visible = false
            end
        else
            for _, k in ipairs({"BT","BB","BL","BR","CT","CB","CL","CR","BoxFill"}) do
                o[k].Visible = false
            end
        end

        -- ── NOME ─────────────────────────────────
        if CFG.NameTag then
            o.Name.Text     = p.Name
            o.Name.Position = Vector2.new(minX + bW/2, minY - 17)
            o.Name.Center   = true
            o.Name.Visible  = true
        else o.Name.Visible = false end

        -- ── DISTÂNCIA ────────────────────────────
        if CFG.DistanceTag then
            o.Dist.Text     = string.format("[%.0f m]", dist)
            o.Dist.Position = Vector2.new(minX + bW/2, maxY + 2)
            o.Dist.Center   = true
            o.Dist.Visible  = true
        else o.Dist.Visible = false end

        -- ── HP BAR ───────────────────────────────
        if CFG.HealthBar then
            local ratio   = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local bX      = minX - 7
            local fillH   = bH * ratio
            local hpCol   = Color3.fromRGB(
                math.floor(255*(1-ratio)), math.floor(255*ratio), 0)

            o.HPBack.Position  = Vector2.new(bX, minY)
            o.HPBack.Size      = Vector2.new(5, bH)
            o.HPBack.Visible   = true

            o.HPFront.Color    = hpCol
            o.HPFront.Position = Vector2.new(bX, minY + (bH - fillH))
            o.HPFront.Size     = Vector2.new(5, fillH)
            o.HPFront.Visible  = true

            if CFG.HealthText then
                o.HPTxt.Text     = tostring(math.floor(hum.Health))
                o.HPTxt.Position = Vector2.new(bX - 2, minY + (bH - fillH) - 1)
                o.HPTxt.Center   = false
                o.HPTxt.Visible  = true
            else o.HPTxt.Visible = false end
        else
            o.HPBack.Visible = false
            o.HPFront.Visible = false
            o.HPTxt.Visible  = false
        end

        -- ── TRACER ───────────────────────────────
        if CFG.Tracers then
            local vp   = Camera.ViewportSize
            local from = CFG.TracerOrigin == "Center"
                and Vector2.new(vp.X/2, vp.Y/2)
                or  Vector2.new(vp.X/2, vp.Y)
            o.Tracer.From    = from
            o.Tracer.To      = Vector2.new(minX + bW/2, maxY)
            o.Tracer.Visible = true
        else o.Tracer.Visible = false end

        -- ── HEAD DOT ─────────────────────────────
        if CFG.HeadDot and head then
            local hp, on = W2S(head.Position)
            if on then
                local r = math.clamp(50/dist, 3, 14)
                o.HRing.Position = hp; o.HRing.Radius = r + 1; o.HRing.Visible = true
                o.HDot.Position  = hp; o.HDot.Radius  = r;     o.HDot.Visible  = true
            else o.HDot.Visible = false; o.HRing.Visible = false end
        else o.HDot.Visible = false; o.HRing.Visible = false end

        -- ── CHAMS ────────────────────────────────
        if CFG.Chams then
            if not char:FindFirstChild("_DESP_HL") then ApplyChams(char) end
        else RemoveChams(char) end
    end
end)

-- ═══════════════════════════════════════════════
--  PLAYERS
-- ═══════════════════════════════════════════════
for _, p in ipairs(Players:GetPlayers()) do task.spawn(Make, p) end
Players.PlayerAdded:Connect(function(p)
    Make(p)
    p.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if CFG.Chams and Objects[p] then ApplyChams(char) end
    end)
end)
Players.PlayerRemoving:Connect(function(p)
    task.delay(0.5, function() Kill(p) end)
end)
for _, p in ipairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if CFG.Chams and Objects[p] then ApplyChams(char) end
    end)
end

-- ═══════════════════════════════════════════════
--  ███████╗ GUI MOBILE MOD MENU
-- ═══════════════════════════════════════════════
local GUI = Instance.new("ScreenGui")
GUI.Name             = "DeltaModMenu"
GUI.ResetOnSpawn     = false
GUI.IgnoreGuiInset   = true
GUI.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
GUI.Parent           = (gethui and gethui()) or game.CoreGui

-- ────────────────────────────────────────────────
-- CONSTANTES DE ESTILO
-- ────────────────────────────────────────────────
local C = {
    BG       = Color3.fromRGB(12, 12, 18),
    Panel    = Color3.fromRGB(20, 20, 30),
    Card     = Color3.fromRGB(28, 28, 42),
    Accent   = Color3.fromRGB(220, 40,  40),
    Accent2  = Color3.fromRGB(255, 90,  90),
    Text     = Color3.fromRGB(240, 240, 240),
    SubText  = Color3.fromRGB(160, 160, 180),
    On       = Color3.fromRGB(220, 40,  40),
    Off      = Color3.fromRGB(55, 55, 70),
    SliderBG = Color3.fromRGB(38, 38, 55),
    SliderFG = Color3.fromRGB(220, 40,  40),
}

-- ────────────────────────────────────────────────
-- JANELA PRINCIPAL
-- ────────────────────────────────────────────────
local WIN_W, WIN_H = 300, 480

local Win = Instance.new("Frame")
Win.Name              = "Window"
Win.Size              = UDim2.new(0, WIN_W, 0, WIN_H)
Win.Position          = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
Win.BackgroundColor3  = C.BG
Win.BorderSizePixel   = 0
Win.ClipsDescendants  = true
Win.Parent            = GUI
Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 16)

-- Stroke
local WinStroke = Instance.new("UIStroke")
WinStroke.Color       = C.Accent
WinStroke.Thickness   = 1.5
WinStroke.Transparency = 0.5
WinStroke.Parent      = Win

-- ────────────────────────────────────────────────
-- HEADER
-- ────────────────────────────────────────────────
local Header = Instance.new("Frame")
Header.Size             = UDim2.new(1, 0, 0, 54)
Header.BackgroundColor3 = C.Panel
Header.BorderSizePixel  = 0
Header.Parent           = Win
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 16)

-- Fix cantos inferiores do header
local HeaderFix = Instance.new("Frame")
HeaderFix.Size             = UDim2.new(1, 0, 0.5, 0)
HeaderFix.Position         = UDim2.new(0, 0, 0.5, 0)
HeaderFix.BackgroundColor3 = C.Panel
HeaderFix.BorderSizePixel  = 0
HeaderFix.Parent           = Header

-- Acento lateral esquerdo
local AccentBar = Instance.new("Frame")
AccentBar.Size            = UDim2.new(0, 4, 0, 28)
AccentBar.Position        = UDim2.new(0, 14, 0.5, -14)
AccentBar.BackgroundColor3 = C.Accent
AccentBar.BorderSizePixel  = 0
AccentBar.Parent          = Header
Instance.new("UICorner", AccentBar).CornerRadius = UDim.new(1, 0)

-- Título
local Title = Instance.new("TextLabel")
Title.Size             = UDim2.new(1, -110, 1, 0)
Title.Position         = UDim2.new(0, 28, 0, 0)
Title.BackgroundTransparency = 1
Title.Text             = "Delta ESP"
Title.TextColor3       = C.Text
Title.TextSize         = 17
Title.Font             = Enum.Font.GothamBold
Title.TextXAlignment   = Enum.TextXAlignment.Left
Title.Parent           = Header

-- Sub-label
local Sub = Instance.new("TextLabel")
Sub.Size               = UDim2.new(1, -110, 0, 14)
Sub.Position           = UDim2.new(0, 28, 1, -18)
Sub.BackgroundTransparency = 1
Sub.Text               = "Mod Menu • Mobile"
Sub.TextColor3         = C.SubText
Sub.TextSize           = 11
Sub.Font               = Enum.Font.Gotham
Sub.TextXAlignment     = Enum.TextXAlignment.Left
Sub.Parent             = Header

-- Botão FECHAR / ABRIR
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size              = UDim2.new(0, 38, 0, 38)
CloseBtn.Position          = UDim2.new(1, -48, 0.5, -19)
CloseBtn.BackgroundColor3  = C.Accent
CloseBtn.Text              = "✕"
CloseBtn.TextColor3        = Color3.new(1,1,1)
CloseBtn.TextSize          = 18
CloseBtn.Font              = Enum.Font.GothamBold
CloseBtn.BorderSizePixel   = 0
CloseBtn.ZIndex            = 5
CloseBtn.Parent            = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1, 0)

-- ────────────────────────────────────────────────
-- TABS
-- ────────────────────────────────────────────────
local TabRow = Instance.new("Frame")
TabRow.Size             = UDim2.new(1, 0, 0, 40)
TabRow.Position         = UDim2.new(0, 0, 0, 54)
TabRow.BackgroundColor3 = C.Panel
TabRow.BorderSizePixel  = 0
TabRow.Parent           = Win

local TabFix = Instance.new("Frame")
TabFix.Size             = UDim2.new(1, 0, 0.5, 0)
TabFix.BackgroundColor3 = C.Panel
TabFix.BorderSizePixel  = 0
TabFix.Parent           = TabRow

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection        = Enum.FillDirection.Horizontal
TabLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Center
TabLayout.VerticalAlignment    = Enum.VerticalAlignment.Center
TabLayout.Padding              = UDim.new(0, 6)
TabLayout.Parent               = TabRow

-- ────────────────────────────────────────────────
-- SCROLL CONTENT
-- ────────────────────────────────────────────────
local Content = Instance.new("ScrollingFrame")
Content.Name                  = "Content"
Content.Size                  = UDim2.new(1, 0, 1, -98)
Content.Position              = UDim2.new(0, 0, 0, 98)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness    = 0
Content.CanvasSize            = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize   = Enum.AutomaticSize.Y
Content.Parent                = Win

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding          = UDim.new(0, 8)
ContentLayout.SortOrder        = Enum.SortOrder.LayoutOrder
ContentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ContentLayout.Parent           = Content

local ContentPad = Instance.new("UIPadding")
ContentPad.PaddingTop     = UDim.new(0, 10)
ContentPad.PaddingBottom  = UDim.new(0, 16)
ContentPad.PaddingLeft    = UDim.new(0, 12)
ContentPad.PaddingRight   = UDim.new(0, 12)
ContentPad.Parent         = Content

-- ════════════════════════════════════════════════
-- COMPONENTES DE UI
-- ════════════════════════════════════════════════

-- ── TOGGLE SWITCH ────────────────────────────────
local function MakeToggle(parent, label, sublabel, flagKey, order, onChange)
    local row = Instance.new("Frame")
    row.Size              = UDim2.new(1, 0, 0, sublabel and 52 or 44)
    row.BackgroundColor3  = C.Card
    row.BorderSizePixel   = 0
    row.LayoutOrder       = order
    row.Parent            = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1, -66, 0, 20)
    lbl.Position         = UDim2.new(0, 14, 0, sublabel and 8 or 12)
    lbl.BackgroundTransparency = 1
    lbl.Text             = label
    lbl.TextColor3       = C.Text
    lbl.TextSize         = 13
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = row

    if sublabel then
        local sub = Instance.new("TextLabel")
        sub.Size              = UDim2.new(1, -66, 0, 14)
        sub.Position          = UDim2.new(0, 14, 0, 28)
        sub.BackgroundTransparency = 1
        sub.Text              = sublabel
        sub.TextColor3        = C.SubText
        sub.TextSize          = 11
        sub.Font              = Enum.Font.Gotham
        sub.TextXAlignment    = Enum.TextXAlignment.Left
        sub.Parent            = row
    end

    local switchBG = Instance.new("Frame")
    switchBG.Size            = UDim2.new(0, 46, 0, 26)
    switchBG.Position        = UDim2.new(1, -58, 0.5, -13)
    switchBG.BackgroundColor3 = CFG[flagKey] and C.On or C.Off
    switchBG.BorderSizePixel = 0
    switchBG.Parent          = row
    Instance.new("UICorner", switchBG).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size             = UDim2.new(0, 22, 0, 22)
    knob.Position         = CFG[flagKey]
        and UDim2.new(1, -24, 0.5, -11)
        or  UDim2.new(0,   2, 0.5, -11)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 2
    knob.Parent           = switchBG
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local function Refresh()
        local v = CFG[flagKey]
        TweenService:Create(switchBG, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
            BackgroundColor3 = v and C.On or C.Off
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.14, Enum.EasingStyle.Quad), {
            Position = v and UDim2.new(1,-24,0.5,-11) or UDim2.new(0,2,0.5,-11)
        }):Play()
    end

    local hit = Instance.new("TextButton")
    hit.Size              = UDim2.new(1,0,1,0)
    hit.BackgroundTransparency = 1
    hit.Text              = ""
    hit.ZIndex            = 3
    hit.Parent            = row

    hit.MouseButton1Click:Connect(function()
        CFG[flagKey] = not CFG[flagKey]
        Refresh()
        if onChange then onChange(CFG[flagKey]) end
    end)

    return row
end

-- ── SLIDER ───────────────────────────────────────
local function MakeSlider(parent, label, min, max, key, decimals, suffix, order, onChange)
    local h = 66
    local card = Instance.new("Frame")
    card.Size             = UDim2.new(1, 0, 0, h)
    card.BackgroundColor3 = C.Card
    card.BorderSizePixel  = 0
    card.LayoutOrder      = order
    card.Parent           = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1, -80, 0, 18)
    lbl.Position         = UDim2.new(0, 14, 0, 10)
    lbl.BackgroundTransparency = 1
    lbl.Text             = label
    lbl.TextColor3       = C.Text
    lbl.TextSize         = 13
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = card

    local valLbl = Instance.new("TextLabel")
    valLbl.Size           = UDim2.new(0, 72, 0, 18)
    valLbl.Position       = UDim2.new(1, -82, 0, 10)
    valLbl.BackgroundTransparency = 1
    valLbl.TextColor3     = C.Accent2
    valLbl.TextSize       = 13
    valLbl.Font           = Enum.Font.GothamBold
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent         = card

    -- Track
    local track = Instance.new("Frame")
    track.Size            = UDim2.new(1, -28, 0, 6)
    track.Position        = UDim2.new(0, 14, 0, 42)
    track.BackgroundColor3 = C.SliderBG
    track.BorderSizePixel = 0
    track.Parent          = card
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    -- Fill
    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = C.SliderFG
    fill.BorderSizePixel  = 0
    fill.Parent           = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    -- Knob
    local knob = Instance.new("Frame")
    knob.Size             = UDim2.new(0, 18, 0, 18)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel  = 0
    knob.ZIndex           = 3
    knob.Parent           = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    Instance.new("UIStroke", knob).Color = C.Accent

    local function SetVal(v)
        v = math.clamp(v, min, max)
        if not decimals or decimals == 0 then v = math.round(v) end
        CFG[key] = v

        local pct = (v - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, -9, 0.5, -9)

        local fmt = decimals and decimals > 0 and ("%." .. decimals .. "f") or "%d"
        valLbl.Text = string.format(fmt, v) .. (suffix or "")
        if onChange then onChange(v) end
    end

    -- Init
    SetVal(CFG[key])

    -- Drag
    local dragging = false
    local function CalcVal(inputX)
        local abs = track.AbsolutePosition.X
        local sz  = track.AbsoluteSize.X
        local pct = math.clamp((inputX - abs) / sz, 0, 1)
        SetVal(min + (max - min) * pct)
    end

    local hitBox = Instance.new("TextButton")
    hitBox.Size              = UDim2.new(1, 0, 0, 30)
    hitBox.Position          = UDim2.new(0, 0, 0, 30)
    hitBox.BackgroundTransparency = 1
    hitBox.Text              = ""
    hitBox.ZIndex            = 4
    hitBox.Parent            = card

    hitBox.MouseButton1Down:Connect(function(x) dragging = true; CalcVal(x) end)
    hitBox.TouchLongPress:Connect(function() dragging = true end)

    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        local t = inp.UserInputType
        if t == Enum.UserInputType.MouseMovement then CalcVal(inp.Position.X) end
        if t == Enum.UserInputType.Touch then CalcVal(inp.Position.X) end
    end)
    UserInputService.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return card
end

-- ── SECTION HEADER ───────────────────────────────
local function MakeSec(parent, text, order)
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1, 0, 0, 24)
    f.BackgroundTransparency = 1
    f.LayoutOrder      = order
    f.Parent           = parent

    local line = Instance.new("Frame")
    line.Size            = UDim2.new(1, 0, 0, 1)
    line.Position        = UDim2.new(0, 0, 0.5, 0)
    line.BackgroundColor3 = Color3.fromRGB(50, 20, 20)
    line.BorderSizePixel = 0
    line.Parent          = f

    local bg = Instance.new("Frame")
    bg.Size              = UDim2.new(0, 0, 1, 0)
    bg.Position          = UDim2.new(0, 0, 0, 0)
    bg.BackgroundColor3  = C.BG
    bg.AutomaticSize     = Enum.AutomaticSize.X
    bg.BorderSizePixel   = 0
    bg.Parent            = f

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(0, 0, 1, 0)
    lbl.AutomaticSize    = Enum.AutomaticSize.X
    lbl.BackgroundTransparency = 1
    lbl.Text             = "  " .. text .. "  "
    lbl.TextColor3       = C.Accent
    lbl.TextSize         = 11
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = bg
end

-- ── PRESET SELETOR DE COR ────────────────────────
local function MakeColorPicker(parent, order)
    local card = Instance.new("Frame")
    card.Size             = UDim2.new(1, 0, 0, 62)
    card.BackgroundColor3 = C.Card
    card.BorderSizePixel  = 0
    card.LayoutOrder      = order
    card.Parent           = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1, 0, 0, 20)
    lbl.Position         = UDim2.new(0, 14, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.Text             = "Cor do ESP"
    lbl.TextColor3       = C.Text
    lbl.TextSize         = 13
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = card

    local row = Instance.new("Frame")
    row.Size              = UDim2.new(1, -28, 0, 26)
    row.Position          = UDim2.new(0, 14, 0, 30)
    row.BackgroundTransparency = 1
    row.Parent            = card

    local rl = Instance.new("UIListLayout")
    rl.FillDirection       = Enum.FillDirection.Horizontal
    rl.Padding             = UDim.new(0, 8)
    rl.VerticalAlignment   = Enum.VerticalAlignment.Center
    rl.Parent              = row

    local presetOrder = {"Red","Blue","Green","Purple","White"}
    local dots = {}

    for _, name in ipairs(presetOrder) do
        local dot = Instance.new("TextButton")
        dot.Size              = UDim2.new(0, 26, 0, 26)
        dot.BackgroundColor3  = PRESETS[name][1]
        dot.Text              = ""
        dot.BorderSizePixel   = 0
        dot.Parent            = row
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local stroke = Instance.new("UIStroke")
        stroke.Color     = Color3.new(1,1,1)
        stroke.Thickness = CFG.ColorPreset == name and 2.5 or 0
        stroke.Parent    = dot

        dots[name] = stroke

        dot.MouseButton1Click:Connect(function()
            CFG.ColorPreset = name
            for n, s in pairs(dots) do
                s.Thickness = n == name and 2.5 or 0
            end
            RefreshAllChams()
        end)
    end
end

-- ── TRACER ORIGIN PICKER ─────────────────────────
local function MakeTracerPicker(parent, order)
    local card = Instance.new("Frame")
    card.Size             = UDim2.new(1, 0, 0, 62)
    card.BackgroundColor3 = C.Card
    card.BorderSizePixel  = 0
    card.LayoutOrder      = order
    card.Parent           = parent
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Size             = UDim2.new(1, 0, 0, 20)
    lbl.Position         = UDim2.new(0, 14, 0, 8)
    lbl.BackgroundTransparency = 1
    lbl.Text             = "Origem do Tracer"
    lbl.TextColor3       = C.Text
    lbl.TextSize         = 13
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.Parent           = card

    local opts = {"Bottom", "Center"}
    local btns = {}

    for i, opt in ipairs(opts) do
        local btn = Instance.new("TextButton")
        btn.Size              = UDim2.new(0, 110, 0, 26)
        btn.Position          = UDim2.new(0, 14 + (i-1)*120, 0, 30)
        btn.BackgroundColor3  = CFG.TracerOrigin == opt and C.Accent or C.SliderBG
        btn.Text              = opt
        btn.TextColor3        = Color3.new(1,1,1)
        btn.TextSize          = 12
        btn.Font              = Enum.Font.GothamBold
        btn.BorderSizePixel   = 0
        btn.Parent            = card
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        btns[opt] = btn

        btn.MouseButton1Click:Connect(function()
            CFG.TracerOrigin = opt
            for o, b in pairs(btns) do
                b.BackgroundColor3 = o == opt and C.Accent or C.SliderBG
            end
        end)
    end
end

-- ════════════════════════════════════════════════
-- TABS SETUP
-- ════════════════════════════════════════════════
local Pages = {}
local TabBtns = {}
local ActiveTab = nil

local TAB_DATA = {
    {name = "ESP",     icon = "◈"},
    {name = "Câmera",  icon = "◉"},
    {name = "Cores",   icon = "◍"},
}

local function SwitchTab(name)
    if ActiveTab == name then return end
    ActiveTab = name

    for n, page in pairs(Pages) do
        page.Visible = n == name
    end
    for n, btn in pairs(TabBtns) do
        local on = n == name
        TweenService:Create(btn, TweenInfo.new(0.12), {
            BackgroundColor3 = on and C.Accent or C.SliderBG,
            TextColor3       = on and Color3.new(1,1,1) or C.SubText
        }):Play()
    end
end

-- Cria tabs + páginas
for _, td in ipairs(TAB_DATA) do
    -- Botão tab
    local tbtn = Instance.new("TextButton")
    tbtn.Size              = UDim2.new(0, 82, 0, 28)
    tbtn.BackgroundColor3  = C.SliderBG
    tbtn.Text              = td.icon .. " " .. td.name
    tbtn.TextColor3        = C.SubText
    tbtn.TextSize          = 12
    tbtn.Font              = Enum.Font.GothamBold
    tbtn.BorderSizePixel   = 0
    tbtn.Parent            = TabRow
    Instance.new("UICorner", tbtn).CornerRadius = UDim.new(0, 8)
    TabBtns[td.name] = tbtn

    -- Página
    local page = Instance.new("Frame")
    page.Name              = td.name
    page.Size              = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible           = false
    page.Parent            = Content
    Pages[td.name] = page

    local pageList = Instance.new("UIListLayout")
    pageList.Padding               = UDim.new(0, 8)
    pageList.SortOrder             = Enum.SortOrder.LayoutOrder
    pageList.HorizontalAlignment   = Enum.HorizontalAlignment.Center
    pageList.Parent                = page

    tbtn.MouseButton1Click:Connect(function() SwitchTab(td.name) end)
end

-- Desabilita layout do Content para que as páginas sobreponham
ContentLayout:Destroy()
Content.AutomaticCanvasSize = Enum.AutomaticSize.None
Content.CanvasSize = UDim2.new(0, 0, 0, 0)

-- Cada página tem seu próprio scroll
local function MakePage(name)
    local outer = Instance.new("ScrollingFrame")
    outer.Name                  = name .. "_scroll"
    outer.Size                  = UDim2.new(1, 0, 1, 0)
    outer.BackgroundTransparency = 1
    outer.ScrollBarThickness    = 0
    outer.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    outer.CanvasSize            = UDim2.new(0, 0, 0, 0)
    outer.Visible               = false
    outer.Parent                = Content

    local layout = Instance.new("UIListLayout")
    layout.Padding              = UDim.new(0, 8)
    layout.SortOrder            = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment  = Enum.HorizontalAlignment.Center
    layout.Parent               = outer

    local pad = Instance.new("UIPadding")
    pad.PaddingTop    = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 20)
    pad.PaddingLeft   = UDim.new(0, 12)
    pad.PaddingRight  = UDim.new(0, 12)
    pad.Parent        = outer

    return outer
end

-- Destrói as páginas Frame vazias e recria como ScrollingFrame
for _, td in ipairs(TAB_DATA) do
    Pages[td.name]:Destroy()
end

local P = {}
for _, td in ipairs(TAB_DATA) do
    P[td.name] = MakePage(td.name)
    TabBtns[td.name].MouseButton1Click:Connect(function()
        ActiveTab = td.name
        for n, pg in pairs(P) do
            pg.Visible = n == td.name
        end
        for n, btn in pairs(TabBtns) do
            local on = n == td.name
            TweenService:Create(btn, TweenInfo.new(0.12), {
                BackgroundColor3 = on and C.Accent or C.SliderBG,
                TextColor3       = on and Color3.new(1,1,1) or C.SubText
            }):Play()
        end
    end)
end

-- Ativa tab inicial
local function ActivateFirst()
    local first = TAB_DATA[1].name
    ActiveTab = first
    P[first].Visible = true
    TabBtns[first].BackgroundColor3 = C.Accent
    TabBtns[first].TextColor3 = Color3.new(1,1,1)
end

-- ════════════════════════════════════════════════
-- CONTEÚDO DAS TABS
-- ════════════════════════════════════════════════

-- ── ABA: ESP ─────────────────────────────────────
local esp = P["ESP"]

MakeSec(esp, "GERAL", 0)
MakeToggle(esp, "ESP Ligado",  "Ativa/desativa todo o ESP", "ESPEnabled", 1)
MakeToggle(esp, "Team Check",  "Ignora jogadores do seu time", "TeamCheck",  2)
MakeSlider(esp, "Distância Máxima", 50, 1000, "MaxDistance", 0, " m", 3)

MakeSec(esp, "VISUAIS", 10)
MakeToggle(esp, "Box 2D",      "Caixa ao redor do player", "Box2D",   11)
MakeToggle(esp, "Preencher Box", "Box com fundo semitransparente", "FillBox", 12)
MakeToggle(esp, "Chams",       "Destaque através das paredes", "Chams",  13)
MakeToggle(esp, "Head Dot",    "Ponto na cabeça do player", "HeadDot", 14)
MakeToggle(esp, "Tracers",     "Linha da tela até o player", "Tracers", 15)
MakeTracerPicker(esp, 16)

MakeSec(esp, "INFORMAÇÕES", 20)
MakeToggle(esp, "Nome",        nil,  "NameTag",    21)
MakeToggle(esp, "Barra de HP", nil,  "HealthBar",  22)
MakeToggle(esp, "Texto de HP", nil,  "HealthText", 23)
MakeToggle(esp, "Distância",   nil,  "DistanceTag",24)

-- ── ABA: CÂMERA ──────────────────────────────────
local cam = P["Câmera"]
MakeSec(cam, "CAMPO DE VISÃO", 0)
MakeSlider(cam, "FOV da Câmera", 30, 120, "FOV", 0, "°", 1)

MakeSec(cam, "CHAMS", 10)
MakeSlider(cam, "Transparência Chams", 0, 0.95, "ChamTransparency", 2, "", 11, function()
    RefreshAllChams()
end)

-- ── ABA: CORES ───────────────────────────────────
local col = P["Cores"]
MakeSec(col, "PRESET DE CORES", 0)
MakeColorPicker(col, 1)

-- ════════════════════════════════════════════════
-- DRAG DA JANELA
-- ════════════════════════════════════════════════
local dragging, dragStart, winStart = false, nil, nil

Header.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging  = true
        dragStart = inp.Position
        winStart  = Win.Position
    end
end)

UserInputService.InputChanged:Connect(function(inp)
    if not dragging then return end
    if inp.UserInputType ~= Enum.UserInputType.Touch
    and inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local delta = inp.Position - dragStart
    local vp    = GUI.AbsoluteSize
    local nx    = math.clamp(winStart.X.Offset + delta.X, 0, vp.X - WIN_W)
    local ny    = math.clamp(winStart.Y.Offset + delta.Y, 0, vp.Y - WIN_H)
    Win.Position = UDim2.new(0, nx, 0, ny)
end)

UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.Touch
    or inp.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- ════════════════════════════════════════════════
-- FECHAR / REABRIR
-- ════════════════════════════════════════════════
local contentArea = Instance.new("Frame")
contentArea.Name              = "ContentArea"
contentArea.Size              = UDim2.new(1, 0, 1, -54)
contentArea.Position          = UDim2.new(0, 0, 0, 54)
contentArea.BackgroundTransparency = 1
contentArea.ClipsDescendants  = true
contentArea.Parent            = Win

-- Move o TabRow e o Content para dentro do contentArea
TabRow.Parent  = contentArea
Content.Parent = contentArea

-- Muda a posição
TabRow.Position  = UDim2.new(0, 0, 0, 0)
Content.Position = UDim2.new(0, 0, 0, 40)
Content.Size     = UDim2.new(1, 0, 1, -40)

local open = true

CloseBtn.MouseButton1Click:Connect(function()
    open = not open
    TweenService:Create(Win, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = open
            and UDim2.new(0, WIN_W, 0, WIN_H)
            or  UDim2.new(0, WIN_W, 0, 54)
    }):Play()
    CloseBtn.Text = open and "✕" or "☰"
end)

-- ════════════════════════════════════════════════
-- BOTÃO FLUTUANTE (quando menu fechado ou minimizado)
-- ════════════════════════════════════════════════
local FAB = Instance.new("TextButton")
FAB.Size             = UDim2.new(0, 48, 0, 48)
FAB.Position         = UDim2.new(1, -60, 1, -100)
FAB.BackgroundColor3 = C.Accent
FAB.Text             = "ESP"
FAB.TextColor3       = Color3.new(1,1,1)
FAB.TextSize         = 12
FAB.Font             = Enum.Font.GothamBold
FAB.BorderSizePixel  = 0
FAB.ZIndex           = 10
FAB.Visible          = false
FAB.Parent           = GUI
Instance.new("UICorner", FAB).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", FAB).Color = Color3.fromRGB(255, 100, 100)

FAB.MouseButton1Click:Connect(function()
    Win.Visible = true
    FAB.Visible = false
end)

-- Botão minimizar (esconde a janela, mostra FAB)
local MinBtn = Instance.new("TextButton")
MinBtn.Size             = UDim2.new(0, 38, 0, 38)
MinBtn.Position         = UDim2.new(1, -90, 0.5, -19)
MinBtn.BackgroundColor3 = C.SliderBG
MinBtn.Text             = "—"
MinBtn.TextColor3       = C.SubText
MinBtn.TextSize         = 16
MinBtn.Font             = Enum.Font.GothamBold
MinBtn.BorderSizePixel  = 0
MinBtn.ZIndex           = 5
MinBtn.Parent           = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(1, 0)

MinBtn.MouseButton1Click:Connect(function()
    Win.Visible = false
    FAB.Visible = true
end)

-- ════════════════════════════════════════════════
-- CONTADOR AO VIVO
-- ════════════════════════════════════════════════
task.spawn(function()
    while task.wait(1) do
        local n = 0
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and IsAlive(p) then n += 1 end
        end
        Title.Text = "Delta ESP  [" .. n .. "]"
    end
end)

-- ════════════════════════════════════════════════
-- INICIA
-- ════════════════════════════════════════════════
ActivateFirst()

print("✅ [Delta Mod Menu] Carregado! Arraste o painel para mover.")
