-- ══════════════════════════════════════════
--  AR Aimbot v4 | Kalman + Remote Finder + Camera Return
--  Full Mobile Optimized | Horizontal Compact UI
-- ══════════════════════════════════════════

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local VirtualUser      = game:GetService("VirtualUser")
local GuiService       = game:GetService("GuiService")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer
local Mouse            = LocalPlayer:GetMouse()

local drawingOK = typeof(Drawing) ~= "nil"
local function safeGui()
    if gethui then return gethui() end
    local ok, res = pcall(function() return game:GetService("CoreGui") end)
    return ok and res or LocalPlayer.PlayerGui
end

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ══════════════════════════════════════════
--  CONFIG
-- ══════════════════════════════════════════
local Cfg = {
    Enabled       = true,
    FOV           = 180,
    Smoothness    = 0.20,
    Prediction    = 0.10,
    AimPart       = "Head",
    TeamCheck     = false,
    WallCheck     = true,
    FOVCircle     = true,
    FOVColor      = Color3.fromRGB(220, 55, 55),
    AutoFire      = false,
    ManualFire    = false,
    FireRate      = 0.12,
    AimMode       = "nearest",
    TargetNick    = "",
    BotKW         = {"Bot","NPC","Dummy","Enemy","Zombie","Bandit","Guard","Monster","Alien"},
    -- Kalman
    KalmanEnabled = true,
    KalmanProcessNoise  = 1.0,
    KalmanMeasureNoise  = 4.0,
    -- Camera Return
    CamReturnEnabled  = false,
    CamReturnKey      = Enum.KeyCode.E,
    CamReturnSpeed    = 0.8,
    CamReturnRemote   = true,
    -- Mobile
    JumpAimActive = false,
}

-- ══════════════════════════════════════════
--  KALMAN FILTER (3D Constant Velocity)
-- ══════════════════════════════════════════
local AR_Kalman = {}
AR_Kalman.__index = AR_Kalman

local function makeAxis()
    return { x = 0, v = 0, p = 1000, pv = 1000 }
end

function AR_Kalman.new(config)
    local cfg = config or {}
    return setmetatable({
        axes = { x = makeAxis(), y = makeAxis(), z = makeAxis() },
        q = cfg.processNoise or 1.0,
        r = cfg.measurementNoise or 4.0,
        lastTime = 0,
        initialized = false,
    }, AR_Kalman)
end

local function updateAxis(axis, measurement, dt, q, r)
    local xPred = axis.x + axis.v * dt
    local pPred = axis.p + axis.pv * dt + q
    local pvPred = axis.pv + q
    local innovation = measurement - xPred
    local s = pPred + r
    local k = pPred / s
    local kv = pvPred / s
    axis.x = xPred + k * innovation
    axis.v = axis.v + kv * innovation / dt
    axis.p = (1 - k) * pPred
    axis.pv = (1 - kv) * pvPred
end

function AR_Kalman:update(pos)
    local now = tick()
    if not self.initialized then
        self.axes.x.x = pos.X
        self.axes.y.x = pos.Y
        self.axes.z.x = pos.Z
        self.lastTime = now
        self.initialized = true
        return pos, Vector3.zero
    end
    local dt = math.max(now - self.lastTime, 0.001)
    self.lastTime = now
    updateAxis(self.axes.x, pos.X, dt, self.q, self.r)
    updateAxis(self.axes.y, pos.Y, dt, self.q, self.r)
    updateAxis(self.axes.z, pos.Z, dt, self.q, self.r)
    return Vector3.new(self.axes.x.x, self.axes.y.x, self.axes.z.x),
           Vector3.new(self.axes.x.v, self.axes.y.v, self.axes.z.v)
end

function AR_Kalman:predict(futureDt)
    futureDt = futureDt or 0.1
    if not self.initialized then return nil end
    return Vector3.new(
        self.axes.x.x + self.axes.x.v * futureDt,
        self.axes.y.x + self.axes.y.v * futureDt,
        self.axes.z.x + self.axes.z.v * futureDt
    )
end

function AR_Kalman:getVelocity()
    if not self.initialized then return Vector3.zero end
    return Vector3.new(self.axes.x.v, self.axes.y.v, self.axes.z.v)
end

function AR_Kalman:reset()
    self.axes = { x = makeAxis(), y = makeAxis(), z = makeAxis() }
    self.initialized = false
    self.lastTime = 0
end

-- ══════════════════════════════════════════
--  REMOTE FINDER
-- ══════════════════════════════════════════
local AR_RemoteFinder = {}
local rf_state = {
    db = {}, shots = {}, selected = nil, autoSelected = nil,
    monitoring = false, hooked = false,
}

local SHOT_WINDOW = 300
local SHOT_DECAY = 5000

local COMBAT_PATTERNS = {
    {p="fire",s=40},{p="shoot",s=40},{p="attack",s=35},{p="hit",s=35},
    {p="shot",s=35},{p="damage",s=30},{p="kill",s=30},{p="bullet",s=30},
    {p="strike",s=30},{p="blast",s=30},{p="hurt",s=30},{p="punch",s=25},
    {p="swing",s=25},{p="weapon",s=25},{p="gun",s=25},{p="explode",s=25},
    {p="combat",s=25},{p="impact",s=25},{p="throw",s=20},{p="trigger",s=20},
    {p="cast",s=20},{p="activate",s=15},{p="ability",s=15},{p="use",s=10},
}

local IGNORE_PATTERNS = {
    "chat","message","ui","menu","shop","buy","sell","equip","unequip",
    "load","save","spawn","init","connect","ping","heartbeat","render",
    "update","ticker","loop","vote","kick","ban","report","friend",
    "party","invite","join","leave","quit","setting","config","option",
    "preference","theme","notification","alert","toast","popup","dialog",
    "inventory","backpack","storage","bank","trade","quest","mission",
    "task","objective","achievement","music","sound","effect","particle",
    "animate",
}

local LOCATION_BONUSES = {
    "combat","weapon","gun","fire","attack","battle","fight","enemy","npc","mob",
}

local function getPath(instance)
    local path = instance.Name
    local parent = instance.Parent
    while parent and parent ~= game do
        path = parent.Name .. "." .. path
        parent = parent.Parent
    end
    return path
end

local function levenshtein(s1, s2)
    local len1, len2 = #s1, #s2
    if len1 == 0 then return len2 end
    if len2 == 0 then return len1 end
    local prev, curr = {}, {}
    for j = 0, len2 do prev[j] = j end
    for i = 1, len1 do
        curr[0] = i
        for j = 1, len2 do
            local cost = s1:sub(i,i) == s2:sub(j,j) and 0 or 1
            curr[j] = math.min(prev[j]+1, curr[j-1]+1, prev[j-1]+cost)
        end
        prev, curr = curr, prev
    end
    return prev[len2]
end

local function scoreName(name)
    local lower = name:lower()
    local best = 0
    local match = "none"
    for _, ip in ipairs(IGNORE_PATTERNS) do
        if lower:find(ip) then return -25, "ignore:"..ip end
    end
    for _, entry in ipairs(COMBAT_PATTERNS) do
        local p, s = entry.p, entry.s
        if lower == p then
            if s > best then best = s; match = p end
        elseif lower:find(p) then
            local sc = s - 5
            if sc > best then best = sc; match = p end
        else
            local dist = levenshtein(lower, p)
            if dist <= 2 and #lower <= #p + 3 then
                local sc = s - dist * 8
                if sc > best then best = sc; match = p.."(fuzzy)" end
            end
        end
    end
    return best, match
end

local function scoreArgs(args)
    local score = 0
    local types = {}
    for i, arg in ipairs(args) do
        local t = typeof(arg)
        types[i] = t
        if t == "Vector3" then score = math.max(score, 12)
        elseif t == "CFrame" then score = math.max(score, 12)
        elseif t == "Instance" then
            if arg and arg:IsA("Model") then score = math.max(score, 15)
            elseif arg and arg:IsA("Humanoid") then score = math.max(score, 15)
            else score = math.max(score, 8) end
        elseif t == "string" then score = math.max(score, 5)
        elseif t == "number" then score = math.max(score, 3) end
    end
    return score, types
end

local function scoreTiming(remoteLastCall)
    local bestDelta = math.huge
    for _, shotTime in ipairs(rf_state.shots) do
        local delta = math.abs(remoteLastCall - shotTime) * 1000
        if delta < bestDelta then bestDelta = delta end
    end
    if bestDelta < 50 then return 30, "shot+50ms"
    elseif bestDelta < 100 then return 25, "shot+100ms"
    elseif bestDelta < 200 then return 15, "shot+200ms"
    elseif bestDelta < SHOT_WINDOW then return 8, "shot+window"
    else return 0, "no-correlation" end
end

local function scoreLocation(instance)
    local path = getPath(instance):lower()
    local score = 0
    for _, bonus in ipairs(LOCATION_BONUSES) do
        if path:find(bonus) then score = score + 10; break end
    end
    local parent = instance.Parent
    if parent then
        if parent:IsA("Tool") then score = score + 15
        elseif parent:IsA("Folder") then
            local pname = parent.Name:lower()
            for _, bonus in ipairs(LOCATION_BONUSES) do
                if pname:find(bonus) then score = score + 8; break end
            end
        end
    end
    return score
end

local function scoreFrequency(entry)
    local score = 0
    local elapsed = tick() - entry.firstCall
    if elapsed > 0.5 then
        local rate = entry.calls / elapsed
        if rate > 0.5 and rate < 5 then score = 15
        elseif rate >= 5 and rate < 20 then score = 8
        elseif rate >= 20 then score = 3 end
    end
    local shotCount = #rf_state.shots
    if shotCount >= 2 then
        local ratio = entry.calls / shotCount
        if ratio >= 0.8 and ratio <= 1.3 then score = score + 20
        elseif ratio >= 0.5 and ratio <= 2.0 then score = score + 10 end
    end
    return score
end

local function logRemote(instance, method, args)
    local path = getPath(instance)
    if not instance or not instance.Parent then return end
    if not rf_state.db[path] then
        rf_state.db[path] = {
            name = instance.Name, path = path, instance = instance,
            method = method, calls = 0, firstCall = tick(), lastCall = tick(),
            lastArgs = args, argTypes = {}, score = 0, breakdown = {},
        }
    end
    local entry = rf_state.db[path]
    entry.calls = entry.calls + 1
    entry.lastCall = tick()
    entry.lastArgs = args
    entry.instance = instance
    local nameScore, nameMatch = scoreName(instance.Name)
    local argScore, argTypes = scoreArgs(args)
    local timingScore, timingMatch = scoreTiming(entry.lastCall)
    local locScore = scoreLocation(instance)
    local freqScore = scoreFrequency(entry)
    entry.argTypes = argTypes
    entry.score = nameScore + timingScore + argScore + locScore + freqScore
    entry.breakdown = {
        name=nameScore, nameMatch=nameMatch, timing=timingScore,
        timingMatch=timingMatch, args=argScore, location=locScore, frequency=freqScore,
    }
    if not rf_state.selected then
        if entry.score > 40 then
            if not rf_state.autoSelected or
               entry.score > (rf_state.db[rf_state.autoSelected] and
               rf_state.db[rf_state.autoSelected].score or 0) then
                rf_state.autoSelected = path
            end
        end
    end
end

local function registerShot()
    table.insert(rf_state.shots, tick())
    local now = tick()
    while #rf_state.shots > 0 and (now - rf_state.shots[1]) * 1000 > SHOT_DECAY do
        table.remove(rf_state.shots, 1)
    end
end

local function installHook()
    if rf_state.hooked then return end
    local mt = getrawmetatable(game)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if (method == "FireServer" or method == "InvokeServer") and rf_state.monitoring then
            pcall(function() logRemote(self, method, {...}) end)
        end
        return oldNamecall(self, ...)
    end)
    setreadonly(mt, true)
    rf_state.hooked = true
end

local function installShotDetection()
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            registerShot()
        end
    end)
    UserInputService.TouchStarted:Connect(function(_, gpe)
        if gpe then return end
        registerShot()
    end)
    local function hookCharacter(char)
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                tool.Activated:Connect(registerShot)
            end
        end
        char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                child.Activated:Connect(registerShot)
            end
        end)
    end
    if LocalPlayer.Character then hookCharacter(LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(hookCharacter)
end

function AR_RemoteFinder.scanDataModel()
    for _, obj in ipairs(game:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local path = getPath(obj)
            if not rf_state.db[path] then
                local nameScore, nameMatch = scoreName(obj.Name)
                local locScore = scoreLocation(obj)
                rf_state.db[path] = {
                    name = obj.Name, path = path, instance = obj,
                    method = obj:IsA("RemoteEvent") and "FireServer" or "InvokeServer",
                    calls = 0, firstCall = 0, lastCall = 0, lastArgs = {}, argTypes = {},
                    score = nameScore + locScore,
                    breakdown = { name=nameScore, nameMatch=nameMatch, location=locScore },
                }
            end
        end
    end
end

function AR_RemoteFinder.start()
    if rf_state.monitoring then return end
    rf_state.monitoring = true
    installHook()
    installShotDetection()
    AR_RemoteFinder.scanDataModel()
end

function AR_RemoteFinder.stop()
    rf_state.monitoring = false
end

function AR_RemoteFinder.getTopCandidates(limit)
    local sorted = {}
    for path, entry in pairs(rf_state.db) do
        if entry.instance and entry.instance.Parent then
            table.insert(sorted, entry)
        end
    end
    table.sort(sorted, function(a, b) return a.score > b.score end)
    local result = {}
    for i = 1, math.min(limit or 8, #sorted) do
        result[i] = sorted[i]
    end
    return result
end

function AR_RemoteFinder.getSelected()
    return rf_state.selected or rf_state.autoSelected
end

function AR_RemoteFinder.selectRemote(path)
    if rf_state.db[path] then rf_state.selected = path end
end

function AR_RemoteFinder.clearSelection()
    rf_state.selected = nil
end

function AR_RemoteFinder.fireRemote(target)
    local path = rf_state.selected or rf_state.autoSelected
    if not path then return false end
    local entry = rf_state.db[path]
    if not entry or not entry.instance or not entry.instance.Parent then return false end
    local instance = entry.instance
    local args = entry.lastArgs or {}
    if #args > 0 then
        args[1] = target or args[1]
    else
        args = { target }
    end
    if entry.method == "FireServer" then
        pcall(function() instance:FireServer(unpack(args)) end)
    else
        pcall(function() instance:InvokeServer(unpack(args)) end)
    end
    return true
end

function AR_RemoteFinder.getDB() return rf_state.db end

function AR_RemoteFinder.getStats()
    local count, totalCalls = 0, 0
    for _, entry in pairs(rf_state.db) do
        count = count + 1
        totalCalls = totalCalls + entry.calls
    end
    return {
        remotes = count, calls = totalCalls, shots = #rf_state.shots,
        selected = rf_state.selected or rf_state.autoSelected,
        monitoring = rf_state.monitoring,
    }
end

-- Start remote finder immediately
AR_RemoteFinder.start()

-- ══════════════════════════════════════════
--  KALMAN PER TARGET
-- ══════════════════════════════════════════
local kalmanPerTarget = {}

local function getKalmanFor(char)
    if not kalmanPerTarget[char] then
        kalmanPerTarget[char] = AR_Kalman.new({
            processNoise = Cfg.KalmanProcessNoise,
            measurementNoise = Cfg.KalmanMeasureNoise,
        })
    end
    local k = kalmanPerTarget[char]
    k.q = Cfg.KalmanProcessNoise
    k.r = Cfg.KalmanMeasureNoise
    return k
end

local function getPredicted(char)
    local part = char:FindFirstChild(Cfg.AimPart) or char:FindFirstChild("Head")
    if not part then return nil, nil end

    if Cfg.KalmanEnabled then
        local kalman = getKalmanFor(char)
        kalman:update(part.Position)
        local predicted = kalman:predict(Cfg.Prediction)
        return predicted or part.Position, part
    else
        local root = char:FindFirstChild("HumanoidRootPart")
        local vel = root and root.Velocity or Vector3.zero
        return part.Position + vel * Cfg.Prediction, part
    end
end

-- ══════════════════════════════════════════
--  UTILS
-- ══════════════════════════════════════════
local function screenCenter()
    return Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
end

local function toScreen(pos)
    local sp, vis = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X, sp.Y), vis
end

local function screenDist(pos)
    local sp, vis = toScreen(pos)
    if not vis then return math.huge end
    return (sp - screenCenter()).Magnitude
end

local function wallCheck(targetPart)
    if not Cfg.WallCheck then return true end
    local origin = Camera.CFrame.Position
    local dir = (targetPart.Position - origin)
    local ray = Ray.new(origin, dir.Unit * dir.Magnitude)
    local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, Camera})
    if not hit then return true end
    return targetPart:IsDescendantOf(hit.Parent)
end

local function isRealPlayer(char)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == char then return true end
    end
    return false
end

local function isBotChar(char)
    if isRealPlayer(char) then return false end
    for _, kw in ipairs(Cfg.BotKW) do
        if char.Name:lower():find(kw:lower()) then return true end
    end
    local hum = char:FindFirstChild("Humanoid")
    return hum ~= nil
end

-- ══════════════════════════════════════════
--  TARGET RESOLUTION
-- ══════════════════════════════════════════
local function resolveNearest()
    local best, bd = nil, Cfg.FOV
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if Cfg.TeamCheck and p.Team == LocalPlayer.Team then continue end
        local c = p.Character
        if not c then continue end
        local hum = c:FindFirstChild("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local part = c:FindFirstChild(Cfg.AimPart) or c:FindFirstChild("Head")
        if not part then continue end
        if not wallCheck(part) then continue end
        local d = screenDist(part.Position)
        if d < bd then bd = d; best = c end
    end
    return best
end

local function resolveBot()
    local best, bd = nil, Cfg.FOV
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Health > 0 then
            local c = obj.Parent
            if c == LocalPlayer.Character then continue end
            if not isBotChar(c) then continue end
            local part = c:FindFirstChild(Cfg.AimPart) or c:FindFirstChild("Head")
            if not part then continue end
            if not wallCheck(part) then continue end
            local d = screenDist(part.Position)
            if d < bd then bd = d; best = c end
        end
    end
    return best
end

local function resolveNick()
    if Cfg.TargetNick == "" then return nil end
    local n = Cfg.TargetNick:lower()
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if p.Name:lower():find(n) or p.DisplayName:lower():find(n) then
            local c = p.Character
            if not c then continue end
            local hum = c:FindFirstChild("Humanoid")
            if not hum or hum.Health <= 0 then continue end
            return c
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Humanoid") and obj.Health > 0 then
            local c = obj.Parent
            if c.Name:lower():find(n) then
                local part = c:FindFirstChild("Head")
                if part and wallCheck(part) then return c end
            end
        end
    end
end

local function getTarget()
    if Cfg.AimMode == "nearest" then return resolveNearest()
    elseif Cfg.AimMode == "bot" then return resolveBot()
    elseif Cfg.AimMode == "nickname" then return resolveNick() end
end

-- ══════════════════════════════════════════
--  FIRE SYSTEM
-- ══════════════════════════════════════════
local lastFire = 0

local function doFire()
    local now = tick()
    if now - lastFire < Cfg.FireRate then return end
    lastFire = now
    local cx = Camera.ViewportSize.X / 2
    local cy = Camera.ViewportSize.Y / 2
    VirtualUser:Button1Down(Vector2.new(cx, cy), Camera.CFrame)
    task.delay(0.05, function()
        VirtualUser:Button1Up(Vector2.new(cx, cy), Camera.CFrame)
    end)
end

-- ══════════════════════════════════════════
--  CAMERA RETURN
-- ══════════════════════════════════════════
local camReturnBusy = false

local function cameraReturn()
    if camReturnBusy then return end
    local tgt = getTarget()
    if not tgt then return end

    local part = tgt:FindFirstChild(Cfg.AimPart) or tgt:FindFirstChild("Head")
    if not part then return end

    local predicted = getPredicted(tgt)
    if not predicted then return end

    camReturnBusy = true
    local originalCFrame = Camera.CFrame
    local goalCFrame = CFrame.new(Camera.CFrame.Position, predicted)

    local usedRemote = false
    if Cfg.CamReturnRemote and AR_RemoteFinder.getSelected() then
        usedRemote = AR_RemoteFinder.fireRemote(part)
    end

    if not usedRemote then
        Camera.CFrame = goalCFrame
        task.wait(0.02)
        local cx = Camera.ViewportSize.X / 2
        local cy = Camera.ViewportSize.Y / 2
        VirtualUser:Button1Down(Vector2.new(cx, cy), Camera.CFrame)
        task.wait(0.03)
        VirtualUser:Button1Up(Vector2.new(cx, cy), Camera.CFrame)
        task.wait(0.02)
    end

    local returnSpeed = Cfg.CamReturnSpeed
    Camera.CFrame = Camera.CFrame:Lerp(originalCFrame, returnSpeed)
    task.wait(0.02)
    Camera.CFrame = Camera.CFrame:Lerp(originalCFrame, math.min(returnSpeed + 0.15, 0.98))
    task.wait(0.02)
    Camera.CFrame = originalCFrame
    camReturnBusy = false
end

-- Camera Return hotkey
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if Cfg.CamReturnEnabled and input.KeyCode == Cfg.CamReturnKey then
        task.spawn(cameraReturn)
    end
end)

-- Mobile jump-aim hook
if isMobile then
    local CAS = game:GetService("ContextActionService")
    CAS:BindAction("AR_JumpAim", function(_, state, _)
        if state == Enum.UserInputState.Begin then
            Cfg.JumpAimActive = not Cfg.JumpAimActive
            if Cfg.ManualFire and Cfg.JumpAimActive then
                local tgt = getTarget()
                if tgt then doFire() end
            end
        end
        return Cfg.Enabled and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
    end, true, Enum.KeyCode.ButtonB, Enum.KeyCode.Space)
    CAS:SetPosition("AR_JumpAim", UDim2.new(1,-70,1,-70))
end

-- ══════════════════════════════════════════
--  MAIN LOOP
-- ══════════════════════════════════════════
local fovDraw
if drawingOK then
    fovDraw = Drawing.new("Circle")
    fovDraw.Thickness = 1.5
    fovDraw.NumSides = 80
    fovDraw.Filled = false
    fovDraw.Color = Cfg.FOVColor
    fovDraw.Visible = false
    fovDraw.Position = screenCenter()
    fovDraw.Radius = Cfg.FOV
end

RunService.RenderStepped:Connect(function()
    if drawingOK and fovDraw then
        fovDraw.Position = screenCenter()
        fovDraw.Radius = Cfg.FOV
        fovDraw.Visible = Cfg.Enabled and Cfg.FOVCircle
        fovDraw.Color = Cfg.FOVColor
    end

    if not Cfg.Enabled then return end

    local shouldAim = isMobile and Cfg.JumpAimActive
        or (not isMobile and UserInputService:IsKeyDown(Enum.KeyCode.Q))
    if not shouldAim then return end

    local tgt = getTarget()
    if not tgt then return end

    local predicted, aimPart = getPredicted(tgt)
    if not predicted then return end

    local goal = CFrame.new(Camera.CFrame.Position, predicted)
    Camera.CFrame = Camera.CFrame:Lerp(goal, Cfg.Smoothness)

    if Cfg.AutoFire then doFire() end
end)

-- Cleanup stale kalman filters
task.spawn(function()
    while true do
        task.wait(5)
        for char, _ in pairs(kalmanPerTarget) do
            if not char or not char.Parent or
               (char:FindFirstChild("Humanoid") and char.Humanoid.Health <= 0) then
                kalmanPerTarget[char] = nil
            end
        end
    end
end)

-- ══════════════════════════════════════════
--  UI — HORIZONTAL COMPACT
-- ══════════════════════════════════════════
local T = {
    bg      = Color3.fromRGB(10, 10, 13),
    surface = Color3.fromRGB(18, 18, 22),
    card    = Color3.fromRGB(24, 24, 30),
    border  = Color3.fromRGB(38, 38, 48),
    accent  = Color3.fromRGB(220, 50, 50),
    accentD = Color3.fromRGB(160, 30, 30),
    green   = Color3.fromRGB(55, 190, 95),
    red     = Color3.fromRGB(200, 48, 48),
    text    = Color3.fromRGB(238, 238, 245),
    sub     = Color3.fromRGB(110, 110, 130),
    white   = Color3.fromRGB(255,255,255),
}

local function corner(parent, r)
    local c = Instance.new("UICorner", parent)
    c.CornerRadius = UDim.new(0, r or 8)
    return c
end

local function stroke(parent, color, thickness, trans)
    local s = Instance.new("UIStroke", parent)
    s.Color = color or T.border
    s.Thickness = thickness or 1
    s.Transparency = trans or 0
    return s
end

local function gradient(parent, c0, c1, rot)
    local g = Instance.new("UIGradient", parent)
    g.Color = ColorSequence.new(c0, c1)
    g.Rotation = rot or 90
    return g
end

local function tween(obj, t, props)
    TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end

local function label(parent, text, size, font, color, xa, zindex)
    local l = Instance.new("TextLabel", parent)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextSize = size or 13
    l.Font = font or Enum.Font.Gotham
    l.TextColor3 = color or T.text
    l.TextXAlignment = xa or Enum.TextXAlignment.Left
    l.ZIndex = zindex or 8
    l.RichText = true
    return l
end

local ROOT = safeGui()

local PW = isMobile and math.min(380, Camera.ViewportSize.X - 32) or 460
local PH = isMobile and 240 or 220

local Gui = Instance.new("ScreenGui", ROOT)
Gui.Name = "AR_v4"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 999

-- ── MAIN PANEL ─────────────────────────────
local Panel = Instance.new("Frame", Gui)
Panel.Name = "Panel"
Panel.Size = UDim2.fromOffset(PW, PH)
Panel.Position = UDim2.new(0, 16, 0.5, -PH/2)
Panel.BackgroundColor3 = T.bg
Panel.BorderSizePixel = 0
Panel.Active = true
Panel.Draggable = true
Panel.ZIndex = 5
corner(Panel, 10)
stroke(Panel, T.border, 1, 0)

-- ── TITLE BAR ──────────────────────────────
local TBar = Instance.new("Frame", Panel)
TBar.Size = UDim2.new(1,0,0,32)
TBar.BackgroundColor3 = T.surface
TBar.ZIndex = 6
corner(TBar, 10)
local tbFix = Instance.new("Frame", TBar)
tbFix.Size = UDim2.new(1,0,0,10); tbFix.Position = UDim2.new(0,0,1,-10)
tbFix.BackgroundColor3 = T.surface; tbFix.BorderSizePixel = 0; tbFix.ZIndex = 6

local accentBar = Instance.new("Frame", TBar)
accentBar.Size = UDim2.new(1,0,0,2)
accentBar.BackgroundColor3 = T.accent
accentBar.ZIndex = 9
corner(accentBar, 1)
gradient(accentBar, T.accent, T.accentD, 0)

local logoDot = Instance.new("Frame", TBar)
logoDot.Size = UDim2.fromOffset(6,6)
logoDot.Position = UDim2.new(0,12,0.5,-3)
logoDot.BackgroundColor3 = T.accent
logoDot.ZIndex = 9
corner(logoDot, 3)

local titleLbl = label(TBar, "AR  v4", 13, Enum.Font.GothamBold, T.text, Enum.TextXAlignment.Left, 9)
titleLbl.Size = UDim2.new(0.5,0,1,0)
titleLbl.Position = UDim2.new(0,24,0,0)

local statusLbl = label(TBar, '<font color="#37be5f">●</font> ON', 11, Enum.Font.Gotham, T.sub, Enum.TextXAlignment.Right, 9)
statusLbl.Size = UDim2.new(0,60,1,0)
statusLbl.Position = UDim2.new(1,-72,0,0)

local closeBtn = Instance.new("TextButton", TBar)
closeBtn.Size = UDim2.fromOffset(24,24)
closeBtn.Position = UDim2.new(1,-32,0.5,-12)
closeBtn.BackgroundColor3 = T.red
closeBtn.Text = "✕"
closeBtn.TextColor3 = T.white
closeBtn.TextSize = 12
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 9
corner(closeBtn, 6)

-- ── TAB BAR (left sidebar) ─────────────────
local Sidebar = Instance.new("Frame", Panel)
Sidebar.Size = UDim2.new(0, 72, 1, -32)
Sidebar.Position = UDim2.new(0, 0, 0, 32)
Sidebar.BackgroundColor3 = T.surface
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 6

local sidebarLine = Instance.new("Frame", Sidebar)
sidebarLine.Size = UDim2.new(0,1,1,0)
sidebarLine.Position = UDim2.new(1,-1,0,0)
sidebarLine.BackgroundColor3 = T.border
sidebarLine.BorderSizePixel = 0
sidebarLine.ZIndex = 7

local tabContainer = Instance.new("Frame", Sidebar)
tabContainer.Size = UDim2.new(1,0,1,-8)
tabContainer.Position = UDim2.new(0,0,0,4)
tabContainer.BackgroundTransparency = 1
tabContainer.ZIndex = 7

local tabList = Instance.new("UIListLayout", tabContainer)
tabList.Padding = UDim.new(0,2)
tabList.SortOrder = Enum.SortOrder.LayoutOrder
tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center

local TABS = {"CORE", "FIRE", "AIM", "REMOTE"}
local tabButtons = {}
local tabPages = {}

for i, name in ipairs(TABS) do
    local btn = Instance.new("TextButton", tabContainer)
    btn.Size = UDim2.new(1,-8,0,28)
    btn.BackgroundColor3 = (i == 1) and T.card or T.surface
    btn.Text = name
    btn.TextColor3 = (i == 1) and T.accent or T.sub
    btn.TextSize = 10
    btn.Font = Enum.Font.GothamBold
    btn.ZIndex = 8
    corner(btn, 6)
    tabButtons[name] = btn
end

-- ── CONTENT AREA ───────────────────────────
local Content = Instance.new("Frame", Panel)
Content.Size = UDim2.new(1, -72, 1, -32)
Content.Position = UDim2.new(0, 72, 0, 32)
Content.BackgroundTransparency = 1
Content.ZIndex = 7

-- Create a page for each tab
for _, name in ipairs(TABS) do
    local page = Instance.new("ScrollingFrame", Content)
    page.Size = UDim2.fromScale(1,1)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = T.accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.fromScale(0,0)
    page.Visible = (name == "CORE")
    page.ZIndex = 7
    page.ClipsDescendants = true

    local pad = Instance.new("UIPadding", page)
    pad.PaddingLeft = UDim.new(0,8)
    pad.PaddingRight = UDim.new(0,8)
    pad.PaddingTop = UDim.new(0,8)
    pad.PaddingBottom = UDim.new(0,8)

    local list = Instance.new("UIListLayout", page)
    list.Padding = UDim.new(0,4)
    list.SortOrder = Enum.SortOrder.LayoutOrder

    tabPages[name] = page
end

-- Tab switching
for name, btn in pairs(tabButtons) do
    btn.MouseButton1Click:Connect(function()
        for n, b in pairs(tabButtons) do
            tween(b, 0.15, {BackgroundColor3 = T.surface, TextColor3 = T.sub})
            tabPages[n].Visible = false
        end
        tween(btn, 0.15, {BackgroundColor3 = T.card, TextColor3 = T.accent})
        tabPages[name].Visible = true
    end)
end

-- ══════════════════════════════════════════
--  UI COMPONENTS (compact)
-- ══════════════════════════════════════════
local ROW_H = 30

local function toggle(parent, text, state, order, cb)
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(1,0,0,ROW_H)
    card.BackgroundColor3 = T.card
    card.LayoutOrder = order
    card.ZIndex = 7
    corner(card, 6)
    stroke(card, T.border, 1, 0.4)

    local lbl = label(card, text, 11, Enum.Font.Gotham, T.text, Enum.TextXAlignment.Left, 8)
    lbl.Size = UDim2.new(0.6,0,1,0)
    lbl.Position = UDim2.new(0,8,0,0)

    local pill = Instance.new("Frame", card)
    pill.Size = UDim2.fromOffset(32,16)
    pill.Position = UDim2.new(1,-40,0.5,-8)
    pill.BackgroundColor3 = state and T.green or T.border
    pill.ZIndex = 8
    corner(pill, 8)

    local knob = Instance.new("Frame", pill)
    knob.Size = UDim2.fromOffset(12,12)
    knob.Position = state and UDim2.fromOffset(17,2) or UDim2.fromOffset(3,2)
    knob.BackgroundColor3 = T.white
    knob.ZIndex = 9
    corner(knob, 6)

    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.fromScale(1,1); btn.BackgroundTransparency = 1
    btn.Text = ""; btn.ZIndex = 9

    local current = state
    btn.MouseButton1Click:Connect(function()
        current = not current
        tween(pill, 0.12, {BackgroundColor3 = current and T.green or T.border})
        tween(knob, 0.12, {Position = current and UDim2.fromOffset(17,2) or UDim2.fromOffset(3,2)})
        cb(current)
    end)
    return pill, btn
end

local function slider(parent, text, min, max, default, order, cb)
    local H = 42
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(1,0,0,H)
    card.BackgroundColor3 = T.card
    card.LayoutOrder = order
    card.ZIndex = 7
    corner(card, 6)
    stroke(card, T.border, 1, 0.4)

    local topLbl = label(card, text, 10, Enum.Font.Gotham, T.sub, Enum.TextXAlignment.Left, 8)
    topLbl.Size = UDim2.new(0.55,0,0,16)
    topLbl.Position = UDim2.new(0,8,0,4)

    local valLbl = label(card, tostring(default), 10, Enum.Font.GothamBold, T.accent, Enum.TextXAlignment.Right, 8)
    valLbl.Size = UDim2.new(0.3,0,0,16)
    valLbl.Position = UDim2.new(0.65,0,0,4)

    local track = Instance.new("Frame", card)
    track.Size = UDim2.new(1,-16,0,4)
    track.Position = UDim2.new(0,8,0,H-12)
    track.BackgroundColor3 = T.border
    track.ZIndex = 8
    corner(track, 2)

    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new((default-min)/(max-min),0,1,0)
    fill.BackgroundColor3 = T.accent
    fill.ZIndex = 9
    corner(fill, 2)
    gradient(fill, T.accent, T.accentD, 0)

    local thumb = Instance.new("Frame", track)
    thumb.Size = UDim2.fromOffset(8,8)
    thumb.AnchorPoint = Vector2.new(0.5,0.5)
    thumb.Position = UDim2.new((default-min)/(max-min),0,0.5,0)
    thumb.BackgroundColor3 = T.white
    thumb.ZIndex = 10
    corner(thumb, 4)

    local hit = Instance.new("TextButton", track)
    hit.Size = UDim2.new(1,0,0,24)
    hit.Position = UDim2.new(0,0,0.5,-12)
    hit.BackgroundTransparency = 1; hit.Text = ""; hit.ZIndex = 11

    local dragging = false
    hit.MouseButton1Down:Connect(function() dragging = true end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    RunService.Heartbeat:Connect(function()
        if not dragging then return end
        local mx = UserInputService:GetMouseLocation().X
        local rel = math.clamp((mx - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + rel*(max-min))
        fill.Size = UDim2.new(rel,0,1,0)
        thumb.Position = UDim2.new(rel,0,0.5,0)
        valLbl.Text = tostring(val)
        cb(val)
    end)
end

local function dropdown(parent, text, opts, default, order, cb)
    local closed = ROW_H
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(1,0,0,closed)
    card.BackgroundColor3 = T.card
    card.LayoutOrder = order
    card.ClipsDescendants = true
    card.ZIndex = 7
    corner(card, 6)
    stroke(card, T.border, 1, 0.4)

    local hdr = Instance.new("TextButton", card)
    hdr.Size = UDim2.new(1,0,0,closed)
    hdr.BackgroundTransparency = 1
    hdr.Text = ""
    hdr.ZIndex = 9

    local hLbl = label(hdr, text .. "  <b>" .. default .. "</b>", 11, Enum.Font.Gotham, T.text, Enum.TextXAlignment.Left, 10)
    hLbl.Size = UDim2.new(0.85,0,1,0)
    hLbl.Position = UDim2.new(0,8,0,0)

    local arrow = label(hdr, "▾", 12, Enum.Font.GothamBold, T.accent, Enum.TextXAlignment.Right, 10)
    arrow.Size = UDim2.new(0,20,1,0)
    arrow.Position = UDim2.new(1,-24,0,0)

    local opened = false
    local IH = 26
    local totalH = closed + (#opts * (IH+2)) + 4
    local optBtns = {}

    for i, opt in ipairs(opts) do
        local ob = Instance.new("TextButton", card)
        ob.Size = UDim2.new(1,-16,0,IH)
        ob.Position = UDim2.new(0,8,0, closed + (i-1)*(IH+2) + 2)
        ob.BackgroundColor3 = opt == default and T.accent or Color3.fromRGB(30,30,38)
        ob.TextColor3 = T.text
        ob.Text = opt
        ob.TextSize = 10
        ob.Font = Enum.Font.Gotham
        ob.ZIndex = 10
        corner(ob, 5)
        table.insert(optBtns, ob)

        ob.MouseButton1Click:Connect(function()
            for _, b in ipairs(optBtns) do
                tween(b, 0.1, {BackgroundColor3 = Color3.fromRGB(30,30,38)})
            end
            tween(ob, 0.1, {BackgroundColor3 = T.accent})
            hLbl.Text = text .. "  <b>" .. opt .. "</b>"
            opened = false
            tween(card, 0.15, {Size = UDim2.new(1,0,0,closed)})
            tween(arrow, 0.15, {Rotation = 0})
            cb(opt)
        end)
    end

    hdr.MouseButton1Click:Connect(function()
        opened = not opened
        tween(card, 0.15, {Size = UDim2.new(1,0,0, opened and totalH or closed)})
        tween(arrow, 0.15, {Rotation = opened and 180 or 0})
    end)
end

local function inputBox(parent, text, placeholder, order, cb)
    local H = 46
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(1,0,0,H)
    card.BackgroundColor3 = T.card
    card.LayoutOrder = order
    card.ZIndex = 7
    corner(card, 6)
    stroke(card, T.border, 1, 0.4)

    local lbl = label(card, text, 9, Enum.Font.GothamBold, T.sub, Enum.TextXAlignment.Left, 8)
    lbl.Size = UDim2.new(1,-12,0,14)
    lbl.Position = UDim2.new(0,8,0,4)

    local box = Instance.new("TextBox", card)
    box.Size = UDim2.new(1,-16,0,22)
    box.Position = UDim2.new(0,8,0,20)
    box.BackgroundColor3 = Color3.fromRGB(20,20,26)
    box.TextColor3 = T.text
    box.PlaceholderText = placeholder
    box.PlaceholderColor3 = T.sub
    box.Text = ""
    box.TextSize = 11
    box.Font = Enum.Font.Gotham
    box.ClearTextOnFocus = false
    box.ZIndex = 8
    corner(box, 5)
    stroke(box, T.border, 1, 0.3)

    box.FocusLost:Connect(function() cb(box.Text) end)
end

local function actionButton(parent, text, order, cb)
    local card = Instance.new("TextButton", parent)
    card.Size = UDim2.new(1,0,0,ROW_H)
    card.BackgroundColor3 = T.card
    card.LayoutOrder = order
    card.Text = ""
    card.ZIndex = 7
    corner(card, 6)
    stroke(card, T.border, 1, 0.4)

    local lbl = label(card, text, 11, Enum.Font.GothamBold, T.text, Enum.TextXAlignment.Center, 8)
    lbl.Size = UDim2.fromScale(1,1)

    card.MouseButton1Click:Connect(function()
        tween(card, 0.1, {BackgroundColor3 = T.accent})
        task.delay(0.15, function()
            tween(card, 0.15, {BackgroundColor3 = T.card})
        end)
        cb()
    end)
    return card
end

-- ══════════════════════════════════════════
--  BUILD TAB PAGES
-- ══════════════════════════════════════════

-- ── CORE TAB ───────────────────────────────
local corePage = tabPages["CORE"]

toggle(corePage, "Aimbot Enable", Cfg.Enabled, 1, function(v)
    Cfg.Enabled = v
    statusLbl.Text = v and '<font color="#37be5f">●</font> ON' or '<font color="#c83030">●</font> OFF'
end)
toggle(corePage, "Team Check", Cfg.TeamCheck, 2, function(v) Cfg.TeamCheck = v end)
toggle(corePage, "Wall Check", Cfg.WallCheck, 3, function(v) Cfg.WallCheck = v end)
toggle(corePage, "FOV Circle", Cfg.FOVCircle, 4, function(v) Cfg.FOVCircle = v end)
toggle(corePage, "Kalman Filter", Cfg.KalmanEnabled, 5, function(v) Cfg.KalmanEnabled = v end)

slider(corePage, "Process Noise", 1, 20, math.floor(Cfg.KalmanProcessNoise * 10), 6, function(v)
    Cfg.KalmanProcessNoise = v / 10
end)
slider(corePage, "Measure Noise", 1, 30, math.floor(Cfg.KalmanMeasureNoise), 7, function(v)
    Cfg.KalmanMeasureNoise = v
end)

-- ── FIRE TAB ───────────────────────────────
local firePage = tabPages["FIRE"]

toggle(firePage, "Auto-Fire", Cfg.AutoFire, 1, function(v) Cfg.AutoFire = v end)
toggle(firePage, "Manual Fire", Cfg.ManualFire, 2, function(v) Cfg.ManualFire = v end)
slider(firePage, "Fire Rate (ms)", 50, 500, math.floor(Cfg.FireRate*1000), 3, function(v)
    Cfg.FireRate = v / 1000
end)

toggle(firePage, "Camera Return", Cfg.CamReturnEnabled, 4, function(v) Cfg.CamReturnEnabled = v end)
slider(firePage, "Cam Return Speed", 50, 98, math.floor(Cfg.CamReturnSpeed * 100), 5, function(v)
    Cfg.CamReturnSpeed = v / 100
end)
toggle(firePage, "Use Remote (CR)", Cfg.CamReturnRemote, 6, function(v) Cfg.CamReturnRemote = v end)

actionButton(firePage, "▶  FIRE CAMERA RETURN", 7, function()
    task.spawn(cameraReturn)
end)

-- ── AIM TAB ────────────────────────────────
local aimPage = tabPages["AIM"]

slider(aimPage, "FOV", 50, 400, Cfg.FOV, 1, function(v) Cfg.FOV = v end)
slider(aimPage, "Smoothness %", 5, 40, math.floor(Cfg.Smoothness*100), 2, function(v)
    Cfg.Smoothness = v/100
end)
slider(aimPage, "Prediction", 0, 30, math.floor(Cfg.Prediction*100), 3, function(v)
    Cfg.Prediction = v/100
end)

dropdown(aimPage, "Aim Part", {"Head","HumanoidRootPart","UpperTorso","Torso"}, Cfg.AimPart, 4, function(v)
    Cfg.AimPart = v
end)
dropdown(aimPage, "Aim Mode", {"nearest","bot","nickname"}, Cfg.AimMode, 5, function(v)
    Cfg.AimMode = v
end)
inputBox(aimPage, "Nickname Target", "partial or full name...", 6, function(v)
    Cfg.TargetNick = v
end)
inputBox(aimPage, "Add Bot Keyword", "e.g. Guard, Zombie...", 7, function(v)
    if v ~= "" then table.insert(Cfg.BotKW, v) end
end)

-- ── REMOTE TAB ─────────────────────────────
local remotePage = tabPages["REMOTE"]

local remoteInfoLbl = label(remotePage, "Scanning remotes...", 10, Enum.Font.Gotham, T.sub, Enum.TextXAlignment.Left, 8)
remoteInfoLbl.Size = UDim2.new(1,-12,0,16)
remoteInfoLbl.Position = UDim2.new(0,8,0,0)
remoteInfoLbl.LayoutOrder = 1

local remoteListFrame = Instance.new("Frame", remotePage)
remoteListFrame.Size = UDim2.new(1,0,0,120)
remoteListFrame.BackgroundColor3 = Color3.fromRGB(20,20,26)
remoteListFrame.LayoutOrder = 2
remoteListFrame.ZIndex = 7
corner(remoteListFrame, 6)
stroke(remoteListFrame, T.border, 1, 0.4)

local remoteScroll = Instance.new("ScrollingFrame", remoteListFrame)
remoteScroll.Size = UDim2.fromScale(1,1)
remoteScroll.Position = UDim2.fromScale(0,0)
remoteScroll.BackgroundTransparency = 1
remoteScroll.BorderSizePixel = 0
remoteScroll.ScrollBarThickness = 2
remoteScroll.ScrollBarImageColor3 = T.accent
remoteScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
remoteScroll.CanvasSize = UDim2.fromScale(0,0)
remoteScroll.ZIndex = 8
remoteScroll.ClipsDescendants = true

local remoteListPad = Instance.new("UIPadding", remoteScroll)
remoteListPad.PaddingLeft = UDim.new(0,4)
remoteListPad.PaddingRight = UDim.new(0,4)
remoteListPad.PaddingTop = UDim.new(0,4)
remoteListPad.PaddingBottom = UDim.new(0,4)

local remoteListLayout = Instance.new("UIListLayout", remoteScroll)
remoteListLayout.Padding = UDim.new(0,2)
remoteListLayout.SortOrder = Enum.SortOrder.LayoutOrder

local selectedRemoteLbl = label(remotePage, "Selected: none", 10, Enum.Font.Gotham, T.text, Enum.TextXAlignment.Left, 8)
selectedRemoteLbl.Size = UDim2.new(1,-12,0,16)
selectedRemoteLbl.LayoutOrder = 3
selectedRemoteLbl.RichText = true

actionButton(remotePage, "↻  RESCAN DATA MODEL", 4, function()
    AR_RemoteFinder.scanDataModel()
    task.delay(0.5, updateRemoteList)
end)

actionButton(remotePage, "✕  CLEAR SELECTION", 5, function()
    AR_RemoteFinder.clearSelection()
    updateRemoteList()
end)

-- Remote list updater
function updateRemoteList()
    for _, child in ipairs(remoteScroll:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end

    local candidates = AR_RemoteFinder.getTopCandidates(12)
    local sel = AR_RemoteFinder.getSelected()

    for i, entry in ipairs(candidates) do
        local rb = Instance.new("TextButton", remoteScroll)
        rb.Size = UDim2.new(1,-4,0,24)
        rb.BackgroundColor3 = (entry.path == sel) and T.accent or T.card
        rb.Text = ""
        rb.ZIndex = 9
        corner(rb, 4)

        local rl = label(rb, string.format("[%d] %s  (%d calls)", entry.score, entry.name, entry.calls),
            9, Enum.Font.Gotham, T.text, Enum.TextXAlignment.Left, 10)
        rl.Size = UDim2.new(1,-8,1,0)
        rl.Position = UDim2.new(0,4,0,0)

        rb.MouseButton1Click:Connect(function()
            AR_RemoteFinder.selectRemote(entry.path)
            updateRemoteList()
        end)

        rb.LayoutOrder = i
    end

    local stats = AR_RemoteFinder.getStats()
    remoteInfoLbl.Text = string.format("Found: %d remotes | Shots: %d | Monitoring: %s",
        stats.remotes, stats.shots, stats.monitoring and "YES" or "NO")

    if sel then
        local entry = rf_state.db[sel]
        if entry then
            selectedRemoteLbl.Text = string.format('Selected: <font color="#dc3232">%s</font> (%s)', entry.name, entry.method)
        end
    else
        selectedRemoteLbl.Text = "Selected: none (auto)"
    end
end

-- Auto-refresh remote list every 2 seconds
task.spawn(function()
    while true do
        task.wait(2)
        pcall(updateRemoteList)
    end
end)

-- ── CLOSE BUTTON ───────────────────────────
closeBtn.MouseButton1Click:Connect(function()
    tween(Panel, 0.2, {Size = UDim2.fromOffset(PW, 0)})
    task.delay(0.21, function() Panel.Visible = false end)
end)

-- ── MENU TOGGLE PILL ───────────────────────
local MenuPill = Instance.new("TextButton", Gui)
MenuPill.Size = UDim2.fromOffset(isMobile and 56 or 48, isMobile and 28 or 24)
MenuPill.Position = UDim2.new(0, 8, 0, 48)
MenuPill.BackgroundColor3 = T.accent
MenuPill.Text = "☰ AR"
MenuPill.TextColor3 = T.white
MenuPill.TextSize = isMobile and 12 or 10
MenuPill.Font = Enum.Font.GothamBold
MenuPill.ZIndex = 20
corner(MenuPill, isMobile and 14 or 12)
gradient(MenuPill, T.accent, T.accentD, 90)
stroke(MenuPill, T.white, 1, 0.8)

local menuVisible = true
MenuPill.MouseButton1Click:Connect(function()
    menuVisible = not menuVisible
    Panel.Visible = menuVisible
    if menuVisible then
        Panel.Size = UDim2.fromOffset(PW, 0)
        tween(Panel, 0.2, {Size = UDim2.fromOffset(PW, PH)})
    end
end)

-- ── CLAMP PANEL ────────────────────────────
RunService.RenderStepped:Connect(function()
    local vp = Camera.ViewportSize
    local inset = GuiService:GetGuiInset()
    local pos = Panel.AbsolutePosition
    local sz = Panel.AbsoluteSize
    local nx = math.clamp(pos.X, 0, vp.X - sz.X)
    local ny = math.clamp(pos.Y, inset.Y, vp.Y - sz.Y)
    if nx ~= pos.X or ny ~= pos.Y then
        Panel.Position = UDim2.fromOffset(nx, ny)
    end
end)

-- Initial remote list populate
task.delay(1, updateRemoteList)

print("[AR v4] Loaded — Kalman Filter: active | Remote Finder: monitoring | Tabs: CORE / FIRE / AIM / REMOTE")
