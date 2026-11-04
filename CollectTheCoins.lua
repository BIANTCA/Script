local Tumblr = loadstring(game:HttpGet('https://pastebin.com/raw/2BGUWvbd'))()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Window = Tumblr:Init({
 Name = "Collect The Coins",
 Subtitle = "Auto Coin & deposti by Bulb",
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

-- Deteksi mode deposit:
-- "Vault" = ada workspace.VaultCoins -> VaultRemotes.Shop
-- "Shop"  = tidak ada VaultCoins (map Rooms) -> Remotes.ShopAction
local function getDepositMode()
 if workspace:FindFirstChild("VaultCoins") then
  return "Vault"
 end
 return "Shop"
end

-- Ada folder Rooms di ActiveDungeons?
local function hasRooms()
 local dungeons = workspace:FindFirstChild("ActiveDungeons")
 if not dungeons then return false end
 for _, run in ipairs(dungeons:GetChildren()) do
  if run:FindFirstChild("Rooms") then
   return true
  end
 end
 return false
end

-- Fitur Rooms aktif hanya jika ada Rooms dan TIDAK ada VaultCoins
local function isRoomsActive()
 return not workspace:FindFirstChild("VaultCoins") and hasRooms()
end

-- Vault: MeshPart "Coin" | Rooms: BasePart "Coin"
local function collectCoins(root, list)
 for _, v in ipairs(root:GetDescendants()) do
  if v.Name == "Coin" and (v:IsA("MeshPart") or (getDepositMode() == "Shop" and v:IsA("BasePart"))) then
   table.insert(list, v)
  end
 end
end

local function coinPosition(obj)
 if not obj or not obj.Parent then return nil end
 if obj:IsA("Model") then
  return obj:GetPivot().Position
 elseif obj:IsA("BasePart") then
  return obj.Position
 end
 return nil
end

local function getCoins()
 local list = {}

 -- Rooms: koin ada di ActiveDungeons.<Run>.Treasure, punya attribute "CoinId"
 if getDepositMode() == "Shop" then
  local dungeons = workspace:FindFirstChild("ActiveDungeons")
  if dungeons then
   for _, run in ipairs(dungeons:GetChildren()) do
    local treasure = run:FindFirstChild("Treasure")
    if treasure then
     for _, v in ipairs(treasure:GetDescendants()) do
      if (v:IsA("BasePart") or v:IsA("Model")) and v:GetAttribute("CoinId") ~= nil then
       table.insert(list, v)
      end
     end
    end
   end
  end
  return list
 end

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

-- DepositChest dicari di mana saja di workspace
local function getChests()
 local list = {}
 for _, v in ipairs(workspace:GetDescendants()) do
  if (v:IsA("Model") or v:IsA("BasePart")) and (v.Name == "DepositChest" or v:GetAttribute("Deposit") ~= nil) then
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
 -- Rooms: Remotes.Collect:FireServer(posisi, coinId, {coinId})
 if getDepositMode() == "Shop" then
  local remotes = ReplicatedStorage:FindFirstChild("Remotes")
  local collect = remotes and remotes:FindFirstChild("Collect")
  local id = coin:GetAttribute("CoinId")
  local pos = coinPosition(coin)
  if collect and id ~= nil and pos then
   collect:FireServer(pos, id, {id})
  end
  return
 end

 -- Vault: VaultRemotes.Grab
 local folder = ReplicatedStorage:FindFirstChild("VaultRemotes")
 local remote = folder and folder:FindFirstChild("Grab")
 if remote then
  remote:FireServer(coin)
 end
end

-- Vault  : VaultBag / VaultBagCap / VaultBanking
-- Rooms  : attribute Bag / BagCap, fallback label RunHud (slots / cap)
local hudSlots, hudCap

local function findHudBag()
 if hudSlots and hudSlots.Parent and hudCap and hudCap.Parent then
  return hudSlots, hudCap
 end
 hudSlots, hudCap = nil, nil

 local gui = player:FindFirstChild("PlayerGui")
 local hud = gui and gui:FindFirstChild("RunHud", true)
 if not hud then return nil end

 for _, f in ipairs(hud:GetChildren()) do
  if f:IsA("Frame") and f.Size.X.Offset == 340 and f.Size.Y.Offset == 140 then
   for _, l in ipairs(f:GetChildren()) do
    if l:IsA("TextLabel") then
     if l.Position.X.Offset == 0 then
      hudCap = l
     elseif l.Position.X.Offset == 168 then
      hudSlots = l
     end
    end
   end
   if hudSlots and hudCap then
    return hudSlots, hudCap
   end
  end
 end
 return nil
end

local function getBag()
 if getDepositMode() == "Vault" then
  return player:GetAttribute("VaultBag") or 0
 end

 local v = player:GetAttribute("Bag")
 if type(v) == "number" then return v end

 local slots = findHudBag()
 return slots and tonumber(slots.Text) or 0
end

local function getBagCap()
 if getDepositMode() == "Vault" then
  return player:GetAttribute("VaultBagCap") or 20
 end

 local v = player:GetAttribute("BagCap")
 if type(v) == "number" then return v end

 local _, cap = findHudBag()
 if cap then
  if cap.Text == "\u{221E}" then return 99999 end
  return tonumber(cap.Text) or 20
 end
 return 20
end

local function isBanking()
 if getDepositMode() == "Vault" then
  return player:GetAttribute("VaultBanking") and true or false
 end
 return false
end

local function bagFull()
 local cap = getBagCap()
 return cap < 99999 and getBag() >= cap
end

local function bagEmpty()
 return getBag() <= 0 and not isBanking()
end

-- spam pickup pada koin yang dituju
local function spamPickup(coin)
 for _ = 1, S.GrabSpam do
  if not S.Grab or not coin or not coin.Parent or bagFull() then
   break
  end
  pcall(fireGrab, coin)
  if getDepositMode() == "Vault" then
   pressGrabButton()
  end
  task.wait(0.03)
 end
end

local function spamDeposit()
 for _ = 1, S.DepositSpam do
  pcall(function()
   if getDepositMode() == "Vault" then
    local vaultRemotes = ReplicatedStorage:FindFirstChild("VaultRemotes")
    local shop = vaultRemotes and vaultRemotes:FindFirstChild("Shop")
    if shop then
     shop:FireServer("Deposit")
    end
   else
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local shopAction = remotes and remotes:FindFirstChild("ShopAction")
    if shopAction then
     shopAction:FireServer("Deposit")
    end
   end
  end)
  task.wait(0.05)
 end
end

-- tahan posisi di chest + spam deposit
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

  if getBag() < startBag or isBanking() then
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

 -- urutan: default dulu, lalu chest lain berdasarkan jarak terdekat
 local origin = startHRP.Position
 table.sort(chests, function(a, b)
  local pa, pb = chestPosition(a), chestPosition(b)
  if not pa then return false end
  if not pb then return true end
  return (pa - origin).Magnitude < (pb - origin).Magnitude
 end)

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
  if tryChest(chest, 5) then
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
    if S.Busy or bagFull() or isBanking() then
     aimPoint = nil
     task.wait(0.2)
    else
     local hrp = getHRP()
     local coins = getCoins()
     if hrp and #coins > 0 then
      local coin = coins[math.random(1, #coins)]
      if coin and coin.Parent then
       local p = coinPosition(coin) or hrp.Position

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

-- ============================================
-- ROOMS ONLY (tampil jika ada Rooms & tidak ada VaultCoins)
-- ============================================
local roomsFrames = {}
local function addRoomsFrame(f)
 if f then
  table.insert(roomsFrames, f)
 end
end

-- Status tas: FULL / EMPTY / FILLING
addRoomsFrame(VaultTab:CreateSection("Rooms Status"))
local statusFrame, _, statusLabel = VaultTab:CreateParagraph({
 Title = "Bag Status",
 Content = "Checking..."
})
addRoomsFrame(statusFrame)

local function bagStatusText()
 if player:GetAttribute("Bag") == nil and not findHudBag() then
  return "Bag tidak terdeteksi (attribute Bag / label RunHud)"
 end

 local bag = getBag()
 local cap = getBagCap()
 local state
 if bagFull() then
  state = "FULL"
 elseif bagEmpty() then
  state = "EMPTY"
 else
  state = "FILLING"
 end
 return string.format("Bag: %d / %s\nStatus: %s", bag, cap < 99999 and tostring(cap) or "Unlimited", state)
end

-- Trophy (EquipTrophy via ShopAction)
local okCfg, TrophyConfig = pcall(function()
 return require(ReplicatedStorage.Shared.TrophyConfig)
end)

if okCfg and type(TrophyConfig) == "table" then
 local HttpService = game:GetService("HttpService")
 local selectedTrophy = "None"
 local displayToId = {}

 local function getUnlockedIds()
  local ok, data = pcall(function()
   return HttpService:JSONDecode(player:GetAttribute("Trophies") or "{}")
  end)
  if not ok or type(data) ~= "table" then
   data = {}
  end

  local ids = {}
  for tier = 1, #TrophyConfig.Tiers do
   for _, board in ipairs(TrophyConfig.Boards) do
    if board.MaxTier and board.MaxTier < tier then
     continue
    end
    local id = TrophyConfig.Id(board.Id, tier)
    local boardKey, boardTier = TrophyConfig.Parse(id)
    if data[boardKey] == boardTier or data[boardKey] == "all" then
     table.insert(ids, id)
    end
   end
  end
  return ids
 end

 local function buildOptions()
  displayToId = {["None"] = "None"}
  local options = {"None"}
  for _, id in ipairs(getUnlockedIds()) do
   local label = TrophyConfig.DisplayName(id)
   if displayToId[label] then
    label = label .. " (" .. id .. ")"
   end
   displayToId[label] = id
   table.insert(options, label)
  end
  return options
 end

 addRoomsFrame(VaultTab:CreateSection("Trophy"))

 local trophyDropdown = VaultTab:CreateDropdown({
  Name = "Select Trophy",
  Options = buildOptions(),
  CurrentOption = "None",
  Callback = function(option)
   selectedTrophy = displayToId[option] or "None"
  end
 })
 addRoomsFrame(trophyDropdown.Frame)

 local equipBtn = VaultTab:CreateButton({
  Name = "Equip Trophy",
  Interact = "Equip",
  Callback = function()
   pcall(function()
    ReplicatedStorage.Remotes.ShopAction:FireServer("EquipTrophy", selectedTrophy)
   end)
  end
 })
 addRoomsFrame(equipBtn.Frame)

 local refreshBtn = VaultTab:CreateButton({
  Name = "Refresh Trophy List",
  Interact = "Refresh",
  Callback = function()
   selectedTrophy = "None"
   trophyDropdown:Refresh(buildOptions(), false)
  end
 })
 addRoomsFrame(refreshBtn.Frame)

 player:GetAttributeChangedSignal("Trophies"):Connect(function()
  trophyDropdown:Refresh(buildOptions(), true)
 end)
end

-- Rooms Tools (ShopAction)
local function shopAction(...)
 local remotes = ReplicatedStorage:FindFirstChild("Remotes")
 local sa = remotes and remotes:FindFirstChild("ShopAction")
 if sa then
  sa:FireServer(...)
 end
end

addRoomsFrame(VaultTab:CreateSection("Rooms Tools"))

local roomIds = {"Shop", "Armory", "Chapel", "DiningHall", "GreatHall", "Library", "ThroneRoom", "TreasureRoom"}
local selectedRoom = "Shop"

local roomDropdown = VaultTab:CreateDropdown({
 Name = "Teleport Room",
 Options = roomIds,
 CurrentOption = "Shop",
 Callback = function(option)
  selectedRoom = option
 end
})
addRoomsFrame(roomDropdown.Frame)

local roomBtn = VaultTab:CreateButton({
 Name = "Teleport To Room",
 Interact = "Go",
 Callback = function()
  shopAction("Teleport", selectedRoom)
 end
})
addRoomsFrame(roomBtn.Frame)

local boostChoice = 1
local boostDropdown = VaultTab:CreateDropdown({
 Name = "Boost Choice",
 Options = {"1", "2", "3"},
 CurrentOption = "1",
 Callback = function(option)
  boostChoice = tonumber(option) or 1
 end
})
addRoomsFrame(boostDropdown.Frame)

local function roomsLoopToggle(name, flag, interval, fn)
 local token = 0
 local t = VaultTab:CreateToggle({
  Name = name,
  Flag = flag,
  CurrentValue = false,
  Callback = function(v)
   token += 1
   if not v then return end
   local my = token
   task.spawn(function()
    while my == token do
     if isRoomsActive() then
      pcall(fn)
     end
     task.wait(interval)
    end
   end)
  end
 })
 addRoomsFrame(t.Frame)
end

roomsLoopToggle("Auto Pick Boost", "RoomsAutoBoost", 1, function()
 shopAction("PickBoost", boostChoice)
end)

roomsLoopToggle("Auto Upgrade Bag", "RoomsAutoBag", 2, function()
 shopAction("BuyRunBag")
end)

roomsLoopToggle("Auto Feed Mimic", "RoomsAutoMimic", 1, function()
 if player:GetAttribute("Pass_Mimic") == true then
  shopAction("FeedMimic")
 end
end)

-- Tampilkan / sembunyikan elemen Rooms + update status tas
task.spawn(function()
 local lastActive = nil
 while true do
  local active = isRoomsActive()
  if active ~= lastActive then
   lastActive = active
   for _, f in ipairs(roomsFrames) do
    f.Visible = active
   end
  end
  if active and statusLabel then
   statusLabel.Text = bagStatusText()
  end
  task.wait(0.5)
 end
end)
