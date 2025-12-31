local Universal = {}

function Universal.CreateUniversalTab(Window, Rayfield, Players, RunService)
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local mouse = player:GetMouse()
local TeleportService = game:GetService("TeleportService")

local MainTab = _G.MainTab or Window:CreateTab("Main", 4483362458)
local WaypointTab = Window:CreateTab("Waypoints", 4483362458)
local ToolsTab = Window:CreateTab("Tools", 4483362458)

-- ======== MAIN TAB ========
local noclipConn
local flySpeed = 100
local flying = false
local flyBV, flyBG, flyConn
local cflyConn
local wsLoop, jpLoop
local brightLoop
local highlightActive = false
local highlightObjects = {}

--char main
MainTab:CreateSection("Character Main Menu")
local function startNoclip()
noclipConn = RunService.Stepped:Connect(function()
 local char = player.Character
 if char then
 for _,p in pairs(char:GetDescendants()) do
 if p:IsA("BasePart") then p.CanCollide = false end
 end
 end
 end)
end

local function stopNoclip()
if noclipConn then noclipConn:Disconnect() noclipConn = nil end
end

MainTab:CreateToggle({
 Name = "Noclip",
 CurrentValue = false,
 Callback = function(v)
 if v then startNoclip() else stopNoclip() end
 end
})

local UserInputService = game:GetService("UserInputService")
local infJumpConn

local function startInfiniteJump()
infJumpConn = UserInputService.JumpRequest:Connect(function()
 local char = Players.LocalPlayer.Character
 local hum = char and char:FindFirstChildOfClass("Humanoid")
 if hum then
 hum:ChangeState(Enum.HumanoidStateType.Jumping)
 end
 end)
end

local function stopInfiniteJump()
if infJumpConn then
infJumpConn:Disconnect()
infJumpConn = nil
end
end

MainTab:CreateToggle({
 Name = "Infinite Jump",
 CurrentValue = false,
 Callback = function(v)
 if v then
 startInfiniteJump()
 else
  stopInfiniteJump()
 end
 end
})

local antiRagdollConn

local function startAntiRagdoll()
antiRagdollConn = RunService.Stepped:Connect(function()
 local char = Players.LocalPlayer.Character
 if char then
 for _, obj in ipairs(char:GetDescendants()) do
 if obj:IsA("BallSocketConstraint") or obj:IsA("HingeConstraint") then
 obj:Destroy()
 end
 end
 end
 end)
end

local function stopAntiRagdoll()
if antiRagdollConn then
antiRagdollConn:Disconnect()
antiRagdollConn = nil
end
end

MainTab:CreateToggle({
 Name = "Anti Ragdoll",
 CurrentValue = false,
 Callback = function(v)
 if v then startAntiRagdoll() else stopAntiRagdoll() end
 end
})

local godConn

local function startGodMode()
local function apply(char)
local hum = char:FindFirstChildOfClass("Humanoid")
if hum then
hum.MaxHealth = math.huge
hum.Health = hum.MaxHealth
if godConn then godConn:Disconnect() end
godConn = hum:GetPropertyChangedSignal("Health"):Connect(function()
 if hum.Health < hum.MaxHealth then
 hum.Health = hum.MaxHealth
 end
 end)
end
end

local plr = Players.LocalPlayer
apply(plr.Character)
plr.CharacterAdded:Connect(function(c)
 task.wait(0.1)
 apply(c)
 end)
end

local function stopGodMode()
if godConn then godConn:Disconnect() godConn = nil end
local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
if hum then
hum.MaxHealth = 100
hum.Health = hum.MaxHealth
end
end

MainTab:CreateToggle({
 Name = "God Mode",
 CurrentValue = false,
 Callback = function(v)
 if v then startGodMode() else stopGodMode() end
 end
})

local noFallConn

local function startNoFall()
noFallConn = RunService.Stepped:Connect(function()
 local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
 if hum then
 hum:SetStateEnabled(Enum.HumanoidStateType.Freefall, true)
 hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
 end
 end)
end

local function stopNoFall()
if noFallConn then
noFallConn:Disconnect()
noFallConn = nil
end
end

MainTab:CreateToggle({
 Name = "No Fall Damage",
 CurrentValue = false,
 Callback = function(v)
 if v then startNoFall() else stopNoFall() end
 end
})

local antiStunConn

local function startAntiStun()
antiStunConn = RunService.Stepped:Connect(function()
 local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
 if hum then
 hum.PlatformStand = false
 hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
 end
 end)
end

local function stopAntiStun()
if antiStunConn then
antiStunConn:Disconnect()
antiStunConn = nil
end
end

MainTab:CreateToggle({
 Name = "Anti Stun",
 CurrentValue = false,
 Callback = function(v)
 if v then startAntiStun() else stopAntiStun() end
 end
})

--Movement
MainTab:CreateSection("Movement")
MainTab:CreateSlider({
 Name = "WalkSpeed",
 Range = {
  16,300
 },
 Increment = 5,
 CurrentValue = 16,
 Callback = function(v)
 local hum = player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
 if hum then
 hum.WalkSpeed = v
 if wsLoop then wsLoop:Disconnect() end
 wsLoop = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
  hum.WalkSpeed = v
  end)
 end
 end
})

MainTab:CreateSlider({
 Name = "JumpPower",
 Range = {
  50,300
 },
 Increment = 10,
 CurrentValue = 50,
 Callback = function(v)
 local hum = player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
 if hum then
 hum.JumpPower = v
 if jpLoop then jpLoop:Disconnect() end
 jpLoop = hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
  hum.JumpPower = v
  end)
 end
 end
})

local airControlConn
local airControlForce = 100

local function startAirControl()
airControlConn = RunService.RenderStepped:Connect(function()
 local char = Players.LocalPlayer.Character
 local hum = char and char:FindFirstChildOfClass("Humanoid")
 local root = char and char:FindFirstChild("HumanoidRootPart")
 if hum and root and hum:GetState() == Enum.HumanoidStateType.Freefall then
 local moveDir = hum.MoveDirection
 if moveDir.Magnitude > 0 then
 root.Velocity = root.Velocity + moveDir * (airControlForce * RunService.RenderStepped:Wait())
 end
 end
 end)
end

local function stopAirControl()
if airControlConn then
airControlConn:Disconnect()
airControlConn = nil
end
end

MainTab:CreateToggle({
 Name = "Air Control",
 CurrentValue = false,
 Callback = function(v)
 if v then startAirControl() else stopAirControl() end
 end
})

local climbConn
local climbSpeed = 25

local function startClimbAnywhere()
climbConn = RunService.Heartbeat:Connect(function()
 local plr = Players.LocalPlayer
 local char = plr.Character
 local root = char and char:FindFirstChild("HumanoidRootPart")
 local hum = char and char:FindFirstChildOfClass("Humanoid")
 if not root or not hum then return end

 local ray = Ray.new(root.Position, root.CFrame.LookVector * 3)
 local hit = workspace:FindPartOnRay(ray, char)
 if hit then
 local move = hum.MoveDirection
 if move.Magnitude > 0 then
 root.Velocity = Vector3.new(0, climbSpeed, 0)
 end
 end
 end)
end

local function stopClimbAnywhere()
if climbConn then
climbConn:Disconnect()
climbConn = nil
end
end

MainTab:CreateToggle({
 Name = "Climb Anywhere",
 CurrentValue = false,
 Callback = function(v)
 if v then startClimbAnywhere() else stopClimbAnywhere() end
 end
})

local alignConn

local function startAutoAlign()
alignConn = RunService.RenderStepped:Connect(function()
 local plr = Players.LocalPlayer
 local char = plr.Character
 local root = char and char:FindFirstChild("HumanoidRootPart")
 if not root then return end

 local ray = Ray.new(root.Position, Vector3.new(0, -5, 0))
 local hit, pos, normal = workspace:FindPartOnRay(ray, char)
 if hit and normal then
 local right = root.CFrame.RightVector
 local forward = root.CFrame.LookVector
 local newCFrame = CFrame.fromMatrix(pos, right, normal, -forward)
 root.CFrame = CFrame.new(root.Position, root.Position + forward) * CFrame.Angles(0, 0, 0)
 end
 end)
end

local function stopAutoAlign()
if alignConn then
alignConn:Disconnect()
alignConn = nil
end
end

MainTab:CreateToggle({
 Name = "Auto Align to Ground",
 CurrentValue = false,
 Callback = function(v)
 if v then startAutoAlign() else stopAutoAlign() end
 end
})

--Visual
MainTab:CreateSection("Visual")
local function loopfullbright()
if brightLoop then brightLoop:Disconnect() end
brightLoop = RunService.RenderStepped:Connect(function()
 Lighting.Brightness = 2
 Lighting.ClockTime = 14
 Lighting.FogEnd = 1e5
 Lighting.GlobalShadows = false
 Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
 end)
end

local function unloopfullbright()
if brightLoop then brightLoop:Disconnect() brightLoop = nil end
end

MainTab:CreateToggle({
 Name = "Fullbright",
 CurrentValue = false,
 Callback = function(v)
 if v then loopfullbright() else unloopfullbright() end
 end
})

local function clearHighlights()
for _,h in pairs(highlightObjects) do
if h then h:Destroy() end
end
highlightObjects = {}
end

local function getTeamColor(plr)
if not plr.Team or not player.Team then
return Color3.fromRGB(255,255,255)
end
if plr.Team == player.Team then
return Color3.fromRGB(0,170,255)
else
 return Color3.fromRGB(255,60,60)
end
end

RunService.RenderStepped:Connect(function()
 if not highlightActive then
 clearHighlights()
 return
 end

 for _,plr in pairs(Players:GetPlayers()) do
 if plr ~= player and plr.Character then
 local h = highlightObjects[plr]
 if not h then
 h = Instance.new("Highlight")
 h.FillTransparency = 0.25
 h.OutlineTransparency = 0
 h.Parent = plr.Character
 highlightObjects[plr] = h
 end
 local col = getTeamColor(plr)
 h.FillColor = col
 h.OutlineColor = col
 end
 end
 end)

MainTab:CreateToggle({
 Name = "Highlight Players",
 CurrentValue = false,
 Callback = function(v)
 highlightActive = v
 if not v then clearHighlights() end
 end
})

local tracerActive = false
local tracerDrawings = {}

local function clearTracers()
for _, d in pairs(tracerDrawings) do
if d then d:Remove() end
end
tracerDrawings = {}
end

RunService.RenderStepped:Connect(function()
 if not tracerActive then
 clearTracers()
 return
 end

 local camera = workspace.CurrentCamera
 for _, plr in pairs(Players:GetPlayers()) do
 if plr ~= Players.LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
 local hrp = plr.Character.HumanoidRootPart
 local pos, onScreen = camera:WorldToViewportPoint(hrp.Position)
 if onScreen then
 local line = tracerDrawings[plr] or Drawing.new("Line")
 line.Visible = true
 line.From = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
 line.To = Vector2.new(pos.X, pos.Y)
 line.Color = Color3.fromRGB(255, 255, 255)
 line.Thickness = 1.5
 line.Transparency = 0.8
 tracerDrawings[plr] = line
 else
  if tracerDrawings[plr] then tracerDrawings[plr].Visible = false end
 end
 end
 end
 end)

MainTab:CreateToggle({
 Name = "Tracers",
 CurrentValue = false,
 Callback = function(v)
 tracerActive = v
 if not v then clearTracers() end
 end
})

local distanceActive = false
local distanceLabels = {}

local function clearDistanceLabels()
for _, label in pairs(distanceLabels) do
if label then label:Destroy() end
end
distanceLabels = {}
end

RunService.RenderStepped:Connect(function()
 if not distanceActive then
 clearDistanceLabels()
 return
 end

 local plr = Players.LocalPlayer
 local cam = workspace.CurrentCamera
 local char = plr.Character
 local hrp = char and char:FindFirstChild("HumanoidRootPart")

 if not hrp then return end

 for _, target in pairs(Players:GetPlayers()) do
 if target ~= plr and target.Character and target.Character:FindFirstChild("Head") then
 local head = target.Character.Head
 local dist = (head.Position - hrp.Position).Magnitude

 local label = distanceLabels[target]
 if not label then
 label = Instance.new("BillboardGui")
 label.Size = UDim2.new(0, 100, 0, 20)
 label.Adornee = head
 label.AlwaysOnTop = true
 label.Name = "DistanceLabel"
 local text = Instance.new("TextLabel", label)
 text.Size = UDim2.new(1, 0, 1, 0)
 text.BackgroundTransparency = 1
 text.TextColor3 = Color3.fromRGB(255, 255, 255)
 text.TextStrokeTransparency = 0
 text.Font = Enum.Font.SourceSansBold
 text.TextScaled = true
 distanceLabels[target] = label
 label.Parent = head
 end
 label.TextLabel.Text = string.format("[%.1f]", dist)
 end
 end
 end)

MainTab:CreateToggle({
 Name = "Distance Labels",
 CurrentValue = false,
 Callback = function(v)
 distanceActive = v
 if not v then clearDistanceLabels() end
 end
})

local outlineActive = false
local outlinedParts = {}

local function clearOutlineWorld()
for _, h in pairs(outlinedParts) do
if h then h:Destroy() end
end
outlinedParts = {}
end

local function applyOutlineWorld()
clearOutlineWorld()
for _, obj in pairs(workspace:GetDescendants()) do
if obj:IsA("BasePart") and not obj:IsDescendantOf(Players.LocalPlayer.Character) then
local h = Instance.new("Highlight")
h.FillTransparency = 1
h.OutlineTransparency = 0
h.OutlineColor = Color3.fromRGB(0, 255, 255)
h.Parent = obj
table.insert(outlinedParts, h)
end
end
end

MainTab:CreateToggle({
 Name = "Outline World",
 CurrentValue = false,
 Callback = function(v)
 outlineActive = v
 if v then applyOutlineWorld() else clearOutlineWorld() end
 end
})

MainTab:CreateSection("Fly menu")
local function stopFly()
if flyConn then flyConn:Disconnect() flyConn = nil end
if flyBV then flyBV:Destroy() flyBV = nil end
if flyBG then flyBG:Destroy() flyBG = nil end
local hum = player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
if hum then hum.PlatformStand = false end
flying = false
end

MainTab:CreateSlider({
 Name = "Fly Speed",
 Range = {
  20,300
 },
 Increment = 10,
 CurrentValue = flySpeed,
 Callback = function(v)
 flySpeed = v
 end
})

MainTab:CreateToggle({
 Name = "Fly (Mobile)",
 CurrentValue = false,
 Callback = function(v)
 if v then
 local char = player.Character or player.CharacterAdded:Wait()
 local root = char:WaitForChild("HumanoidRootPart")
 local hum = char:FindFirstChildWhichIsA("Humanoid")
 hum.PlatformStand = true

 flyBV = Instance.new("BodyVelocity")
 flyBV.MaxForce = Vector3.new(9e9,9e9,9e9)
 flyBV.Parent = root

 flyBG = Instance.new("BodyGyro")
 flyBG.MaxTorque = Vector3.new(9e9,9e9,9e9)
 flyBG.P = 1000
 flyBG.D = 50
 flyBG.Parent = root

 local control = require(player.PlayerScripts.PlayerModule.ControlModule)

 flyConn = RunService.RenderStepped:Connect(function()
  local cam = workspace.CurrentCamera
  local move = control:GetMoveVector()
  flyBG.CFrame = cam.CFrame
  flyBV.Velocity = Vector3.new()
  if move.Magnitude > 0 then
  flyBV.Velocity =
  (cam.CFrame.LookVector * -move.Z + cam.CFrame.RightVector * move.X)
  * flySpeed
  end
  end)
 else
  stopFly()
 end
 end
})

MainTab:CreateToggle({
 Name = "CFly",
 CurrentValue = false,
 Callback = function(v)
 if v then
 stopFly()
 local char = player.Character or player.CharacterAdded:Wait()
 local hum = char:FindFirstChildWhichIsA("Humanoid")
 local head = char:WaitForChild("Head")
 hum.PlatformStand = true
 head.Anchored = true

 cflyConn = RunService.Heartbeat:Connect(function(dt)
  local move = hum.MoveDirection * (flySpeed * dt)
  local cam = workspace.CurrentCamera
  local hc = head.CFrame
  local cc = cam.CFrame
  local off = hc:ToObjectSpace(cc).Position
  cc = cc * CFrame.new(-off.X, -off.Y, -off.Z + 1)
  local cp, hp = cc.Position, hc.Position
  local obj = CFrame.new(cp, Vector3.new(hp.X, cp.Y, hp.Z)):VectorToObjectSpace(move)
  head.CFrame = CFrame.new(hp) * (cc - cp) * CFrame.new(obj)
  end)
 cFlying = true
 else
  if cflyConn then cflyConn:Disconnect() cflyConn = nil end
 local char = player.Character
 if char then
 local hum = char:FindFirstChildWhichIsA("Humanoid")
 local head = char:FindFirstChild("Head")
 if hum then hum.PlatformStand = false end
 if head then head.Anchored = false end
 end
 cFlying = false
 end
 end
})

-- ======== TOOLS TAB ========
local deleteTool, bringTool, antiAFKConn, antiHooked, oldNamecall

ToolsTab:CreateSection("Tools utility")
ToolsTab:CreateToggle({
 Name = "Delete Tool",
 CurrentValue = false,
 Callback = function(v)
 if v then
 if deleteTool then return end
 deleteTool = Instance.new("Tool")
 deleteTool.Name = "Delete Tool"
 deleteTool.RequiresHandle = false
 deleteTool.Parent = player.Backpack
 deleteTool.Activated:Connect(function()
  local target = mouse.Target
  if target and not target:IsDescendantOf(player.Character) then
  target:Destroy()
  end
  end)
 else
  if deleteTool then deleteTool:Destroy() deleteTool = nil end
 end
 end
})

ToolsTab:CreateToggle({
 Name = "Bring Tool",
 CurrentValue = false,
 Callback = function(v)
 if v then
 if bringTool then return end
 bringTool = Instance.new("Tool")
 bringTool.Name = "Bring Tool"
 bringTool.RequiresHandle = false
 bringTool.Parent = player.Backpack
 bringTool.Activated:Connect(function()
  local target = mouse.Target
  local char = player.Character
  local root = char and char:FindFirstChild("HumanoidRootPart")
  if root and target and target:IsA("BasePart") and not target:IsDescendantOf(char) then
  target.CFrame = root.CFrame * CFrame.new(0,0,-5)
  end
  end)
 else
  if bringTool then bringTool:Destroy() bringTool = nil end
 end
 end
})

ToolsTab:CreateToggle({
 Name = "Anti AFK",
 CurrentValue = false,
 Callback = function(v)
 if v then
 local VirtualUser = game:GetService("VirtualUser")
 antiAFKConn = player.Idled:Connect(function()
  VirtualUser:CaptureController()
  VirtualUser:ClickButton2(Vector2.new())
  end)
 else
  if antiAFKConn then antiAFKConn:Disconnect() antiAFKConn = nil end
 end
 end
})

ToolsTab:CreateToggle({
 Name = "Anti Kick / Ban",
 CurrentValue = false,
 Callback = function(v)
 if v and not antiHooked then
 antiHooked = true
 oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
  local method = getnamecallmethod()
  if method == "Kick" then return end
  if method == "FireServer" or method == "InvokeServer" then
  local n = tostring(self):lower()
  if n:find("ban") or n:find("kick") then
  return
  end
  end
  return oldNamecall(self, ...)
  end)
 elseif not v and antiHooked then
 antiHooked = false
 end
 end
})

ToolsTab:CreateSection("Session control")
ToolsTab:CreateButton({
 Name = "Rejoin Server",
 Callback = function()
 TeleportService:Teleport(game.PlaceId, player)
 end
})

ToolsTab:CreateButton({
 Name = "Close & Destroy GUI",
 Callback = function()
 if Window then Window:Destroy() end
 end
})

local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local waypoints = {}
local selectedWaypoint = nil

local waypointDropdown
local function countWaypoints()
return #waypoints
end

local function refreshWaypointDropdown()
if waypointDropdown then
waypointDropdown:Destroy()
waypointDropdown = nil
end

local options = {
 "None"
}
for name in pairs(waypoints) do
table.insert(options, name)
end

waypointDropdown = WaypointTab:CreateDropdown({
 Name = "Waypoint List",
 Options = options,
 CurrentOption = selectedWaypoint or "None",
 Callback = function(option)
 if typeof(option) == "table" then
 option = option[1]
 end
 selectedWaypoint = (option ~= "None") and option or nil
 end
})

task.defer(function()
 if selectedWaypoint and waypoints[selectedWaypoint] then
 waypointDropdown:Set(selectedWaypoint)
 else
  waypointDropdown:Set("None")
 selectedWaypoint = nil
 end
 end)
end

local function getHumanoidRootPart()
local character = player.Character or player.CharacterAdded:Wait()
return character:FindFirstChild("HumanoidRootPart")
end

WaypointTab:CreateButton({
 Name = "Add Current Location",
 Callback = function()
 local hrp = getHumanoidRootPart()
 if not hrp then
 Rayfield:Notify({
  Title = "Error",
  Content = "Character or HumanoidRootPart not found!",
  Duration = 3
 })
 return
 end

 local name = "Waypoint_" .. tostring(countWaypoints() + 1)
 waypoints[name] = hrp.CFrame
 selectedWaypoint = name

 refreshWaypointDropdown()

 Rayfield:Notify({
  Title = "Waypoint Added",
  Content = "Added: " .. name,
  Duration = 2
 })
 end
})

WaypointTab:CreateButton({
 Name = "Teleport to Selected",
 Callback = function()
 if not selectedWaypoint or not waypoints[selectedWaypoint] then
 Rayfield:Notify({
  Title = "Error",
  Content = "No waypoint selected!",
  Duration = 3
 })
 return
 end

 local hrp = getHumanoidRootPart()
 if not hrp then
 Rayfield:Notify({
  Title = "Error",
  Content = "Character or HumanoidRootPart not found!",
  Duration = 3
 })
 return
 end

 local tween = TweenService:Create(
  hrp,
  TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
  {
   CFrame = waypoints[selectedWaypoint]}
 )
 tween:Play()

 Rayfield:Notify({
  Title = "Teleporting",
  Content = "Teleporting to " .. selectedWaypoint,
  Duration = 2
 })
 end
})

WaypointTab:CreateButton({
 Name = "Delete Selected Waypoint",
 Callback = function()
 if not selectedWaypoint or not waypoints[selectedWaypoint] then
 Rayfield:Notify({
  Title = "Error",
  Content = "No waypoint selected to delete!",
  Duration = 3
 })
 return
 end

 waypoints[selectedWaypoint] = nil
 selectedWaypoint = nil
 refreshWaypointDropdown()

 Rayfield:Notify({
  Title = "Deleted",
  Content = "Waypoint removed successfully",
  Duration = 2
 })
 end
})
refreshWaypointDropdown()

return {
 MainTab = MainTab,
 ToolsTab = ToolsTab,
 WaypointTab = WaypointTab
}
end

return Universal
