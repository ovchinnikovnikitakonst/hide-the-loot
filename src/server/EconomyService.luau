local Players = game:GetService("Players")

local STARTING_COINS = 100000 -- Temporary test balance; no persistence yet.
local MAX_SAFE_INTEGER = 9007199254740991
local EconomyService = {}
local accounts = {}
local started = false

function EconomyService.getBalance(player)
	local account = accounts[player]
	return account and account.balance
end

function EconomyService.addCoins(player, amount, reason)
	local account = accounts[player]
	if not account or player.Parent ~= Players then return false end
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0
		or amount > MAX_SAFE_INTEGER or amount % 1 ~= 0
		or typeof(reason) ~= "string" or reason == "" then
		return false
	end
	if account.balance > MAX_SAFE_INTEGER - amount then return false end
	-- No yields: the private balance and its display are updated together.
	account.balance += amount
	account.display.Value = account.balance
	account.lastReason = reason
	return true
end

function EconomyService.trySpendCoins(player, amount, reason)
	local account = accounts[player]
	if not account or player.Parent ~= Players then return false end
	if typeof(amount) ~= "number" or amount ~= amount or amount <= 0
		or amount > MAX_SAFE_INTEGER or amount % 1 ~= 0
		or typeof(reason) ~= "string" or reason == "" then return false end
	if account.balance < amount then return false end
	account.balance -= amount
	account.display.Value = account.balance
	account.lastReason = reason
	return true
end

function EconomyService.start()
	if started then return end
	started = true
	local function addPlayer(player)
		if accounts[player] or player.Parent ~= Players then return end
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = STARTING_COINS
		coins.Parent = stats
		accounts[player] = { balance = STARTING_COINS, display = coins }
		stats.Parent = player
	end
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player)
		accounts[player] = nil
	end)
	for _, player in Players:GetPlayers() do addPlayer(player) end
end

return EconomyService
