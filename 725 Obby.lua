local Players = game:GetService("Players")
local player = Players.LocalPlayer
local hrp = player.Character and player.Character:WaitForChild("HumanoidRootPart")

local stagesFolder = workspace:WaitForChild("Stages")
local leaderstats = player:WaitForChild("leaderstats")
local stageValue = leaderstats:WaitForChild("Stage")

local stages = {}
for _, stage in pairs(stagesFolder:GetChildren()) do
 if tonumber(stage.Name) then
  table.insert(stages, stage)
 end
end
table.sort(stages, function(a, b)
 return tonumber(a.Name) < tonumber(b.Name)
end)

task.spawn(function()
 local currentStage = stageValue.Value
 for i = currentStage + 1, #stages do
  if not hrp or not hrp.Parent then break end
  local targetStage = stages[i]
  if targetStage and targetStage:FindFirstChild("Spawn") then
   hrp.CFrame = targetStage.Spawn.CFrame + Vector3.new(0, 1, 0)
  else
   hrp.CFrame = targetStage:GetPivot() + Vector3.new(0, 1, 0)
  end
  task.wait(0.1)
 end
end)
