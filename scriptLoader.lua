local Tumblr = loadstring(game:HttpGet('https://pastebin.com/raw/2BGUWvbd'))()
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local CoreGui = game:GetService("CoreGui")

local gameInfo
local ok, info = pcall(function()
	return MarketplaceService:GetProductInfo(game.PlaceId)
end)
gameInfo = (ok and info and info.Name) or "Unknown Game"

local Window = Tumblr:Init({
	Name = "Tumblr Hub",
	Subtitle = "Script loader V4",
	FolderName = "TumblrConfigs",
	FileName = tostring(game.GameId)..".json"
})

local MainTab = Window:CreateTab("Main", 4483362458)
_G.MainTab = MainTab
local ScriptTab = Window:CreateTab("Script", 4483362458)

Window:CreateSettingsParagraph({
	Title = "9 February 2026",
	Content = "NEW: Favorites system! Star your favorite scripts for quick access per game."
})

-- Favorites storage (per GameId)
local favoriteScripts = {}
local favoritesFolderName = "TumblrScriptFavorites"
local favoritesFileName = tostring(game.GameId) .. "_favorites.json"

if not isfolder(favoritesFolderName) then
	makefolder(favoritesFolderName)
end

local favoritesFilePath = favoritesFolderName .. "/" .. favoritesFileName

-- Load favorites
local function loadFavorites()
	if not isfile(favoritesFilePath) then
		return {}
	end
	
	local success, result = pcall(function()
		local data = readfile(favoritesFilePath)
		return HttpService:JSONDecode(data)
	end)
	
	if success and type(result) == "table" then
		return result
	end
	return {}
end

-- Save favorites
local function saveFavorites()
	local success = pcall(function()
		writefile(favoritesFilePath, HttpService:JSONEncode(favoriteScripts))
	end)
	
	if not success then
		warn("[ScriptLoader] Failed to save favorites")
	end
end

-- Check if script is favorited
local function isFavorited(scriptTitle)
	for _, fav in ipairs(favoriteScripts) do
		if fav.title == scriptTitle then
			return true
		end
	end
	return false
end

-- Add to favorites
local function addToFavorites(scriptData)
	if not isFavorited(scriptData.title) then
		table.insert(favoriteScripts, {
			title = scriptData.title,
			script = scriptData.script,
			game = scriptData.game,
			scriptType = scriptData.scriptType,
			isPatched = scriptData.isPatched,
			key = scriptData.key,
			isUniversal = scriptData.isUniversal,
			likeCount = scriptData.likeCount,
			dislikeCount = scriptData.dislikeCount,
			views = scriptData.views
		})
		saveFavorites()
		return true
	end
	return false
end

-- Remove from favorites
local function removeFromFavorites(scriptTitle)
	for i, fav in ipairs(favoriteScripts) do
		if fav.title == scriptTitle then
			table.remove(favoriteScripts, i)
			saveFavorites()
			return true
		end
	end
	return false
end

-- Load saved favorites
favoriteScripts = loadFavorites()

-- CoreGui Snapshot Utils
local function snapshotCoreGui()
	local t = {}
	for _, v in ipairs(CoreGui:GetChildren()) do
		t[v] = true
	end
	return t
end

local function diffCoreGui(before)
	local added = {}
	for _, v in ipairs(CoreGui:GetChildren()) do
		if not before[v] then
			table.insert(added, v)
		end
	end
	return added
end

-- ScriptBlox API
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
			Content = "Search query set to: "..tostring(value),
			Duration = 2
		})
	end
})

local function fetchScripts(query)
	local scripts = {}
	local page = 1
	local hasNext = true
	while hasNext do
		local url = ("https://scriptblox.com/api/script/search?q=%s&page=%d")
			:format(HttpService:UrlEncode(query), page)
		local success, result = pcall(function()
			return game:HttpGet(url)
		end)
		if not success then break end

		local ok, data = pcall(function()
			return HttpService:JSONDecode(result)
		end)
		if not ok or not data.result or not data.result.scripts then break end

		for _, s in ipairs(data.result.scripts) do
			table.insert(scripts, s)
		end

		hasNext = data.result.hasNextPage or false
		page += 1
		task.wait(0.1)
	end
	return scripts
end

local function formatScriptInfo(s)
	local lines = {}
	table.insert(lines, s.scriptType == "Paid" and "💰 Paid Script" or "🆓 Free Script")
	table.insert(lines, s.isPatched and "⚠️ Patched" or "✅ Working")
	table.insert(lines, s.key and "🔒 Requires Key" or "🔓 Keyless")
	table.insert(lines, s.isUniversal and "🌐 Universal" or "🎯 Game-Specific")
	table.insert(lines, "")
	table.insert(lines,
		string.format("👍 %d   👎 %d   👁️ %d",
			s.likeCount or 0,
			s.dislikeCount or 0,
			s.views or 0
		)
	)
	return table.concat(lines, "\n")
end

-- Execute script with key confirmation
local function executeScript(scriptData, onSuccess)
	if scriptData.key then
		Tumblr:ConfirmationAction({
			Title = "🔒 Key System Detected",
			Message = string.format(
				"This script requires a key system.\n\n" ..
				"Script: %s\n\n" ..
				"⚠️ You will need to complete the key system to use this script.\n\n" ..
				"Do you want to continue?",
				scriptData.title or "Unknown"
			),
			ConfirmText = "Continue",
			CancelText = "Cancel",
			OnConfirm = function()
				local before = snapshotCoreGui()
				
				local ok, err = pcall(function()
					loadstring(scriptData.script)()
				end)
				
				if not ok then
					Tumblr:Notify({
						Title = "Error",
						Content = tostring(err),
						Duration = 4
					})
					return
				end
				
				task.wait(0.2)
				local spawnedGuis = diffCoreGui(before)
				
				if onSuccess then
					onSuccess(spawnedGuis)
				end
				
				Tumblr:Notify({
					Title = "Script Executed",
					Content = "Key system script loaded. Complete the key to use.",
					Duration = 3
				})
			end,
			OnCancel = function()
				Tumblr:Notify({
					Title = "Cancelled",
					Content = "Script execution cancelled",
					Duration = 2
				})
			end
		})
	else
		local before = snapshotCoreGui()
		
		local ok, err = pcall(function()
			loadstring(scriptData.script)()
		end)
		
		if not ok then
			Tumblr:Notify({
				Title = "Error",
				Content = tostring(err),
				Duration = 4
			})
			return
		end
		
		task.wait(0.2)
		local spawnedGuis = diffCoreGui(before)
		
		if onSuccess then
			onSuccess(spawnedGuis)
		end
	end
end

-- Create script button
local function createScriptButton(s, isFavorite)
	local gameName = (s.game and s.game.name) or "Unknown Game"
	local title = s.title or "Untitled"
	
	local sectionTitle = isFavorite and "⭐ " .. gameName or gameName
	ScriptTab:CreateSection(sectionTitle)
	
	ScriptTab:CreateParagraph({
		Title = (isFavorite and "⭐ " or "") .. title,
		Content = formatScriptInfo(s)
	})
	
	local running = false
	local spawnedGuis = {}
	
	local runButton = ScriptTab:CreateButton({
		Name = "Run Script",
		Callback = function()
			if not running then
				executeScript(s, function(guis)
					spawnedGuis = guis
					
					if #spawnedGuis == 0 then
						Tumblr:Notify({
							Title = "Notice",
							Content = "Script ran but GUI not detected.",
							Duration = 3
						})
						return
					end
					
					running = true
					runButton:Set("Name", "Delete Script UI")
					
					Tumblr:Notify({
						Title = "Success",
						Content = "Script detected & tracked.",
						Duration = 3
					})
				end)
			else
				for _, gui in ipairs(spawnedGuis) do
					pcall(function()
						gui:Destroy()
					end)
				end
				
				spawnedGuis = {}
				running = false
				runButton:Set("Name", "Run Script")
				
				Tumblr:Notify({
					Title = "Removed",
					Content = "Script UI removed.",
					Duration = 3
				})
			end
		end
	})
	
	local favButton = ScriptTab:CreateButton({
		Name = isFavorited(title) and "★ Remove from Favorites" or "☆ Add to Favorites",
		Callback = function()
			if isFavorited(title) then
				if removeFromFavorites(title) then
					favButton:Set("Name", "☆ Add to Favorites")
					Tumblr:Notify({
						Title = "Removed",
						Content = "Removed from favorites",
						Duration = 2
					})
				end
			else
				if addToFavorites(s) then
					favButton:Set("Name", "★ Remove from Favorites")
					Tumblr:Notify({
						Title = "Added",
						Content = "Added to favorites!",
						Duration = 2
					})
				end
			end
		end
	})
end

-- Show loaded scripts
local function showScripts(scripts)
	for i, s in ipairs(scripts) do
		createScriptButton(s, false)
	end
end

-- Show favorites
local function showFavorites()
	if #favoriteScripts > 0 then
		for _, fav in ipairs(favoriteScripts) do
			createScriptButton(fav, true)
		end
	end
end

ScriptTab:CreateButton({
	Name = "Load Scripts",
	Callback = function()
		local scripts = fetchScripts(currentQuery)
		if scripts and #scripts > 0 then
			Tumblr:Notify({
				Title = "Updated",
				Content = "Loaded "..#scripts.." scripts (including key scripts).",
				Duration = 3
			})
			showScripts(scripts)
		else
			Tumblr:Notify({
				Title = "No Scripts",
				Content = "No scripts found.",
				Duration = 3
			})
		end
	end
})

-- Show favorites on load
showFavorites()

ScriptTab:CreateButton({
	Name = "Clear All Favorites",
	Callback = function()
		if #favoriteScripts == 0 then
			Tumblr:Notify({
				Title = "No Favorites",
				Content = "You don't have any favorites yet",
				Duration = 2
			})
			return
		end
		
		Tumblr:ConfirmationAction({
			Title = "Clear Favorites",
			Message = string.format(
				"Are you sure you want to remove all %d favorite script(s) for this game?",
				#favoriteScripts
			),
			ConfirmText = "Clear All",
			CancelText = "Cancel",
			OnConfirm = function()
				favoriteScripts = {}
				saveFavorites()
				
				-- Refresh Script tab
				for _, child in ipairs(ScriptTab.TabContent:GetChildren()) do
					if child:IsA("Frame") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
						child:Destroy()
					end
				end
				
				Tumblr:Notify({
					Title = "Cleared",
					Content = "All favorites removed",
					Duration = 2
				})
			end
		})
	end
})

-- Load Universal Tab
local Universal = loadstring(game:HttpGet("https://pastebin.com/raw/436invAL"))()
Universal.CreateUniversalTab(
	Window,
	Tumblr,
	game:GetService("Players"),
	game:GetService("RunService")
)
end
end
return false
end

-- Load saved favorites
favoriteScripts = loadFavorites()

-- CoreGui Snapshot Utils
local function snapshotCoreGui()
local t = {}
for _, v in ipairs(CoreGui:GetChildren()) do
t[v] = true
end
return t
end

local function diffCoreGui(before)
local added = {}
for _, v in ipairs(CoreGui:GetChildren()) do
if not before[v] then
table.insert(added, v)
end
end
return added
end

-- ScriptBlox API
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
  Content = "Search query set to: "..tostring(value),
  Duration = 2
 })
 end
})

local function fetchScripts(query)
local scripts = {}
local page = 1
local hasNext = true
while hasNext do
local url = ("https://scriptblox.com/api/script/search?q=%s&page=%d")
:format(HttpService:UrlEncode(query), page)
local success, result = pcall(function()
 return game:HttpGet(url)
 end)
if not success then break end

local ok, data = pcall(function()
 return HttpService:JSONDecode(result)
 end)
if not ok or not data.result or not data.result.scripts then break end

for _, s in ipairs(data.result.scripts) do
table.insert(scripts, s)
end

hasNext = data.result.hasNextPage or false
page += 1
task.wait(0.1)
end
return scripts
end

local function formatScriptInfo(s)
local lines = {}
table.insert(lines, s.scriptType == "Paid" and "💰 Paid Script" or "🆓 Free Script")
table.insert(lines, s.isPatched and "⚠️ Patched" or "✅ Working")
table.insert(lines, s.key and "🔒 Requires Key" or "🔓 Keyless")
table.insert(lines, s.isUniversal and "🌐 Universal" or "🎯 Game-Specific")
table.insert(lines, "")
table.insert(lines,
 string.format("👍 %d   👎 %d   👁️ %d",
  s.likeCount or 0,
  s.dislikeCount or 0,
  s.views or 0
 )
)
return table.concat(lines, "\n")
end

-- Execute script with key confirmation
local function executeScript(scriptData, onSuccess)
if scriptData.key then
Tumblr:ConfirmationAction({
 Title = "🔒 Key System Detected",
 Message = string.format(
  "This script requires a key system.\n"
  "Do you want to continue?",
  scriptData.title or "Unknown"
 ),
 ConfirmText = "Continue",
 CancelText = "Cancel",
 OnConfirm = function()
 local before = snapshotCoreGui()

 local ok, err = pcall(function()
  loadstring(scriptData.script)()
  end)

 if not ok then
 Tumblr:Notify({
  Title = "Error",
  Content = tostring(err),
  Duration = 4
 })
 return
 end

 task.wait(0.2)
 local spawnedGuis = diffCoreGui(before)

 if onSuccess then
 onSuccess(spawnedGuis)
 end

 Tumblr:Notify({
  Title = "Script Executed",
  Content = "Key system script loaded. Complete the key to use.",
  Duration = 3
 })
 end,
 OnCancel = function()
 Tumblr:Notify({
  Title = "Cancelled",
  Content = "Script execution cancelled",
  Duration = 2
 })
 end
})
else
 local before = snapshotCoreGui()

local ok, err = pcall(function()
 loadstring(scriptData.script)()
 end)

if not ok then
Tumblr:Notify({
 Title = "Error",
 Content = tostring(err),
 Duration = 4
})
return
end

task.wait(0.2)
local spawnedGuis = diffCoreGui(before)

if onSuccess then
onSuccess(spawnedGuis)
end
end
end

-- Create script button
local function createScriptButton(s, isFavorite)
local gameName = (s.game and s.game.name) or "Unknown Game"
local title = s.title or "Untitled"

local sectionTitle = isFavorite and "⭐ " .. gameName or gameName
ScriptTab:CreateSection(sectionTitle)

ScriptTab:CreateParagraph({
 Title = (isFavorite and "⭐ " or "") .. title,
 Content = formatScriptInfo(s)
})

local running = false
local spawnedGuis = {}

local runButton = ScriptTab:CreateButton({
 Name = "Run Script",
 Callback = function()
 if not running then
 executeScript(s, function(guis)
  spawnedGuis = guis

  if #spawnedGuis == 0 then
  Tumblr:Notify({
   Title = "Notice",
   Content = "Script ran but GUI not detected.",
   Duration = 3
  })
  return
  end

  running = true
  runButton:Set("Name", "Delete Script UI")

  Tumblr:Notify({
   Title = "Success",
   Content = "Script detected & tracked.",
   Duration = 3
  })
  end)
 else
  for _, gui in ipairs(spawnedGuis) do
 pcall(function()
  gui:Destroy()
  end)
 end

 spawnedGuis = {}
 running = false
 runButton:Set("Name", "Run Script")

 Tumblr:Notify({
  Title = "Removed",
  Content = "Script UI removed.",
  Duration = 3
 })
 end
 end
})

local favButton = ScriptTab:CreateButton({
 Name = isFavorited(title) and "★ Remove from Favorites" or "☆ Add to Favorites",
 Callback = function()
 if isFavorited(title) then
 if removeFromFavorites(title) then
 favButton:Set("Name", "☆ Add to Favorites")
 Tumblr:Notify({
  Title = "Removed",
  Content = "Removed from favorites",
  Duration = 2
 })
 end
 else
  if addToFavorites(s) then
 favButton:Set("Name", "★ Remove from Favorites")
 Tumblr:Notify({
  Title = "Added",
  Content = "Added to favorites!",
  Duration = 2
 })
 end
 end
 end
})
end

-- Show loaded scripts
local function showScripts(scripts)
for i, s in ipairs(scripts) do
createScriptButton(s, false)
end
end

-- Show favorites
local function showFavorites()
if #favoriteScripts > 0 then

for _, fav in ipairs(favoriteScripts) do
createScriptButton(fav, true)
end
end
end

ScriptTab:CreateButton({
 Name = "Load Scripts",
 Callback = function()
 local scripts = fetchScripts(currentQuery)
 if scripts and #scripts > 0 then
 Tumblr:Notify({
  Title = "Updated",
  Content = "Loaded "..#scripts.." scripts (including key scripts).",
  Duration = 3
 })
 showScripts(scripts)
 else
  Tumblr:Notify({
  Title = "No Scripts",
  Content = "No scripts found.",
  Duration = 3
 })
 end
 end
})

-- Show favorites on load
showFavorites()

ScriptTab:CreateButton({
 Name = "Clear All Favorites",
 Callback = function()
 if #favoriteScripts == 0 then
 Tumblr:Notify({
  Title = "No Favorites",
  Content = "You don't have any favorites yet",
  Duration = 2
 })
 return
 end

 Tumblr:ConfirmationAction({
  Title = "Clear Favorites",
  Message = string.format(
   "Are you sure you want to remove all %d favorite script(s) for this game?",
   #favoriteScripts
  ),
  ConfirmText = "Clear All",
  CancelText = "Cancel",
  OnConfirm = function()
  favoriteScripts = {}
  saveFavorites()

-- Refresh Script tab
  for _, child in ipairs(ScriptTab.TabContent:GetChildren()) do
  if child:IsA("Frame") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
  child:Destroy()
  end
  end

  Tumblr:Notify({
   Title = "Cleared",
   Content = "All favorites removed",
   Duration = 2
  })
  end
 })
 end
})

-- Load Universal Tab
local Universal = loadstring(game:HttpGet("https://pastebin.com/raw/436invAL"))()
Universal.CreateUniversalTab(
 Window,
 Tumblr,
 game:GetService("Players"),
 game:GetService("RunService")
)
