local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
 Name = "Brainrot Army",
 LoadingTitle = "Rayfield Interface",
 LoadingSubtitle = "by GANTJENK",
 ConfigurationSaving = { Enabled = false }
})

local MainTab = Window:CreateTab("Main", 4483362458)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local autoFarm = false
local farmDelay = 0.5

MainTab:CreateSection("Automatically")
MainTab:CreateToggle({
 Name = "Auto Rebirth",
 CurrentValue = false,
 Callback = function(value)
  autoFarm = value
  if value then
   task.spawn(function()
    while autoFarm do
     pcall(function()
      local info = ReplicatedStorage.Remotes.GetSpawnTierInfo:InvokeServer()
      local required = info and info.RequiredCash or 1e180
      ReplicatedStorage.Remotes.CrateDestroyed:FireServer(required)
      ReplicatedStorage.Remotes.Rebirth:FireServer()
     end)
     task.wait(farmDelay)
    end
   end)
  end
 end
})

MainTab:CreateSection("Manually")
MainTab:CreateButton({
 Name = "Inf Money",
 Callback = function()
  pcall(function()
   local info = ReplicatedStorage.Remotes.GetSpawnTierInfo:InvokeServer()
   local required = info and info.RequiredCash or 1e180
   ReplicatedStorage.Remotes.CrateDestroyed:FireServer(required)
  end)
 end
})

MainTab:CreateButton({
 Name = "Upgrade Spawn Tier",
 Callback = function()
  pcall(function()
   ReplicatedStorage.Remotes.UpgradeSpawnTier:FireServer()
  end)
 end
})

MainTab:CreateButton({
 Name = "Rebirth",
 Callback = function()
  pcall(function()
   ReplicatedStorage.Remotes.Rebirth:FireServer()
  end)
 end
})

MainTab:CreateButton({
 Name = "Buy Brainrot",
 Callback = function()
  pcall(function()
   ReplicatedStorage.Remotes.BuyBrainrot:FireServer(3)
  end)
 end
})
