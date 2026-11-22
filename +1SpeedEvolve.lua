if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LP = Players.LocalPlayer

local fc = loadstring(game:HttpGet("https://pasteblox.com/raw/87b7cj24z3"))()
local gameName = (fc.getGameName and fc.getGameName()) or "Unknown Game"

-- ===== SETTINGS =====
-- RAW link of this script (Pastebin/Pasteblox) so it runs automatically after switching worlds.
local SCRIPT_URL = "https://pastebin.com/raw/YOUR_SCRIPT_ID_HERE"
-- Alternative without a link: save the script as a file in your executor and put its name here, e.g. "AutoFarm.lua"
local SCRIPT_FILE = nil
-- Currency used to buy Trails / Auras / Items (relative to the player)
local CASH = "leaderstats.Wins"

-- ===== NUMBER SUFFIXES (K, M, B, T, ...) =====
local SuffixOrder = {
	"", "K", "M", "B", "T", "Qd", "Qn", "Sx", "Sp", "Oc", "No",
	"Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg",
}

local SuffixMult = {}
local SuffixMultLower = {}
for i, s in ipairs(SuffixOrder) do
	local mult = 10 ^ ((i - 1) * 3)
	SuffixMult[s] = mult
	if s ~= "" then SuffixMultLower[s:lower()] = mult end
end

-- "750K Wins Required" -> 750000, "1.5M" -> 1500000, "2,500" -> 2500
-- returns nil if no number is found
local function parseAbbrev(text)
	if text == nil then return nil end
	if type(text) == "number" then return text end
	local s = tostring(text):gsub(",", "")
	local num, suf = s:match("([%d%.]+)(%a*)")
	num = tonumber(num)
	if not num then return nil end
	local mult = SuffixMult[suf] or SuffixMultLower[suf:lower()] or 1
	return num * mult
end

-- ===== USER STATS (always updated) =====
local User = fc.getUser()
local UserWins = 0
local UserRebirth = 0
local UserUpgradeOwned = nil     -- Player.PlayerStats.UpgradeOwned
local UserUpgradeSelected = nil  -- Player.PlayerStats.UpgradeSelected

-- Reads a stat through fc.getValue first, then falls back to the instance itself.
-- parentName: "leaderstats" or "PlayerStats"
local function readStat(path, parentName, fallbackNames)
	local v
	pcall(function() v = fc.getValue(User .. "." .. path) end)
	local n = parseAbbrev(v)
	if n then return n end

	local parent = LP:FindFirstChild(parentName)
	if parent then
		for _, name in ipairs(fallbackNames) do
			local o = parent:FindFirstChild(name)
			if o then
				local ok, num = pcall(fc.getNumber, o)
				if ok and tonumber(num) then return tonumber(num) end
				local p = parseAbbrev(o.Value)
				if p then return p end
			end
		end
	end
	return nil
end

local function refreshStats()
	local w = readStat("leaderstats.Wins", "leaderstats", {"Wins"})
	local r = readStat("leaderstats.Rebirth", "leaderstats", {"Rebirth", "Rebirths"})
	local o = readStat("PlayerStats.UpgradeOwned", "PlayerStats", {"UpgradeOwned"})
	local s = readStat("PlayerStats.UpgradeSelected", "PlayerStats", {"UpgradeSelected"})
	if w then UserWins = w end
	if r then UserRebirth = r end
	if o then UserUpgradeOwned = o end
	if s then UserUpgradeSelected = s end
end

refreshStats()
print(UserWins, UserRebirth, UserUpgradeOwned, UserUpgradeSelected)

task.spawn(function()
	while true do
		pcall(refreshStats)
		task.wait(1)
	end
end)

-- ===== STATE =====
local AutoStep = false
local AutoWin = false
local AutoRebirth = false
local AutoEvo = false
local AutoTrain = false
local AutoBuySteps = false

-- One config file for all worlds (fixed name, not the game name)
local Gui = loadstring(game:HttpGet("https://pastebin.com/raw/2BGUWvbd"))()
Gui:Init({
	Name = gameName,
	Subtitle = "Auto farm " .. gameName,
	FolderName = "BulbConfigs",
	FileName = "AutoFarm.json"
})

local function notify(title, text, dur)
	pcall(function()
		Gui:Notify({Title = title, Content = tostring(text), Duration = dur or 3})
	end)
end

-- ===== DATA =====
local worldPlaceId = {
	World1 = 83569851223739,
	World2 = 107654875426558,
	World3 = 140128707775918,
	World4 = 140544451091543,
	World5 = 139473336308623,
	World6 = 112667591128641,
	World7 = 81297463814585,
}

local worldOrder = {"World1", "World2", "World3", "World4", "World5", "World6", "World7"}

local WorldRebirthMinimal = {
	World1 = 0,
	World2 = 5,
	World3 = 10,
	World4 = 14,
	World5 = 17,
	World6 = 21,
	World7 = 25,
}

local TrailCost = {
	["Orange"] = 250,
	["Green"] = 2500,
	["Blue"] = 25000,
	["Purple"] = 250000,
	["Rainbow"] = 2500000,
	["Galaxy"] = 25000000,
	["Snow"] = 250000000,
	["Fire"] = 2500000000,
	["Star"] = 25000000000,
	["Jupiter"] = 250000000000,
	["Saturn"] = 2500000000000,
	["Sun"] = 25000000000000,
	["Moon"] = 250000000000000,
	["Bubble"] = 2500000000000000,
	["Ghost"] = 2.5e16,
	["Cloud"] = 2.5e17,
	["Storm"] = 2.5e18,
	["Heart"] = 2.5e19,
	["Halo"] = 2.5e20,
	["Black Hole"] = 2.5e21,
	["Earth"] = 2.5e23,
	["DNA"] = 2.5e25,
	["Atom"] = 2.5e27,
	["Plasma"] = 2.5e29,
	["Supernova"] = 2.5e31,
}

local AuraCost = {
	["Yellow"] = 10000,
	["Green"] = 100000,
	["Blue"] = 1000000,
	["Red"] = 10000000,
	["Purple"] = 100000000,
	["Heart"] = 1000000000,
	["Fire"] = 10000000000,
	["Leaf"] = 100000000000,
	["Snow"] = 1000000000000,
	["Electric"] = 10000000000000,
	["Rainbow"] = 100000000000000,
	["Super Saiyan"] = 1000000000000000,
	["Binary"] = 1e16,
	["Shadow"] = 1e17,
	["Wrath"] = 1e18,
	["Crystal Circle"] = 1e19,
	["Gravity Circle"] = 1e20,
	["Psychic Orbs"] = 1e21,
	["Wormhole"] = 1e22,
	["Solar Flare"] = 1e23,
	["Green Flare"] = 1e25,
	["Red Flare"] = 1e27,
	["Blue Flare"] = 1e29,
	["Purple Flare"] = 1e31,
}

local ItemsCost = {
	["Apple"] = 50000000000,
	["Bamboo"] = 500000000000,
	["Yellow Flower"] = 5000000000000,
	["Maple Leaf"] = 50000000000000,
	["Red Mushroom"] = 500000000000000,
	["Snowflake"] = 5000000000000000,
	["Pumpkin"] = 5e16,
	["Blue Wing"] = 5e17,
	["Purple Crystal"] = 5e18,
	["Fire Crystal"] = 5e19,
	["Dragon Scale"] = 5e20,
	["Dragon Tooth"] = 5e21,
	["Lucky Block"] = 5e23,
	["Purple Block"] = 5e25,
	["Rainbow Block"] = 5e27,
	["Galaxy Block"] = 5e29,
	["Golden Apple"] = 5e31,
}

-- ===== WORLD HELPERS =====
local function currentWorld()
	for name, id in pairs(worldPlaceId) do
		if id == game.PlaceId then return name end
	end
	return nil
end

local function getRebirths()
	return UserRebirth
end

-- ===== CHARACTER TELEPORT HELPERS =====
local function getHRP()
	local char = LP.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function moveTo(pos)
	local ok = pcall(function() fc.Teleport({pos.X, pos.Y, pos.Z}) end)
	if not ok then
		local hrp = getHRP()
		if hrp then hrp.CFrame = CFrame.new(pos) end
	end
end

-- ===== AUTO TRAIN (TREADMILLS) =====
local TRAIN_RADIUS = 15

-- Reads the rebirth requirement from RebirthN.BillboardGui.RequirementLabel
-- Fallback: the number N from the RebirthN name
local function readRequirement(model, n)
	local need
	pcall(function()
		local gui = model:FindFirstChild("BillboardGui") or model:FindFirstChild("BillboardGui", true)
		local label = gui and (gui:FindFirstChild("RequirementLabel") or gui:FindFirstChild("RequirementLabel", true))
		if label and label.Text then
			need = parseAbbrev(label.Text:match("[%d%.,]+%a*"))
		end
	end)
	return need or n
end

-- Finds the Treadmill_Cube part inside a treadmill (supports a "Meshes" folder
-- as well as a literal "Meshes/Treadmill_Cube" name)
local function findTreadmillPart(model)
	local found
	local meshes = model:FindFirstChild("Meshes")
	if meshes then
		found = meshes:FindFirstChild("Treadmill_Cube")
	end
	found = found or model:FindFirstChild("Meshes/Treadmill_Cube", true)
	found = found or model:FindFirstChild("Treadmill_Cube", true)
	if found and found:IsA("BasePart") then return found end
	return nil
end

-- Picks the treadmill: the RebirthN with the highest requirement that is still met, otherwise Basic
local function pickTreadmill(rebirth)
	local folder = workspace:FindFirstChild("Treadmills")
	if not folder then return nil end

	local best, bestNeed
	for _, child in ipairs(folder:GetChildren()) do
		local lname = child.Name:lower()
		if not lname:find("robux", 1, true) then
			local n = child.Name:match("^Rebirth(%d+)$")
			if n then
				local need = readRequirement(child, tonumber(n))
				if need <= rebirth and (not bestNeed or need > bestNeed) then
					best, bestNeed = child, need
				end
			end
		end
	end

	if best then return best end
	return folder:FindFirstChild("Basic")
end

local lastTrainName
local function doAutoTrain()
	local model = pickTreadmill(UserRebirth)
	if not model then return end

	local part = findTreadmillPart(model)
	if not part then return end

	local hrp = getHRP()
	if not hrp then return end

	local target = part.Position + Vector3.new(0, part.Size.Y / 2 + 3, 0)

	-- Already near the correct treadmill -> no teleport needed
	if (hrp.Position - target).Magnitude <= TRAIN_RADIUS then
		lastTrainName = model.Name
		return
	end

	if lastTrainName ~= model.Name then
		notify("Auto Train", "Treadmill: " .. model.Name .. " (rebirth " .. UserRebirth .. ")", 2)
		lastTrainName = model.Name
	end

	moveTo(target)
end

-- ===== AUTO BUY STEPS (workspace.UpgradeButtons.N.Touch) =====
-- The next step is always UpgradeOwned + 1 (owned 10 -> buy step 11).
local STEP_MAX = 12
local MAX_FAILED_ATTEMPTS = 3   -- failed purchases before a longer cooldown
local FAILED_COOLDOWN = 10      -- seconds to wait after repeated failures
local buyGen = 0                -- increases on every toggle change, stops old threads
local isBuyingStep = false      -- true while teleporting to buy, other loops pause

-- Reads the cost from Touch.BillboardGui.List.UpgradeLabel.WinsCostLabel
-- Example text: "750K Wins Required"
-- Returns the cost as a number, or nil if it cannot be read
local function readStepCost(touch)
	local cost
	pcall(function()
		local gui = touch:FindFirstChild("BillboardGui") or touch:FindFirstChild("BillboardGui", true)
		local label = gui and gui:FindFirstChild("WinsCostLabel", true)
		if label and label.Text then
			cost = parseAbbrev(label.Text)
		end
	end)
	return cost
end

local function getStepTouch(n)
	local folder = workspace:FindFirstChild("UpgradeButtons")
	local step = folder and folder:FindFirstChild(tostring(n))
	return step and step:FindFirstChild("Touch")
end

-- Steps on the Touch part to trigger the purchase
local function touchStep(touch)
	local hrp = getHRP()
	if not hrp then return end

	local pos = touch.Position + Vector3.new(0, touch.Size.Y / 2 + 3, 0)
	moveTo(pos)
	task.wait(0.3)

	-- Helps trigger Touched if the executor supports it
	if typeof(firetouchinterest) == "function" then
		pcall(function()
			firetouchinterest(hrp, touch, 0)
			task.wait(0.1)
			firetouchinterest(hrp, touch, 1)
		end)
	end
end

local function runAutoBuySteps(gen)
	notify("Auto Buy Steps", "Started, buying the next step after UpgradeOwned", 3)

	local failed = 0
	local warnedNoStat = false
	local announcedStep

	while gen == buyGen and AutoBuySteps do
		local owned = UserUpgradeOwned
		if not owned then
			if not warnedNoStat then
				notify("Auto Buy Steps", "Cannot read PlayerStats.UpgradeOwned, waiting...", 3)
				warnedNoStat = true
			end
			task.wait(1)
		else
			warnedNoStat = false
			local nextStep = owned + 1

			if nextStep > STEP_MAX then
				notify("Auto Buy Steps", "All " .. STEP_MAX .. " steps are owned", 3)
				return
			end

			local touch = getStepTouch(nextStep)
			local cost = touch and readStepCost(touch)

			if announcedStep ~= nextStep then
				announcedStep = nextStep
				failed = 0
			end

			if not touch or not cost then
				-- Step part or cost label not available (yet), try again shortly
				task.wait(1)
			elseif UserWins < cost then
				-- Not enough Wins yet, keep waiting on this step
				task.wait(1)
			else
				-- Enough Wins: pause other loops, remember position, step on Touch, then go back
				isBuyingStep = true
				local hrp = getHRP()
				local back = hrp and hrp.CFrame

				touchStep(touch)
				task.wait(1)

				if back then
					local h = getHRP()
					if h then h.CFrame = back end
				end
				isBuyingStep = false

				-- Let the stats refresh, then check if UpgradeOwned increased
				task.wait(1.2)
				if (UserUpgradeOwned or owned) > owned then
					notify("Auto Buy Steps", "Bought step " .. nextStep, 2)
					failed = 0
				else
					failed = failed + 1
					if failed >= MAX_FAILED_ATTEMPTS then
						notify("Auto Buy Steps", "Step " .. nextStep .. " was not bought after " .. failed .. " tries, retrying in " .. FAILED_COOLDOWN .. "s", 3)
						failed = 0
						task.wait(FAILED_COOLDOWN)
					end
				end
			end
		end
	end

	isBuyingStep = false
end

-- ===== TAB: MAIN =====
local mainTab = Gui:CreateTab("Main Tab", 4483362458)

mainTab:CreateSection("Auto Farm")

mainTab:CreateToggle({
	Name = "Auto Step",
	Description = "Leveling up function",
	CurrentValue = false,
	Flag = "TAutoStep",
	Callback = function(v) AutoStep = v end
})

mainTab:CreateToggle({
	Name = "Auto Rebirth",
	Description = "Automatically rebirths",
	CurrentValue = false,
	Flag = "TAutoRebirth",
	Callback = function(v) AutoRebirth = v end
})

mainTab:CreateToggle({
	Name = "Auto Win",
	Description = "Automatically collects wins",
	CurrentValue = false,
	Flag = "TAutoWin",
	Callback = function(v) AutoWin = v end
})

mainTab:CreateToggle({
	Name = "Auto Train",
	Description = "Teleports to the best treadmill for your rebirths (ignored while Auto Win is on)",
	CurrentValue = false,
	Flag = "TAutoTrain",
	Callback = function(v)
		AutoTrain = v
		if not v then lastTrainName = nil end
	end
})

mainTab:CreateToggle({
	Name = "Auto Evolution",
	Description = "Automatically evolves",
	CurrentValue = false,
	Flag = "TAutoEvo",
	Callback = function(v) AutoEvo = v end
})

mainTab:CreateToggle({
	Name = "Auto Buy Steps",
	Description = "Buys the next upgrade step (UpgradeOwned + 1) by stepping on its Touch part",
	CurrentValue = false,
	Flag = "TAutoBuySteps",
	Callback = function(v)
		AutoBuySteps = v
		buyGen = buyGen + 1
		isBuyingStep = false
		if v then
			local gen = buyGen
			task.spawn(function()
				local ok, err = pcall(runAutoBuySteps, gen)
				if not ok then
					isBuyingStep = false
					notify("Auto Buy Steps error", err, 4)
				end
			end)
		end
	end
})

-- Every feature has its own loop, so they never wait on each other
task.spawn(function()
	while true do
		if AutoWin and not isBuyingStep then fc.Teleport({7353.6, 96.5, 40.6}) end
		task.wait(1.5)
	end
end)

task.spawn(function()
	while true do
		-- Auto Win on -> Auto Train is ignored
		if AutoTrain and not AutoWin and not isBuyingStep then
			pcall(doAutoTrain)
		end
		task.wait(1)
	end
end)

task.spawn(function()
	while true do
		if AutoRebirth then fc.fire("RemoteEventService.RebirthRemoteEvent") end
		task.wait(1.5)
	end
end)

task.spawn(function()
	while true do
		if AutoEvo then fc.fire("RemoteEventService.EvolutionRemoteEvent", {Action = "Evolve"}) end
		task.wait(1.5)
	end
end)

task.spawn(function()
	while true do
		if AutoStep then fc.fire("RemoteEventService.AddSpeedRemoteEvent") end
		task.wait(0.5)
	end
end)

-- ===== AUTO BUY =====
-- continueOnFail: if one item fails (e.g. already owned), continue with the next one
-- retryAfter: delay before a failed item is tried again (seconds)
fc.setupBuyNextItems({
	id = "trail",
	cash = CASH,
	items = TrailCost,
	mode = "fromBottom",
	remote = "RemoteEventService.TrailRemoteEvent",
	args = function(name, price)
		return {{Action = "Buy", TrailName = name}}
	end,
	continueOnFail = true,
	retryAfter = 30,
	interval = 1.5,
})

fc.setupBuyNextItems({
	id = "aura",
	cash = CASH,
	items = AuraCost,
	mode = "fromBottom",
	remote = "RemoteEventService.AuraRemoteEvent",
	args = function(name, price)
		return {{Action = "Buy", AuraName = name}}
	end,
	continueOnFail = true,
	retryAfter = 30,
	interval = 1.5,
})

fc.setupBuyNextItems({
	id = "item",
	cash = CASH,
	items = ItemsCost,
	mode = "fromBottom",
	remote = "RemoteEventService.ItemRemoteEvent",
	args = function(name, price)
		return {{Action = "Buy", ItemName = name}}
	end,
	continueOnFail = true,
	retryAfter = 30,
	interval = 1.5,
})

mainTab:CreateSection("Shop")

mainTab:CreateToggle({
	Name = "Auto Buy Trail",
	Flag = "TAutoTrail",
	CurrentValue = false,
	Callback = function(v) fc.setBuyNextItem("trail", v) end
})

mainTab:CreateToggle({
	Name = "Auto Buy Aura",
	Flag = "TAutoAura",
	CurrentValue = false,
	Callback = function(v) fc.setBuyNextItem("aura", v) end
})

mainTab:CreateToggle({
	Name = "Auto Buy Item",
	Flag = "TAutoItem",
	CurrentValue = false,
	Callback = function(v) fc.setBuyNextItem("item", v) end
})

-- ===== WORLD TELEPORT =====
local TeleportConfig = {
	AutoRun = true,
	CheckRebirth = true,
}
local isTeleporting = false

local function queueScript()
	if not TeleportConfig.AutoRun then return false end
	local queue = queue_on_teleport or (syn and syn.queue_on_teleport)
	if not queue then return false end

	local code
	if SCRIPT_FILE and typeof(isfile) == "function" and isfile(SCRIPT_FILE) then
		code = 'if not game:IsLoaded() then game.Loaded:Wait() end '
			.. 'loadstring(readfile("' .. SCRIPT_FILE .. '"))()'
	elseif SCRIPT_URL and not SCRIPT_URL:find("YOUR_SCRIPT_ID_HERE", 1, true) then
		code = 'if not game:IsLoaded() then game.Loaded:Wait() end '
			.. 'loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()'
	else
		return false
	end

	return (pcall(queue, code))
end

local function doTeleport(id)
	local ok, err = pcall(function()
		TeleportService:Teleport(id, LP)
	end)
	return ok, err
end

local function teleportToWorld(name)
	local id = worldPlaceId[name]
	if not id then
		notify("Teleport", "World not found", 2)
		return
	end

	if isTeleporting then return end

	if id == game.PlaceId then
		notify("Teleport", "You are already in " .. name, 2)
		return
	end

	if TeleportConfig.CheckRebirth then
		local need = WorldRebirthMinimal[name]
		local have = getRebirths()
		if need and have and have < need then
			notify("Requirement not met", name .. " needs " .. need .. " rebirths (you have " .. have .. ")", 4)
			return
		end
	end

	isTeleporting = true
	local queued = queueScript()
	notify("Teleport", "Moving to " .. name
		.. (queued and " (script will run automatically)" or "") .. "...")

	local ok, err = doTeleport(id)
	if not ok then
		isTeleporting = false
		notify("Teleport failed", err, 4)
		return
	end
	task.delay(15, function() isTeleporting = false end)
end

pcall(function()
	TeleportService.TeleportInitFailed:Connect(function(_, result, message)
		isTeleporting = false
		notify("Teleport failed", tostring(result) .. " " .. tostring(message or ""), 4)
	end)
end)

local selectedWorld = currentWorld() or worldOrder[1]
local teleTab = Gui:CreateTab("Teleport", 4483362458)

teleTab:CreateSection("Info")

teleTab:CreateParagraph({
	Title = "Current Location",
	Content = "World: " .. (currentWorld() or "Unknown") .. "\nPlaceId: " .. tostring(game.PlaceId)
})

teleTab:CreateSection("Teleport")

teleTab:CreateDropdown({
	Name = "Select World",
	Description = "Choose the destination world",
	Options = worldOrder,
	CurrentOption = selectedWorld,
	Callback = function(v)
		if type(v) == "string" then selectedWorld = v end
	end
})

teleTab:CreateButton({
	Name = "Teleport To World",
	Description = "Go to the selected world",
	Interact = "Go",
	Callback = function() teleportToWorld(selectedWorld) end
})

teleTab:CreateButton({
	Name = "Next World",
	Description = "Go to the world after the current one",
	Interact = "Next",
	Callback = function()
		local idx = table.find(worldOrder, currentWorld() or "") or 0
		local nextName = worldOrder[idx + 1]
		if nextName then
			teleportToWorld(nextName)
		else
			notify("Teleport", "Already in the last world", 2)
		end
	end
})

teleTab:CreateButton({
	Name = "Previous World",
	Description = "Go to the world before the current one",
	Interact = "Back",
	Callback = function()
		local idx = table.find(worldOrder, currentWorld() or "") or 0
		local prevName = worldOrder[idx - 1]
		if prevName then
			teleportToWorld(prevName)
		else
			notify("Teleport", "Already in the first world", 2)
		end
	end
})

teleTab:CreateSection("Settings")

teleTab:CreateToggle({
	Name = "Auto Run After Teleport",
	Description = "Automatically run this script again in the new world",
	Flag = "TTeleAutoRun",
	CurrentValue = true,
	Callback = function(v) TeleportConfig.AutoRun = v and true or false end
})

teleTab:CreateToggle({
	Name = "Check Rebirth Requirement",
	Description = "Cancel the teleport if you do not have enough rebirths",
	Flag = "TTeleCheckRebirth",
	CurrentValue = true,
	Callback = function(v) TeleportConfig.CheckRebirth = v and true or false end
})

teleTab:CreateSection("Quick Teleport")

for _, name in ipairs(worldOrder) do
	local need = WorldRebirthMinimal[name]
	local desc = (worldPlaceId[name] == game.PlaceId) and "You are here"
		or ("PlaceId " .. worldPlaceId[name] .. (need and (" | Rebirth " .. need) or ""))
	teleTab:CreateButton({
		Name = name,
		Description = desc,
		Interact = "Go",
		Callback = function() teleportToWorld(name) end
	})
end

teleTab:CreateSection("Tools")

teleTab:CreateButton({
	Name = "Copy PlaceId",
	Description = "Copy the PlaceId of the current world",
	Interact = "Copy",
	Callback = function()
		fc.copy(tostring(game.PlaceId))
		notify("Teleport", "PlaceId copied: " .. tostring(game.PlaceId), 2)
	end
})
