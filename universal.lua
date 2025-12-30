-- universal.lua
local Universal = {}

function Universal.CreateUniversalTab(Window, Rayfield, Players, RunService)
 local player = Players.LocalPlayer
 local character = player.Character or player.CharacterAdded:Wait()
 local hrp = character:WaitForChild("HumanoidRootPart")

 local Lighting = game:GetService("Lighting")
 local UserInputService = game:GetService("UserInputService")
 local mouse = player:GetMouse()
 local TeleportService = game:GetService("TeleportService")

 -- Tabs
local MainTab = _G.MainTab or Window:CreateTab("Main", 4483362458)
 local ToolsTab = Window:CreateTab("Tools", 4483362458)

 -- ======== MAIN TAB ========

 -- Character control
 local noclipConn
 local flySpeed = 100
 local flying = false
 local flyBV, flyBG, flyConn
 local cflyConn
 local wsLoop, jpLoop
 local brightLoop
 local highlightActive = false
 local highlightObjects = {}

 -- NOCLIP
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
  if noclipConn then noclipConn:Disconnect() noclipConn=nil end
 end

 MainTab:CreateToggle({
  Name = "Noclip",
  CurrentValue = false,
  Callback = function(v)
   if v then startNoclip() else stopNoclip() end
  end
 })

 -- WALKSPEED
 MainTab:CreateSlider({
  Name = "WalkSpeed",
  Range = {16,300},
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

 -- JUMPPOWER
 MainTab:CreateSlider({
  Name = "JumpPower",
  Range = {50,300},
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

 -- FULLBRIGHT / NO FOG
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
  if brightLoop then brightLoop:Disconnect() brightLoop=nil end
 end

 MainTab:CreateToggle({
  Name = "Fullbright",
  CurrentValue = false,
  Callback = function(v)
   if v then loopfullbright() else unloopfullbright() end
  end
 })

 -- HIGHLIGHT PLAYERS
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

 -- FLY & CFly
 local function stopFly()
  if flyConn then flyConn:Disconnect() flyConn=nil end
  if flyBV then flyBV:Destroy() flyBV=nil end
  if flyBG then flyBG:Destroy() flyBG=nil end
  local hum = player.Character and player.Character:FindFirstChildWhichIsA("Humanoid")
  if hum then hum.PlatformStand = false end
  flying = false
 end

 MainTab:CreateSlider({
  Name = "Fly Speed",
  Range = {20,300},
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

 -- ======== TOOLS TAB ========

 local deleteTool, bringTool, antiAFKConn, antiHooked, oldNamecall

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
    if deleteTool then deleteTool:Destroy() deleteTool=nil end
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
    if bringTool then bringTool:Destroy() bringTool=nil end
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
    if antiAFKConn then antiAFKConn:Disconnect() antiAFKConn=nil end
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

 return {MainTab = MainTab, ToolsTab = ToolsTab}
end

return Universal
