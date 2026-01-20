local Tumblr = loadstring(game:HttpGet('https://pastebin.com/raw/2BGUWvbd'))()
--local Tumblr = loadstring(game:HttpGet('https://sirius.menu/rayfield'))() -- use this for rayfield GUI
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local gameInfo
local ok, info = pcall(function()
 return MarketplaceService:GetProductInfo(game.PlaceId)
end)
gameInfo = (ok and info and info.Name) or "Unknown Game"

-- local Window = Rayfield:CreateWindow({ Name = "Auto Script",LoadingTitle = "Auto Script",LoadingSubtitle = "By Scriptblox",ConfigurationSaving = {Enabled = false},}) -- use this for Rayfield GUI

local Window = Tumblr:Init({
 Name = "Tumblr Hub",
 Subtitle = "Script loader"
})

local MainTab = Window:CreateTab("Main", 4483362458)
_G.MainTab = MainTab
local ScriptTab = Window:CreateTab("Script", 4483362458)

ScriptTab:CreateSection("ScriptBlox Search")
local currentQuery = gameInfo

ScriptTab:CreateInput({
 Name = "Search Script:",
 PlaceholderText = "Game name",
 RemoveTextAfterFocusLost = false,
 CurrentValue = currentQuery,
 Callback = function(value)
  currentQuery = value
  Tumblr:Notify({
   Title = "Search Updated",
   Content = "Search query set to: " .. tostring(value),
   Duration = 2
  })
 end
})

local function fetchScripts(query)
 local scripts = {}
 local page = 1
 local hasNext = true
 while hasNext do
  local url = ("https://scriptblox.com/api/script/search?q=%s&page=%d"):format(HttpService:UrlEncode(query), page)
  local success, result = pcall(function()
   return game:HttpGet(url)
  end)
  if not success then break end
  local ok, data = pcall(function()
   return HttpService:JSONDecode(result)
  end)
  if not ok or not data.result or not data.result.scripts then break end
  for _, s in ipairs(data.result.scripts) do
   if not s.key then
    table.insert(scripts, s)
   end
  end
  hasNext = data.result.hasNextPage or false
  page += 1
  task.wait(0.1)
 end
 return scripts
end

local function formatScriptInfo(s)
 local lines = {}
 local patched = s.isPatched and "⚠️ Patched (Not Working)" or "✅ Working"
 local typeText = s.scriptType == "Paid" and "💰 Paid Script" or "🆓 Free Script"
 local keyText = s.key and "🔒 Requires Key" or "🔓 Keyless"
 local universalText = s.isUniversal and "🌐 Universal" or "🎯 Game-Specific"
 local stats = string.format("👍 %d   👎 %d   👁️ %d", s.likeCount or 0, s.dislikeCount or 0, s.views or 0)
 table.insert(lines, typeText)
 table.insert(lines, patched)
 table.insert(lines, keyText)
 table.insert(lines, universalText)
 table.insert(lines, "")
 table.insert(lines, stats)
 return table.concat(lines, "\n")
end

local function showScripts(scripts)
 for i, s in ipairs(scripts) do
  local gameName = (s.game and s.game.name) or "Unknown Game"
  ScriptTab:CreateSection(gameName)
  local title = "[" .. i .. "] " .. (s.title or "Untitled")
  ScriptTab:CreateParagraph({
   Title = title,
   Content = formatScriptInfo(s)
  })
  ScriptTab:CreateButton({
   Name = "Run Script",
   Callback = function()
    local code = s.script
    if code and code ~= "" then
     local ok, err = pcall(function()
      loadstring(code)()
     end)
     if ok then
      Tumblr:Notify({
       Title = "Success",
       Content = "Script executed successfully!",
       Duration = 3
      })
     else
      Tumblr:Notify({
       Title = "Error",
       Content = tostring(err),
       Duration = 4
      })
     end
    else
     Tumblr:Notify({
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
  if scripts and #scripts > 0 then
   Tumblr:Notify({
    Title = "Updated",
    Content = "Loaded " .. tostring(#scripts) .. " scripts (no key system).",
    Duration = 3
   })
   showScripts(scripts)
  else
   Tumblr:Notify({
    Title = "No Scripts",
    Content = "No public scripts found without key system.",
    Duration = 3
   })
  end
 end
})

local Universal = loadstring(game:HttpGet("https://pastebin.com/raw/436invAL"))()
Universal.CreateUniversalTab(Window, Tumblr, game:GetService("Players"), game:GetService("RunService"))
