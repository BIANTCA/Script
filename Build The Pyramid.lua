local Tumblr = loadstring(game:HttpGet("https://pastebin.com/raw/ECe9auLu"))()

local Window = Tumblr:Init({
 Name = "Build a Pyramid",
 Subtitle = "By Bulb",
 FolderName = "TumblrConfigs",
 FileName = tostring(game.GameId) .. ".json"
})

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local REMOTE_PATH = {
 "Packages", "_Index", "sleitnick_knit@1.7.0", "knit",
 "Services", "BlockService", "RF", "Pickup"
}

local REGION_PATH = {
 "Regions", "Region:Quarry"
}

local PICKUP_AMOUNT = 1
local MAX_CONCURRENT = 10

local BLOCKED_DELAY = 0.2   -- jeda saat gameplay diblokir / tas penuh
local REJECTED_DELAY = 0.15 -- jeda jika server menolak (return false)
local ERROR_DELAY = 1       -- jeda jika terjadi error

-- Auto Refill
local REFILL_AT_CARRIED = 0                 -- setelah kembali, refill lagi saat isi tas <= angka ini
local QUARRY_OFFSET = Vector3.new(0, 5, 0)  -- offset teleport dari titik tengah Region:Quarry
local REFILL_TIMEOUT = 120                  -- batas waktu mengisi tas (detik), lalu tetap kembali

-- Auto Place (klik = tekan lalu lepas tombol Place milik game)
local PLACE_HOLD_TIME = 0.1  -- lama "tahan" per klik (detik)
local PLACE_INTERVAL = 0.05  -- jeda antar klik (detik)

local function findChild(parent, name)
 if not parent then return nil end

 local exact = parent:FindFirstChild(name)
 if exact then return exact end

 local lowered = name:lower()

 for _, child in ipairs(parent:GetChildren()) do
  if child.Name:lower() == lowered then
   return child
  end
 end

 return nil
end

local function resolve(root, path)
 local current = root

 for _, name in ipairs(path) do
  current = findChild(current, name)

  if not current then
   return nil
  end
 end

 return current
end

local function notify(title, content)
 Tumblr:Notify({
  Title = title,
  Content = content,
  Duration = 3
 })
end

local MainTab = Window:CreateTab("Main", 4483362458)

--== CACHE REMOTE & REGION ==--
local cachedRemote, cachedRegion

local function getRemote()
 if not (cachedRemote and cachedRemote.Parent) then
  cachedRemote = resolve(ReplicatedStorage, REMOTE_PATH)
 end
 return cachedRemote
end

local function getRegion()
 if not (cachedRegion and cachedRegion.Parent) then
  cachedRegion = resolve(Workspace, REGION_PATH)
 end
 return cachedRegion
end

--== SISA SLOT TAS ==--
local carryTools

local function requireByPath(path)
 local inst = resolve(ReplicatedStorage, path)
 return inst and require(inst)
end

local interactionController
local carryStateModule

local function getInteractionController()
 if interactionController == nil then
  local ok, controller = pcall(function()
   return require(ReplicatedStorage.Packages.Knit).GetController("InteractionController")
  end)
  interactionController = (ok and controller) or false
 end

 return interactionController or nil
end

local function getCarriedCount()
 if carryStateModule == nil then
  local ok, mod = pcall(requireByPath, { "Shared", "Blocks", "CarryState" })
  carryStateModule = (ok and mod) or false
 end

 if carryStateModule then
  local ok, snapshot = pcall(carryStateModule.read, player)
  if ok and type(snapshot) == "table" and type(snapshot.count) == "number" then
   return snapshot.count, "CarryState"
  end
 end

 local controller = getInteractionController()
 local runtime = controller and controller._runtime
 local tracker = runtime and runtime._heldItemTracker

 if tracker and type(tracker.getCarriedCount) == "function" then
  local ok, count = pcall(tracker.getCarriedCount, tracker)
  if ok and type(count) == "number" then
   return count, "HeldItemTracker"
  end
 end

 -- 3) Atribut player
 if carryTools then
  local value = player:GetAttribute(carryTools.carriedAttr)
  if type(value) == "number" then
   return value, "Attribute"
  end
 end

 return nil
end

local function getCarryInfo()
 if carryTools == nil then
  local ok, tools = pcall(function()
   local contracts = requireByPath({ "Shared", "Contracts", "ClientContracts" })
   local carryConfig = requireByPath({ "Shared", "Config", "CarryConfig" })
   local statProgression = requireByPath({ "Shared", "Stats", "StatProgression" })

   if not (contracts and carryConfig and statProgression) then
    return nil
   end

   local attrs = contracts.Attributes.Player
   return {
    carryConfig = carryConfig,
    statProgression = statProgression,
    carriedAttr = type(attrs.CarriedCount) == "string" and attrs.CarriedCount or "CarriedCount",
    levelAttr = attrs.StrengthLevel
   }
  end)

  carryTools = (ok and tools) or false
 end

 if not carryTools then
  return nil
 end

 local carried, source = getCarriedCount()
 if not carried then
  return nil
 end

 local level = player:GetAttribute(carryTools.levelAttr)

 local ok, capacity = pcall(
  carryTools.statProgression.carryCapacityForLevel,
  carryTools.carryConfig.Capacity,
  level
 )

 if not ok or type(capacity) ~= "number" then
  return nil
 end

 return carried, capacity, source
end

local function getFreeSlots()
 local carried, capacity = getCarryInfo()

 if not carried then
  return math.huge
 end

 return capacity - carried
end

local function isGameplayBlocked()
 local controller = getInteractionController()
 return controller and controller._gameplayBlocked == true or false
end

--== AUTO PICKUP ==--
local running = false
local session = 0
local active = 0
local autoPickupToggle

autoPickupToggle = MainTab:CreateToggle({
 Name = "autoPickup + Boost",
 Flag = "TautoPickup",
 CurrentValue = false,

 Callback = function(enabled)
  running = enabled
  session += 1

  if not enabled then
   return
  end

  cachedRemote, cachedRegion = nil, nil
  interactionController = nil
  carryTools = nil
  carryStateModule = nil

  if not getRemote() then
   notify("autoPickup", "Remote Pickup tidak ditemukan")
   autoPickupToggle.Set(false)
   return
  end

  if not getRegion() then
   notify("autoPickup", "Region tidak ditemukan")
   autoPickupToggle.Set(false)
   return
  end

  local mySession = session

  for _ = 1, MAX_CONCURRENT do
   task.spawn(function()
    while running and mySession == session do
     local remote = getRemote()
     local region = getRegion()

     if not (remote and region) then
      task.wait(0.5)
     elseif isGameplayBlocked() or getFreeSlots() - active * PICKUP_AMOUNT <= 0 then
      task.wait(BLOCKED_DELAY)
     else
      active += 1

      local ok, result = pcall(function()
       return remote:InvokeServer(region, PICKUP_AMOUNT)
      end)

      active -= 1

      if not ok then
       warn("[autoPickup] Error:", result)
       task.wait(ERROR_DELAY)
      elseif result == false then
       task.wait(REJECTED_DELAY)
      end
     end
    end
   end)
  end
 end
})

--== AUTO REFILL ==--
local function getRootPart()
 local character = player.Character
 return character and character:FindFirstChild("HumanoidRootPart")
end

local function getQuarryCFrame()
 local region = getRegion()
 if not region then return nil end

 local cf
 if region:IsA("BasePart") then
  cf = region.CFrame
 elseif region:IsA("Model") then
  cf = region:GetPivot()
 else
  local part = region:FindFirstChildWhichIsA("BasePart", true)
  cf = part and part.CFrame
 end

 return cf and CFrame.new(cf.Position + QUARRY_OFFSET)
end

local function teleportTo(cframe)
 local root = getRootPart()
 if not root then return false end

 root.AssemblyLinearVelocity = Vector3.zero
 root.CFrame = cframe
 return true
end

local refillRunning = false
local refillSession = 0
local autoRefillToggle

autoRefillToggle = MainTab:CreateToggle({
 Name = "autoRefill",
 Flag = "TautoRefill",
 CurrentValue = false,

 Callback = function(enabled)
  refillRunning = enabled
  refillSession += 1

  if not enabled then
   return
  end

  carryTools = nil
  carryStateModule = nil

  if not getCarryInfo() then
   notify("autoRefill", "Kapasitas tas tidak bisa dihitung")
   autoRefillToggle.Set(false)
   return
  end

  if not getQuarryCFrame() then
   notify("autoRefill", "Region:Quarry tidak ditemukan")
   autoRefillToggle.Set(false)
   return
  end

  local mySession = refillSession

  local function alive()
   return refillRunning and mySession == refillSession
  end

  task.spawn(function()
   local firstRound = true

   while alive() do
    local carried, capacity = getCarryInfo()
    local startNow = firstRound
    firstRound = false

    local needRefill = carried and carried < capacity
     and (startNow or carried <= REFILL_AT_CARRIED)

    local root = getRootPart()
    local quarryCFrame = getQuarryCFrame()

    if not (needRefill and root and quarryCFrame) then
     task.wait(0.5)
    else
     local home = root.CFrame

     teleportTo(quarryCFrame)
     task.wait(0.3)

     local startedPickup = not running
     if startedPickup then
      autoPickupToggle.Set(true)
     end

     local startedAt = tick()
     while alive() do
      if getFreeSlots() <= 0 then
       break
      end

      if tick() - startedAt >= REFILL_TIMEOUT then
       notify("autoRefill", "Timeout, kembali ke posisi semula")
       break
      end

      task.wait(0.2)
     end

     if startedPickup then
      autoPickupToggle.Set(false)
     end

     teleportTo(home)
    end
   end
  end)
 end
})

--== AUTO PLACE ==--
local function getPlaceContext()
 local ok, ctx = pcall(function()
  local knit = require(ReplicatedStorage.Packages.Knit)
  local controller = knit.GetController("InteractionController")
  local runtime = controller and controller._runtime

  local moduleScript = resolve(player:FindFirstChild("PlayerScripts"), {
   "Utils", "Interaction", "InteractionRuntime"
  })
  local runtimeModule = moduleScript and require(moduleScript)

  if runtime and runtimeModule then
   return { runtime = runtime, module = runtimeModule }
  end
  return nil
 end)

 if ok then
  return ctx
 end
 return nil
end
 -- always put this tag #madeByBulbGui
local placeRunning = false
local placeSession = 0
local autoPlaceToggle

autoPlaceToggle = MainTab:CreateToggle({
 Name = "autoPlace",
 Flag = "TautoPlace",
 CurrentValue = false,

 Callback = function(enabled)
  placeRunning = enabled
  placeSession += 1

  if not enabled then
   return
  end

  local ctx = getPlaceContext()

  if not ctx then
   notify("autoPlace", "InteractionRuntime tidak ditemukan")
   autoPlaceToggle.Set(false)
   return
  end

  local mySession = placeSession

  task.spawn(function()
   while placeRunning and mySession == placeSession do
    pcall(ctx.module.beginPlaceHold, ctx.runtime)
    task.wait(PLACE_HOLD_TIME)
    pcall(ctx.module.endPlaceHold, ctx.runtime)
    task.wait(PLACE_INTERVAL)
   end
  end)
 end
})

--== UTILITY ==--
MainTab:CreateButton({
 Name = "GetRemainingCapacity",
 Callback = function()
  local Remote = ReplicatedStorage
   .Packages
   ._Index["sleitnick_knit@1.7.0"]
   .knit.Services.PyramidService.RF.GetRemainingCapacity

  local Success, Result = pcall(function()
   return Remote:InvokeServer()
  end)

  if Success then
   Tumblr:Notify({
    Title = "GetRemainingCapacity",
    Content = tostring(Result),
    Duration = 5
   })
  else
   warn("[GetRemainingCapacity]", Result)
  end
 end
})
