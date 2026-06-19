-- ====================================================================
-- AXIOM — Gun Tool Inspector
-- Запусти ЭТОТ скрипт ОТДЕЛЬНО в executor (не вместо AXIOM, а ДО или ПОСЛЕ).
-- Игроком должен быть Sheriff (то есть Gun должен быть в руках или Backpack).
-- Скрипт ничего не стреляет — только смотрит и пишет в консоль F9.
-- ====================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local function findGun()
    local char = LocalPlayer.Character
    if char then
        for _, c in ipairs(char:GetChildren()) do
            if c:IsA("Tool") and (c.Name == "Gun" or c.Name == "Revolver") then
                return c
            end
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, c in ipairs(bp:GetChildren()) do
            if c:IsA("Tool") and (c.Name == "Gun" or c.Name == "Revolver") then
                return c
            end
        end
    end
    return nil
end

local gun = findGun()
if not gun then
    warn("[AXIOM Inspector] Gun tool not found. Ты Sheriff? Подожди раунд.")
    return
end

print("=========================================")
print("[AXIOM Inspector] Gun tool: " .. gun.Name)
print("[AXIOM Inspector] Полное содержимое:")
print("=========================================")

local function describe(obj, indent)
    indent = indent or ""
    local className = obj.ClassName
    local name = obj.Name
    print(indent .. "├ [" .. className .. "] " .. name)

    if className == "RemoteEvent" or className == "RemoteFunction" then
        print(indent .. "│  ★ ЭТО REMOTE — кандидат для FireServer")
    end

    if className == "LocalScript" or className == "ModuleScript" then
        print(indent .. "│  ⚙ Script внутри (нужно ловить FireServer изнутри)")
    end

    for _, child in ipairs(obj:GetChildren()) do
        describe(child, indent .. "│  ")
    end
end

describe(gun)

print("=========================================")
print("[AXIOM Inspector] Все RemoteEvent и RemoteFunction в инстанции:")
print("=========================================")
for _, d in ipairs(gun:GetDescendants()) do
    if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
        print("  → " .. d:GetFullName() .. "  [" .. d.ClassName .. "]")
    end
end

print("=========================================")
print("[AXIOM Inspector] Перехватываю FireServer на этих Remote'ах...")
print("[AXIOM Inspector] Теперь СТРЕЛЯЙ ВРУЧНУЮ (ЛКМ в игре).")
print("[AXIOM Inspector] Я запишу ТОЧНЫЕ аргументы, которые игра шлёт.")
print("=========================================")

-- Хук на FireServer этих Remote'ов
local oldNamecall
local mt = getrawmetatable(game)
local setReadonly = (setreadonly or function() end)
setReadonly(mt, false)
oldNamecall = mt.__namecall

local gunRemotes = {}
for _, d in ipairs(gun:GetDescendants()) do
    if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
        gunRemotes[d] = true
    end
end

mt.__namecall = function(self, ...)
    local method = getnamecallmethod()
    if gunRemotes[self] and (method == "FireServer" or method == "InvokeServer") then
        print("[AXIOM Inspector] 🔥 ВЫСТРЕЛ ЗАСЕЧЁН:")
        print("  Remote: " .. self:GetFullName())
        print("  Method: " .. method)
        local args = {...}
        print("  Аргументов: " .. #args)
        for i, v in ipairs(args) do
            local t = typeof(v)
            local vStr = tostring(v)
            if #vStr > 100 then vStr = vStr:sub(1, 100) .. "..." end
            print("    [" .. i .. "] (" .. t .. ") = " .. vStr)
        end
        print("---")
    end
    return oldNamecall(self, ...)
end
setReadonly(mt, true)

print("[AXIOM Inspector] Готов. СТРЕЛЯЙ из ствола вручную — я запишу всё.")
