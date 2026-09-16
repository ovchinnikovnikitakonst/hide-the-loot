local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.config.TreasureConfig)

local TreasureUpgradeService = {}
local levels = {}
local lastRequest = {}
local started = false

function TreasureUpgradeService.getTypeId(player)
	return levels[player] or Config.defaultTypeId
end

function TreasureUpgradeService.start(economyService, remote, shopService)
	if started then return end
	started = true
	local function addPlayer(player)
		if player.Parent ~= Players or levels[player] then return end
		levels[player] = Config.defaultTypeId
		player:SetAttribute("TreasureUpgradeTypeId", levels[player])
	end
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player)
		levels[player] = nil
		lastRequest[player] = nil
	end)
	for _, player in Players:GetPlayers() do addPlayer(player) end
	remote.OnServerEvent:Connect(function(player, sign)
		if not levels[player] then return end
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < 1 then
			remote:FireClient(player, false, "Подожди секунду перед следующей покупкой")
			return
		end
		lastRequest[player] = now
		if not shopService.canUse(player, sign) then
			remote:FireClient(player, false, "Подойди к табличке на своём участке")
			return
		end
		local current = Config.types[levels[player]]
		if not current.nextTypeId then
			remote:FireClient(player, false, "Достигнута максимальная редкость")
			return
		end
		-- No yields between spending and granting the next level.
		if not economyService.trySpendCoins(player, current.upgradePrice, "treasure_upgrade") then
			remote:FireClient(player, false, "Недостаточно Coins")
			return
		end
		levels[player] = current.nextTypeId
		player:SetAttribute("TreasureUpgradeTypeId", levels[player])
		remote:FireClient(player, true, "Куплено: " .. Config.types[levels[player]].rarity .. ". Применится к следующему кладу")
	end)
end

return TreasureUpgradeService
