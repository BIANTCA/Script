local Universal = {}

function Universal.CreateUniversalTab(Window, Rayfield, Players, RunService)
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Camera = workspace.CurrentCamera or nil


local Lighting = game:GetService("Lighting")
local mouse = player:GetMouse()
local TeleportService = game:GetService("TeleportService")

local ControlTab = Window:CreateTab("Control", 4483362458)
_G.ControlTab = ControlTab
local MainTab = _G.MainTab or Window:CreateTab("Main", 4483362458)
_G.MainTab = MainTab

local autoScript = loadstring(game:HttpGet("https://pastebin.com/raw/Krib3xmR"))()
autoScript.SearchScript(Window, Rayfield, Players, RunService)

--==SESSION TAB==--
ControlTab:CreateSection("Information")
ControlTab:CreateParagraph({
 Title = "Universal Script",
 Content = "This script includes a universal script framework. Some features in MainTab and ControlTab may not be fully compatible with this game and could not work as intended."
})

local function addNotify()
Rayfield:Notify({
 Title = "Clicked",
 Content = "Tab adding...",
 Duration = 1
})
end

--==ControlTab==--
ControlTab:CreateSection({
   Name = "Main Menu",
   Description = "Turn on for always on the feature when u back"
  })
local charTab = loadstring(game:HttpGet("https://pastebin.com/raw/QqHFC3xm"))()
charTab.CreateMainTab(Window, Rayfield, Players, RunService)

ControlTab:CreateToggle({
 Name = "Teleport Tab",
 CurrentValue = false,
 Flag = "TTeleportTab",
 Callback = function(v)
 if v then
  addNotify()
  local TpTab = loadstring(game:HttpGet("https://pastebin.com/raw/7KGnvAjW"))()
  TpTab.CreateTeleportTab(Window)
 end
 end
})

ControlTab:CreateToggle({
 Name = "Combat Tab",
 CurrentValue = false,
 Flag = "TCombatTab",
 Callback = function(v)
 if v then
 Rayfield:ConfirmationAction({
  Title = "⚠️ Risky Feature",
  Message = "Expanding hitboxes may be detected by the game. Do you want to proceed?",
  ConfirmText = "Continue",
  CancelText = "Cancel",
  OnConfirm = function()
  addNotify()
  local CombatTab = loadstring(game:HttpGet("https://pastebin.com/raw/Yx5w8kd4"))()
  CombatTab.CreateCombatTab(Window, Rayfield, Players, RunService, UserInputService, VirtualInputManager)
  end,
  OnCancel = function()
  print("User declined to continue.")
  end
 })
 end
 end
})

ControlTab:CreateToggle({
 Name = "Visual Tab",
 Flag = "TVisualTab",
 CurrentValue = false,
 Callback = function(v)
 if v then
 addNotify()
 local visualTab = loadstring(game:HttpGet("https://pastebin.com/raw/jb37dqiW"))()
 visualTab.CreateVisualTab(Window, Rayfield, Players, RunService)
 end
 end
})

ControlTab:CreateToggle({
 Name = "Tools Tab",
 CurrentValue = false,
 Flag = "TToolsTab",
 Callback = function(v)
 if v then
  addNotify()
  local UtilityTools = loadstring(game:HttpGet("https://pastebin.com/raw/F2sM2itv"))()
  UtilityTools.CreateToolsTab(Window, Rayfield, Players)
 end
 end
})

ControlTab:CreateSection("Remote Tools")
ControlTab:CreateButton({
 Name = "Remote Executor",
 Callback = function()
 addNotify()
 local RemoteLogger = loadstring(game:HttpGet("https://pastebin.com/raw/3C5BF1cc"))()
 RemoteLogger.CreateFireTab(Window, Rayfield)
 end
})

ControlTab:CreateButton({
 Name = "Remote Listener",
 Callback = function()
 addNotify()
 local RemoteListen = loadstring(game:HttpGet("https://pastebin.com/raw/r8JTcWjx"))()
 RemoteListen.CreateListenerTab(Window, Rayfield)
 end
})

ControlTab:CreateButton({
 Name = "Remote Spy",
 Callback = function()
 addNotify()
 local RemoteSpy = loadstring(game:HttpGet("https://pastebin.com/raw/rg3UcaQG"))()
 RemoteSpy.CreateSpyTab(Window, Rayfield)
 end
})

ControlTab:CreateButton({
 Name = "Remote Interceptor",
 Callback = function()
 addNotify()
 local RInterceptor = loadstring(game:HttpGet("https://pastebin.com/raw/VjgLhY6i"))()
 RInterceptor.CreateListenerTab(Window, Rayfield)
 end
})

ControlTab:CreateButton({
 Name = "Console Tab",
 Callback = function()
 addNotify()
 local ConsoleTab = loadstring(game:HttpGet("https://pastebin.com/raw/FWpgnCrW"))()
 ConsoleTab.CreateConsoleTab(Window)
 end
})

ControlTab:CreateSection("Scripts")
ControlTab:CreateButton({
 Name = "Dex/Explorer",
 Callback = function()
 addNotify()
 loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/dex.lua"))()
 end
})

ControlTab:CreateSection("Session Protection")
ControlTab:CreateToggle({
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

ControlTab:CreateToggle({
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

ControlTab:CreateSection("Session control")
ControlTab:CreateButton({
 Name = "Rejoin Server",
 Callback = function()
 TeleportService:Teleport(game.PlaceId, player)
 end
})

ControlTab:CreateButton({
 Name = "Force Respawn",
 Callback = function()
 local char = player.Character
 if char then
 char:BreakJoints()
 end
 end
})

ControlTab:CreateButton({
 Name = "Close & Destroy GUI",
 Callback = function()
 local CoreGui = game:GetService("CoreGui")
 if CoreGui:FindFirstChild("BulbGui") then
 CoreGui.TumblrGui:Destroy()
 end
 end
})

-- add us on roblox vincentplayz9356
local function SetupProximityPrompt(prompt)
    prompt.HoldDuration = 0
end

workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("ProximityPrompt") then
        SetupProximityPrompt(descendant)
    end
end)

for _, prompt in ipairs(workspace:GetDescendants()) do
    if prompt:IsA("ProximityPrompt") then
        SetupProximityPrompt(prompt)
    end
end

loadstring(game:HttpGet("https://pastebin.com/raw/cBX435uR"))()

return {
 MainTab = MainTab,
 ControlTab = ControlTab,
}
end

return Universal
