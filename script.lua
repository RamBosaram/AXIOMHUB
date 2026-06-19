--[[
=========================================================================
    AXIOM — MM2 Multi-Feature Script
    Target  : Roblox / Murder Mystery 2
    Modules : ESP (players + dropped gun) | Gun Silent Aim | Shoot Button
    UI      : Dark themed menu with toggleable sidebar + draggable shoot

    Inject via any modern executor (Synapse / Krnl / Fluxus / Solara).
    Menu opens on inject. RightCtrl or MENU button toggles visibility.
=========================================================================
]]

--======================== SERVICES ========================--
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UserInputSvc  = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")
local Workspace     = game:GetService("Workspace")
local CoreGui       = game:GetService("CoreGui")

local LocalPlayer   = Players.LocalPlayer
local Mouse         = LocalPlayer:GetMouse()
local Camera        = Workspace.CurrentCamera

--======================== THEME / COLORS ========================--
local Theme = {
    Background   = Color3.fromRGB(15, 15, 15),
    Panel        = Color3.fromRGB(22, 22, 22),
    PanelAlt     = Color3.fromRGB(28, 28, 28),
    SidebarBg    = Color3.fromRGB(18, 18, 18),
    Border       = Color3.fromRGB(55, 55, 55),
    BorderActive = Color3.fromRGB(80, 80, 80),
    TextPrimary  = Color3.fromRGB(235, 235, 235),
    TextDim      = Color3.fromRGB(150, 150, 150),
    Accent       = Color3.fromRGB(0, 200, 80),
    AccentSoft   = Color3.fromRGB(0, 140, 60),
    ToggleOff    = Color3.fromRGB(70, 70, 70),
    InputBg      = Color3.fromRGB(30, 30, 30),
    TabHover     = Color3.fromRGB(35, 35, 35),
    TabActive    = Color3.fromRGB(45, 45, 45),
    ShootBg      = Color3.fromRGB(180, 30, 30),
    ShootHover   = Color3.fromRGB(220, 50, 50),
    MenuToggleBg = Color3.fromRGB(25, 25, 25),
}

local ESPColors = {
    Innocent = Color3.fromRGB(0, 255, 0),
    Murderer = Color3.fromRGB(255, 0, 0),
    Sheriff  = Color3.fromRGB(0, 120, 255),
    GunDrop  = Color3.fromRGB(255, 220, 0),
}

--======================== STATE ========================--
local State = {
    ESP = {
        Enabled             = false,
        FillTransparency    = 0.55,
        OutlineTransparency = 0,
        ThroughWalls        = true,
        RefreshInterval     = 0.5,
    },
    SilentAim = {
        Enabled            = false,
        PrioritizePing     = false,
        PredictJump        = false,
        PredictLag         = false,
        MaxSimulationTime  = 60,   -- ms, 30..90
        PredictionInterval = 100,  -- ms, 1..800
        OffsetX            = 0,    -- %, -350..350
        OffsetY            = 0,    -- %, -350..350
        OffsetZ            = 0,    -- %, -350..350
        HMultiplier        = 100,  -- %, 90..350
        VMultiplier        = 100,  -- %, 90..350
    },
}

--======================== UTILITIES ========================--
local function safeParent(gui)
    local ok, hui = pcall(function() return gethui and gethui() end)
    if ok and hui then gui.Parent = hui; return end
    local ok2 = pcall(function() gui.Parent = CoreGui end)
    if not ok2 then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end

local function create(class, props, children)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do obj[k] = v end
    for _, c in ipairs(children or {}) do c.Parent = obj end
    return obj
end

local function tween(obj, t, props)
    TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

--======================== ROLE / PLAYER LOGIC ========================--
local function hasTool(player, toolName)
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack and backpack:FindFirstChild(toolName) then return true end
    local char = player.Character
    if char and char:FindFirstChild(toolName) then return true end
    return false
end

local function getRole(player)
    if hasTool(player, "Knife") then return "Murderer"
    elseif hasTool(player, "Gun") then return "Sheriff"
    else return "Innocent" end
end

local function isAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function getMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and isAlive(p) and getRole(p) == "Murderer" then
            return p
        end
    end
    return nil
end

local function getHRP(player)
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart") or nil
end

--======================== ESP MODULE ========================--
local ESP = { tracked = {}, gunDrops = {} }

function ESP:removePlayer(player)
    local s = self.tracked[player]
    if s and s.highlight then s.highlight:Destroy() end
    self.tracked[player] = nil
end

function ESP:applyPlayer(player)
    if player == LocalPlayer then return end
    if not isAlive(player) then self:removePlayer(player); return end
    local char = player.Character
    if not char then return end

    self.tracked[player] = self.tracked[player] or {}
    local s = self.tracked[player]

    if not s.highlight or not s.highlight.Parent then
        s.highlight = Instance.new("Highlight")
        s.highlight.Name    = "AXIOM_ESP_PlayerHL"
        s.highlight.Adornee = char
        s.highlight.Parent  = char
    elseif s.highlight.Adornee ~= char then
        s.highlight.Adornee = char
        s.highlight.Parent  = char
    end

    local color = ESPColors[getRole(player)] or Color3.new(1,1,1)
    s.highlight.FillColor           = color
    s.highlight.OutlineColor        = color
    s.highlight.FillTransparency    = State.ESP.FillTransparency
    s.highlight.OutlineTransparency = State.ESP.OutlineTransparency
    s.highlight.DepthMode           = State.ESP.ThroughWalls
        and Enum.HighlightDepthMode.AlwaysOnTop
        or  Enum.HighlightDepthMode.Occluded
    s.highlight.Enabled             = true
end

function ESP:isGunDrop(obj)
    return obj:IsA("Tool") and obj.Name == "Gun" and obj.Parent == Workspace
end

function ESP:applyGunDrop(tool)
    local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
    if not handle then return end

    self.gunDrops[tool] = self.gunDrops[tool] or {}
    local s = self.gunDrops[tool]

    if not s.highlight or not s.highlight.Parent then
        s.highlight = Instance.new("Highlight")
        s.highlight.Name    = "AXIOM_ESP_GunHL"
        s.highlight.Adornee = tool
        s.highlight.Parent  = tool
    end
    s.highlight.FillColor           = ESPColors.GunDrop
    s.highlight.OutlineColor        = ESPColors.GunDrop
    s.highlight.FillTransparency    = State.ESP.FillTransparency
    s.highlight.OutlineTransparency = State.ESP.OutlineTransparency
    s.highlight.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    s.highlight.Enabled             = true

    if not s.billboard or not s.billboard.Parent then
        local bb = create("BillboardGui", {
            Name           = "AXIOM_ESP_GunLabel",
            Adornee        = handle,
            Size           = UDim2.new(0, 80, 0, 24),
            StudsOffset    = Vector3.new(0, 2, 0),
            AlwaysOnTop    = true,
            LightInfluence = 0,
        }, {
            create("TextLabel", {
                Size                   = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text                   = "GUN",
                Font                   = Enum.Font.GothamBold,
                TextSize               = 16,
                TextColor3             = Color3.fromRGB(255, 255, 255),
                TextStrokeColor3       = Color3.fromRGB(0, 0, 0),
                TextStrokeTransparency = 0,
            }),
        })
        s.billboard = bb
        bb.Parent = tool
    end
end

function ESP:removeGunDrop(tool)
    local s = self.gunDrops[tool]
    if not s then return end
    if s.highlight then s.highlight:Destroy() end
    if s.billboard then s.billboard:Destroy() end
    self.gunDrops[tool] = nil
end

function ESP:scanGunDrops()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if self:isGunDrop(obj) and not self.gunDrops[obj] then
            self:applyGunDrop(obj)
        end
    end
    for tool, _ in pairs(self.gunDrops) do
        if not tool.Parent or tool.Parent ~= Workspace then
            self:removeGunDrop(tool)
        end
    end
end

function ESP:disableAll()
    for player, s in pairs(self.tracked) do
        if s.highlight then s.highlight:Destroy() end
        self.tracked[player] = nil
    end
    for tool, s in pairs(self.gunDrops) do
        if s.highlight then s.highlight:Destroy() end
        if s.billboard then s.billboard:Destroy() end
        self.gunDrops[tool] = nil
    end
end

function ESP:tick()
    if not State.ESP.Enabled then return end
    for _, p in ipairs(Players:GetPlayers()) do
        pcall(function() self:applyPlayer(p) end)
    end
    pcall(function() self:scanGunDrops() end)
end

--======================== SILENT AIM MODULE ========================--
local SilentAim = {
    velocityHistory = {},
    lastPositions   = {},
    HISTORY_SIZE    = 8,
}

function SilentAim:trackVelocities()
    local now = tick()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local hrp = getHRP(p)
            if hrp then
                local prev = self.lastPositions[p]
                if prev then
                    local dt = now - prev.t
                    if dt > 0 then
                        local v = (hrp.Position - prev.pos) / dt
                        local hist = self.velocityHistory[p] or {}
                        table.insert(hist, v)
                        if #hist > self.HISTORY_SIZE then
                            table.remove(hist, 1)
                        end
                        self.velocityHistory[p] = hist
                    end
                end
                self.lastPositions[p] = { pos = hrp.Position, t = now }
            end
        end
    end
end

function SilentAim:smoothedVelocity(player)
    local hist = self.velocityHistory[player]
    if not hist or #hist == 0 then
        local hrp = getHRP(player)
        return hrp and hrp.AssemblyLinearVelocity or Vector3.new()
    end
    local sum = Vector3.new()
    for _, v in ipairs(hist) do sum = sum + v end
    return sum / #hist
end

function SilentAim:getPing()
    local ok, ping = pcall(function()
        return LocalPlayer:GetNetworkPing() * 2
    end)
    return ok and ping or 0
end

function SilentAim:computeAimPoint(target)
    local hrp = getHRP(target)
    if not hrp then return nil end

    local cfg = State.SilentAim
    local basePos = hrp.Position

    local horizonMs = 0
    if cfg.PrioritizePing then
        horizonMs = self:getPing() * 1000
    end
    horizonMs = math.min(horizonMs, cfg.MaxSimulationTime)
    local horizonSec = horizonMs / 1000

    local vel
    if cfg.PredictLag then
        vel = self:smoothedVelocity(target)
    else
        vel = hrp.AssemblyLinearVelocity
    end

    local stepMs  = math.max(1, cfg.PredictionInterval)
    local stepSec = stepMs / 1000
    local steps   = math.max(1, math.floor(horizonSec / stepSec))

    local hMul = cfg.HMultiplier / 100
    local vMul = cfg.VMultiplier / 100

    local velXZ = Vector3.new(vel.X, 0, vel.Z) * hMul
    local velY  = vel.Y * vMul

    local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
    local inAir = hum and (hum.FloorMaterial == Enum.Material.Air) or false
    local gravity = Workspace.Gravity

    local pos = basePos
    if cfg.PredictJump and inAir then
        for _ = 1, steps do
            pos = pos + velXZ * stepSec + Vector3.new(0, velY * stepSec, 0)
            velY = velY - gravity * stepSec
        end
    else
        local totalSec = stepSec * steps
        pos = basePos + Vector3.new(velXZ.X, velY, velXZ.Z) * totalSec
    end

    local sizeRef = 4
    local offX = (cfg.OffsetX / 100) * sizeRef
    local offY = (cfg.OffsetY / 100) * sizeRef
    local offZ = (cfg.OffsetZ / 100) * sizeRef
    local cf = hrp.CFrame
    pos = pos + cf.RightVector * offX
              + cf.UpVector    * offY
              + cf.LookVector  * offZ

    return pos
end

--======================== GUN TOOL HELPERS ========================--
function SilentAim:findGunTool()
    local char = LocalPlayer.Character
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") and (child.Name == "Gun" or child.Name == "Revolver") then
                return child, true
            end
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, child in ipairs(bp:GetChildren()) do
            if child:IsA("Tool") and (child.Name == "Gun" or child.Name == "Revolver") then
                return child, false
            end
        end
    end
    return nil, false
end

local KNOWN_GUN_REMOTES = {
    "KnifeServer", "ShootGun", "GunFire", "Shoot", "Fire",
}

local FIRE_VARIANTS = {
    function(remote, aimPos) remote:FireServer(CFrame.new(aimPos), aimPos) end,
    function(remote, aimPos) remote:FireServer(CFrame.new(aimPos))         end,
    function(remote, aimPos) remote:FireServer(aimPos)                     end,
    function(remote, aimPos) remote:FireServer(aimPos, aimPos)             end,
}

function SilentAim:shoot()
    -- 1. Найти ствол
    local gun, equipped = self:findGunTool()
    if not gun then
        warn("[AXIOM Shoot] No Gun tool found")
        return false, "no_gun"
    end

    -- 2. Экипировать, если в Backpack
    if not equipped then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not hum then
            warn("[AXIOM Shoot] No Humanoid")
            return false, "no_humanoid"
        end
        hum:EquipTool(gun)
        local waited = 0
        while waited < 0.5 do
            task.wait(0.05)
            waited = waited + 0.05
            local newGun, isEquipped = self:findGunTool()
            if isEquipped then
                gun = newGun
                equipped = true
                break
            end
        end
        if not equipped then
            warn("[AXIOM Shoot] Equip failed (still in Backpack after 0.5s)")
            return false, "equip_failed"
        end
    end

    -- 3. Цель
    local murderer = getMurderer()
    if not murderer then
        warn("[AXIOM Shoot] No murderer detected")
        return false, "no_murderer"
    end

    -- 4. Точка прицела
    local aim = self:computeAimPoint(murderer)
    if not aim then
        warn("[AXIOM Shoot] Could not compute aim point")
        return false, "no_aim_point"
    end

    -- 5. RemoteEvent для выстрела
    local fireRemote = nil
    for _, name in ipairs(KNOWN_GUN_REMOTES) do
        local r = gun:FindFirstChild(name, true)
        if r and r:IsA("RemoteEvent") then
            fireRemote = r
            break
        end
    end
    if not fireRemote then
        for _, child in ipairs(gun:GetDescendants()) do
            if child:IsA("RemoteEvent") then
                fireRemote = child
                break
            end
        end
    end
    if not fireRemote then
        warn("[AXIOM Shoot] No RemoteEvent inside Gun tool")
        return false, "no_remote"
    end

    -- 6. Server-side hit validation bypass — кратко повернуть камеру
    local originalCFrame = Camera.CFrame
    Camera.CFrame = CFrame.new(Camera.CFrame.Position, aim)

    -- 7. Перебор вариантов FireServer
    local success = false
    local lastError = nil
    for _, variant in ipairs(FIRE_VARIANTS) do
        local ok, err = pcall(variant, fireRemote, aim)
        if ok then success = true; break end
        lastError = err
    end

    -- 8. Вернуть камеру
    RunService.RenderStepped:Wait()
    Camera.CFrame = originalCFrame

    if not success then
        warn("[AXIOM Shoot] All variants failed: " .. tostring(lastError))
        return false, "all_variants_failed"
    end

    print("[AXIOM Shoot] Fired at " .. tostring(murderer.Name))
    return true, "ok"
end

--======================== HOOKS ========================--
local oldNamecall
local mt = getrawmetatable(game)
local setReadonly = (setreadonly or function() end)
setReadonly(mt, false)

oldNamecall = mt.__namecall
local function namecallHandler(self, ...)
    local method = getnamecallmethod()
    if State.SilentAim.Enabled and (method == "FireServer" or method == "InvokeServer") then
        local murderer = getMurderer()
        if murderer then
            local aim = SilentAim:computeAimPoint(murderer)
            if aim then
                local args = {...}
                for i, v in ipairs(args) do
                    if typeof(v) == "Vector3" then
                        args[i] = aim
                    elseif typeof(v) == "CFrame" then
                        args[i] = CFrame.new(aim)
                    end
                end
                return oldNamecall(self, table.unpack(args))
            end
        end
    end
    return oldNamecall(self, ...)
end
mt.__namecall = (newcclosure and newcclosure(namecallHandler)) or namecallHandler
setReadonly(mt, true)

if hookmetamethod then
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if State.SilentAim.Enabled and self == Mouse then
            if key == "Hit" then
                local m = getMurderer()
                if m then
                    local aim = SilentAim:computeAimPoint(m)
                    if aim then return CFrame.new(aim) end
                end
            elseif key == "Target" then
                local m = getMurderer()
                if m and m.Character then
                    local hrp = getHRP(m)
                    if hrp then return hrp end
                end
            end
        end
        return oldIndex(self, key)
    end)
end

--======================== GUI HELPERS ========================--
local function makeStroke(parent, color, thickness)
    return create("UIStroke", {
        Color     = color or Theme.Border,
        Thickness = thickness or 1,
        Parent    = parent,
    })
end

local function makeCorner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 6),
        Parent       = parent,
    })
end

--======================== GUI: ROOT ========================--
local ScreenGui = create("ScreenGui", {
    Name              = "AXIOM_Suite",
    ResetOnSpawn      = false,
    ZIndexBehavior    = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset    = true,
})
safeParent(ScreenGui)

--======================== GUI: MENU TOGGLE BUTTON ========================--
-- Маленький квадратик слева сверху с текстом "MENU"
local MenuToggle = create("TextButton", {
    Name             = "MenuToggle",
    Size             = UDim2.new(0, 64, 0, 28),
    Position         = UDim2.new(0, 16, 0, 16),
    BackgroundColor3 = Theme.MenuToggleBg,
    BorderSizePixel  = 0,
    Text             = "MENU",
    Font             = Enum.Font.GothamBold,
    TextSize         = 12,
    TextColor3       = Theme.TextPrimary,
    AutoButtonColor  = false,
    Parent           = ScreenGui,
})
makeCorner(MenuToggle, 6)
local menuToggleStroke = makeStroke(MenuToggle, Theme.Border, 1)

MenuToggle.MouseEnter:Connect(function()
    tween(MenuToggle, 0.1, { BackgroundColor3 = Theme.TabHover })
end)
MenuToggle.MouseLeave:Connect(function()
    tween(MenuToggle, 0.1, { BackgroundColor3 = Theme.MenuToggleBg })
end)

--======================== GUI: MAIN WINDOW ========================--
-- Двухколоночное вытянутое окно: слева вкладки, справа настройки
local MainFrame = create("Frame", {
    Name             = "Main",
    Size             = UDim2.new(0, 560, 0, 340),
    Position         = UDim2.new(0, 90, 0, 16),
    BackgroundColor3 = Theme.Background,
    BorderSizePixel  = 0,
    Parent           = ScreenGui,
})
makeCorner(MainFrame, 8)
makeStroke(MainFrame, Theme.Border, 1)

-- Title bar
local TitleBar = create("Frame", {
    Name             = "Title",
    Size             = UDim2.new(1, 0, 0, 32),
    BackgroundColor3 = Theme.Panel,
    BorderSizePixel  = 0,
    Parent           = MainFrame,
})
makeCorner(TitleBar, 8)

create("Frame", {
    Size             = UDim2.new(1, 0, 0, 16),
    Position         = UDim2.new(0, 0, 1, -16),
    BackgroundColor3 = Theme.Panel,
    BorderSizePixel  = 0,
    Parent           = TitleBar,
})

create("TextLabel", {
    Size                   = UDim2.new(1, -20, 1, 0),
    Position               = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text                   = "AXIOM",
    Font                   = Enum.Font.GothamBold,
    TextSize               = 14,
    TextColor3             = Theme.TextPrimary,
    TextXAlignment         = Enum.TextXAlignment.Left,
    Parent                 = TitleBar,
})

-- Drag logic для главного окна
do
    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = MainFrame.Position
        end
    end)
    TitleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputSvc.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                      or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

--======================== GUI: LEFT SIDEBAR (TABS) ========================--
local Sidebar = create("Frame", {
    Name             = "Sidebar",
    Size             = UDim2.new(0, 150, 1, -40),
    Position         = UDim2.new(0, 8, 0, 36),
    BackgroundColor3 = Theme.SidebarBg,
    BorderSizePixel  = 0,
    Parent           = MainFrame,
})
makeCorner(Sidebar, 6)
makeStroke(Sidebar, Theme.Border, 1)

create("UIListLayout", {
    Padding       = UDim.new(0, 4),
    SortOrder     = Enum.SortOrder.LayoutOrder,
    Parent        = Sidebar,
})
create("UIPadding", {
    PaddingTop    = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
    PaddingLeft   = UDim.new(0, 6),
    PaddingRight  = UDim.new(0, 6),
    Parent        = Sidebar,
})

--======================== GUI: RIGHT CONTENT AREA ========================--
local ContentArea = create("Frame", {
    Name             = "ContentArea",
    Size             = UDim2.new(1, -174, 1, -40),
    Position         = UDim2.new(0, 166, 0, 36),
    BackgroundColor3 = Theme.Panel,
    BorderSizePixel  = 0,
    Parent           = MainFrame,
})
makeCorner(ContentArea, 6)
makeStroke(ContentArea, Theme.Border, 1)

-- Заголовок текущей вкладки
local ContentTitle = create("TextLabel", {
    Size                   = UDim2.new(1, -16, 0, 24),
    Position               = UDim2.new(0, 12, 0, 8),
    BackgroundTransparency = 1,
    Text                   = "",
    Font                   = Enum.Font.GothamBold,
    TextSize               = 14,
    TextColor3             = Theme.TextPrimary,
    TextXAlignment         = Enum.TextXAlignment.Left,
    Parent                 = ContentArea,
})

local ContentScroll = create("ScrollingFrame", {
    Size                   = UDim2.new(1, -16, 1, -44),
    Position               = UDim2.new(0, 8, 0, 36),
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
    CanvasSize             = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness     = 4,
    ScrollBarImageColor3   = Theme.Border,
    Parent                 = ContentArea,
})

--======================== GUI: TAB SYSTEM ========================--
local Tabs = {}         -- name -> { button, page (Frame) }
local ActiveTab = nil

local function showTab(name)
    for tabName, tab in pairs(Tabs) do
        tab.page.Visible = (tabName == name)
        tween(tab.button, 0.1, {
            BackgroundColor3 = (tabName == name) and Theme.TabActive or Theme.SidebarBg
        })
    end
    ContentTitle.Text = name:upper()
    ActiveTab = name

    -- Пересчитать CanvasSize под содержимое
    task.wait()
    local page = Tabs[name].page
    local layout = page:FindFirstChildOfClass("UIListLayout")
    if layout then
        ContentScroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 12)
    end
end

local function makeTab(name, layoutOrder)
    local btn = create("TextButton", {
        Size             = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = Theme.SidebarBg,
        BorderSizePixel  = 0,
        Text             = name,
        Font             = Enum.Font.GothamMedium,
        TextSize         = 13,
        TextColor3       = Theme.TextPrimary,
        AutoButtonColor  = false,
        LayoutOrder      = layoutOrder,
        Parent           = Sidebar,
    })
    makeCorner(btn, 4)

    btn.MouseEnter:Connect(function()
        if ActiveTab ~= name then
            tween(btn, 0.1, { BackgroundColor3 = Theme.TabHover })
        end
    end)
    btn.MouseLeave:Connect(function()
        if ActiveTab ~= name then
            tween(btn, 0.1, { BackgroundColor3 = Theme.SidebarBg })
        end
    end)

    -- Страница содержимого
    local page = create("Frame", {
        Name             = "Page_" .. name,
        Size             = UDim2.new(1, 0, 0, 0),
        BackgroundTransparency = 1,
        AutomaticSize    = Enum.AutomaticSize.Y,
        Visible          = false,
        Parent           = ContentScroll,
    })
    create("UIListLayout", {
        Padding       = UDim.new(0, 6),
        SortOrder     = Enum.SortOrder.LayoutOrder,
        Parent        = page,
    })

    Tabs[name] = { button = btn, page = page }
    btn.MouseButton1Click:Connect(function() showTab(name) end)
    return page
end

--======================== GUI: WIDGETS ========================--
local function makeToggle(parent, labelText, initial, onChange)
    local row = create("Frame", {
        Size             = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.PanelAlt,
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    makeCorner(row, 6)
    local stroke = makeStroke(row, Theme.Border, 1)

    create("TextLabel", {
        Size                   = UDim2.new(1, -60, 1, 0),
        Position               = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text                   = labelText,
        Font                   = Enum.Font.Gotham,
        TextSize               = 13,
        TextColor3             = Theme.TextPrimary,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Parent                 = row,
    })

    local toggle = create("Frame", {
        Size             = UDim2.new(0, 40, 0, 18),
        Position         = UDim2.new(1, -50, 0.5, -9),
        BackgroundColor3 = Theme.ToggleOff,
        BorderSizePixel  = 0,
        Parent           = row,
    })
    makeCorner(toggle, 9)

    local knob = create("Frame", {
        Size             = UDim2.new(0, 14, 0, 14),
        Position         = UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = Color3.fromRGB(200, 200, 200),
        BorderSizePixel  = 0,
        Parent           = toggle,
    })
    makeCorner(knob, 7)

    local value = initial and true or false

    local function render()
        if value then
            tween(toggle, 0.15, { BackgroundColor3 = Theme.Accent })
            tween(knob,   0.15, { Position = UDim2.new(1, -16, 0.5, -7) })
            tween(stroke, 0.15, { Color = Theme.Accent })
        else
            tween(toggle, 0.15, { BackgroundColor3 = Theme.ToggleOff })
            tween(knob,   0.15, { Position = UDim2.new(0, 2, 0.5, -7) })
            tween(stroke, 0.15, { Color = Theme.Border })
        end
    end
    render()

    local btn = create("TextButton", {
        Size                   = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text                   = "",
        Parent                 = row,
    })
    btn.MouseButton1Click:Connect(function()
        value = not value
        render()
        if onChange then onChange(value) end
    end)

    return {
        frame = row,
        set = function(v) value = v and true or false; render() end,
        get = function() return value end,
    }
end

local function makeNumberInput(parent, labelText, minV, maxV, initial, onChange)
    local row = create("Frame", {
        Size             = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = Theme.PanelAlt,
        BorderSizePixel  = 0,
        Parent           = parent,
    })
    makeCorner(row, 6)
    makeStroke(row, Theme.Border, 1)

    create("TextLabel", {
        Size                   = UDim2.new(1, -110, 1, 0),
        Position               = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text                   = string.format("%s (%d..%d)", labelText, minV, maxV),
        Font                   = Enum.Font.Gotham,
        TextSize               = 12,
        TextColor3             = Theme.TextDim,
        TextXAlignment         = Enum.TextXAlignment.Left,
        Parent                 = row,
    })

    local box = create("TextBox", {
        Size                   = UDim2.new(0, 90, 0, 20),
        Position               = UDim2.new(1, -100, 0.5, -10),
        BackgroundColor3       = Theme.InputBg,
        BorderSizePixel        = 0,
        Text                   = tostring(initial),
        Font                   = Enum.Font.GothamMedium,
        TextSize               = 12,
        TextColor3             = Theme.TextPrimary,
        ClearTextOnFocus       = false,
        Parent                 = row,
    })
    makeCorner(box, 4)
    makeStroke(box, Theme.Border, 1)

    box.FocusLost:Connect(function()
        local n = tonumber(box.Text)
        if n then
            n = clamp(n, minV, maxV)
            box.Text = tostring(n)
            if onChange then onChange(n) end
        else
            box.Text = tostring(initial)
        end
    end)

    return row
end

local function makeSection(parent, name, layoutOrder)
    return create("TextLabel", {
        Size                   = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text                   = name,
        Font                   = Enum.Font.GothamBold,
        TextSize               = 11,
        TextColor3             = Theme.TextDim,
        TextXAlignment         = Enum.TextXAlignment.Left,
        LayoutOrder            = layoutOrder or 0,
        Parent                 = parent,
    })
end

--======================== GUI: BUILD TABS ========================--
-- ВКЛАДКА: VISUALS
local VisualsPage = makeTab("Visuals", 1)
makeSection(VisualsPage, "VISUALS", 1)
local espToggle = makeToggle(VisualsPage, "ESP", false, function(v)
    State.ESP.Enabled = v
    if not v then ESP:disableAll() end
end)
espToggle.frame.LayoutOrder = 2

-- ВКЛАДКА: COMBAT
local CombatPage = makeTab("Combat", 2)
makeSection(CombatPage, "GUN SILENT AIM", 1)

local aimToggle = makeToggle(CombatPage, "Enabled", false, function(v)
    State.SilentAim.Enabled = v
end)
aimToggle.frame.LayoutOrder = 2

local function aimChild(widget, order)
    if widget and widget.LayoutOrder ~= nil then
        widget.LayoutOrder = order
    elseif widget and widget.frame then
        widget.frame.LayoutOrder = order
    end
end

local t1 = makeToggle(CombatPage, "Prioritize Your Ping", false,
    function(v) State.SilentAim.PrioritizePing = v end)
t1.frame.LayoutOrder = 3

local t2 = makeToggle(CombatPage, "Predict Jump", false,
    function(v) State.SilentAim.PredictJump = v end)
t2.frame.LayoutOrder = 4

local t3 = makeToggle(CombatPage, "Predict Lag", false,
    function(v) State.SilentAim.PredictLag = v end)
t3.frame.LayoutOrder = 5

makeSection(CombatPage, "PREDICTION", 6)

local n1 = makeNumberInput(CombatPage, "Max Simulation Time (ms)", 30, 90,
    State.SilentAim.MaxSimulationTime,
    function(n) State.SilentAim.MaxSimulationTime = n end)
n1.LayoutOrder = 7

local n2 = makeNumberInput(CombatPage, "Prediction Interval (ms)", 1, 800,
    State.SilentAim.PredictionInterval,
    function(n) State.SilentAim.PredictionInterval = n end)
n2.LayoutOrder = 8

local n3 = makeNumberInput(CombatPage, "Horizontal Multiplier (%)", 90, 350,
    State.SilentAim.HMultiplier,
    function(n) State.SilentAim.HMultiplier = n end)
n3.LayoutOrder = 9

local n4 = makeNumberInput(CombatPage, "Vertical Multiplier (%)", 90, 350,
    State.SilentAim.VMultiplier,
    function(n) State.SilentAim.VMultiplier = n end)
n4.LayoutOrder = 10

makeSection(CombatPage, "POSITION OFFSETS", 11)

local n5 = makeNumberInput(CombatPage, "X Offset (%)", -350, 350,
    State.SilentAim.OffsetX,
    function(n) State.SilentAim.OffsetX = n end)
n5.LayoutOrder = 12

local n6 = makeNumberInput(CombatPage, "Y Offset (%)", -350, 350,
    State.SilentAim.OffsetY,
    function(n) State.SilentAim.OffsetY = n end)
n6.LayoutOrder = 13

local n7 = makeNumberInput(CombatPage, "Z Offset (%)", -350, 350,
    State.SilentAim.OffsetZ,
    function(n) State.SilentAim.OffsetZ = n end)
n7.LayoutOrder = 14

-- Открыть первую вкладку
showTab("Visuals")

--======================== GUI: SHOOT BUTTON (DRAGGABLE) ========================--
local ShootBtn = create("TextButton", {
    Name             = "ShootBtn",
    Size             = UDim2.new(0, 120, 0, 44),
    Position         = UDim2.new(0.5, -60, 1, -90),
    BackgroundColor3 = Theme.ShootBg,
    BorderSizePixel  = 0,
    Text             = "SHOOT",
    Font             = Enum.Font.GothamBold,
    TextSize         = 18,
    TextColor3       = Color3.fromRGB(255, 255, 255),
    AutoButtonColor  = false,
    Visible          = false,
    Parent           = ScreenGui,
})
makeCorner(ShootBtn, 10)
makeStroke(ShootBtn, Color3.fromRGB(255, 255, 255), 1).Transparency = 0.7

-- Логика драга для Shoot-кнопки
do
    local dragging = false
    local dragStart, startPos
    local dragMoved = false
    local DRAG_THRESHOLD = 6  -- пикселей, после чего считаем за drag, а не click

    ShootBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging   = true
            dragMoved  = false
            dragStart  = input.Position
            startPos   = ShootBtn.Position
        end
    end)

    UserInputSvc.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                      or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > DRAG_THRESHOLD or math.abs(delta.Y) > DRAG_THRESHOLD then
                dragMoved = true
            end
            if dragMoved then
                ShootBtn.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end
    end)

    ShootBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and not dragMoved then
                -- Это был клик, не драг — стреляем
                tween(ShootBtn, 0.08, { Size = UDim2.new(0, 116, 0, 42) })
                task.delay(0.08, function()
                    tween(ShootBtn, 0.08, { Size = UDim2.new(0, 120, 0, 44) })
                end)
                task.spawn(function() SilentAim:shoot() end)
            end
            dragging = false
        end
    end)
end

ShootBtn.MouseEnter:Connect(function()
    tween(ShootBtn, 0.1, { BackgroundColor3 = Theme.ShootHover })
end)
ShootBtn.MouseLeave:Connect(function()
    tween(ShootBtn, 0.1, { BackgroundColor3 = Theme.ShootBg })
end)

-- Sync SHOOT visibility with Silent Aim state
task.spawn(function()
    while ScreenGui.Parent do
        ShootBtn.Visible = State.SilentAim.Enabled
        task.wait(0.1)
    end
end)

--======================== MENU TOGGLE LOGIC ========================--
local function toggleMenu()
    MainFrame.Visible = not MainFrame.Visible
end

MenuToggle.MouseButton1Click:Connect(toggleMenu)

UserInputSvc.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightControl then
        toggleMenu()
    end
end)

--======================== LOOPS ========================--
RunService.Heartbeat:Connect(function()
    SilentAim:trackVelocities()
end)

task.spawn(function()
    while ScreenGui.Parent do
        ESP:tick()
        task.wait(State.ESP.RefreshInterval)
    end
end)

print("[AXIOM] loaded.")
