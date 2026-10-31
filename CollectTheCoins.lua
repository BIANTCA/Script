local Tumblr = loadstring(game:HttpGet('https://pastebin.com/raw/2BGUWvbd'))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Window = Tumblr:Init({
 Name = "Vault Hub",
 Subtitle = "Auto Coin & Deposit",
 FolderName = "TumblrConfigs",
 FileName = "Vault_" .. tostring(game.GameId) .. ".json"
})

local VaultTab = Window:CreateTab("Vault", 4483362458)

local S = {
 Grab = false,
 Deposit = false,
 GrabDelay = 0.3,
 Busy = false,
 AimMode = "Coin",
 GrabKey = Enum.KeyCode.E,
 DepositSpam = 5,
 GrabSpam = 5,
 DefaultChest = nil,
 HeightAbove = 3,
 PressQ = false,
 QInterval = 5,
}
local grabToken, depositToken, qToken = 0, 0, 0
local aimPoint = nil

RunService:BindToRenderStep("VaultAim", Enum.RenderPriority.Camera.Value + 1, function()
 if aimPoint then
  Camera = workspace.CurrentCamera
  Camera.CFrame = CFrame.new(Camera.CFrame.Position, aimPoint)
 end
end)

local function getHRP()
 local char = player.Character
 return char and char:FindFirstChild("HumanoidRootPart")
end

-- hanya MeshPart dengan nama persis "Coin"
local function collectCoins(root, list)
 for _, v in ipairs(root:GetDescendants()) do
  if v.Name == "Coin" and v:IsA("MeshPart") then
   table.insert(list, v)
  end
 end
end

local function getCoins()
 local list = {}

 local vaultCoins = workspace:FindFirstChild("VaultCoins")
 if vaultCoins then
  collectCoins(vaultCoins, list)
 end

 local dungeons = workspace:FindFirstChild("ActiveDungeons")
 if dungeons then
  for _, run in ipairs(dungeons:GetChildren()) do
   if run:IsA("Model") then
    for _, folderName in ipairs({"Treasure", "Secret", "Rooms", "Halls", "Gates"}) do
     local folder = run:FindFirstChild(folderName)
     if folder then
      collectCoins(folder, list)
     end
    end
   end
  end
 end

 return list
end

-- semua DepositChest di workspace
local function getChests()
 local list = {}
 for _, v in ipairs(workspace:GetDescendants()) do
  if v.Name == "DepositChest" and (v:IsA("Model") or v:IsA("BasePart")) then
   table.insert(list, v)
  end
 end
 return list
end

local function chestPosition(chest)
 if not chest or not chest.Parent then return nil end
 if chest:IsA("Model") then
  return chest:GetPivot().Position
 elseif chest:IsA("BasePart") then
  return chest.Position
 end
end

local function pressGrabButton()
 local vp = Camera.ViewportSize
 local cx, cy = vp.X / 2, vp.Y / 2
 pcall(function()
  VirtualInputManager:SendKeyEvent(true, S.GrabKey, false, game)
  task.wait(0.02)
  VirtualInputManager:SendKeyEvent(false, S.GrabKey, false, game)
 end)
 pcall(function()
  VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
  task.wait(0.02)
  VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
 end)
end

local function pressQ()
 pcall(function()
  VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
  task.wait(0.05)
  VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
 end)
end

local function fireGrab(coin)
 local remote = ReplicatedStorage:FindFirstChild("VaultRemotes")
 remote = remote and remote:FindFirstChild("Grab")
 if remote then
  remote:FireServer(coin)
 end
end

local function getBag()
 return player:GetAttribute("VaultBag") or 0
end

local function bagFull()
 local cap = player:GetAttribute("VaultBagCap") or 20
 return cap < 99999 and getBag() >= cap
end

local function bagEmpty()
 return getBag() <= 0 and not player:GetAttribute("VaultBanking")
end

-- spam pickup pada koin yang dituju
local function spamPickup(coin)
 for _ = 1, S.GrabSpam do
  if not S.Grab or not coin or not coin.Parent or bagFull() then
   break
  end
  pcall(fireGrab, coin)
  pressGrabButton()
  task.wait(0.03)
 end
end

local function spamDeposit()
 for _ = 1, S.DepositSpam do
  pcall(function()
   ReplicatedStorage.VaultRemotes.Shop:FireServer("Deposit")
  end)
  task.wait(0.05)
 end
end

-- tahan posisi di chest (while teleport) + spam deposit
-- return true jika coin berkurang / banking berjalan
local function tryChest(chest, timeout)
 local pos = chestPosition(chest)
 if not pos then return false end

 local targetCFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
 local startBag = getBag()
 local startTime = tick()
 local lastSpam = 0

 while tick() - startTime < timeout do
  local hrp = getHRP()
  if hrp then
   hrp.CFrame = targetCFrame
   hrp.AssemblyLinearVelocity = Vector3.zero
  end

  if tick() - lastSpam >= 1.5 then
   lastSpam = tick()
   task.spawn(spamDeposit)
  end

  if getBag() < startBag or player:GetAttribute("VaultBanking") then
   return true
  end

  RunService.Heartbeat:Wait()
 end

 return false
end

local function holdUntilEmpty(chest)
 local pos = chestPosition(chest)
 if not pos then return end

 local targetCFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
 local startTime = tick()
 local lastSpam = 0

 while tick() - startTime < 20 do
  local hrp = getHRP()
  if hrp then
   hrp.CFrame = targetCFrame
   hrp.AssemblyLinearVelocity = Vector3.zero
  end

  if tick() - lastSpam >= 1.5 then
   lastSpam = tick()
   task.spawn(spamDeposit)
  end

  if bagEmpty() then break end

  RunService.Heartbeat:Wait()
 end
end

local function doDeposit()
 if S.Busy then return end

 local chests = getChests()
 local startHRP = getHRP()
 if #chests == 0 or not startHRP then
  Tumblr:Notify({Title = "Deposit", Content = "DepositChest tidak ditemukan", Duration = 2})
  return
 end

 S.Busy = true
 aimPoint = nil

 -- simpan posisi semula
 local backCFrame = startHRP.CFrame

 -- urutan: default dulu, lalu chest lain
 local ordered = {}
 if S.DefaultChest and S.DefaultChest.Parent then
  table.insert(ordered, S.DefaultChest)
 end
 for _, c in ipairs(chests) do
  if c ~= S.DefaultChest then
   table.insert(ordered, c)
  end
 end

 local success = false
 for _, chest in ipairs(ordered) do
  if tryChest(chest, 4) then
   S.DefaultChest = chest
   holdUntilEmpty(chest)
   success = true
   break
  end
 end

 if not success then
  Tumblr:Notify({Title = "Deposit", Content = "Coin tidak berkurang di semua DepositChest", Duration = 3})
 end

 task.wait(0.3)

 -- kembali ke posisi semula
 local hrp = getHRP()
 if hrp then
  hrp.CFrame = backCFrame
  hrp.AssemblyLinearVelocity = Vector3.zero
 end

 task.wait(0.2)
 S.Busy = false
end

VaultTab:CreateSection("Auto Coin Grab")

VaultTab:CreateToggle({
 Name = "Auto Coin Grab",
 Flag = "VaultAutoGrab",
 CurrentValue = false,
 Callback = function(v)
  S.Grab = v
  grabToken += 1
  if not v then
   aimPoint = nil
   return
  end
  local myToken = grabToken
  task.spawn(function()
   while S.Grab and myToken == grabToken do
    if S.Busy or bagFull() or player:GetAttribute("VaultBanking") then
     aimPoint = nil
     task.wait(0.2)
    else
     local hrp = getHRP()
     local coins = getCoins()
     if hrp and #coins > 0 then
      local coin = coins[math.random(1, #coins)]
      if coin and coin.Parent then
       local p = coin.Position

       -- spawn di atas koin
       hrp.CFrame = CFrame.new(p + Vector3.new(0, S.HeightAbove, 0))
       hrp.AssemblyLinearVelocity = Vector3.zero
       task.wait(0.05)

       if S.AimMode == "Feet" then
        aimPoint = hrp.Position - Vector3.new(0, 5, 0)
       else
        aimPoint = p
       end
       task.wait(0.1)

       -- spam pickup
       spamPickup(coin)
      end
     end
     task.wait(S.GrabDelay)
    end
   end
   aimPoint = nil
  end)
 end
})

VaultTab:CreateSlider({
 Name = "Grab Spam",
 Range = {1, 15},
 Increment = 1,
 Suffix = "x",
 Flag = "VaultGrabSpam",
 CurrentValue = 5,
 Callback = function(v) S.GrabSpam = v end
})

VaultTab:CreateDropdown({
 Name = "Aim Mode",
 Options = {"Coin", "Feet"},
 CurrentOption = "Coin",
 Flag = "VaultAimMode",
 Callback = function(option)
  S.AimMode = option
 end
})

VaultTab:CreateSlider({
 Name = "Height Above Coin",
 Range = {1, 10},
 Increment = 1,
 Suffix = " studs",
 Flag = "VaultHeightAbove",
 CurrentValue = 3,
 Callback = function(v) S.HeightAbove = v end
})

VaultTab:CreateSlider({
 Name = "Grab Delay",
 Range = {0.1, 3},
 Increment = 0.1,
 Suffix = " s",
 Flag = "VaultGrabDelay",
 CurrentValue = 0.3,
 Callback = function(v) S.GrabDelay = v end
})

VaultTab:CreateSection("Auto Deposit")

VaultTab:CreateToggle({
 Name = "Auto Deposit (Bag Full)",
 Flag = "VaultAutoDeposit",
 CurrentValue = false,
 Callback = function(v)
  S.Deposit = v
  depositToken += 1
  if not v then return end
  local myToken = depositToken
  task.spawn(function()
   while S.Deposit and myToken == depositToken do
    if not S.Busy and bagFull() then
     doDeposit()
    end
    task.wait(0.3)
   end
  end)
 end
})

VaultTab:CreateSlider({
 Name = "Deposit Spam",
 Range = {1, 10},
 Increment = 1,
 Suffix = "x",
 Flag = "VaultDepositSpam",
 CurrentValue = 5,
 Callback = function(v) S.DepositSpam = v end
})

VaultTab:CreateButton({
 Name = "Deposit Now",
 Interact = "Deposit",
 Callback = function() task.spawn(doDeposit) end
})

VaultTab:CreateSection("Auto Press Q")

VaultTab:CreateToggle({
 Name = "Auto Press Q",
 Flag = "VaultAutoPressQ",
 CurrentValue = false,
 Callback = function(v)
  S.PressQ = v
  qToken += 1
  if not v then return end
  local myToken = qToken
  task.spawn(function()
   while S.PressQ and myToken == qToken do
    local waited = 0
    while waited < S.QInterval and S.PressQ and myToken == qToken do
     task.wait(0.25)
     waited += 0.25
    end
    if S.PressQ and myToken == qToken then
     pressQ()
    end
   end
  end)
 end
})

VaultTab:CreateSlider({
 Name = "Press Q Interval",
 Range = {5, 30},
 Increment = 1,
 Suffix = " s",
 Flag = "VaultQInterval",
 CurrentValue = 5,
 Callback = function(v) S.QInterval = v end
})
