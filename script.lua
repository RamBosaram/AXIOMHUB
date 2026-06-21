--[[
=========================================================================
    AXIOM — MM2 Suite (build 2.0)
    Modules : ESP | Sheriff Aim | Murderer Knife Aim | World tools
    UI      : Draggable OpenPlate (left side), Menu, Floating buttons
=========================================================================
]]

if not game:IsLoaded() then
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "AXIOM",
        Text = "Waiting for the game to load...",
        Duration = 5
    })
    game.Loaded:Wait()
end

----------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------
local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local UIS           = game:GetService("UserInputService")
local CoreGui       = game:GetService("CoreGui")
local HttpService   = game:GetService("HttpService")
local TextChatSvc   = game:GetService("TextChatService")

local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------
local AXIOM = {}
AXIOM.__v = "2.0-MM2"

local State = {
    -- Visuals
    playerESP        = false,
    gunDropESP       = false,
    trapESP          = false,
    hideMeESP        = false,
    roundTimerOn     = false,

    -- Sheriff combat
    autoShoot          = false,
    instakillShoot     = false,
    sheriffWallCheck   = true,
    autoUnequipGun     = true,
    shootOffset        = 2.8,
    offsetPingMult     = 1.0,

    -- Sheriff prediction
    sheriffPrioritizePing  = false,
    sheriffPredictJump     = false,
    sheriffPredictLag      = false,
    sheriffMaxSim          = 60,
    sheriffInterval        = 100,
    sheriffHMul            = 100,
    sheriffVMul            = 100,
    sheriffOffsetX         = 0,
    sheriffOffsetY         = 0,
    sheriffOffsetZ         = 0,

    -- Murderer combat
    loopKnifeThrow       = false,
    spawnKnifeAtPlayer   = false,
    killAuraOn           = false,
    autoGetGun           = false,
    murdererWallCheck    = true,
    knifeFOVEnabled      = false,
    knifeFOV             = 200,
    knifeOffset          = 3.5,

    -- Murderer knife prediction
    knifePrioritizePing  = false,
    knifePredictJump     = false,
    knifePredictLag      = false,
    knifeMaxSim          = 80,
    knifeInterval        = 100,
    knifeHMul            = 100,
    knifeVMul            = 100,
    knifeOffsetX         = 0,
    knifeOffsetY         = 0,
    knifeOffsetZ         = 0,

    -- World
    fly              = false,
    flySpeed         = 50,
    infJump          = false,
    infJumpLimit2    = false,
    loopWSFOV        = false,
    ws               = 16,
    fov              = 70,
    ctrlClickTP      = false,
    hitboxExpand     = 1,
    aggressiveHitbox = false,
    loopHitbox       = false,
    noclip           = false,
    antiFling        = false,
    antiAFK          = false,

    hubOpen          = true,
}

local Theme = {
    font           = Enum.Font.Montserrat,
    text           = Color3.fromRGB(255, 255, 255),
    accent         = Color3.fromRGB(140, 90, 255),
    accentAlt      = Color3.fromRGB(90, 200, 255),
    accentDeep     = Color3.fromRGB(75, 50, 180),
    primary        = Color3.fromRGB(14, 12, 18),
    secondary      = Color3.fromRGB(8, 8, 12),
    danger         = Color3.fromRGB(255, 60, 80),
    bgGradient     = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromRGB(8, 8, 8)),
        ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(16, 13, 22)),
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(22, 18, 28)),
    }),
    strokeGradient = ColorSequence.new({
        ColorSequenceKeypoint.new(0,    Color3.fromRGB(140, 90, 255)),
        ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(90, 200, 255)),
        ColorSequenceKeypoint.new(1,    Color3.fromRGB(75, 50, 180)),
    }),
}

----------------------------------------------------------------
-- UTILITIES
----------------------------------------------------------------
local function safeGetCharacter() return LocalPlayer.Character end
local function safeGetHRP()
    local c = safeGetCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function safeGetHumanoid()
    local c = safeGetCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function randomString()
    local len = math.random(10, 20)
    local out = {}
    for i = 1, len do out[i] = string.char(math.random(65, 90)) end
    return table.concat(out)
end

----------------------------------------------------------------
-- ROOT GUI
----------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = randomString()
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 3

do
    local ok = pcall(function()
        local hidden = (gethui and gethui()) or (get_hidden_gui and get_hidden_gui())
        if hidden then
            ScreenGui.Parent = hidden
        elseif syn and syn.protect_gui then
            syn.protect_gui(ScreenGui)
            ScreenGui.Parent = CoreGui
        else
            ScreenGui.Parent = CoreGui
        end
    end)
    if not ok then ScreenGui.Parent = CoreGui end
end

----------------------------------------------------------------
-- NOTIFICATIONS
----------------------------------------------------------------
local NotifContainer = Instance.new("Frame")
NotifContainer.Name = "Notifications"
NotifContainer.AnchorPoint = Vector2.new(0.5, 0)
NotifContainer.Position = UDim2.new(0.5, 0, 0, 0)
NotifContainer.Size = UDim2.new(0, 400, 1, 0)
NotifContainer.BackgroundTransparency = 1
NotifContainer.Parent = ScreenGui

local notifLayout = Instance.new("UIListLayout")
notifLayout.Padding = UDim.new(0, 8)
notifLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
notifLayout.VerticalAlignment = Enum.VerticalAlignment.Top
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.Parent = NotifContainer

local notifPad = Instance.new("UIPadding", NotifContainer)
notifPad.PaddingTop = UDim.new(0, 70)

local function notify(text, color, duration)
    color = color or Theme.accent
    duration = duration or 4

    local n = Instance.new("Frame")
    n.Size = UDim2.new(0, 400, 0, 50)
    n.BackgroundColor3 = Theme.secondary
    n.BackgroundTransparency = 0.05
    n.BorderSizePixel = 0
    n.Parent = NotifContainer
    n.ClipsDescendants = true

    local corner = Instance.new("UICorner", n)
    corner.CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", n)
    stroke.Color = color
    stroke.Thickness = 1.6
    stroke.Transparency = 0.2

    local grad = Instance.new("UIGradient", n)
    grad.Color = Theme.bgGradient
    grad.Rotation = 45

    local icon = Instance.new("Frame", n)
    icon.AnchorPoint = Vector2.new(0, 0.5)
    icon.Position = UDim2.new(0, 14, 0.5, 0)
    icon.Size = UDim2.fromOffset(8, 24)
    icon.BackgroundColor3 = color
    icon.BorderSizePixel = 0
    Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)

    local label = Instance.new("TextLabel", n)
    label.AnchorPoint = Vector2.new(0, 0.5)
    label.Position = UDim2.new(0, 36, 0.5, 0)
    label.Size = UDim2.new(1, -70, 1, -10)
    label.BackgroundTransparency = 1
    label.Font = Theme.font
    label.TextColor3 = Theme.text
    label.TextSize = 14
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.Text = tostring(text)

    local close = Instance.new("TextButton", n)
    close.AnchorPoint = Vector2.new(1, 0.5)
    close.Position = UDim2.new(1, -10, 0.5, 0)
    close.Size = UDim2.fromOffset(22, 22)
    close.BackgroundTransparency = 1
    close.Text = "×"
    close.TextColor3 = Theme.text
    close.Font = Enum.Font.GothamBold
    close.TextSize = 18

    local scale = Instance.new("UIScale", n)
    scale.Scale = 0.5
    n.Position = UDim2.new(0.5, 0, -0.2, 0)

    TweenService:Create(n, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 0, 0)
    }):Play()
    TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = 1
    }):Play()

    local closed = false
    local function closeNotif()
        if closed then return end
        closed = true
        local fade = TweenService:Create(n, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0.5, 0, -0.2, 0),
            BackgroundTransparency = 1
        })
        TweenService:Create(scale, TweenInfo.new(0.4), {Scale = 0.5}):Play()
        fade:Play()
        fade.Completed:Wait()
        n:Destroy()
    end

    close.MouseButton1Click:Connect(closeNotif)
    task.delay(duration, closeNotif)
end

AXIOM.notify = notify

----------------------------------------------------------------
-- MULTI-TOUCH SAFE DRAGGABLE
----------------------------------------------------------------
-- Per-input dragging: каждый touch отслеживается своим input объектом.
-- Это решает баг "палец на джойстике теряется, когда другой палец тапает кнопку".
local function makeDraggable(frame, dragHandle)
    dragHandle = dragHandle or frame
    dragHandle.Active = true

    local activeInput = nil
    local dragStart = nil
    local startPos = nil

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if activeInput then return end
            activeInput = input
            dragStart = input.Position
            startPos = frame.Position

            local stateChange
            stateChange = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    stateChange:Disconnect()
                    if activeInput == input then activeInput = nil end
                end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input ~= activeInput then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end

        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end)
end

----------------------------------------------------------------
-- FLOATING BUTTONS LAYER
----------------------------------------------------------------
local FloatingLayer = Instance.new("Frame", ScreenGui)
FloatingLayer.Name = "FloatingLayer"
FloatingLayer.Size = UDim2.new(1, 0, 1, 0)
FloatingLayer.BackgroundTransparency = 1
FloatingLayer.ZIndex = 5
FloatingLayer.Active = false  -- не блокируем нижние input'ы

local floatingButtons = {}

local function makeFloatingButton(label, callback)
    if floatingButtons[label] then
        floatingButtons[label]:Destroy()
        floatingButtons[label] = nil
        notify("Floating button removed: "..label, Theme.accentAlt, 2)
        return
    end

    local btn = Instance.new("TextButton", FloatingLayer)
    btn.Size = UDim2.fromOffset(160, 44)
    btn.Position = UDim2.fromOffset(80, 100 + (#FloatingLayer:GetChildren() * 52))
    btn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    btn.BackgroundTransparency = 0.15
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.Font = Theme.font
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    btn.AutoButtonColor = false
    btn.ZIndex = 5
    btn.ClipsDescendants = true
    btn.Active = true
    btn.Modal = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", btn)
    stroke.Thickness = 1.5
    stroke.Color = Color3.new(1, 1, 1)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    local strokeGrad = Instance.new("UIGradient", stroke)
    strokeGrad.Color = Theme.strokeGradient
    strokeGrad.Rotation = 45

    task.spawn(function()
        while strokeGrad.Parent do
            TweenService:Create(strokeGrad, TweenInfo.new(8, Enum.EasingStyle.Linear), {Rotation = 405}):Play()
            task.wait(8)
            strokeGrad.Rotation = 45
        end
    end)

    local scale = Instance.new("UIScale", btn)
    scale.Scale = 0
    TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = 1
    }):Play()

    -- per-input multi-touch handling
    local activeInput = nil
    local dragStart, startPos
    local moved = false
    local DRAG_THRESHOLD = 8
    local longPressTask = nil

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if activeInput then return end
            activeInput = input
            dragStart = input.Position
            startPos = btn.Position
            moved = false

            if input.UserInputType == Enum.UserInputType.Touch then
                longPressTask = task.delay(1.5, function()
                    if floatingButtons[label] and not moved then
                        floatingButtons[label]:Destroy()
                        floatingButtons[label] = nil
                        notify("Floating button removed: "..label, Theme.accentAlt, 2)
                    end
                end)
            end

            local stateChange
            stateChange = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    stateChange:Disconnect()
                    if longPressTask then task.cancel(longPressTask) longPressTask = nil end

                    if not moved and activeInput == input then
                        TweenService:Create(scale, TweenInfo.new(0.08), {Scale = 0.93}):Play()
                        task.delay(0.08, function()
                            TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                                Scale = 1
                            }):Play()
                        end)
                        local ok, err = pcall(callback, btn)
                        if not ok then notify("Error: "..tostring(err), Theme.danger) end
                    end
                    activeInput = nil
                end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input ~= activeInput then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end

        local delta = input.Position - dragStart
        if math.abs(delta.X) > DRAG_THRESHOLD or math.abs(delta.Y) > DRAG_THRESHOLD then
            moved = true
            if longPressTask then task.cancel(longPressTask) longPressTask = nil end
        end
        if moved then
            btn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    btn.MouseButton2Click:Connect(function()
        if floatingButtons[label] then
            floatingButtons[label]:Destroy()
            floatingButtons[label] = nil
            notify("Floating button removed: "..label, Theme.accentAlt, 2)
        end
    end)

    floatingButtons[label] = btn
    notify("Floating button created. Long-press (mobile) or right-click (PC) to remove.", Theme.accent, 3)
end

----------------------------------------------------------------
-- OPEN/CLOSE BUTTON (DRAGGABLE, LEFT SIDE START)
----------------------------------------------------------------
local OpenPlate = Instance.new("TextButton", ScreenGui)
OpenPlate.Name = "OpenPlate"
OpenPlate.AnchorPoint = Vector2.new(0, 0.5)
OpenPlate.Position = UDim2.new(0, 14, 0.5, 0)  -- слева по центру
OpenPlate.Size = UDim2.fromOffset(56, 56)
OpenPlate.BackgroundColor3 = Color3.new(1, 1, 1)
OpenPlate.AutoButtonColor = false
OpenPlate.Text = ""
OpenPlate.BorderSizePixel = 0
OpenPlate.ZIndex = 10
OpenPlate.Active = true

local plateCorner = Instance.new("UICorner", OpenPlate)
plateCorner.CornerRadius = UDim.new(0, 14)

local plateStroke = Instance.new("UIStroke", OpenPlate)
plateStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
plateStroke.Thickness = 2.5
plateStroke.Color = Color3.new(1, 1, 1)
local plateStrokeGrad = Instance.new("UIGradient", plateStroke)
plateStrokeGrad.Color = Theme.strokeGradient
plateStrokeGrad.Rotation = 45

local plateScale = Instance.new("UIScale", OpenPlate)
plateScale.Scale = 1

local DiamondHolder = Instance.new("Frame", OpenPlate)
DiamondHolder.AnchorPoint = Vector2.new(0.5, 0.5)
DiamondHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
DiamondHolder.Size = UDim2.fromOffset(34, 34)
DiamondHolder.BackgroundTransparency = 1
DiamondHolder.ZIndex = 11

local Diamond = Instance.new("Frame", DiamondHolder)
Diamond.AnchorPoint = Vector2.new(0.5, 0.5)
Diamond.Position = UDim2.new(0.5, 0, 0.5, 0)
Diamond.Size = UDim2.fromOffset(26, 26)
Diamond.Rotation = 45
Diamond.BackgroundColor3 = Theme.accent
Diamond.BorderSizePixel = 0
Diamond.ZIndex = 11
local diamondCorner = Instance.new("UICorner", Diamond)
diamondCorner.CornerRadius = UDim.new(0, 3)

local diamondGrad = Instance.new("UIGradient", Diamond)
diamondGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.accent),
    ColorSequenceKeypoint.new(0.5, Theme.accentAlt),
    ColorSequenceKeypoint.new(1, Theme.accentDeep),
})
diamondGrad.Rotation = 90

local function makeStripe(offsetY)
    local s = Instance.new("Frame", Diamond)
    s.AnchorPoint = Vector2.new(0.5, 0.5)
    s.Position = UDim2.new(0.5, 0, 0.5, offsetY)
    s.Size = UDim2.fromOffset(38, 2)
    s.BackgroundColor3 = Color3.new(1, 1, 1)
    s.BackgroundTransparency = 0.75
    s.BorderSizePixel = 0
    s.ZIndex = 12
end
makeStripe(-6)
makeStripe(0)
makeStripe(6)

task.spawn(function()
    while plateStrokeGrad.Parent do
        TweenService:Create(plateStrokeGrad, TweenInfo.new(6, Enum.EasingStyle.Linear), {Rotation = 405}):Play()
        task.wait(6)
        plateStrokeGrad.Rotation = 45
    end
end)
task.spawn(function()
    while diamondGrad.Parent do
        TweenService:Create(diamondGrad, TweenInfo.new(4, Enum.EasingStyle.Linear), {Rotation = 450}):Play()
        task.wait(4)
        diamondGrad.Rotation = 90
    end
end)

-- Drag для OpenPlate (тоже мульти-тач safe)
do
    local activeInput = nil
    local dragStart, startPos
    local moved = false
    local DRAG_THRESHOLD = 6
    local pendingClick = nil

    OpenPlate.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if activeInput then return end
            activeInput = input
            dragStart = input.Position
            startPos = OpenPlate.Position
            moved = false

            local stateChange
            stateChange = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    stateChange:Disconnect()
                    if not moved and activeInput == input then
                        pendingClick = true
                    end
                    activeInput = nil
                end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input ~= activeInput then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end

        local delta = input.Position - dragStart
        if math.abs(delta.X) > DRAG_THRESHOLD or math.abs(delta.Y) > DRAG_THRESHOLD then
            moved = true
        end
        if moved then
            OpenPlate.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Click consumer для openMenu / closeMenu (определяется ниже)
    AXIOM.__platePoll = function()
        if pendingClick then
            pendingClick = false
            return true
        end
        return false
    end
end

----------------------------------------------------------------
-- MAIN MENU
----------------------------------------------------------------
local Menu = Instance.new("Frame")
Menu.Name = "Menu"
Menu.AnchorPoint = Vector2.new(0.5, 0)
Menu.Position = UDim2.new(0.5, 0, -0.6, 0)
Menu.Size = UDim2.fromOffset(441, 268)
Menu.BackgroundColor3 = Theme.primary
Menu.BorderSizePixel = 0
Menu.Parent = ScreenGui
Menu.ClipsDescendants = true
Menu.Active = true

local menuScale = Instance.new("UIScale", Menu)
menuScale.Scale = 1

local menuCorner = Instance.new("UICorner", Menu)
menuCorner.CornerRadius = UDim.new(0, 14)

local menuGrad = Instance.new("UIGradient", Menu)
menuGrad.Color = Theme.bgGradient
menuGrad.Rotation = 135

local menuStroke = Instance.new("UIStroke", Menu)
menuStroke.Thickness = 1.5
menuStroke.Color = Color3.new(1,1,1)
local menuStrokeGrad = Instance.new("UIGradient", menuStroke)
menuStrokeGrad.Color = Theme.strokeGradient
menuStrokeGrad.Rotation = 45

task.spawn(function()
    while menuStrokeGrad.Parent do
        TweenService:Create(menuStrokeGrad, TweenInfo.new(8, Enum.EasingStyle.Linear), {Rotation = 405}):Play()
        task.wait(8)
        menuStrokeGrad.Rotation = 45
    end
end)

-- Header
local Header = Instance.new("Frame", Menu)
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundTransparency = 1
Header.Active = true

local Title = Instance.new("TextLabel", Header)
Title.AnchorPoint = Vector2.new(0, 0.5)
Title.Position = UDim2.new(0, 16, 0.5, 0)
Title.Size = UDim2.new(0, 150, 1, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.Text = "AXIOM"
Title.TextColor3 = Theme.text
Title.TextSize = 18
Title.TextXAlignment = Enum.TextXAlignment.Left

makeDraggable(Menu, Header)

-- Side tabs (с фиксом левого нижнего угла)
local TabBar = Instance.new("Frame", Menu)
TabBar.Position = UDim2.new(0, 0, 0, 40)
TabBar.Size = UDim2.new(0, 110, 1, -40)
TabBar.BackgroundColor3 = Theme.secondary
TabBar.BackgroundTransparency = 0.3
TabBar.BorderSizePixel = 0


local tabLayout = Instance.new("UIListLayout", TabBar)
tabLayout.Padding = UDim.new(0, 4)
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder

local tabPad = Instance.new("UIPadding", TabBar)
tabPad.PaddingTop = UDim.new(0, 8)
tabPad.PaddingLeft = UDim.new(0, 6)
tabPad.PaddingRight = UDim.new(0, 6)
local tabBarCorner = Instance.new("UICorner", TabBar)
tabBarCorner.CornerRadius = UDim.new(0, 14)
local Content = Instance.new("Frame", Menu)
Content.Position = UDim2.new(0, 110, 0, 40)
Content.Size = UDim2.new(1, -110, 1, -40)
Content.BackgroundTransparency = 1

local Pages = {}
local currentPage = nil

local function makeTab(name, order)
    local btn = Instance.new("TextButton", TabBar)
    btn.Name = name.."Tab"
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(28, 24, 38)  -- светлее фона
    btn.BackgroundTransparency = 0.1
    btn.BorderSizePixel = 0
    btn.Text = name
    btn.Font = Enum.Font.GothamBold                     -- жирный
    btn.TextColor3 = Theme.text
    btn.TextSize = 14
    btn.LayoutOrder = order
    btn.AutoButtonColor = false
    btn.Active = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    -- Тонкая обводка для контраста
    local btnStroke = Instance.new("UIStroke", btn)
    btnStroke.Color = Theme.accentDeep
    btnStroke.Thickness = 1
    btnStroke.Transparency = 0.6

    local page = Instance.new("ScrollingFrame", Content)
    page.Name = name.."Page"
    page.Size = UDim2.new(1, -16, 1, -16)
    page.Position = UDim2.new(0, 8, 0, 8)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = Theme.accent
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false

    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

    Pages[name] = {button = btn, page = page, order = 0, stroke = btnStroke}

    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do
            p.page.Visible = false
            TweenService:Create(p.button, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(28, 24, 38),
                BackgroundTransparency = 0.1
            }):Play()
            if p.stroke then
                TweenService:Create(p.stroke, TweenInfo.new(0.2), {
                    Color = Theme.accentDeep,
                    Transparency = 0.6
                }):Play()
            end
        end
        page.Visible = true
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundColor3 = Theme.accentDeep,
            BackgroundTransparency = 0
        }):Play()
        TweenService:Create(btnStroke, TweenInfo.new(0.2), {
            Color = Theme.accent,
            Transparency = 0
        }):Play()
        currentPage = name

        page.Position = UDim2.new(0, 8, 0, 16)
        TweenService:Create(page, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 8, 0, 8)
        }):Play()
    end)

    return Pages[name]
end

local VisualPage  = makeTab("Visual", 1)
local CombatPage  = makeTab("Combat", 2)
local WorldPage   = makeTab("World", 3)
----------------------------------------------------------------
-- WIDGETS (multi-touch safe)
----------------------------------------------------------------
-- Универсальный per-input click handler для виджетов.
-- Использует ту же логику, что и floating-кнопка: индивидуальный input.Changed.
local function safeClick(target, onClick)
    target.Active = true
    local activeInput = nil

    target.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if activeInput then return end
            activeInput = input

            local stateChange
            stateChange = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    stateChange:Disconnect()
                    if activeInput == input then
                        activeInput = nil
                        -- Проверка что палец всё ещё над кнопкой
                        local pos = input.Position
                        local absPos = target.AbsolutePosition
                        local absSize = target.AbsoluteSize
                        if pos.X >= absPos.X and pos.X <= absPos.X + absSize.X
                        and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y then
                            local ok, err = pcall(onClick)
                            if not ok then notify("Error: "..tostring(err), Theme.danger) end
                        end
                    end
                end
            end)
        end
    end)
end

local function attachPinButton(row, label, callback)
    local pin = Instance.new("TextButton", row)
    pin.AnchorPoint = Vector2.new(1, 0.5)
    pin.Position = UDim2.new(1, -4, 0.5, 0)
    pin.Size = UDim2.fromOffset(20, 20)
    pin.BackgroundColor3 = Theme.accentDeep
    pin.BorderSizePixel = 0
    pin.Text = "+"
    pin.Font = Enum.Font.GothamBold
    pin.TextColor3 = Theme.text
    pin.TextSize = 14
    pin.AutoButtonColor = false
    pin.ZIndex = 3
    pin.Active = true
    Instance.new("UICorner", pin).CornerRadius = UDim.new(1, 0)

    pin.MouseEnter:Connect(function()
        TweenService:Create(pin, TweenInfo.new(0.2), {BackgroundColor3 = Theme.accent}):Play()
    end)
    pin.MouseLeave:Connect(function()
        TweenService:Create(pin, TweenInfo.new(0.2), {BackgroundColor3 = Theme.accentDeep}):Play()
    end)

    safeClick(pin, function() makeFloatingButton(label, callback) end)
    return pin
end

local function addSection(pageData, title)
    local lbl = Instance.new("TextLabel", pageData.page)
    lbl.Size = UDim2.new(1, -10, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = title
    lbl.TextColor3 = Theme.accentAlt
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    pageData.order = pageData.order + 1
    lbl.LayoutOrder = pageData.order
    return lbl
end

local function addText(pageData, text)
    local lbl = Instance.new("TextLabel", pageData.page)
    lbl.Size = UDim2.new(1, -10, 0, 18)
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.BackgroundTransparency = 1
    lbl.Font = Theme.font
    lbl.Text = text
    lbl.TextColor3 = Theme.text
    lbl.TextTransparency = 0.3
    lbl.TextSize = 11
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.RichText = true
    pageData.order = pageData.order + 1
    lbl.LayoutOrder = pageData.order
    return lbl
end

local function addButton(pageData, text, callback)
    local row = Instance.new("Frame", pageData.page)
    row.Size = UDim2.new(1, -10, 0, 28)
    row.BackgroundTransparency = 1
    pageData.order = pageData.order + 1
    row.LayoutOrder = pageData.order

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1, -28, 1, 0)
    btn.Position = UDim2.new(0, 0, 0, 0)
    btn.BackgroundColor3 = Theme.secondary
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.Font = Theme.font
    btn.TextColor3 = Theme.text
    btn.TextSize = 12
    btn.AutoButtonColor = false
    btn.Active = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Theme.accentDeep
    stroke.Thickness = 1
    stroke.Transparency = 0.5

    btn.MouseEnter:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0.1, Color = Theme.accent}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0.5, Color = Theme.accentDeep}):Play()
    end)

    local btnScale = Instance.new("UIScale", btn)
    safeClick(btn, function()
        TweenService:Create(btnScale, TweenInfo.new(0.08), {Scale = 0.97}):Play()
        task.delay(0.08, function()
            TweenService:Create(btnScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        end)
        callback(btn)
    end)

    attachPinButton(row, text, callback)
    return row
end

local function addToggle(pageData, text, default, callback)
    local row = Instance.new("Frame", pageData.page)
    row.Size = UDim2.new(1, -10, 0, 28)
    row.BackgroundTransparency = 1
    pageData.order = pageData.order + 1
    row.LayoutOrder = pageData.order

    local frame = Instance.new("Frame", row)
    frame.Size = UDim2.new(1, -28, 1, 0)
    frame.BackgroundColor3 = Theme.secondary
    frame.BorderSizePixel = 0
    frame.Active = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", frame)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Theme.font
    lbl.Text = text
    lbl.TextColor3 = Theme.text
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", frame)
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, -8, 0.5, 0)
    track.Size = UDim2.fromOffset(34, 16)
    track.BackgroundColor3 = Theme.primary
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", track)
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Position = UDim2.new(0, 2, 0.5, 0)
    knob.Size = UDim2.fromOffset(12, 12)
    knob.BackgroundColor3 = Color3.new(0.6, 0.6, 0.7)
    knob.BorderSizePixel = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = default or false
    local function refresh()
        if state then
            TweenService:Create(knob, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(1, -14, 0.5, 0),
                BackgroundColor3 = Theme.accent
            }):Play()
            TweenService:Create(track, TweenInfo.new(0.2), {BackgroundColor3 = Theme.accentDeep}):Play()
        else
            TweenService:Create(knob, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 2, 0.5, 0),
                BackgroundColor3 = Color3.new(0.6, 0.6, 0.7)
            }):Play()
            TweenService:Create(track, TweenInfo.new(0.2), {BackgroundColor3 = Theme.primary}):Play()
        end
    end
    refresh()

    local function flip()
        state = not state
        refresh()
        local ok, err = pcall(callback, state)
        if not ok then notify("Error: "..tostring(err), Theme.danger) end
    end

    safeClick(frame, flip)
    attachPinButton(row, text, flip)
    return row
end

local function addInput(pageData, placeholder, buttonText, callback)
    local row = Instance.new("Frame", pageData.page)
    row.Size = UDim2.new(1, -10, 0, 28)
    row.BackgroundTransparency = 1
    pageData.order = pageData.order + 1
    row.LayoutOrder = pageData.order

    local box = Instance.new("TextBox", row)
    box.Size = UDim2.new(1, -100, 1, 0)
    box.Position = UDim2.new(0, 0, 0, 0)
    box.BackgroundColor3 = Theme.secondary
    box.BorderSizePixel = 0
    box.PlaceholderText = placeholder
    box.PlaceholderColor3 = Color3.fromRGB(120, 120, 130)
    box.Text = ""
    box.Font = Theme.font
    box.TextColor3 = Theme.text
    box.TextSize = 11
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
    local boxPad = Instance.new("UIPadding", box)
    boxPad.PaddingLeft = UDim.new(0, 8)
    boxPad.PaddingRight = UDim.new(0, 8)

    local btn = Instance.new("TextButton", row)
    btn.Position = UDim2.new(1, -94, 0, 0)
    btn.Size = UDim2.new(0, 66, 1, 0)
    btn.BackgroundColor3 = Theme.accentDeep
    btn.BorderSizePixel = 0
    btn.Text = buttonText
    btn.Font = Theme.font
    btn.TextColor3 = Theme.text
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.Active = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.accent}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Theme.accentDeep}):Play()
    end)

    safeClick(btn, function() callback(box.Text, box) end)

    attachPinButton(row, placeholder, function() callback(box.Text, box) end)
    return row
end

local function addSlider(pageData, text, min, max, default, step, callback)
    local row = Instance.new("Frame", pageData.page)
    row.Size = UDim2.new(1, -10, 0, 44)
    row.BackgroundTransparency = 1
    pageData.order = pageData.order + 1
    row.LayoutOrder = pageData.order

    local frame = Instance.new("Frame", row)
    frame.Size = UDim2.new(1, -28, 1, 0)
    frame.BackgroundColor3 = Theme.secondary
    frame.BorderSizePixel = 0
    frame.Active = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel", frame)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.Size = UDim2.new(1, -20, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Font = Theme.font
    lbl.Text = text..": "..tostring(default)
    lbl.TextColor3 = Theme.text
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local track = Instance.new("Frame", frame)
    track.Position = UDim2.new(0, 10, 1, -14)
    track.Size = UDim2.new(1, -20, 0, 5)
    track.BackgroundColor3 = Theme.primary
    track.BorderSizePixel = 0
    track.Active = true
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Theme.accent
    fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local fillGrad = Instance.new("UIGradient", fill)
    fillGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.accentDeep),
        ColorSequenceKeypoint.new(1, Theme.accentAlt),
    })

    -- per-input slider drag (multi-touch safe)
    local activeInput = nil

    local function update(inputPos)
        local rel = math.clamp((inputPos.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local value = min + (max - min) * rel
        if step and step > 0 then
            value = math.floor(value / step + 0.5) * step
        end
        value = math.clamp(value, min, max)
        fill.Size = UDim2.new((value - min) / (max - min), 0, 1, 0)
        lbl.Text = text..": "..(step and step >= 1 and math.floor(value) or string.format("%.2f", value))
        pcall(callback, value)
    end

    -- Dead-zone: слайдер активируется только если палец двинулся горизонтально
    -- больше чем на 8px, либо удерживается на месте больше 150мс.
    -- Это позволяет нормально листать страницу через слайдер не задевая его.
    local DRAG_THRESHOLD = 8
    local HOLD_MS = 150
    local startPos = nil
    local startTime = 0
    local engaged = false
    local engageTask = nil

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if activeInput then return end
            activeInput = input
            startPos = input.Position
            startTime = tick()
            engaged = false

            -- Через HOLD_MS активируем слайдер если палец не сдвинулся вертикально
            engageTask = task.delay(HOLD_MS / 1000, function()
                if activeInput == input and not engaged then
                    engaged = true
                    update(input.Position)
                end
            end)

            local stateChange
            stateChange = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    stateChange:Disconnect()
                    if engageTask then task.cancel(engageTask) engageTask = nil end
                    if activeInput == input then activeInput = nil end
                    engaged = false
                end
            end)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if input ~= activeInput then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end

        if not engaged then
            local delta = input.Position - startPos
            -- Если вертикальное движение больше горизонтального — пользователь листает страницу
            if math.abs(delta.Y) > math.abs(delta.X) and math.abs(delta.Y) > DRAG_THRESHOLD then
                activeInput = nil
                if engageTask then task.cancel(engageTask) engageTask = nil end
                return
            end
            -- Если горизонтальное движение превысило порог — это слайдер
            if math.abs(delta.X) > DRAG_THRESHOLD then
                engaged = true
                if engageTask then task.cancel(engageTask) engageTask = nil end
            end
        end

        if engaged then
            update(input.Position)
        end
    end)

    return row
end

----------------------------------------------------------------
-- ESP CONTAINER
----------------------------------------------------------------
local ESPGui = Instance.new("ScreenGui")
ESPGui.Name = randomString()
ESPGui.ResetOnSpawn = false
ESPGui.IgnoreGuiInset = true
ESPGui.DisplayOrder = 2
do
    local ok = pcall(function()
        local hidden = (gethui and gethui()) or (get_hidden_gui and get_hidden_gui())
        if hidden then ESPGui.Parent = hidden else ESPGui.Parent = CoreGui end
    end)
    if not ok then ESPGui.Parent = CoreGui end
end

local ESP = {}
ESP.entries = {}

function ESP:Add(adornee, opts)
    if not adornee or not adornee.Parent then return end
    if self.entries[adornee] then self:Remove(adornee) end

    opts = opts or {}
    local color = opts.color or Theme.accent
    local entry = {color = color, opts = opts}

    local hl = Instance.new("Highlight")
    hl.Adornee = adornee
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = opts.fillTransparency or 0.7
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = ESPGui
    entry.highlight = hl

    if opts.showArrow then
        local arrow = Instance.new("ImageLabel")
        arrow.AnchorPoint = Vector2.new(0.5, 0.5)
        arrow.Size = opts.arrowSize or UDim2.fromOffset(30, 30)
        arrow.BackgroundTransparency = 1
        arrow.Image = "rbxassetid://97136202386756"
        arrow.ImageColor3 = color
        arrow.Parent = ESPGui
        entry.arrow = arrow

        if opts.showDistance then
            local distLabel = Instance.new("TextLabel", arrow)
            distLabel.AnchorPoint = Vector2.new(0.5, 0)
            distLabel.Position = UDim2.new(0.5, 0, 1, 4)
            distLabel.Size = UDim2.fromOffset(80, 16)
            distLabel.BackgroundTransparency = 1
            distLabel.Font = Theme.font
            distLabel.TextColor3 = color
            distLabel.TextSize = 13
            distLabel.Text = ""
            entry.distLabel = distLabel
        end
    end

    if opts.label then
        local bb = Instance.new("BillboardGui")
        bb.AlwaysOnTop = true
        bb.Size = UDim2.fromOffset(100, 30)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.Adornee = adornee
        bb.Parent = ESPGui

        local txt = Instance.new("TextLabel", bb)
        txt.Size = UDim2.new(1, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.Font = Enum.Font.GothamBold
        txt.Text = opts.label
        txt.TextColor3 = color
        txt.TextSize = 14
        txt.TextStrokeTransparency = 0.4
        entry.label = bb
    end

    self.entries[adornee] = entry
end

function ESP:Remove(adornee)
    local e = self.entries[adornee]
    if not e then return end
    if e.highlight then e.highlight:Destroy() end
    if e.arrow then e.arrow:Destroy() end
    if e.label then e.label:Destroy() end
    self.entries[adornee] = nil
end

function ESP:RemoveGroup(groupName)
    for adornee, e in pairs(self.entries) do
        if e.opts and e.opts.group == groupName then self:Remove(adornee) end
    end
end

RunService.RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local vp = camera.ViewportSize
    local hrp = safeGetHRP()

    for adornee, e in pairs(ESP.entries) do
        if not adornee or not adornee.Parent then
            ESP:Remove(adornee)
        else
            local pos
            if adornee:IsA("Model") then
                pos = adornee.PrimaryPart and adornee.PrimaryPart.Position or adornee:GetPivot().Position
            elseif adornee:IsA("BasePart") then
                pos = adornee.Position
            end

            if pos and e.arrow then
                local screenPos, onScreen = camera:WorldToViewportPoint(pos)
                local dist = hrp and (hrp.Position - pos).Magnitude or 0

                if onScreen and dist < 30 then
                    e.arrow.Visible = false
                else
                    e.arrow.Visible = true
                    local padding = 60
                    local cx, cy = vp.X/2, vp.Y/2
                    local dx, dy = screenPos.X - cx, screenPos.Y - cy
                    if not onScreen then dx, dy = -dx, -dy end
                    local angle = math.atan2(dy, dx)
                    local cosA, sinA = math.cos(angle), math.sin(angle)
                    if math.abs(cosA) < 0.0001 then cosA = 0.0001 end
                    if math.abs(sinA) < 0.0001 then sinA = 0.0001 end
                    local px = cx + cosA * math.min(math.abs((vp.X/2 - padding)/cosA), math.abs((vp.Y/2 - padding)/sinA))
                    local py = cy + sinA * math.min(math.abs((vp.X/2 - padding)/cosA), math.abs((vp.Y/2 - padding)/sinA))
                    e.arrow.Position = UDim2.fromOffset(px, py)
                    e.arrow.Rotation = math.deg(angle) + 90
                    if e.distLabel then
                        e.distLabel.Text = string.format("%dm", math.floor(dist))
                    end
                end
            end
        end
    end
end)

----------------------------------------------------------------
-- FOV CIRCLE INDICATOR (for murderer knife aim)
----------------------------------------------------------------
local FOVCircle = Instance.new("Frame", ESPGui)
FOVCircle.Name = "FOVCircle"
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVCircle.BackgroundTransparency = 1
FOVCircle.BorderSizePixel = 0
FOVCircle.Size = UDim2.fromOffset(200, 200)
FOVCircle.Visible = false
FOVCircle.ZIndex = 1

local fovStroke = Instance.new("UIStroke", FOVCircle)
fovStroke.Color = Theme.danger
fovStroke.Thickness = 1.2
fovStroke.Transparency = 0.3

local fovCorner = Instance.new("UICorner", FOVCircle)
fovCorner.CornerRadius = UDim.new(1, 0)

local function updateFOVCircle()
    if not State.knifeFOVEnabled then
        FOVCircle.Visible = false
        return
    end
    FOVCircle.Visible = true
    local size = State.knifeFOV * 2
    FOVCircle.Size = UDim2.fromOffset(size, size)
end

----------------------------------------------------------------
-- ROLE / PLAYER HELPERS
----------------------------------------------------------------
local function getMap()
    for _, o in ipairs(workspace:GetChildren()) do
        if o:FindFirstChild("CoinContainer") and o:FindFirstChild("Spawns") then
            return o
        end
    end
    return nil
end

local function findMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("Knife") then return p end
    end
    if LocalPlayer.Backpack:FindFirstChild("Knife") then return LocalPlayer end
    return nil
end

local function findSheriff()
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and p.Character:FindFirstChild("Gun") then return p end
    end
    if LocalPlayer.Backpack:FindFirstChild("Gun") then return LocalPlayer end
    return nil
end

local function findNearestPlayer()
    local hrp = safeGetHRP()
    if not hrp then return nil end
    local nearest, shortest = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local other = p.Character:FindFirstChild("HumanoidRootPart")
            if other then
                local d = (hrp.Position - other.Position).Magnitude
                if d < shortest then shortest = d nearest = p end
            end
        end
    end
    return nearest
end

-- Возвращает ближайшего игрока, чей HRP попадает в FOV-круг на экране.
-- Используется ТОЛЬКО для броска ножа убийцей.
local function getPlayerInKnifeFOV()
    local camera = workspace.CurrentCamera
    if not camera then return nil end
    local vp = camera.ViewportSize
    local screenCenter = Vector2.new(vp.X / 2, vp.Y / 2)
    local fov = State.knifeFOV

    local bestPlayer, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local screenPos, onScreen = camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local distFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if distFromCenter <= fov and distFromCenter < bestDist then
                        bestDist = distFromCenter
                        bestPlayer = p
                    end
                end
            end
        end
    end
    return bestPlayer
end

----------------------------------------------------------------
-- VELOCITY HISTORY (for Predict Lag)
----------------------------------------------------------------
local velocityHistory = {}
local lastPositions = {}
local HISTORY_SIZE = 8

RunService.Heartbeat:Connect(function()
    local now = tick()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local prev = lastPositions[p]
                if prev then
                    local dt = now - prev.t
                    if dt > 0 then
                        local v = (hrp.Position - prev.pos) / dt
                        local hist = velocityHistory[p] or {}
                        table.insert(hist, v)
                        if #hist > HISTORY_SIZE then
                            table.remove(hist, 1)
                        end
                        velocityHistory[p] = hist
                    end
                end
                lastPositions[p] = { pos = hrp.Position, t = now }
            end
        end
    end
end)

local function smoothedVelocity(player)
    local hist = velocityHistory[player]
    if not hist or #hist == 0 then
        local char = typeof(player) == "Instance" and player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        return hrp and hrp.AssemblyLinearVelocity or Vector3.zero
    end
    local sum = Vector3.zero
    for _, v in ipairs(hist) do sum = sum + v end
    return sum / #hist
end

local function getPing()
    local ok, ping = pcall(function()
        return LocalPlayer:GetNetworkPing() * 2
    end)
    return ok and ping or 0
end

----------------------------------------------------------------
-- PREDICTION (separate config blocks for sheriff/knife)
----------------------------------------------------------------
-- Универсальная функция предикта.
-- cfg — таблица с полями prioritizePing, predictJump, predictLag,
-- maxSim, interval, hMul, vMul, offsetX, offsetY, offsetZ.
local function computePredictedPos(player, offset, cfg)
    local char
    if typeof(player) == "Instance" and player:IsA("Player") then
        char = player.Character
    else
        char = player
    end
    if not char then return Vector3.zero end

    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return Vector3.zero end

    local playerObj = typeof(player) == "Instance" and player:IsA("Player") and player or nil

    -- Простая формула (быстрый путь) если все продвинутые предикты выключены
    if not cfg.prioritizePing and not cfg.predictJump and not cfg.predictLag then
        local vel = hrp.AssemblyLinearVelocity
        local move = hum.MoveDirection
        local predicted = hrp.Position
            + (vel * Vector3.new(0.75, 0.5, 0.75)) * (offset / 15)
            + move * offset
        local pingFactor = ((LocalPlayer:GetNetworkPing() * 1000) * ((State.offsetPingMult - 1) * 0.01)) + 1
        return predicted * pingFactor
    end

    -- Полный предикт
    local basePos = hrp.Position

    local horizonMs = 0
    if cfg.prioritizePing then
        horizonMs = getPing() * 1000
    end
    horizonMs = math.min(horizonMs, cfg.maxSim)
    local horizonSec = horizonMs / 1000

    local vel
    if cfg.predictLag and playerObj then
        vel = smoothedVelocity(playerObj)
    else
        vel = hrp.AssemblyLinearVelocity
    end

    local stepMs = math.max(1, cfg.interval)
    local stepSec = stepMs / 1000
    local steps = math.max(1, math.floor(horizonSec / stepSec))

    local hMul = cfg.hMul / 100
    local vMul = cfg.vMul / 100

    local velXZ = Vector3.new(vel.X, 0, vel.Z) * hMul
    local velY = vel.Y * vMul

    local inAir = hum.FloorMaterial == Enum.Material.Air
    local gravity = workspace.Gravity

    local pos = basePos
    if cfg.predictJump and inAir then
        for _ = 1, steps do
            pos = pos + velXZ * stepSec + Vector3.new(0, velY * stepSec, 0)
            velY = velY - gravity * stepSec
        end
    else
        local totalSec = stepSec * steps
        pos = basePos + Vector3.new(velXZ.X, velY, velXZ.Z) * totalSec
    end

    local sizeRef = 4
    local cf = hrp.CFrame
    pos = pos
        + cf.RightVector * ((cfg.offsetX / 100) * sizeRef)
        + cf.UpVector    * ((cfg.offsetY / 100) * sizeRef)
        + cf.LookVector  * ((cfg.offsetZ / 100) * sizeRef)

    return pos
end

local function getSheriffPredicted(target)
    return computePredictedPos(target, State.shootOffset, {
        prioritizePing = State.sheriffPrioritizePing,
        predictJump    = State.sheriffPredictJump,
        predictLag     = State.sheriffPredictLag,
        maxSim         = State.sheriffMaxSim,
        interval       = State.sheriffInterval,
        hMul           = State.sheriffHMul,
        vMul           = State.sheriffVMul,
        offsetX        = State.sheriffOffsetX,
        offsetY        = State.sheriffOffsetY,
        offsetZ        = State.sheriffOffsetZ,
    })
end

local function getKnifePredicted(target)
    return computePredictedPos(target, State.knifeOffset, {
        prioritizePing = State.knifePrioritizePing,
        predictJump    = State.knifePredictJump,
        predictLag     = State.knifePredictLag,
        maxSim         = State.knifeMaxSim,
        interval       = State.knifeInterval,
        hMul           = State.knifeHMul,
        vMul           = State.knifeVMul,
        offsetX        = State.knifeOffsetX,
        offsetY        = State.knifeOffsetY,
        offsetZ        = State.knifeOffsetZ,
    })
end

----------------------------------------------------------------
-- WALL CHECK (raycast)
----------------------------------------------------------------
-- Возвращает true если между мной и target есть прямая видимость.
-- false — если стена.
local function hasLineOfSight(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    local hrp = safeGetHRP()
    local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp or not targetHRP then return false end

    local rcParams = RaycastParams.new()
    rcParams.FilterType = Enum.RaycastFilterType.Exclude
    rcParams.FilterDescendantsInstances = {safeGetCharacter()}

    local origin = hrp.Position
    local direction = targetHRP.Position - origin
    local hit = workspace:Raycast(origin, direction, rcParams)

    if not hit then return true end
    if hit.Instance:IsDescendantOf(targetPlayer.Character) then return true end
    return false
end

----------------------------------------------------------------
-- ESP RELOAD
----------------------------------------------------------------
local function reloadPlayerESP()
    ESP:RemoveGroup("players")
    if not State.playerESP then return end

    local murd = findMurderer()
    local sher = findSheriff()

    for _, p in ipairs(Players:GetPlayers()) do
        if not p.Character then continue end
        if p == LocalPlayer and State.hideMeESP then continue end

        local opts = {group = "players"}
        if p == murd then
            opts.color = Color3.fromRGB(255, 60, 80)
            opts.showArrow = true
            opts.showDistance = true
            opts.arrowSize = UDim2.fromOffset(36, 36)
        elseif p == sher then
            opts.color = Color3.fromRGB(90, 180, 255)
        else
            opts.color = Color3.fromRGB(120, 255, 140)
        end
        ESP:Add(p.Character, opts)
    end
end

task.spawn(function()
    while task.wait(1) do
        if State.playerESP then reloadPlayerESP() end
    end
end)

local function hookPlayer(p)
    local function bind(char)
        if not char then return end
        char.ChildAdded:Connect(function(c)
            if State.playerESP and (c.Name == "Knife" or c.Name == "Gun") then
                reloadPlayerESP()
            end
        end)
        char.ChildRemoved:Connect(function(c)
            if State.playerESP and (c.Name == "Knife" or c.Name == "Gun") then
                reloadPlayerESP()
            end
        end)
    end
    bind(p.Character)
    p.CharacterAdded:Connect(bind)
end

for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
Players.PlayerAdded:Connect(hookPlayer)

workspace.ChildAdded:Connect(function(ch)
    if ch == getMap() and State.playerESP then
        task.wait(2)
        reloadPlayerESP()
    end
end)
workspace.ChildRemoved:Connect(function(ch)
    if ch == getMap() and State.playerESP then
        ESP:RemoveGroup("players")
    end
end)

workspace.DescendantAdded:Connect(function(ch)
    if State.trapESP and ch.Name == "Trap" and (ch.Parent:IsA("Folder") or ch.Parent:IsA("Model")) then
        if ch:IsA("BasePart") then ch.Transparency = 0 end
        ESP:Add(ch, {
            group = "trap",
            color = Color3.fromRGB(255, 60, 60),
            label = "Trap",
        })
        notify("Trap placed by the murderer.")
    end
    if State.gunDropESP and ch.Name == "GunDrop" then
        ESP:Add(ch, {
            group = "gun",
            color = Color3.fromRGB(255, 240, 80),
            showArrow = true,
            showDistance = true,
            label = "Dropped gun",
            arrowSize = UDim2.fromOffset(36, 36),
        })
        notify("Sheriff's gun has dropped.")
        if State.autoGetGun then
            task.wait(0.5)
            local map = getMap()
            local drop = map and map:FindFirstChild("GunDrop")
            local char = safeGetCharacter()
            if drop and char then
                local prev = char:GetPivot()
                char:PivotTo(drop:GetPivot())
                LocalPlayer.Backpack.ChildAdded:Wait()
                char:PivotTo(prev)
            end
        end
    end
end)
workspace.DescendantRemoving:Connect(function(ch)
    if State.gunDropESP and ch.Name == "GunDrop" then
        ESP:RemoveGroup("gun")
        task.wait(0.5)
        local s = findSheriff()
        if s then notify("New sheriff: "..s.DisplayName) end
        reloadPlayerESP()
    end
end)

----------------------------------------------------------------
-- SHERIFF SHOOT
----------------------------------------------------------------
local function shootMurderer(force)
    if findSheriff() ~= LocalPlayer and not force then
        notify("You're not sheriff.")
        return
    end

    local target = findMurderer() or (force and findNearestPlayer())
    if not target or not target.Character then notify("No target.") return end

    -- Wall check
    if State.sheriffWallCheck and not hasLineOfSight(target) then
        if not force then return end  -- молча пропускаем для auto-shoot
    end

    local char = safeGetCharacter()
    local hum = safeGetHumanoid()
    if not char or not hum then return end

    local wasInBackpack = false
    if not char:FindFirstChild("Gun") then
        local g = LocalPlayer.Backpack:FindFirstChild("Gun")
        if g then
            hum:EquipTool(g)
            wasInBackpack = true
        else
            notify("No gun.") return
        end
    end

    local targetHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end

    local predicted = getSheriffPredicted(target)

    local args
    if State.instakillShoot then
        args = {
            CFrame.new(targetHRP.Position + Vector3.new(0,1,0)),
            CFrame.new(targetHRP.Position),
        }
    else
        args = {
            CFrame.new(char.RightHand.Position),
            CFrame.new(predicted),
        }
    end

    local gun = char:WaitForChild("Gun", 1)
    if gun and gun:FindFirstChild("Shoot") then
        gun.Shoot:FireServer(unpack(args))

        if State.autoUnequipGun then
            task.delay(0.03, function()
                local h = safeGetHumanoid()
                if h then h:UnequipTools() end
            end)
        end
    end
end

----------------------------------------------------------------
-- MURDERER KNIFE THROW
----------------------------------------------------------------
-- silent=true: для auto-loop, не показывает уведомления
-- forceFOV=true: использует FOV-режим (только цели в круге)
local function knifeThrow(silent, forceFOV)
    if findMurderer() ~= LocalPlayer then
        if not silent then notify("You're not murderer.") end
        return
    end

    -- Выбор цели: либо ближайший в FOV, либо вообще ближайший
    local target
    if forceFOV or State.knifeFOVEnabled then
        target = getPlayerInKnifeFOV()
        if not target then
            -- Нет жертвы в круге — обычный бросок без коррекции (если не auto-loop)
            if silent then return end
            target = findNearestPlayer()
        end
    else
        target = findNearestPlayer()
    end

    if not target or not target.Character then return end

    -- Wall check
    if State.murdererWallCheck and not hasLineOfSight(target) then
        if not silent then notify("Wall between you and target.", Theme.danger, 2) end
        return
    end

    local char = safeGetCharacter()
    local hum = safeGetHumanoid()
    if not char or not hum then return end

    if not char:FindFirstChild("Knife") then
        local k = LocalPlayer.Backpack:FindFirstChild("Knife")
        if k then hum:EquipTool(k) else
            if not silent then notify("No knife.") end
            return
        end
    end

    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    if not tHRP then return end

    local from = CFrame.new(char.RightHand.Position)
    if State.spawnKnifeAtPlayer then
        from = CFrame.new(tHRP.Position + (tHRP.CFrame.LookVector * 5))
    end

    local predicted = getKnifePredicted(target)
    local to = CFrame.new(predicted)

    local knife = char:WaitForChild("Knife", 1)
    local events = knife and knife:FindFirstChild("Events")
    if events and events:FindFirstChild("KnifeThrown") then
        events.KnifeThrown:FireServer(from, to)
    end
end
----------------------------------------------------------------
-- VISUAL PAGE
----------------------------------------------------------------
addSection(VisualPage, "ESP")

addToggle(VisualPage, "Players (roles)", false, function(s)
    State.playerESP = s
    reloadPlayerESP()
end)

addToggle(VisualPage, "Dropped gun", false, function(s)
    State.gunDropESP = s
    if s then
        local map = getMap()
        local drop = map and map:FindFirstChild("GunDrop")
        if drop then
            ESP:Add(drop, {
                group = "gun",
                color = Color3.fromRGB(255, 240, 80),
                showArrow = true,
                showDistance = true,
                label = "Dropped gun",
                arrowSize = UDim2.fromOffset(36, 36),
            })
        end
    else
        ESP:RemoveGroup("gun")
    end
end)

addToggle(VisualPage, "Traps", false, function(s)
    State.trapESP = s
    if s then
        for _, v in ipairs(workspace:GetDescendants()) do
            if v.Name == "Trap" and (v.Parent:IsA("Folder") or v.Parent:IsA("Model")) then
                if v:IsA("BasePart") then v.Transparency = 0 end
                ESP:Add(v, {
                    group = "trap",
                    color = Color3.fromRGB(255, 60, 60),
                    label = "Trap",
                })
            end
        end
    else
        ESP:RemoveGroup("trap")
    end
end)

addToggle(VisualPage, "Hide my own ESP", false, function(s)
    State.hideMeESP = s
    reloadPlayerESP()
end)

addSection(VisualPage, "Round timer")

local timerLabel = nil
local timerTask = nil
local function secondsToMinutes(seconds)
    if not seconds or seconds == -1 then return "" end
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%dm %ds", m, s)
end

addToggle(VisualPage, "Show round timer", false, function(s)
    State.roundTimerOn = s
    if s then
        timerLabel = Instance.new("TextLabel", ScreenGui)
        timerLabel.BackgroundTransparency = 1
        timerLabel.TextColor3 = Theme.text
        timerLabel.AnchorPoint = Vector2.new(0.5, 0)
        timerLabel.Position = UDim2.new(0.5, 0, 0, 80)
        timerLabel.Size = UDim2.fromOffset(220, 28)
        timerLabel.Font = Enum.Font.GothamBold
        timerLabel.TextSize = 18
        timerLabel.TextStrokeTransparency = 0.6
        timerLabel.Text = ""
        timerTask = task.spawn(function()
            while State.roundTimerOn do
                local part = workspace:FindFirstChild("RoundTimerPart")
                if part then
                    local t = part:GetAttribute("Time")
                    timerLabel.Text = secondsToMinutes(t)
                else
                    timerLabel.Text = ""
                end
                task.wait(0.5)
            end
        end)
    else
        if timerLabel then timerLabel:Destroy() timerLabel = nil end
        if timerTask then task.cancel(timerTask) timerTask = nil end
    end
end)

addSection(VisualPage, "Info")

addButton(VisualPage, "Copy murderer username", function()
    local m = findMurderer()
    if not m then notify("No murderer.") return end
    if setclipboard then setclipboard(m.Name) end
    notify("Copied: "..m.Name)
end)

addButton(VisualPage, "Copy sheriff username", function()
    local s = findSheriff()
    if not s then notify("No sheriff.") return end
    if setclipboard then setclipboard(s.Name) end
    notify("Copied: "..s.Name)
end)

addButton(VisualPage, "Send roles to chat", function()
    local m = findMurderer()
    local s = findSheriff()
    local mn = m and m.Name or "-"
    local sn = s and s.Name or "-"
    local channels = TextChatSvc:WaitForChild("TextChannels"):GetChildren()
    for _, ch in ipairs(channels) do
        if ch.Name ~= "RBXSystem" then
            ch:SendAsync(string.format("Murderer: %s | Sheriff: %s | <<AXIOM>>", mn, sn))
        end
    end
end)

----------------------------------------------------------------
-- COMBAT PAGE (Sheriff блок сверху, Murderer блок снизу)
----------------------------------------------------------------
-- ===================== SHERIFF SECTION =====================
-- Серый заголовок "Sheriff" по центру
local sheriffHeader = Instance.new("TextLabel", CombatPage.page)
sheriffHeader.Size = UDim2.new(1, -10, 0, 22)
sheriffHeader.BackgroundTransparency = 1
sheriffHeader.Font = Enum.Font.GothamMedium
sheriffHeader.Text = "Sheriff"
sheriffHeader.TextColor3 = Color3.fromRGB(170, 170, 175)
sheriffHeader.TextSize = 13
sheriffHeader.TextXAlignment = Enum.TextXAlignment.Center
CombatPage.order = CombatPage.order + 1
sheriffHeader.LayoutOrder = CombatPage.order

-- Контейнер с рамкой для всех функций Шерифа
local sheriffBox = Instance.new("Frame", CombatPage.page)
sheriffBox.Size = UDim2.new(1, -10, 0, 0)
sheriffBox.AutomaticSize = Enum.AutomaticSize.Y
sheriffBox.BackgroundColor3 = Theme.secondary
sheriffBox.BackgroundTransparency = 0.4
sheriffBox.BorderSizePixel = 0
CombatPage.order = CombatPage.order + 1
sheriffBox.LayoutOrder = CombatPage.order
Instance.new("UICorner", sheriffBox).CornerRadius = UDim.new(0, 10)

local sheriffBoxStroke = Instance.new("UIStroke", sheriffBox)
sheriffBoxStroke.Color = Color3.fromRGB(90, 180, 255)
sheriffBoxStroke.Thickness = 1.2
sheriffBoxStroke.Transparency = 0.4

local sheriffBoxPad = Instance.new("UIPadding", sheriffBox)
sheriffBoxPad.PaddingTop = UDim.new(0, 8)
sheriffBoxPad.PaddingBottom = UDim.new(0, 8)
sheriffBoxPad.PaddingLeft = UDim.new(0, 6)
sheriffBoxPad.PaddingRight = UDim.new(0, 6)

local sheriffBoxLayout = Instance.new("UIListLayout", sheriffBox)
sheriffBoxLayout.Padding = UDim.new(0, 6)
sheriffBoxLayout.SortOrder = Enum.SortOrder.LayoutOrder
sheriffBoxLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- SheriffPage теперь указывает на sheriffBox (а не на CombatPage)
local SheriffPage = {page = sheriffBox, order = 0, button = CombatPage.button}

addSection(SheriffPage, "Combat")

addButton(SheriffPage, "Shoot murderer", function() shootMurderer(false) end)
addToggle(SheriffPage, "Auto-shoot murderer", false, function(s) State.autoShoot = s end)
addToggle(SheriffPage, "Instakill shoot", false, function(s) State.instakillShoot = s end)
addToggle(SheriffPage, "Wall check (Sheriff)", true, function(s) State.sheriffWallCheck = s end)
addToggle(SheriffPage, "Auto-unequip after shot", true, function(s) State.autoUnequipGun = s end)

-- Auto-shoot loop
task.spawn(function()
    while task.wait(0.5) do
        if not State.autoShoot then continue end
        if findSheriff() ~= LocalPlayer then continue end
        local murd = findMurderer()
        if not murd or not murd.Character then continue end
        local hrp = safeGetHRP()
        local targetHRP = murd.Character:FindFirstChild("HumanoidRootPart")
        if not hrp or not targetHRP then continue end

        -- Wall check встроен в shootMurderer, но дополнительно отрезаем здесь
        -- чтобы не тратить ресурсы на equip-цикл когда видимости нет
        if State.sheriffWallCheck and not hasLineOfSight(murd) then continue end

        shootMurderer(false)
        task.wait(0.2)
    end
end)

addSection(SheriffPage, "Tuning")
addSlider(SheriffPage, "Shoot offset", -2, 8, State.shootOffset, 0.1, function(v) State.shootOffset = v end)
addSlider(SheriffPage, "Offset×Ping mult", 0, 5, State.offsetPingMult, 0.1, function(v) State.offsetPingMult = v end)

addSection(SheriffPage, "Advanced prediction")
addText(SheriffPage, "Turn ON for predictive aim instead of simple offset.")

addToggle(SheriffPage, "Prioritize Your Ping", false, function(s) State.sheriffPrioritizePing = s end)
addToggle(SheriffPage, "Predict Jump", false, function(s) State.sheriffPredictJump = s end)
addToggle(SheriffPage, "Predict Lag", false, function(s) State.sheriffPredictLag = s end)

addSlider(SheriffPage, "Max Sim Time (ms)", 30, 90, State.sheriffMaxSim, 1, function(v) State.sheriffMaxSim = v end)
addSlider(SheriffPage, "Prediction Interval (ms)", 1, 800, State.sheriffInterval, 1, function(v) State.sheriffInterval = v end)
addSlider(SheriffPage, "Horizontal Mult (%)", 90, 350, State.sheriffHMul, 1, function(v) State.sheriffHMul = v end)
addSlider(SheriffPage, "Vertical Mult (%)", 90, 350, State.sheriffVMul, 1, function(v) State.sheriffVMul = v end)

addSection(SheriffPage, "Position offsets (advanced)")
addSlider(SheriffPage, "X Offset (%)", -350, 350, State.sheriffOffsetX, 1, function(v) State.sheriffOffsetX = v end)
addSlider(SheriffPage, "Y Offset (%)", -350, 350, State.sheriffOffsetY, 1, function(v) State.sheriffOffsetY = v end)
addSlider(SheriffPage, "Z Offset (%)", -350, 350, State.sheriffOffsetZ, 1, function(v) State.sheriffOffsetZ = v end)

addSection(SheriffPage, "Gun drop")
addButton(SheriffPage, "Teleport to dropped gun", function()
    local map = getMap()
    local drop = map and map:FindFirstChild("GunDrop")
    if not drop then notify("No gun on the ground.") return end
    local char = safeGetCharacter()
    if not char then return end
    local prev = char:GetPivot()
    char:PivotTo(drop:GetPivot())
    LocalPlayer.Backpack.ChildAdded:Wait()
    char:PivotTo(prev)
end)
addToggle(SheriffPage, "Auto-grab dropped gun", false, function(s) State.autoGetGun = s end)

----------------------------------------------------------------
-- MURDERER SECTION (внутри Combat tab, ниже Sheriff)
----------------------------------------------------------------
-- Разделитель + заголовок Убийцы
-- Пустой промежуток между Шерифом и Убийцей
local murdererSpacer = Instance.new("Frame", CombatPage.page)
murdererSpacer.Size = UDim2.new(1, -10, 0, 10)
murdererSpacer.BackgroundTransparency = 1
CombatPage.order = CombatPage.order + 1
murdererSpacer.LayoutOrder = CombatPage.order

-- Серый заголовок "Murderer" по центру
local murdererHeader = Instance.new("TextLabel", CombatPage.page)
murdererHeader.Size = UDim2.new(1, -10, 0, 22)
murdererHeader.BackgroundTransparency = 1
murdererHeader.Font = Enum.Font.GothamMedium
murdererHeader.Text = "Murderer"
murdererHeader.TextColor3 = Color3.fromRGB(170, 170, 175)
murdererHeader.TextSize = 13
murdererHeader.TextXAlignment = Enum.TextXAlignment.Center
CombatPage.order = CombatPage.order + 1
murdererHeader.LayoutOrder = CombatPage.order

-- Контейнер с рамкой для всех функций Убийцы
local murdererBox = Instance.new("Frame", CombatPage.page)
murdererBox.Size = UDim2.new(1, -10, 0, 0)
murdererBox.AutomaticSize = Enum.AutomaticSize.Y
murdererBox.BackgroundColor3 = Theme.secondary
murdererBox.BackgroundTransparency = 0.4
murdererBox.BorderSizePixel = 0
CombatPage.order = CombatPage.order + 1
murdererBox.LayoutOrder = CombatPage.order
Instance.new("UICorner", murdererBox).CornerRadius = UDim.new(0, 10)

local murdererBoxStroke = Instance.new("UIStroke", murdererBox)
murdererBoxStroke.Color = Color3.fromRGB(255, 80, 100)
murdererBoxStroke.Thickness = 1.2
murdererBoxStroke.Transparency = 0.4

local murdererBoxPad = Instance.new("UIPadding", murdererBox)
murdererBoxPad.PaddingTop = UDim.new(0, 8)
murdererBoxPad.PaddingBottom = UDim.new(0, 8)
murdererBoxPad.PaddingLeft = UDim.new(0, 6)
murdererBoxPad.PaddingRight = UDim.new(0, 6)

local murdererBoxLayout = Instance.new("UIListLayout", murdererBox)
murdererBoxLayout.Padding = UDim.new(0, 6)
murdererBoxLayout.SortOrder = Enum.SortOrder.LayoutOrder
murdererBoxLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- MurdererPage теперь указывает на murdererBox
local MurdererPage = {page = murdererBox, order = 0, button = CombatPage.button}

addSection(MurdererPage, "Knife throw")

addButton(MurdererPage, "Throw knife at nearest", function() knifeThrow(false, false) end)
addToggle(MurdererPage, "Auto knife throw", false, function(s) State.loopKnifeThrow = s end)
addToggle(MurdererPage, "Spawn knife near victim", false, function(s) State.spawnKnifeAtPlayer = s end)
addToggle(MurdererPage, "Wall check (Murderer)", true, function(s) State.murdererWallCheck = s end)

-- Auto knife throw loop
task.spawn(function()
    while task.wait(1.5) do
        if State.loopKnifeThrow then knifeThrow(true, false) end
    end
end)

addSection(MurdererPage, "FOV aim assist")
addText(MurdererPage, "When enabled, a red circle appears on screen. If a player enters the circle, the next thrown knife auto-corrects to hit them.")

addToggle(MurdererPage, "Enable FOV indicator", false, function(s)
    State.knifeFOVEnabled = s
    updateFOVCircle()
end)

addSlider(MurdererPage, "FOV radius (px)", 50, 600, State.knifeFOV, 5, function(v)
    State.knifeFOV = v
    updateFOVCircle()
end)

addButton(MurdererPage, "Throw with FOV aim", function() knifeThrow(false, true) end)

addSection(MurdererPage, "Tuning (knife)")
addSlider(MurdererPage, "Knife throw offset", -2, 10, State.knifeOffset, 0.1, function(v) State.knifeOffset = v end)

addSection(MurdererPage, "Advanced prediction (knife)")
addText(MurdererPage, "Predictive aim for thrown knife. Independent from Sheriff settings.")

addToggle(MurdererPage, "Prioritize Your Ping", false, function(s) State.knifePrioritizePing = s end)
addToggle(MurdererPage, "Predict Jump", false, function(s) State.knifePredictJump = s end)
addToggle(MurdererPage, "Predict Lag", false, function(s) State.knifePredictLag = s end)

addSlider(MurdererPage, "Max Sim Time (ms)", 30, 120, State.knifeMaxSim, 1, function(v) State.knifeMaxSim = v end)
addSlider(MurdererPage, "Prediction Interval (ms)", 1, 800, State.knifeInterval, 1, function(v) State.knifeInterval = v end)
addSlider(MurdererPage, "Horizontal Mult (%)", 90, 350, State.knifeHMul, 1, function(v) State.knifeHMul = v end)
addSlider(MurdererPage, "Vertical Mult (%)", 90, 350, State.knifeVMul, 1, function(v) State.knifeVMul = v end)

addSection(MurdererPage, "Position offsets (knife)")
addSlider(MurdererPage, "X Offset (%)", -350, 350, State.knifeOffsetX, 1, function(v) State.knifeOffsetX = v end)
addSlider(MurdererPage, "Y Offset (%)", -350, 350, State.knifeOffsetY, 1, function(v) State.knifeOffsetY = v end)
addSlider(MurdererPage, "Z Offset (%)", -350, 350, State.knifeOffsetZ, 1, function(v) State.knifeOffsetZ = v end)

addSection(MurdererPage, "Melee")

addButton(MurdererPage, "Kill nearest", function()
    if findMurderer() ~= LocalPlayer then notify("Not murderer.") return end
    local char = safeGetCharacter()
    local hum = safeGetHumanoid()
    if not char or not hum then return end
    if not char:FindFirstChild("Knife") then
        local k = LocalPlayer.Backpack:FindFirstChild("Knife")
        if k then hum:EquipTool(k) else notify("No knife.") return end
    end
    local victim = findNearestPlayer()
    if not victim or not victim.Character then notify("No victim.") return end

    if State.murdererWallCheck and not hasLineOfSight(victim) then
        notify("Wall between you and target.", Theme.danger, 2)
        return
    end

    local vHRP = victim.Character:FindFirstChild("HumanoidRootPart")
    local mHRP = safeGetHRP()
    if not vHRP or not mHRP then return end
    vHRP.Anchored = true
    vHRP.CFrame = mHRP.CFrame + mHRP.CFrame.LookVector * 2
    task.wait(0.1)
    char.Knife.Stab:FireServer("Slash")
    task.wait(0.5)
    if vHRP and vHRP.Parent then vHRP.Anchored = false end
end)

addToggle(MurdererPage, "Kill aura", false, function(s) State.killAuraOn = s end)

task.spawn(function()
    while task.wait(0.1) do
        if not State.killAuraOn then continue end
        if findMurderer() ~= LocalPlayer then continue end
        local char = safeGetCharacter()
        if not char or not char:FindFirstChild("Knife") then continue end
        local mHRP = safeGetHRP()
        if not mHRP then continue end
        for _, p in ipairs(Players:GetPlayers()) do
            if p == LocalPlayer then continue end
            if not p.Character then continue end
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            local d = (hrp.Position - mHRP.Position).Magnitude
            if d < 7 then
                hrp.Anchored = true
                hrp.CFrame = mHRP.CFrame + mHRP.CFrame.LookVector * 2
                task.wait(0.1)
                pcall(function() char.Knife.Stab:FireServer("Slash") end)
                task.wait(0.3)
                if hrp and hrp.Parent then hrp.Anchored = false end
            end
        end
    end
end)

addButton(MurdererPage, "Kill EVERYONE", function()
    if findMurderer() ~= LocalPlayer then notify("Not murderer.") return end
    local char = safeGetCharacter()
    local hum = safeGetHumanoid()
    if not char or not hum then return end
    if not char:FindFirstChild("Knife") then
        local k = LocalPlayer.Backpack:FindFirstChild("Knife")
        if k then hum:EquipTool(k) else notify("No knife.") return end
    end
    local mHRP = safeGetHRP()
    if not mHRP then return end
    local anchored = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Anchored = true
                hrp.CFrame = mHRP.CFrame + mHRP.CFrame.LookVector * 1
                table.insert(anchored, hrp)
            end
        end
    end
    char.Knife.Stab:FireServer("Slash")
    task.wait(0.5)
    for _, hrp in ipairs(anchored) do
        if hrp.Parent then hrp.Anchored = false end
    end
end)

addButton(MurdererPage, "Hold everyone hostage", function()
    if findMurderer() ~= LocalPlayer then notify("Not murderer.") return end
    local mHRP = safeGetHRP()
    if not mHRP then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Anchored = true
                hrp.CFrame = mHRP.CFrame + mHRP.CFrame.LookVector * 5
            end
        end
    end
    notify("All players gathered.")
end)

addSection(MurdererPage, "Fling")

local function microFling(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then notify("No target.") return end
    local char = safeGetCharacter()
    local hum = safeGetHumanoid()
    local hrp = safeGetHRP()
    if not char or not hum or not hrp then return end
    local tHum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
    local tHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not tHum or not tHRP then return end
    local oldPos = hrp.CFrame
    workspace.FallenPartsDestroyHeight = 0/0
    local bv = Instance.new("BodyVelocity", hrp)
    bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.new(9e8, 9e8, 9e8)
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    local start = tick()
    repeat
        for i = 1, 8 do
            hrp.CFrame = tHRP.CFrame + Vector3.new(0, (i%2==0) and 1.5 or -1.5, 0)
            hrp.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
            hrp.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
            task.wait()
        end
    until tHRP.Velocity.Magnitude > 500 or tick() - start > 2 or not targetPlayer.Character
    bv:Destroy()
    hum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    repeat
        hrp.CFrame = oldPos * CFrame.new(0, 0.5, 0)
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        for _, p in ipairs(char:GetChildren()) do
            if p:IsA("BasePart") then p.Velocity = Vector3.zero p.RotVelocity = Vector3.zero end
        end
        task.wait()
    until (hrp.Position - oldPos.Position).Magnitude < 25
end

addButton(MurdererPage, "Fling sheriff", function()
    local s = findSheriff()
    if not s then notify("No sheriff.") return end
    microFling(s)
end)
addButton(MurdererPage, "Fling murderer", function()
    local m = findMurderer()
    if not m then notify("No murderer.") return end
    microFling(m)
end)

----------------------------------------------------------------
-- WORLD PAGE
----------------------------------------------------------------
addSection(WorldPage, "Movement")

local flyState = {bv = nil, bg = nil, conn = nil, accel = 0}

local function startFly()
    local char = safeGetCharacter()
    local hum = safeGetHumanoid()
    local hrp = safeGetHRP()
    if not char or not hum or not hrp then return end
    flyState.bg = Instance.new("BodyGyro", hrp)
    flyState.bg.P = 1e5
    flyState.bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    flyState.bg.CFrame = hrp.CFrame
    flyState.bv = Instance.new("BodyVelocity", hrp)
    flyState.bv.P = 1e4
    flyState.bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    flyState.bv.Velocity = Vector3.zero
    hum.PlatformStand = true
    flyState.conn = RunService.Heartbeat:Connect(function()
        if not State.fly then return end
        local h = safeGetHumanoid()
        local r = safeGetHRP()
        local cam = workspace.CurrentCamera
        if not h or not r or not cam then return end
        local move = h.MoveDirection
        if move.Magnitude > 0.01 then
            flyState.accel = math.min(State.flySpeed, flyState.accel + 2)
        else
            flyState.accel = math.max(0, flyState.accel - 2)
        end
        local look = cam.CFrame.LookVector
        local horizontal = Vector3.new(move.X, 0, move.Z)
        if horizontal.Magnitude > 0 then horizontal = horizontal.Unit * flyState.accel end
        local vertical = look.Y * move:Dot(Vector3.new(look.X, 0, look.Z).Unit + Vector3.new(0,0,0.001)) * flyState.accel
        flyState.bv.Velocity = Vector3.new(horizontal.X, vertical, horizontal.Z)
        flyState.bg.CFrame = CFrame.new(r.Position, r.Position + look)
    end)
end

local function stopFly()
    if flyState.conn then flyState.conn:Disconnect() flyState.conn = nil end
    if flyState.bv then flyState.bv:Destroy() flyState.bv = nil end
    if flyState.bg then flyState.bg:Destroy() flyState.bg = nil end
    local hum = safeGetHumanoid()
    if hum then hum.PlatformStand = false end
    flyState.accel = 0
end

addToggle(WorldPage, "Fly", false, function(s)
    State.fly = s
    if s then startFly() else stopFly() end
end)
addSlider(WorldPage, "Fly speed", 20, 350, State.flySpeed, 5, function(v) State.flySpeed = v end)

local infJumpConn, landedConn
local infJumpDeb, jumpCount, landed = false, 0, true

local function setupJumpListener(hum)
    if landedConn then landedConn:Disconnect() end
    landedConn = hum.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
            landed = true jumpCount = 0
        end
    end)
end

addToggle(WorldPage, "Infinite jump", false, function(s)
    State.infJump = s
    if s then
        local char = safeGetCharacter()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then setupJumpListener(hum) end
        infJumpConn = UIS.JumpRequest:Connect(function()
            local h = safeGetHumanoid()
            if not h then return end
            if State.infJumpLimit2 and jumpCount >= 2 and not landed then return end
            if not infJumpDeb then
                infJumpDeb = true
                h:ChangeState(Enum.HumanoidStateType.Jumping)
                jumpCount = jumpCount + 1
                landed = false
                task.wait(0.1)
                infJumpDeb = false
            end
        end)
    else
        if infJumpConn then infJumpConn:Disconnect() infJumpConn = nil end
        if landedConn then landedConn:Disconnect() landedConn = nil end
        jumpCount = 0 landed = true
    end
end)
addToggle(WorldPage, "Limit inf-jump to 2", false, function(s)
    State.infJumpLimit2 = s
    jumpCount = 0
end)

addSection(WorldPage, "Speed / FOV")
addInput(WorldPage, "Walkspeed", "Set", function(text)
    local n = tonumber(text)
    if not n then notify("Not a number.") return end
    State.ws = n
    local h = safeGetHumanoid()
    if h then h.WalkSpeed = n end
end)
addInput(WorldPage, "FOV", "Set", function(text)
    local n = tonumber(text)
    if not n then notify("Not a number.") return end
    State.fov = n
    TweenService:Create(workspace.CurrentCamera, TweenInfo.new(0.5), {FieldOfView = n}):Play()
end)
addToggle(WorldPage, "Loop walkspeed & FOV", false, function(s) State.loopWSFOV = s end)

RunService.RenderStepped:Connect(function()
    if State.loopWSFOV then
        workspace.CurrentCamera.FieldOfView = State.fov
        local h = safeGetHumanoid()
        if h then h.WalkSpeed = State.ws end
    end
end)

addSection(WorldPage, "Hitbox / Noclip")
addInput(WorldPage, "Hitbox size (cube)", "Expand", function(text)
    local n = tonumber(text) or 1
    State.hitboxExpand = n
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer or not p.Character then continue end
        if State.aggressiveHitbox then
            for _, part in ipairs(p.Character:GetChildren()) do
                if part:IsA("BasePart") then
                    if n == 1 then part.Size = Vector3.new(2,1,1) else part.Size = Vector3.new(n,n,n) end
                    part.Transparency = 0.2
                end
            end
        else
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            if r then
                if n == 1 then r.Size = Vector3.new(2,1,1) else r.Size = Vector3.new(n,n,n) end
                r.Transparency = 0.2
                r.CanCollide = false
            end
        end
    end
    notify("Hitboxes expanded.")
end)
addToggle(WorldPage, "Aggressive hitbox (all parts)", false, function(s) State.aggressiveHitbox = s end)

local hitboxLoopConn
addToggle(WorldPage, "Loop hitbox expansion", false, function(s)
    State.loopHitbox = s
    if s then
        hitboxLoopConn = RunService.Heartbeat:Connect(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p == LocalPlayer or not p.Character then continue end
                local r = p.Character:FindFirstChild("HumanoidRootPart")
                if r then
                    local n = State.hitboxExpand
                    if n == 1 then r.Size = Vector3.new(2,1,1) else r.Size = Vector3.new(n,n,n) end
                    r.Transparency = 0.2
                    r.CanCollide = false
                end
            end
        end)
    else
        if hitboxLoopConn then hitboxLoopConn:Disconnect() hitboxLoopConn = nil end
    end
end)

local noclipConn
addToggle(WorldPage, "Noclip", false, function(s)
    State.noclip = s
    if s then
        noclipConn = RunService.Stepped:Connect(function()
            local char = safeGetCharacter()
            if not char then return end
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end)
    else
        if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    end
end)

addSection(WorldPage, "Teleport")

addButton(WorldPage, "Teleport to lobby", function()
    local lobby = workspace:FindFirstChild("Lobby")
    if lobby and lobby:FindFirstChild("Spawns") then
        local sp = lobby.Spawns:FindFirstChildWhichIsA("SpawnLocation")
        if sp then safeGetCharacter():MoveTo(sp.Position) end
    end
end)
addButton(WorldPage, "Teleport to map", function()
    local map = getMap()
    local spawns = map and map:FindFirstChild("Spawns")
    if not spawns then notify("No map.") return end
    local kids = spawns:GetChildren()
    if #kids == 0 then return end
    safeGetCharacter():MoveTo(kids[math.random(1, #kids)].Position)
end)

addInput(WorldPage, "Goto player", "Go", function(text)
    if not text or text == "" then return end
    local target
    local lname = string.lower(text)
    for _, p in ipairs(Players:GetPlayers()) do
        if string.sub(string.lower(p.Name), 1, #lname) == lname
        or string.sub(string.lower(p.DisplayName), 1, #lname) == lname then
            target = p break
        end
    end
    if not target or not target.Character then notify("Not found.") return end
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    local mHRP = safeGetHRP()
    if tHRP and mHRP then
        mHRP.CFrame = CFrame.new(tHRP.Position + Vector3.new(0, 5, 0))
    end
end)
addToggle(WorldPage, "CTRL+Click teleport", false, function(s) State.ctrlClickTP = s end)

UIS.InputBegan:Connect(function(inp, proc)
    if proc then return end
    if State.ctrlClickTP
       and UIS:IsKeyDown(Enum.KeyCode.LeftControl)
       and inp.UserInputType == Enum.UserInputType.MouseButton1 then
        local mouse = LocalPlayer:GetMouse()
        if mouse.Hit then
            local mHRP = safeGetHRP()
            if mHRP then mHRP.CFrame = CFrame.new(mouse.Hit.Position) end
        end
    end
end)

local spectateTask = nil
addButton(WorldPage, "Spectate cycle", function()
    if spectateTask then
        workspace.CurrentCamera.CameraSubject = safeGetHumanoid()
        task.cancel(spectateTask)
        spectateTask = nil
        notify("Spectator off.")
        return
    end
    local list = Players:GetPlayers()
    local idx = 1
    spectateTask = task.spawn(function()
        while true do
            local p = list[idx]
            if p and p.Character and p.Character:FindFirstChildOfClass("Humanoid") then
                workspace.CurrentCamera.CameraSubject = p.Character:FindFirstChildOfClass("Humanoid")
                notify("Spectating: "..p.DisplayName, Theme.accentAlt, 2)
            end
            task.wait(3)
            idx = idx + 1
            if idx > #list then idx = 1 end
            list = Players:GetPlayers()
        end
    end)
end)

addSection(WorldPage, "Defense")

local antiFlingConn, antiFlingMeConn
local antiFlingLastPos = Vector3.zero
local detectedFlingers = {}

addToggle(WorldPage, "Anti-fling", false, function(s)
    State.antiFling = s
    if s then
        antiFlingConn = RunService.Heartbeat:Connect(function()
            for _, p in ipairs(Players:GetPlayers()) do
                if p == LocalPlayer or not p.Character then continue end
                local pp = p.Character.PrimaryPart
                if not pp then continue end
                if pp.AssemblyAngularVelocity.Magnitude > 50
                or pp.AssemblyLinearVelocity.Magnitude > 100 then
                    if not detectedFlingers[p.Name] then
                        detectedFlingers[p.Name] = true
                        notify("Flinger: "..p.Name, Theme.danger)
                    end
                    for _, part in ipairs(p.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                            part.AssemblyAngularVelocity = Vector3.zero
                            part.AssemblyLinearVelocity = Vector3.zero
                            part.CustomPhysicalProperties = PhysicalProperties.new(0,0,0)
                        end
                    end
                end
            end
        end)
        antiFlingMeConn = RunService.Heartbeat:Connect(function()
            local char = safeGetCharacter()
            local pp = char and char.PrimaryPart
            if not pp then return end
            if pp.AssemblyLinearVelocity.Magnitude > 250
            or pp.AssemblyAngularVelocity.Magnitude > 250 then
                notify("Neutralizing fling.", Theme.danger, 2)
                pp.AssemblyLinearVelocity = Vector3.zero
                pp.AssemblyAngularVelocity = Vector3.zero
                if antiFlingLastPos ~= Vector3.zero then
                    pp.CFrame = CFrame.new(antiFlingLastPos)
                end
            else
                antiFlingLastPos = pp.Position
            end
        end)
    else
        if antiFlingConn then antiFlingConn:Disconnect() antiFlingConn = nil end
        if antiFlingMeConn then antiFlingMeConn:Disconnect() antiFlingMeConn = nil end
        detectedFlingers = {}
    end
end)

addToggle(WorldPage, "Anti-AFK", false, function(s)
    State.antiAFK = s
    if s then
        if getconnections then
            for _, c in ipairs(getconnections(LocalPlayer.Idled)) do
                if c.Disable then c:Disable() elseif c.Disconnect then c:Disconnect() end
            end
        end
        LocalPlayer.Idled:Connect(function()
            if not State.antiAFK then return end
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
        notify("Anti-AFK active.")
    end
end)

addSection(WorldPage, "Performance")
addButton(WorldPage, "FPS boost", function()
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if terrain then
        terrain.WaterWaveSize = 0 terrain.WaterWaveSpeed = 0
        terrain.WaterReflectance = 0 terrain.WaterTransparency = 0
    end
    game.Lighting.GlobalShadows = false
    game.Lighting.FogEnd = 9e9
    pcall(function() settings().Rendering.QualityLevel = 1 end)
    for _, v in pairs(game:GetDescendants()) do
        if v:IsA("BasePart") then v.Material = Enum.Material.Plastic v.Reflectance = 0
        elseif v:IsA("Decal") then v.Transparency = 1
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then v.Lifetime = NumberRange.new(0)
        elseif v:IsA("Explosion") then v.BlastPressure = 1 v.BlastRadius = 1
        end
    end
    for _, v in pairs(game.Lighting:GetDescendants()) do
        if v:IsA("PostEffect") then v.Enabled = false end
    end
    notify("FPS boost applied.")
end)
addButton(WorldPage, "Ping", function()
    notify(string.format("%d ms", LocalPlayer:GetNetworkPing() * 1000))
end)
addButton(WorldPage, "Dev console", function()
    game.StarterGui:SetCore("DevConsoleVisible", true)
end)

addButton(WorldPage, "God mode (unstable)", function()
    local cam = workspace.CurrentCamera
    local pos, char = cam.CFrame, safeGetCharacter()
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local newHum = hum:Clone()
    newHum.Parent, LocalPlayer.Character = char, nil
    newHum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    newHum:SetStateEnabled(Enum.HumanoidStateType.Running, false)
    newHum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    newHum.BreakJointsOnDeath = true
    hum:Destroy()
    LocalPlayer.Character, cam.CameraSubject = char, newHum
    task.wait()
    cam.CFrame = pos
    local s_ = char:FindFirstChild("Animate")
    if s_ then s_.Disabled = true task.wait() s_.Disabled = false end
    newHum.Health = newHum.MaxHealth
end)

----------------------------------------------------------------
-- OPEN/CLOSE LOGIC
----------------------------------------------------------------
-- OpenPlate теперь может быть в любой позиции (мы его двигаем).
-- Меню всё ещё открывается из центра-сверху, но плита остаётся там, где её бросили.
local function openMenu()
    State.hubOpen = true
    Menu.Visible = true
    Menu.Position = UDim2.new(0.5, 0, -0.6, 0)
    menuScale.Scale = 0.7
    TweenService:Create(Menu, TweenInfo.new(1.0, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0.08, 0)
    }):Play()
    TweenService:Create(menuScale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Scale = 1
    }):Play()
    TweenService:Create(Diamond, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Rotation = 225
    }):Play()
end

local function closeMenu()
    State.hubOpen = false
    local exit = TweenService:Create(Menu, TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, 0, -0.6, 0)
    })
    TweenService:Create(menuScale, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Scale = 0.7
    }):Play()
    TweenService:Create(Diamond, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Rotation = 45
    }):Play()
    exit:Play()
    exit.Completed:Connect(function()
        Menu.Visible = false
    end)
end

-- Polling click events from OpenPlate (set up в part 1)
RunService.Heartbeat:Connect(function()
    if AXIOM.__platePoll and AXIOM.__platePoll() then
        TweenService:Create(plateScale, TweenInfo.new(0.1), {Scale = 0.9}):Play()
        task.delay(0.1, function()
            TweenService:Create(plateScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        end)
        if State.hubOpen then closeMenu() else openMenu() end
    end
end)

UIS.InputBegan:Connect(function(inp, proc)
    if proc then return end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl)
       and UIS:IsKeyDown(Enum.KeyCode.LeftAlt)
       and inp.KeyCode == Enum.KeyCode.Y then
        if State.hubOpen then closeMenu() else openMenu() end
    end
end)

----------------------------------------------------------------
-- INIT
----------------------------------------------------------------
Pages.Visual.button.BackgroundColor3 = Theme.accentDeep
Pages.Visual.page.Visible = true
currentPage = "Visual"

openMenu()

task.wait(0.5)
notify("AXIOM 2.0 loaded · MM2", Theme.accent, 4)
