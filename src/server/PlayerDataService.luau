local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DATASTORE_NAME = "PlayerData_v1"
local SCHEMA_VERSION = 1
local AUTOSAVE_INTERVAL = 120
local MAX_RETRIES = 3
local DEFAULT_DATA = table.freeze({
	schemaVersion = SCHEMA_VERSION,
	coins = 100000,
	explorerLicenseLevel = 1,
	plotLevel = 1,
})

local dataLoaded = Instance.new("BindableEvent")
local PlayerDataService = { DataLoaded = dataLoaded.Event }
local store
local storeError
local profiles = {}
local started = false

local function copyDefaults()
	return {
		schemaVersion = DEFAULT_DATA.schemaVersion,
		coins = DEFAULT_DATA.coins,
		explorerLicenseLevel = DEFAULT_DATA.explorerLicenseLevel,
		plotLevel = DEFAULT_DATA.plotLevel,
	}
end

local function sanitize(raw)
	local data = copyDefaults()
	if type(raw) ~= "table" then return data end
	if type(raw.coins) == "number" and raw.coins >= 0 and raw.coins % 1 == 0 then
		data.coins = math.min(raw.coins, 9007199254740991)
	end
	if type(raw.explorerLicenseLevel) == "number" and raw.explorerLicenseLevel % 1 == 0 then
		data.explorerLicenseLevel = math.clamp(raw.explorerLicenseLevel, 1, 6)
	end
	if type(raw.plotLevel) == "number" and raw.plotLevel % 1 == 0 then
		data.plotLevel = math.clamp(raw.plotLevel, 1, 6)
	end
	return data
end

local function snapshot(profile)
	return {
		schemaVersion = SCHEMA_VERSION,
		coins = profile.data.coins,
		explorerLicenseLevel = profile.data.explorerLicenseLevel,
		plotLevel = profile.data.plotLevel,
	}
end

local function loadPlayer(player)
	if profiles[player] or player.Parent ~= Players then return end
	local key = "player_" .. player.UserId
	local loadedData
	local loadSucceeded = false
	local lastError = storeError
	if store then
		for attempt = 1, MAX_RETRIES do
			local success, result = pcall(function()
				return store:GetAsync(key)
			end)
			if success then
				loadedData = result
				loadSucceeded = true
				break
			end
			lastError = result
			if attempt < MAX_RETRIES then task.wait(2 ^ (attempt - 1)) end
		end
	end
	if player.Parent ~= Players then return end
	profiles[player] = {
		data = sanitize(loadedData),
		dirty = false,
		revision = 0,
		canSave = loadSucceeded,
		saving = false,
	}
	player:SetAttribute("PlayerDataLoaded", true)
	player:SetAttribute("PlayerDataLoadFailed", not loadSucceeded)
	if not loadSucceeded then
		warn(string.format("Player data could not be loaded for %s; using unsaved session defaults: %s", player.Name, tostring(lastError)))
	end
	dataLoaded:Fire(player)
end

function PlayerDataService.isLoaded(player)
	return profiles[player] ~= nil
end

function PlayerDataService.getValue(player, key)
	local profile = profiles[player]
	return profile and profile.data[key]
end

function PlayerDataService.setValue(player, key, value)
	local profile = profiles[player]
	if not profile or profile.data[key] == nil then return false end
	profile.data[key] = value
	profile.dirty = true
	profile.revision += 1
	return true
end

function PlayerDataService.savePlayer(player, waitForActiveSave)
	local profile = profiles[player]
	if not profile or not profile.canSave then return false end
	if waitForActiveSave and profile.saving then
		local deadline = os.clock() + 10
		while profile.saving and os.clock() < deadline do task.wait(0.1) end
	end
	if profiles[player] ~= profile or profile.saving or not profile.dirty then return false end
	profile.saving = true
	local key = "player_" .. player.UserId
	local data = snapshot(profile)
	local savingRevision = profile.revision
	local saved = false
	local lastError
	for attempt = 1, MAX_RETRIES do
		local success, result = pcall(function()
			return store:UpdateAsync(key, function()
				return data
			end)
		end)
		if success then
			saved = true
			break
		end
		lastError = result
		if attempt < MAX_RETRIES then task.wait(2 ^ (attempt - 1)) end
	end
	profile.saving = false
	if saved then
		if profile.revision == savingRevision then profile.dirty = false end
	else
		warn(string.format("Player data could not be saved for %s: %s", player.Name, tostring(lastError)))
	end
	return saved
end

function PlayerDataService.start()
	if started then return end
	started = true
	if game.GameId == 0 then
		storeError = "Place is not published; persistence is disabled for this session"
	else
		local storeAvailable, result = pcall(function()
			return DataStoreService:GetDataStore(DATASTORE_NAME)
		end)
		if storeAvailable then
			store = result
		else
			storeError = result
		end
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.savePlayer(player, true)
		profiles[player] = nil
	end)
	for _, player in Players:GetPlayers() do task.spawn(loadPlayer, player) end
	task.spawn(function()
		while started do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(PlayerDataService.savePlayer, player)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				PlayerDataService.savePlayer(player, true)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do task.wait(0.1) end
	end)
end

return PlayerDataService
