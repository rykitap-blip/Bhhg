-- ================================================================
--  RuzHub v5.0 - WindUI Crimson Edition
--  MM2 Fan-Made Admin Panel
--  Integrated: ESP, Silent Aim, Bomb Jumps, Grab Gun,
--              Skybox Changer, Anti-Fling, FOV, Stretch
-- ================================================================

-- ==========================================
-- SERVICES
-- ==========================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Lighting          = game:GetService("Lighting")

local player       = Players.LocalPlayer
local Camera       = Workspace.CurrentCamera
local goldCD       = false
local normalCD     = false
local grabCD       = false
local BULLET_SPEED = 250
local MAX_VELOCITY = 200

-- ==========================================
-- WINDUI LOAD
-- ==========================================
local WindUI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/Footagesus/WindUI/refs/heads/main/dist/main.lua"
))()
WindUI:SetTheme("Crimson")

-- ==========================================
-- NOTIFICATION WRAPPER
-- ==========================================
local function Notify(title, content, icon)
    WindUI:Notify({
        Title   = title or "RuzHub",
        Content = content or "",
        Duration = 3,
        Icon    = icon or "bell",
    })
end

-- ==========================================
-- PREDICTION PART
-- ==========================================
local predPart        = Instance.new("Part")
predPart.Name         = "RuzPredictionPart"
predPart.Size         = Vector3.new(0.5, 0.5, 0.5)
predPart.Anchored     = true
predPart.CanCollide   = false
predPart.Transparency = 1
predPart.Material     = Enum.Material.Neon
predPart.Parent       = Workspace

-- ==========================================
-- GUN MARKER
-- ==========================================
local gunMarker = nil

local function ClearGunMarker()
    if gunMarker then
        gunMarker:Destroy()
        gunMarker = nil
    end
end

local function PlaceGunMarker(position)
    ClearGunMarker()
    local p         = Instance.new("Part")
    p.Name          = "RuzGunMarker"
    p.Size          = Vector3.new(1.5, 0.15, 1.5)
    p.Anchored      = true
    p.CanCollide    = false
    p.CastShadow    = false
    p.Material      = Enum.Material.Neon
    p.Color         = Color3.fromRGB(50, 255, 80)
    p.Transparency  = 0.25
    p.CFrame        = CFrame.new(position)
    p.Parent        = Workspace

    task.spawn(function()
        while p and p.Parent do
            for t = 0, 1, 0.05 do
                if not (p and p.Parent) then break end
                p.Transparency = 0.25 + 0.5 * math.sin(t * math.pi)
                task.wait(0.03)
            end
        end
    end)

    gunMarker = p
end

-- ==========================================
-- GUN DROP FINDER
-- ==========================================
local function FindGunDrop()
    return Workspace:FindFirstChild("GunDrop", true)
end

-- ==========================================
-- DROPPED GUN HIGHLIGHT + BILLBOARD
-- ==========================================
local activeHighlight   = nil
local activeBillboard   = nil
local gunHighlightColor = Color3.fromRGB(255, 215, 0)

local function ClearGunESP()
    if activeHighlight then activeHighlight:Destroy(); activeHighlight = nil end
    if activeBillboard then activeBillboard:Destroy(); activeBillboard = nil end
end

local function ApplyGunHighlight(gunDrop)
    ClearGunESP()

    local hl                  = Instance.new("Highlight")
    hl.Adornee                = gunDrop
    hl.FillColor              = gunHighlightColor
    hl.OutlineColor           = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency       = 0.4
    hl.OutlineTransparency    = 0
    hl.DepthMode              = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent                 = gunDrop
    activeHighlight           = hl

    local handle = gunDrop:FindFirstChild("Handle")
        or gunDrop.PrimaryPart
        or gunDrop:FindFirstChildWhichIsA("BasePart")

    if handle then
        PlaceGunMarker(handle.Position + Vector3.new(0, 0.1, 0))

        local bb          = Instance.new("BillboardGui")
        bb.Name           = "RuzGunLabel"
        bb.Adornee        = handle
        bb.Size           = UDim2.new(0, 120, 0, 38)
        bb.StudsOffset    = Vector3.new(0, 4, 0)
        bb.AlwaysOnTop    = true
        bb.MaxDistance    = 300
        bb.Parent         = handle

        local bg                    = Instance.new("Frame", bb)
        bg.Size                     = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3         = Color3.fromRGB(0, 0, 0)
        bg.BackgroundTransparency   = 0.35
        bg.BorderSizePixel          = 0
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

        local bgStroke              = Instance.new("UIStroke", bg)
        bgStroke.Color              = gunHighlightColor
        bgStroke.Thickness          = 1.5
        bgStroke.Transparency       = 0.1

        local lbl                   = Instance.new("TextLabel", bg)
        lbl.Size                    = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency  = 1
        lbl.Text                    = "GRAB GUN"
        lbl.TextColor3              = gunHighlightColor
        lbl.Font                    = Enum.Font.GothamBlack
        lbl.TextSize                = 14
        lbl.TextStrokeTransparency  = 0.4
        lbl.TextStrokeColor3        = Color3.fromRGB(0, 0, 0)

        activeBillboard = bb
    else
        local cf = gunDrop:IsA("Model") and gunDrop:GetModelCFrame()
            or CFrame.new(gunDrop.Position)
        PlaceGunMarker(cf.Position + Vector3.new(0, 0.1, 0))
    end
end

local function OnGunDropFound(gunDrop)
    ApplyGunHighlight(gunDrop)
    Notify("RuzHub", "Gun dropped! Use Grab Gun.", "alert-triangle")
end

local function OnGunDropRemoved()
    ClearGunESP()
    ClearGunMarker()
end

-- ==========================================
-- GUN DROP WATCHER (recursive)
-- ==========================================
local watchedFolders = {}

local function WatchFolder(folder)
    if watchedFolders[folder] then return end
    watchedFolders[folder] = true

    folder.ChildAdded:Connect(function(obj)
        if obj.Name == "GunDrop" then
            task.wait(0.1)
            OnGunDropFound(obj)
        end
        if obj:IsA("Model") or obj:IsA("Folder") then
            WatchFolder(obj)
        end
    end)

    folder.ChildRemoved:Connect(function(obj)
        if obj.Name == "GunDrop" then
            OnGunDropRemoved()
        end
    end)

    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") or child:IsA("Folder") then
            WatchFolder(child)
        end
    end
end

WatchFolder(Workspace)
Workspace.ChildAdded:Connect(function(obj)
    if obj:IsA("Model") or obj:IsA("Folder") then
        WatchFolder(obj)
    end
    if obj.Name == "GunDrop" then
        task.wait(0.1)
        OnGunDropFound(obj)
    end
end)

-- Scan existing GunDrop on startup
task.spawn(function()
    task.wait(1.5)
    local existing = FindGunDrop()
    if existing then
        OnGunDropFound(existing)
    end
end)

-- ==========================================
-- WATCH SHERIFFS (gun drop on death)
-- ==========================================
local function WatchSheriff(p)
    local function hook(char)
        if not char then return end
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        hum.Died:Connect(function()
            if p.Backpack:FindFirstChild("Gun") or char:FindFirstChild("Gun") then
                task.delay(0.8, function()
                    local gd = FindGunDrop()
                    if gd then OnGunDropFound(gd) end
                end)
            end
        end)
    end
    if p.Character then hook(p.Character) end
    p.CharacterAdded:Connect(hook)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= player then task.spawn(WatchSheriff, p) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= player then WatchSheriff(p) end
end)

-- ==========================================
-- GRAB GUN
-- Teleport -> firetouchinterest -> return
-- firetouchinterest can fail silently; teleport
-- is the reliable pickup method.
-- ==========================================
local function GrabDroppedGun()
    if grabCD then
        Notify("RuzHub", "Grab Gun is on cooldown (5s).", "clock")
        return
    end

    local gd = FindGunDrop()
    if not gd then
        Notify("RuzHub", "No gun on the map right now.", "x-circle")
        return
    end

    local handle = gd:FindFirstChild("Handle")
        or gd.PrimaryPart
        or gd:FindFirstChildWhichIsA("BasePart")

    if not handle then
        Notify("RuzHub", "Could not find gun handle.", "x-circle")
        return
    end

    local char = player.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    grabCD = true
    local returnCFrame = hrp.CFrame

    Notify("RuzHub", "Teleporting to gun...", "move")

    -- Step 1: Teleport to gun position
    hrp.CFrame = CFrame.new(handle.Position + Vector3.new(0, 3, 0))

    -- Step 2: Fire touch to register pickup on server
    pcall(function()
        firetouchinterest(hrp, handle, 0)
        task.wait(0.03)
        firetouchinterest(hrp, handle, 1)
    end)

    -- Step 3: Return to original position
    task.wait(0.3)
    hrp.CFrame = returnCFrame

    ClearGunESP()
    ClearGunMarker()

    Notify("RuzHub", "Done! 5 second cooldown active.", "check-circle")
    task.delay(5, function()
        grabCD = false
        Notify("RuzHub", "Grab Gun is ready again!", "check-circle")
    end)
end

-- ==========================================
-- ROLE ESP SYSTEM
-- ==========================================
local espEnabled  = false
local espConn     = nil
local rolesData   = {}
local lastEspTick = 0

local espSettings = {
    Murderer = true,
    Sheriff  = true,
    Hero     = true,
    Innocent = true,
    Self     = true,
}

local ESP_COLORS = {
    Murderer = Color3.fromRGB(255,  40,  40),
    Sheriff  = Color3.fromRGB( 40, 130, 255),
    Hero     = Color3.fromRGB(255, 215,   0),
    Innocent = Color3.fromRGB(  0, 220,   0),
}

local function ApplyRoleHighlight(char, color)
    local hl               = char:FindFirstChild("RuzHub_RoleESP") or Instance.new("Highlight")
    hl.Name                = "RuzHub_RoleESP"
    hl.Parent              = char
    hl.FillColor           = color
    hl.FillTransparency    = 0.45
    hl.OutlineColor        = Color3.fromRGB(255, 255, 255)
    hl.OutlineTransparency = 0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
end

local function RemoveRoleHighlight(char)
    local hl = char:FindFirstChild("RuzHub_RoleESP")
    if hl then hl:Destroy() end
end

local function ClearAllRoleESP()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then RemoveRoleHighlight(p.Character) end
    end
    rolesData    = {}
    lastEspTick  = 0
end

local function GetPlayerRole(p)
    local role  = "Innocent"
    local pData = rolesData[p.Name]
    if pData then
        local r = tostring(pData.Role or pData.role or pData.Team or ""):lower()
        if     r:find("murd")                     then role = "Murderer"
        elseif r:find("sheriff") or r:find("gun") then role = "Sheriff"
        elseif r:find("hero")                     then role = "Hero"
        end
    end
    return role
end

local function StartRoleESP()
    local remote = ReplicatedStorage:FindFirstChild("GetCurrentPlayerData", true)
    if not remote or not remote:IsA("RemoteFunction") then
        Notify("RuzHub", "ESP remote not found!", "alert-triangle")
        espEnabled = false
        return
    end

    espConn = RunService.Heartbeat:Connect(function()
        if not espEnabled then return end

        if tick() - lastEspTick > 0.5 then
            local ok, data = pcall(function() return remote:InvokeServer() end)
            if ok and type(data) == "table" then rolesData = data end
            lastEspTick = tick()
        end

        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local isSelf = (p == player)
                local role   = GetPlayerRole(p)
                local show   = espSettings[role]

                if isSelf and not espSettings.Self then
                    show = false
                end

                if show then
                    ApplyRoleHighlight(p.Character, ESP_COLORS[role])
                else
                    RemoveRoleHighlight(p.Character)
                end
            end
        end
    end)
end

local function StopRoleESP()
    if espConn then espConn:Disconnect(); espConn = nil end
    task.delay(0.1, ClearAllRoleESP)
end

-- ==========================================
-- TARGET FINDER (Duel Mode)
-- ==========================================
local currentKillerChar = nil

local function FindBestTarget()
    local myChar = player.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return nil end

    local killerChar  = nil
    local sheriffList = {}

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local char     = p.Character
            local hum      = char:FindFirstChildOfClass("Humanoid")
            local hasKnife = p.Backpack:FindFirstChild("Knife") or char:FindFirstChild("Knife")
            local hasGun   = p.Backpack:FindFirstChild("Gun")   or char:FindFirstChild("Gun")
            if hum and hum.Health > 0 then
                if hasKnife   then killerChar = char
                elseif hasGun then table.insert(sheriffList, char) end
            end
        end
    end

    if killerChar then return killerChar end

    if #sheriffList >= 1 then
        local best, bestDist = nil, math.huge
        for _, char in ipairs(sheriffList) do
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - myHRP.Position).Magnitude
                if d < bestDist then bestDist = d; best = char end
            end
        end
        return best
    end

    return nil
end

-- ==========================================
-- PREDICTION LOOP
-- ==========================================
RunService.RenderStepped:Connect(function()
    local targetChar = FindBestTarget()
    currentKillerChar = targetChar
    if not targetChar then return end

    local myChar = player.Character
    local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    local head  = targetChar:FindFirstChild("Head")
    local torso = targetChar:FindFirstChild("UpperTorso")
             or  targetChar:FindFirstChild("HumanoidRootPart")
    local hum   = targetChar:FindFirstChildOfClass("Humanoid")
    if not torso then return end

    local basePos    = head and head.Position or (torso.Position + Vector3.new(0, 0.5, 0))
    local dist       = (basePos - myHRP.Position).Magnitude
    local travelTime = dist / BULLET_SPEED

    local vel = torso.AssemblyLinearVelocity
    if hum and (
        hum:GetState() == Enum.HumanoidStateType.Freefall or
        hum:GetState() == Enum.HumanoidStateType.Jumping
    ) then
        vel = Vector3.new(vel.X, 0, vel.Z)
    end

    predPart.CFrame = CFrame.new(basePos + vel * travelTime)
end)

-- ==========================================
-- AUTO KILL / SHOOT MURDERER
-- ==========================================
local function AutoKill()
    local char  = player.Character
    if not char then return end
    local myHRP = char:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end

    local gun = player.Backpack:FindFirstChild("Gun") or char:FindFirstChild("Gun")
    if not gun then
        Notify("RuzHub", "You do not have a Gun!", "x-circle")
        return
    end

    local targetChar = currentKillerChar
    if not targetChar then
        Notify("RuzHub", "No target detected.", "alert-triangle")
        return
    end

    local hasKnife = false
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == targetChar then
            hasKnife = p.Backpack:FindFirstChild("Knife") ~= nil
                or p.Character:FindFirstChild("Knife") ~= nil
            break
        end
    end

    if not hasKnife then
        Notify("RuzHub", "Duel mode: targeting closest sheriff.", "crosshair")
    end

    if gun.Parent ~= char then
        char.Humanoid:EquipTool(gun)
        task.wait(0.05)
    end

    local targetPos = predPart.CFrame.Position
    pcall(function()
        gun:WaitForChild("Shoot"):FireServer(
            CFrame.new(myHRP.Position, targetPos),
            CFrame.new(targetPos)
        )
    end)
end

-- ==========================================
-- BOMB RETRIEVER (background loop)
-- ==========================================
task.spawn(function()
    while true do
        task.wait(2)
        pcall(function()
            ReplicatedStorage.Remotes.Extras.ReplicateToy:InvokeServer("FakeBomb")
            ReplicatedStorage.Remotes.Extras.ReplicateToy:InvokeServer("GoldBomb")
        end)
    end
end)

-- ==========================================
-- JUMP ENGINE
-- ==========================================
local function ExecuteJump(bombName, isGold)
    local char = player.Character
    if not char then return end
    local bomb = player.Backpack:FindFirstChild(bombName) or char:FindFirstChild(bombName)
    if not bomb then
        Notify("RuzHub", "You do not have " .. bombName .. "!", "x-circle")
        return
    end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if bomb.Parent ~= char then
        char.Humanoid:EquipTool(bomb)
        task.wait()
    end
    pcall(function()
        bomb.Remote:FireServer(
            CFrame.new(hrp.Position + hrp.CFrame.LookVector * 1.5 + Vector3.new(0, -3, 0)),
            50
        )
    end)
    char.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
    hrp.AssemblyLinearVelocity = Vector3.new(
        hrp.AssemblyLinearVelocity.X, 62, hrp.AssemblyLinearVelocity.Z
    )
    if isGold then
        task.spawn(function() goldCD = true;   task.wait(4);  goldCD   = false end)
        Notify("RuzHub", "Gold Bomb launched! (4s cooldown)", "zap")
    else
        task.spawn(function() normalCD = true; task.wait(21); normalCD = false end)
        Notify("RuzHub", "Normal Bomb launched! (21s cooldown)", "zap")
    end
end

-- ==========================================
-- ANTI-FLING
-- ==========================================
local antiFlingEnabled = false
local antiFlingConn    = nil

local function StartAntiFling()
    if antiFlingConn then antiFlingConn:Disconnect() end
    antiFlingConn = RunService.Heartbeat:Connect(function()
        if not antiFlingEnabled then return end
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local vel = hrp.AssemblyLinearVelocity
            if vel.Magnitude > MAX_VELOCITY then
                hrp.AssemblyLinearVelocity = vel.Unit * MAX_VELOCITY
            end
        end
    end)
end

local function StopAntiFling()
    if antiFlingConn then antiFlingConn:Disconnect(); antiFlingConn = nil end
end

-- ==========================================
-- FOV CHANGER
-- ==========================================
local function SetFOV(value)
    Camera.FieldOfView = value
end

-- ==========================================
-- STRETCHED RESOLUTION
-- (Simulated via a scaled ScreenGui overlay)
-- ==========================================
local stretchEnabled = false
local stretchGui     = nil

local function ApplyStretch(enabled, amount)
    if enabled then
        if not stretchGui then
            stretchGui = Instance.new("ScreenGui", player.PlayerGui)
            stretchGui.Name          = "RuzStretchGui"
            stretchGui.ResetOnSpawn  = false
            stretchGui.IgnoreGuiInset = true
            stretchGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        end

        -- Black side bars to simulate stretched viewport
        for _, child in ipairs(stretchGui:GetChildren()) do
            child:Destroy()
        end

        local barWidth = (1 - (1 / amount)) / 2

        local leftBar = Instance.new("Frame", stretchGui)
        leftBar.Size              = UDim2.new(barWidth, 0, 1, 0)
        leftBar.Position          = UDim2.new(0, 0, 0, 0)
        leftBar.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
        leftBar.BorderSizePixel   = 0

        local rightBar = Instance.new("Frame", stretchGui)
        rightBar.Size             = UDim2.new(barWidth, 0, 1, 0)
        rightBar.Position         = UDim2.new(1 - barWidth, 0, 0, 0)
        rightBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        rightBar.BorderSizePixel  = 0
    else
        if stretchGui then
            stretchGui:Destroy()
            stretchGui = nil
        end
    end
end

-- ==========================================
-- CUSTOM CROSSHAIR
-- ==========================================
local crosshairEnabled = false
local crosshairGui     = nil
local crosshairColor   = Color3.fromRGB(255, 50, 50)
local crosshairSize    = 20

local function BuildCrosshair()
    if crosshairGui then crosshairGui:Destroy() end

    crosshairGui = Instance.new("ScreenGui", player.PlayerGui)
    crosshairGui.Name           = "RuzCrosshairGui"
    crosshairGui.ResetOnSpawn   = false
    crosshairGui.IgnoreGuiInset = true
    crosshairGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local half = crosshairSize / 2

    local hLine = Instance.new("Frame", crosshairGui)
    hLine.Name              = "HLine"
    hLine.Size              = UDim2.new(0, crosshairSize, 0, 2)
    hLine.Position          = UDim2.new(0.5, -half, 0.5, -1)
    hLine.BackgroundColor3  = crosshairColor
    hLine.BorderSizePixel   = 0

    local vLine = Instance.new("Frame", crosshairGui)
    vLine.Name              = "VLine"
    vLine.Size              = UDim2.new(0, 2, 0, crosshairSize)
    vLine.Position          = UDim2.new(0.5, -1, 0.5, -half)
    vLine.BackgroundColor3  = crosshairColor
    vLine.BorderSizePixel   = 0
end

local function UpdateCrosshairColor(color)
    crosshairColor = color
    if crosshairGui then
        for _, child in ipairs(crosshairGui:GetChildren()) do
            if child:IsA("Frame") then
                child.BackgroundColor3 = color
            end
        end
    end
end

-- ==========================================
-- SKYBOX CHANGER
-- ==========================================
local SKYBOXES = {
    "Default",
    "Night Sky",
    "Sunset",
    "Space",
    "Blizzard",
    "Interstellar",
    "Crimson Dusk",
    "Storm",
    "Neon City",
    "Arctic",
}

local SKYBOX_IDS = {
    ["Night Sky"]    = "1012271366",
    ["Sunset"]       = "159454761",
    ["Space"]        = "159453841",
    ["Blizzard"]     = "159454781",
    ["Interstellar"] = "1454277478",
    ["Crimson Dusk"] = "159453943",
    ["Storm"]        = "159453916",
    ["Neon City"]    = "1258038280",
    ["Arctic"]       = "159453990",
}

local defaultSkyboxData = nil

local function SaveDefaultSkybox()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if sky then
        defaultSkyboxData = {
            SkyboxBk = sky.SkyboxBk,
            SkyboxDn = sky.SkyboxDn,
            SkyboxFt = sky.SkyboxFt,
            SkyboxLf = sky.SkyboxLf,
            SkyboxRt = sky.SkyboxRt,
            SkyboxUp = sky.SkyboxUp,
        }
    end
end

SaveDefaultSkybox()

local function ApplySkybox(name)
    if name == "Default" then
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if sky and defaultSkyboxData then
            for k, v in pairs(defaultSkyboxData) do
                sky[k] = v
            end
        end
        Notify("RuzHub", "Skybox restored to Default.", "cloud")
        return
    end

    local id = SKYBOX_IDS[name]
    if not id then return end

    local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky", Lighting)
    local url = "rbxassetid://" .. id
    sky.SkyboxBk = url
    sky.SkyboxDn = url
    sky.SkyboxFt = url
    sky.SkyboxLf = url
    sky.SkyboxRt = url
    sky.SkyboxUp = url

    Notify("RuzHub", "Skybox changed to " .. name .. ".", "cloud")
end

-- ==========================================
-- WELCOME POPUP
-- ==========================================
WindUI:Popup({
    Title   = "Welcome to RuzHub",
    Icon    = "sparkles",
    Content = "Crimson Edition loaded.\n\nUse the panel to access all features.",
    Buttons = {
        {
            Title    = "Get Started",
            Icon     = "arrow-right",
            Variant  = "Primary",
            Callback = function() end
        }
    }
})

-- ==========================================
-- MAIN WINDOW
-- ==========================================
local Window = WindUI:CreateWindow({
    Title          = "RuzHub",
    Icon           = "sparkles",
    Author         = "Ruz Hub",
    Folder         = "RuzHub",
    Size           = UDim2.fromOffset(700, 550),
    Theme          = "Crimson",
    Acrylic        = false,
    HideSearchBar  = false,
    OpenButton = {
        Title           = "RuzHub",
        CornerRadius    = UDim.new(1, 0),
        StrokeThickness = 2,
        Enabled         = true,
        OnlyMobile      = false,
        Color           = ColorSequence.new(
            Color3.fromHex("#dc2626"),
            Color3.fromHex("#991b1b")
        ),
    },
})

-- ==========================================
-- HOME TAB
-- ==========================================
local HomeSection = Window:Section({ Title = "Home", Opened = true })
local HomeTab     = HomeSection:Tab({ Title = "Home", Icon = "home" })

HomeTab:Paragraph({
    Title   = "RuzHub v5.0 - Crimson Edition",
    Content = "MM2 fan-made admin panel. Navigate the tabs on the left to access all features. All features are customizable."
})

HomeTab:Paragraph({
    Title   = "Quick Guide",
    Content = "Main      ->  Bomb Jumps, Grab Gun, Shoot Murderer\nESP       ->  Role highlights, per-role toggles, custom colors\nCombat    ->  Silent Aim, bullet speed settings\nSky       ->  Skybox dropdown, ambient settings\nExtra     ->  Anti-Fling, FOV changer, Stretch\nCursors   ->  Custom crosshair with color picker"
})

HomeTab:Paragraph({
    Title   = "Grab Gun Fix Note",
    Content = "Grab Gun teleports you to the dropped gun then returns you to your original position. If the server blocks the pickup, move closer manually and try again."
})

-- ==========================================
-- MAIN TAB
-- ==========================================
local MainSection = Window:Section({ Title = "Main", Opened = true })
local MainTab     = MainSection:Tab({ Title = "Main", Icon = "zap" })

MainTab:Paragraph({
    Title   = "Load Actions",
    Content = "Press a button to execute the action instantly."
})

MainTab:Button({
    Title       = "Load Gold Bomb",
    Description = "Execute Gold Bomb jump  |  Cooldown: 4 seconds",
    Icon        = "circle",
    Callback    = function()
        if goldCD then
            Notify("RuzHub", "Gold Bomb is on cooldown.", "clock")
        else
            ExecuteJump("GoldBomb", true)
        end
    end
})

MainTab:Button({
    Title       = "Load Normal Bomb",
    Description = "Execute Normal Bomb jump  |  Cooldown: 21 seconds",
    Icon        = "zap",
    Callback    = function()
        if normalCD then
            Notify("RuzHub", "Normal Bomb is on cooldown.", "clock")
        else
            ExecuteJump("FakeBomb", false)
        end
    end
})

MainTab:Button({
    Title       = "Shoot Murderer",
    Description = "Silent aim shot at murderer or closest sheriff",
    Icon        = "crosshair",
    Callback    = function()
        AutoKill()
    end
})

MainTab:Button({
    Title       = "Grab Gun",
    Description = "Teleport to the dropped gun and grab it  |  Cooldown: 5 seconds",
    Icon        = "move",
    Callback    = function()
        task.spawn(GrabDroppedGun)
    end
})

-- ==========================================
-- ESP TAB
-- ==========================================
local EspSection = Window:Section({ Title = "ESP", Opened = true })
local EspTab     = EspSection:Tab({ Title = "ESP", Icon = "eye" })

EspTab:Toggle({
    Title       = "Enable ESP",
    Description = "Toggle all role-based player highlighting",
    Default     = false,
    Callback    = function(val)
        espEnabled = val
        if val then
            StartRoleESP()
            Notify("RuzHub", "ESP enabled.", "eye")
        else
            StopRoleESP()
            Notify("RuzHub", "ESP disabled.", "eye-off")
        end
    end
})

EspTab:Divider()

EspTab:Toggle({
    Title       = "Show Murderer",
    Description = "Highlight the murderer",
    Default     = true,
    Callback    = function(val) espSettings.Murderer = val end
})

EspTab:Toggle({
    Title       = "Show Sheriff",
    Description = "Highlight the sheriff",
    Default     = true,
    Callback    = function(val) espSettings.Sheriff = val end
})

EspTab:Toggle({
    Title       = "Show Hero",
    Description = "Highlight the hero",
    Default     = true,
    Callback    = function(val) espSettings.Hero = val end
})

EspTab:Toggle({
    Title       = "Show Innocents",
    Description = "Highlight innocent players",
    Default     = true,
    Callback    = function(val) espSettings.Innocent = val end
})

EspTab:Toggle({
    Title       = "Show Self",
    Description = "Apply ESP highlight to your own character",
    Default     = true,
    Callback    = function(val) espSettings.Self = val end
})

EspTab:Divider()

EspTab:ColorPicker({
    Title       = "Murderer Color",
    Description = "Color used for murderer highlight",
    Default     = Color3.fromRGB(255, 40, 40),
    Callback    = function(val) ESP_COLORS.Murderer = val end
})

EspTab:ColorPicker({
    Title       = "Sheriff Color",
    Description = "Color used for sheriff highlight",
    Default     = Color3.fromRGB(40, 130, 255),
    Callback    = function(val) ESP_COLORS.Sheriff = val end
})

EspTab:ColorPicker({
    Title       = "Hero Color",
    Description = "Color used for hero highlight",
    Default     = Color3.fromRGB(255, 215, 0),
    Callback    = function(val) ESP_COLORS.Hero = val end
})

EspTab:ColorPicker({
    Title       = "Innocent Color",
    Description = "Color used for innocent highlight",
    Default     = Color3.fromRGB(0, 220, 0),
    Callback    = function(val) ESP_COLORS.Innocent = val end
})

-- ==========================================
-- COMBAT TAB
-- ==========================================
local CombatSection = Window:Section({ Title = "Combat", Opened = true })
local CombatTab     = CombatSection:Tab({ Title = "Combat", Icon = "sword" })

CombatTab:Paragraph({
    Title   = "Silent Aim",
    Content = "Predicts bullet travel time based on target velocity. Prioritizes murderer first, then the closest sheriff."
})

CombatTab:Slider({
    Title       = "Bullet Speed",
    Description = "Predicted bullet speed for aim correction (default: 250)",
    Min         = 50,
    Max         = 600,
    Default     = 250,
    Rounding    = 0,
    Callback    = function(val)
        BULLET_SPEED = val
    end
})

CombatTab:Button({
    Title       = "Fire at Target",
    Description = "Shoot at the current best target using prediction",
    Icon        = "crosshair",
    Callback    = function()
        AutoKill()
    end
})

-- ==========================================
-- SKY TAB
-- ==========================================
local SkySection = Window:Section({ Title = "Sky", Opened = true })
local SkyTab     = SkySection:Tab({ Title = "Sky", Icon = "cloud" })

SkyTab:Dropdown({
    Title       = "Skybox",
    Description = "Select a skybox preset to apply",
    Options     = SKYBOXES,
    Default     = "Default",
    Callback    = function(val)
        ApplySkybox(val)
    end
})

SkyTab:Slider({
    Title       = "Ambient Brightness",
    Description = "Adjust scene brightness (default: 1)",
    Min         = 0,
    Max         = 10,
    Default     = 1,
    Rounding    = 1,
    Callback    = function(val)
        Lighting.Brightness = val
    end
})

SkyTab:ColorPicker({
    Title       = "Ambient Color",
    Description = "Adjust the ambient light color",
    Default     = Color3.fromRGB(128, 128, 128),
    Callback    = function(val)
        Lighting.Ambient = val
    end
})

SkyTab:ColorPicker({
    Title       = "Outdoor Ambient",
    Description = "Adjust outdoor ambient light color",
    Default     = Color3.fromRGB(70, 70, 70),
    Callback    = function(val)
        Lighting.OutdoorAmbient = val
    end
})

-- ==========================================
-- EXTRA TAB
-- ==========================================
local ExtraSection = Window:Section({ Title = "Extra", Opened = true })
local ExtraTab     = ExtraSection:Tab({ Title = "Extra", Icon = "star" })

ExtraTab:Toggle({
    Title       = "Anti-Fling",
    Description = "Prevents you from being flung by other exploiters",
    Default     = false,
    Callback    = function(val)
        antiFlingEnabled = val
        if val then
            StartAntiFling()
            Notify("RuzHub", "Anti-Fling enabled.", "shield")
        else
            StopAntiFling()
            Notify("RuzHub", "Anti-Fling disabled.", "shield-off")
        end
    end
})

ExtraTab:Slider({
    Title       = "Max Velocity Cap",
    Description = "Max velocity allowed when Anti-Fling is active",
    Min         = 50,
    Max         = 500,
    Default     = 200,
    Rounding    = 0,
    Callback    = function(val)
        MAX_VELOCITY = val
    end
})

ExtraTab:Divider()

ExtraTab:Slider({
    Title       = "Field of View",
    Description = "Adjust camera field of view",
    Min         = 30,
    Max         = 120,
    Default     = 70,
    Rounding    = 0,
    Callback    = function(val)
        SetFOV(val)
    end
})

ExtraTab:Divider()

local stretchAmount = 1.35

ExtraTab:Toggle({
    Title       = "Stretched Resolution",
    Description = "Apply letterbox bars to simulate stretched display",
    Default     = false,
    Callback    = function(val)
        stretchEnabled = val
        ApplyStretch(val, stretchAmount)
    end
})

ExtraTab:Slider({
    Title       = "Stretch Amount",
    Description = "Width multiplier for stretch effect (10 = 1.0x normal)",
    Min         = 10,
    Max         = 20,
    Default     = 14,
    Rounding    = 0,
    Callback    = function(val)
        stretchAmount = val / 10
        if stretchEnabled then
            ApplyStretch(true, stretchAmount)
        end
    end
})

-- ==========================================
-- COLORS TAB
-- ==========================================
local ColorsSection = Window:Section({ Title = "Colors", Opened = true })
local ColorsTab     = ColorsSection:Tab({ Title = "Colors", Icon = "palette" })

ColorsTab:Paragraph({
    Title   = "Visual Customization",
    Content = "Adjust colors for in-world visual elements."
})

ColorsTab:ColorPicker({
    Title       = "Dropped Gun Highlight",
    Description = "Color of the dropped gun ESP highlight",
    Default     = Color3.fromRGB(255, 215, 0),
    Callback    = function(val)
        gunHighlightColor = val
        if activeHighlight then
            activeHighlight.FillColor = val
        end
    end
})

-- ==========================================
-- CURSORS TAB
-- ==========================================
local CursorsSection = Window:Section({ Title = "Cursors", Opened = true })
local CursorsTab     = CursorsSection:Tab({ Title = "Cursors", Icon = "mouse-pointer" })

CursorsTab:Paragraph({
    Title   = "Custom Crosshair",
    Content = "Overlay a crosshair on your screen. Adjustable color and size."
})

CursorsTab:Toggle({
    Title       = "Enable Crosshair",
    Description = "Show a custom crosshair at the center of the screen",
    Default     = false,
    Callback    = function(val)
        crosshairEnabled = val
        if val then
            BuildCrosshair()
            Notify("RuzHub", "Crosshair enabled.", "crosshair")
        else
            if crosshairGui then
                crosshairGui:Destroy()
                crosshairGui = nil
            end
            Notify("RuzHub", "Crosshair disabled.", "x-circle")
        end
    end
})

CursorsTab:ColorPicker({
    Title       = "Crosshair Color",
    Description = "Color of the custom crosshair lines",
    Default     = Color3.fromRGB(255, 50, 50),
    Callback    = function(val)
        UpdateCrosshairColor(val)
    end
})

CursorsTab:Slider({
    Title       = "Crosshair Size",
    Description = "Size of the crosshair in pixels",
    Min         = 8,
    Max         = 60,
    Default     = 20,
    Rounding    = 0,
    Callback    = function(val)
        crosshairSize = val
        if crosshairEnabled then
            BuildCrosshair()
        end
    end
})

-- ==========================================
-- REMINDER NOTIFICATION
-- ==========================================
task.wait(10)
WindUI:Notify({
    Title    = "RuzHub",
    Content  = "All systems loaded and ready.",
    Duration = 3,
    Icon     = "check-circle"
})

print("RuzHub v5.0 | Crimson Edition loaded.")
