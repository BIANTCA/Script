local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local gameInfo
local ok, info = pcall(function()
 return MarketplaceService:GetProductInfo(game.PlaceId)
 end)
gameInfo = (ok and info and info.Name) or "Unknown Game"

local Window = Rayfield:CreateWindow({
 Name = "Auto Script",
 LoadingTitle = "Auto Script",
 LoadingSubtitle = "By Scriptblox",
 ConfigurationSaving = {
  Enabled = false
 },
})

local MainTab = Window:CreateTab("Main", 4483362458)
_G.MainTab = MainTab
local ScriptTab = Window:CreateTab("Script", 4483362458)

ScriptTab:CreateSection("ScriptBlox Search")
local currentQuery = gameInfo

ScriptTab:CreateInput({
 Name = "Search Script: " .. gameInfo,
 PlaceholderText = "Game name",
 RemoveTextAfterFocusLost = false,
 CurrentValue = currentQuery,
 Callback = function(value)
 currentQuery = value
 Rayfield:Notify({
  Title = "Search Updated",
  Content = "Search query set to: " .. tostring(value),
  Duration = 2
 })
 end
})

local function fetchScripts(query)
local url = "https://scriptblox.com/api/script/search?q=" .. HttpService:UrlEncode(query)
local success, result = pcall(function()
 return game:HttpGet(url)
 end)

if not success then
Rayfield:Notify({
 Title = "Error",
 Content = "Failed to fetch data from ScriptBlox.",
 Duration = 4
})
return nil
end

local ok, data = pcall(function()
 return HttpService:JSONDecode(result)
 end)

if not ok or not data.result or not data.result.scripts then
Rayfield:Notify({
 Title = "Error",
 Content = "Invalid JSON format.",
 Duration = 4
})
return nil
end

return data.result.scripts
end

local function tableToText(tbl)
local content = ""
for k, v in pairs(tbl) do
if k ~= "script" and k ~= "slug" and k ~= "matched" and k ~= "game" and k ~= "lastBump" and k ~= "image" and k ~= "_id" and k ~= "createdAt" then
if typeof(v) == "table" then
content = content .. k .. ":\n"
for subk, subv in pairs(v) do
content = content .. "  " .. tostring(subk) .. ": " .. tostring(subv) .. "\n"
end
else
 content = content .. k .. ": " .. tostring(v) .. "\n"
end
end
end
return content
end

local function showScripts(scripts)
for i, s in ipairs(scripts) do
local gameName = (s.game and s.game.name) or "Unknown Game"
ScriptTab:CreateSection(gameName)

local title = "[" .. i .. "] " .. (s.title or "Untitled")
local paragraphText = tableToText(s)

ScriptTab:CreateParagraph({
 Title = title,
 Content = paragraphText
})

local runScript = false

ScriptTab:CreateButton({
 Name = "Run Script",
 Info = "Start",
 Interact = "Start",
 Callback = function()
 local code = s.script
 if code and code ~= "" then
 local hasKey = s.key == true

 if hasKey then
 if not runScript then
 runScript = true
 Rayfield:Notify({
  Title = "Double Click",
  Content = "Double click for key scripts",
  Duration = 1
 })

 task.delay(0.5, function()
  runScript = false
  end)
 return
 end
 end

 local ok, err = pcall(function()
  loadstring(code)()
  end)

 if ok then
 Rayfield:Notify({
  Title = "Success",
  Content = "Script executed successfully!",
  Duration = 3
 })
 else
  Rayfield:Notify({
  Title = "Error",
  Content = "Failed to execute script: " .. tostring(err),
  Duration = 4
 })
 end

 runScript = false
 else
  Rayfield:Notify({
  Title = "Empty",
  Content = "This script has no runnable code.",
  Duration = 3
 })
 end
 end
})
end
end

ScriptTab:CreateButton({
 Name = "Load Scripts",
 Callback = function()
 local scripts = fetchScripts(currentQuery)
 if scripts then
 Rayfield:Notify({
  Title = "Updated",
  Content = "ScriptBlox data refreshed for: " .. tostring(currentQuery),
  Duration = 3
 })
 showScripts(scripts)
 end
 end
})


local Universal = loadstring(game:HttpGet("https://pastebin.com/raw/436invAL"))()
Universal.CreateUniversalTab(Window, Rayfield, game:GetService("Players"), game:GetService("RunService"))
