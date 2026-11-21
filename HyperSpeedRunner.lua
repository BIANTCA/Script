local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local fc = loadstring(game:HttpGet("https://pasteblox.com/raw/87b7cj24z3"))()
local gameName = (fc.getGameName and fc.getGameName()) or "Unknown Game"
local safeName = tostring(gameName):gsub("[^%w%-_ ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
if safeName == "" then safeName = "Default" end
local AutoStep = false
local AutoWin = false
local AutoRebirth = false

Gui = loadstring(game:HttpGet("https://pastebin.com/raw/2BGUWvbd"))()
Gui:Init({
    Name = gameName,
    Subtitle = "Auto farm " .. gameName,
    FolderName = "BulbConfigs",
    FileName = safeName .. ".json"
})

local mainTab = Gui:CreateTab("Main Tab", 4483362458)

mainTab:CreateSection("Auto Farm")
mainTab:CreateToggle({
    Name = "Leveling Up",
    Description = "This is leveling up function",
    CurrentValue = false,
    Flag = "TAutoStep",
    Callback = function(v)
        AutoStep = v
    end
})

mainTab:CreateToggle({
  Name = "Auto Rebirth",
  Description = "This is auto rebirth function",
  CurrentValue = false,
  Flag ="TAutoRebirth",
  Callback = function(v)
   AutoRebirth = v
 end
})

mainTab:CreateToggle({
  Name = "Auto Win",
  Description = "This is auto win function",
  CurrentValue = false,
  Flag ="TAutoWin",
  Callback = function(v)
   AutoWin = v
  end
})

task.spawn(function()
  while true do
   if AutoWin then fc.Teleport({-1.8,5.3,-9076.5}) end
   task.wait(1.5)
   if AutoRebirth then fc.Fire("Remotes.RequestRebirth","free") end
   task.wait(1.5)
  end
end)
 
task.spawn(function()
    while true do
     if AutoStep then
      fc.fire("Remotes.GetStepExperience")
      fc.fire("Remotes.StepTaken",math.huge,false)
     end
     task.wait(0.001)
    end
end)
