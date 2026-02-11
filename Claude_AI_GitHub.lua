-- CLAUDE AI v7.2 [GITHUB VERSION]
-- https://github.com/[TU_USUARIO]/Claude-AI
-- Ejecutar con: loadstring(game:HttpGet("https://raw.githubusercontent.com/[TU_USUARIO]/Claude-AI/main/Claude_AI_v7.2.lua"))()

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Drawing = Drawing or require("Drawing")

-- [CONFIGURACIÓN]
local config = {
    aimLock = false,
    magicBullet = false,
    esp = true,
    fov = 120,
    hitboxSize = 6,
    maxTargetDistance = 3000,
    mode = "Balanceado",
    smoothness = 0.2,
    isSoloMode = true,
    bulletVel = 2500
}

local colors = {
    enemy = Color3.fromRGB(255, 40, 40),
    ally = Color3.fromRGB(40, 150, 255),
    target = Color3.fromRGB(255, 215, 0),
    accent = Color3.fromRGB(0, 200, 255),
    off = Color3.fromRGB(180, 180, 180),
    guiBg = Color3.fromRGB(15, 15, 20)
}

-- Variables Globales UI
local MainFrame, AimBtn, ModeBtn, MagicBtn, SoloBtn

-- Variables Lógicas
local aimLockActive = false
local targetPlayer = nil
local espTexts = {}
local originalSizes = {}
local fovCircle = Drawing.new("Circle")

-- [DETECCIÓN AVANZADA DE ZONAS]

local function getBodyParts(character)
    if not character then return nil, nil end
    local head = character:FindFirstChild("Head")
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    return head, torso
end

local function isAliveAndInMap(player)
    if not player or not player.Character then return false end
    
    local character = player.Character
    local humanoid = character:FindFirstChild("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    
    if not humanoid or not root then return false end
    if humanoid.Health <= 0 then return false end
    
    if root.Parent and root.Parent.Parent == game:GetService("ReplicatedStorage") then
        return false
    end
    
    if character.Name == "Corpse" or character.Name == "Ghost" or character.Name == "Dead" then
        return false
    end
    
    local bodyPartCount = 0
    for _, part in pairs(character:GetChildren()) do
        if part:IsA("BasePart") then
            bodyPartCount = bodyPartCount + 1
        end
    end
    if bodyPartCount < 3 then
        return false
    end
    
    return true
end

local function isSameGameZone(player)
    if not player or not player.Character then return false end
    if not LocalPlayer.Character then return false end
    
    local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local playerRoot = player.Character:FindFirstChild("HumanoidRootPart")
    
    if not myRoot or not playerRoot then return false end
    
    local horizontalDist = math.sqrt(
        (myRoot.Position.X - playerRoot.Position.X)^2 + 
        (myRoot.Position.Z - playerRoot.Position.Z)^2
    )
    
    if horizontalDist > 5000 then
        return false
    end
    
    local verticalDiff = math.abs(myRoot.Position.Y - playerRoot.Position.Y)
    if verticalDiff > 200 then
        return false
    end
    
    if not myRoot:IsDescendantOf(workspace) or not playerRoot:IsDescendantOf(workspace) then
        return false
    end
    
    return true
end

-- [SISTEMA DE UI]
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ClaudeUI_v7.2"
ScreenGui.Parent = game.CoreGui

MainFrame = Instance.new("Frame")
MainFrame.Parent = ScreenGui
MainFrame.BackgroundColor3 = colors.guiBg
MainFrame.Position = UDim2.new(0, 50, 0, 350)
MainFrame.Size = UDim2.new(0, 230, 0, 320)
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Position = UDim2.new(0, 0, 0, 10)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Font = Enum.Font.GothamBlack
Title.Text = "CLAUDE AI v7.2"
Title.TextColor3 = colors.accent
Title.TextSize = 22

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Parent = MainFrame
StatusLabel.BackgroundTransparency = 1
StatusLabel.Position = UDim2.new(0, 0, 0.75, 0)
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.Text = "🟢 ZONE DETECT ACTIVE"
StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
StatusLabel.TextSize = 12

local function createBtn(text, order, callback)
    local btn = Instance.new("TextButton")
    btn.Parent = MainFrame
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    btn.Position = UDim2.new(0.1, 0, 0.15 + (order * 0.15), 0)
    btn.Size = UDim2.new(0.8, 0, 0.12, 0)
    btn.Font = Enum.Font.GothamBold
    btn.Text = text
    btn.TextColor3 = colors.off
    btn.TextSize = 14
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

AimBtn = createBtn("Aimlock: OFF [X]", 0, function() config.aimLock = not config.aimLock end)
ModeBtn = createBtn("Modo: Balanceado", 1, function()
    if config.mode == "Balanceado" then
        config.mode = "Descarado"; config.smoothness = 1; config.fov = 250; config.hitboxSize = 8
    else
        config.mode = "Balanceado"; config.smoothness = 0.2; config.fov = 120; config.hitboxSize = 6
    end
end)
MagicBtn = createBtn("Magic Hitbox: OFF [F2]", 2, function() config.magicBullet = not config.magicBullet end)
SoloBtn = createBtn("Solo Mode: ON [Z]", 3, function() config.isSoloMode = not config.isSoloMode end)

-- [LÓGICA INTERNA]

local function removeESP(player)
    if espTexts[player] then
        espTexts[player].Visible = false
        espTexts[player]:Remove()
        espTexts[player] = nil
    end
    originalSizes[player] = nil
end

local function onCharacterAdded(player)
    wait(0.1)
    
    if player.Character and originalSizes[player] then
        local head, torso = getBodyParts(player.Character)
        if head and originalSizes[player].head then
            head.Size = originalSizes[player].head
            head.Transparency = 0
            head.CanCollide = true
            head.Massless = false
        end
        if torso and originalSizes[player].torso then
            torso.Size = originalSizes[player].torso
            torso.Transparency = 0
            torso.CanCollide = true
            torso.Massless = false
        end
    end
    
    originalSizes[player] = nil
end

Players.PlayerRemoving:Connect(removeESP)

for _, p in pairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function() onCharacterAdded(p) end)
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function() onCharacterAdded(p) end)
end)

local function getRelationship(player)
    if player == LocalPlayer then return "SELF" end
    if config.isSoloMode then return "ENEMY" end
    if player.Team and LocalPlayer.Team then
        return (player.Team == LocalPlayer.Team) and "ALLY" or "ENEMY"
    end
    return (player.TeamColor == LocalPlayer.TeamColor) and "ALLY" or "ENEMY"
end

local function isValidTarget(player)
    if not player or player == LocalPlayer then return false end
    
    if not isAliveAndInMap(player) then return false end
    
    if not isSameGameZone(player) then return false end
    
    local head = player.Character:FindFirstChild("Head")
    if not head then return false end
    
    return true
end

-- [MAGIC BULLET MEJORADO]
local function expandHitbox(player)
    if not isAliveAndInMap(player) then return end
    if not player.Character then return end
    
    local head, torso = getBodyParts(player.Character)
    
    if head and head:IsA("BasePart") then
        if not originalSizes[player] then
            originalSizes[player] = {}
        end
        if not originalSizes[player].head then
            originalSizes[player].head = head.Size
        end
        
        head.Size = Vector3.new(config.hitboxSize, config.hitboxSize, config.hitboxSize)
        head.Transparency = 0.5
        head.CanCollide = false
        head.Massless = true
    end
    
    if torso and torso:IsA("BasePart") then
        if not originalSizes[player] then
            originalSizes[player] = {}
        end
        if not originalSizes[player].torso then
            originalSizes[player].torso = torso.Size
        end
        
        torso.Size = Vector3.new(config.hitboxSize, config.hitboxSize, config.hitboxSize)
        torso.Transparency = 0.5
        torso.CanCollide = false
        torso.Massless = true
    end
end

local function restoreHitbox(player)
    if not player.Character then return end
    if not originalSizes[player] then return end
    
    local head, torso = getBodyParts(player.Character)
    
    if head and originalSizes[player].head then
        head.Size = originalSizes[player].head
        head.Transparency = 0
        head.CanCollide = true
        head.Massless = false
    end
    
    if torso and originalSizes[player].torso then
        torso.Size = originalSizes[player].torso
        torso.Transparency = 0
        torso.CanCollide = true
        torso.Massless = false
    end
end

-- [BUCLE PRINCIPAL]
RunService.Heartbeat:Connect(function()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local isEnemy = getRelationship(player) == "ENEMY"
            local valid = isValidTarget(player)
            
            if config.magicBullet and isEnemy and valid then
                expandHitbox(player)
            else
                if originalSizes[player] then
                    restoreHitbox(player)
                end
            end
        end
    end
end)

RunService.RenderStepped:Connect(function()
    -- ACTUALIZACIÓN DE BOTONES
    AimBtn.Text = config.aimLock and "Aimlock: ON [X]" or "Aimlock: OFF [X]"
    AimBtn.TextColor3 = config.aimLock and colors.accent or colors.off
    
    MagicBtn.Text = config.magicBullet and "Magic Hitbox: ON [F2]" or "Magic Hitbox: OFF [F2]"
    MagicBtn.TextColor3 = config.magicBullet and colors.accent or colors.off
    
    SoloBtn.Text = config.isSoloMode and "Solo Mode: ON [Z]" or "Team Mode: ON [Z]"
    SoloBtn.TextColor3 = config.isSoloMode and colors.accent or colors.ally
    
    ModeBtn.Text = "Modo: " .. config.mode
    ModeBtn.TextColor3 = (config.mode == "Descarado") and colors.enemy or colors.accent

    -- FOV
    fovCircle.Visible = config.aimLock
    fovCircle.Radius = config.fov
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    fovCircle.Color = config.mode == "Balanceado" and colors.accent or colors.enemy
    
    -- AIMLOCK MEJORADO
    if config.aimLock and aimLockActive then
        local closest = nil
        local shortestDist = math.huge
        local mousePos = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer 
                and getRelationship(player) == "ENEMY" 
                and isValidTarget(player)
                and isAliveAndInMap(player)
                and isSameGameZone(player) then
                
                local head = player.Character:FindFirstChild("Head")
                if head then
                    local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                        if dist < config.fov and dist < shortestDist then
                            shortestDist = dist
                            closest = player
                        end
                    end
                end
            end
        end
        targetPlayer = closest
        
        if targetPlayer and isAliveAndInMap(targetPlayer) and targetPlayer.Character then
            local head = targetPlayer.Character:FindFirstChild("Head")
            local root = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
            
            if head and root then
                local dist = (Camera.CFrame.Position - head.Position).Magnitude
                local predicted = head.Position + (root.Velocity * (dist / config.bulletVel))
                Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, predicted), config.smoothness)
            end
        end
    else
        targetPlayer = nil
    end
    
    -- ESP MEJORADO
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local valid = isValidTarget(player)
            
            if not valid then
                if espTexts[player] then 
                    espTexts[player].Visible = false 
                end
            else
                if not espTexts[player] then
                    local t = Drawing.new("Text")
                    t.Size = 16
                    t.Center = true
                    t.Outline = true
                    espTexts[player] = t
                end
                
                local head = player.Character:FindFirstChild("Head")
                if head and config.esp and isAliveAndInMap(player) then
                    local pos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        espTexts[player].Visible = true
                        espTexts[player].Position = Vector2.new(pos.X, pos.Y - 45)
                        
                        if player == targetPlayer then
                            espTexts[player].Color = colors.target
                            espTexts[player].Text = ">> " .. player.Name .. " <<"
                        else
                            local rel = getRelationship(player)
                            espTexts[player].Color = (rel == "ENEMY") and colors.enemy or colors.ally
                            espTexts[player].Text = player.Name
                        end
                    else
                        espTexts[player].Visible = false
                    end
                else
                    espTexts[player].Visible = false
                end
            end
        end
    end
end)

-- CONTROLES
UserInputService.InputBegan:Connect(function(i, g)
    if g then return end
    if i.KeyCode == Enum.KeyCode.X then config.aimLock = not config.aimLock end
    if i.KeyCode == Enum.KeyCode.Z then config.isSoloMode = not config.isSoloMode end
    if i.KeyCode == Enum.KeyCode.F2 then config.magicBullet = not config.magicBullet end
    if i.KeyCode == Enum.KeyCode.F1 then MainFrame.Visible = not MainFrame.Visible end
    if i.UserInputType == Enum.UserInputType.MouseButton2 then aimLockActive = true end
end)

UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton2 then aimLockActive = false end
end)

print("CLAUDE AI v7.2 - LOADED SUCCESSFULLY")
