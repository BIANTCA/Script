-- universal.lua
local Universal = {}

function Universal.CreateUniversalTab(Window, Rayfield, Players, RunService)
 local player = Players.LocalPlayer
 local character = player.Character or player.CharacterAdded:Wait()
 local hrp = character:WaitForChild("HumanoidRootPart")

 local UniversalTab = Window:CreateTab("Universal", 4483362458)

 -- ========== STATE VAR ==========
 local noclipConn, wsLoop, jpLoop, brightLoop, highlightActive = nil, nil, nil, nil, false
 local highlightObjects = {}
 local flyConn, flyBV, flyBG, flySpeed = nil, nil, nil, 100
 local cflyConn, cFlying = nil, false

 -- ========== NOCLIP ==========
 local function startNoclip()
  noclipConn = RunService.Stepped:Connect(function()
   local char = player.Character
   if char then
    for _,p in pairs(char:GetDescendants()) do
     if p:IsA("BasePart") then
      p.CanCollide = false
     end
    end
   end
  end)
 end

 local function stopNoclip()
  if noclipConn then noclipConn:Disconnect() noclipConn = nil end
 end

 UniversalTab:CreateToggle({
  Name = "Noclip",
  CurrentValue = false,
  Callback = function(v)
   if v then startNoclip() else stopNoclip() end
  end
 })

 -- ========== WALKSPEED ==========
 UniversalTab:CreateSlider({
  Name = "WalkSpeed",
  Range = {16,300},
  Increment = 5,
  CurrentValue = 16,
  Callback = function(v)
   local char = player.Character
   local hum = char and char:FindFirstChildWhichIsA("Humanoid")
   if hum then
    hum.WalkSpeed = v
    if wsLoop then wsLoop:Disconnect() end
    wsLoop = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
     hum.WalkSpeed = v
    end)
   end
  end
 })

 -- ========== JUMPPOWER ==========
 UniversalTab:CreateSlider({
  Name = "JumpPower",
  Range = {50,300},
  Increment = 10,
  CurrentValue = 50,
  Callback = function(v)
   local char = player.Character
   local hum = char and char:FindFirstChildWhichIsA("Humanoid")
   if hum then
    hum.JumpPower = v
    if jpLoop then jpLoop:Disconnect() end
    jpLoop = hum:GetPropertyChangedSignal("JumpPower"):Connect(function()
     hum.JumpPower = v
    end)
   end
  end
 })

 -- ========== HIGHLIGHT ==========
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

 UniversalTab:CreateToggle({
  Name = "Highlight Players",
  CurrentValue = false,
  Callback = function(v)
   highlightActive = v
   if not v then clearHighlights() end
  end
 })

 -- ========== FLY ==========
 local function stopFly()
  if flyConn then flyConn:Disconnect() flyConn=nil end
  if flyBV then flyBV:Destroy() flyBV=nil end
  if flyBG then flyBG:Destroy() flyBG=nil end
  local char = player.Character
  if char then
   local hum = char:FindFirstChildWhichIsA("Humanoid")
   if hum then hum.PlatformStand = false end
  end
 end

 UniversalTab:CreateSlider({
  Name = "Fly Speed",
  Range = {20,300},
  Increment = 10,
  CurrentValue = flySpeed,
  Callback = function(v)
   flySpeed = v
  end
 })

 UniversalTab:CreateToggle({
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

 -- ========== CFLY ==========
 UniversalTab:CreateToggle({
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
    if cflyConn then cflyConn:Disconnect() cflyConn=nil end
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

 return UniversalTab
end

return Universal
