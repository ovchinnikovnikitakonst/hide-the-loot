local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.config.MazeConfig)

local TreasureUpgradeService = {}
local levels = {}
local lastRequest = {}
local started = false

function TreasureUpgradeService.getLicenseLevel(player)
	return levels[player] or Config.defaultLicenseLevel
end

function TreasureUpgradeService.start(economyService, remote, shopService, playerDataService)
	if started then return end
	started = true
	local function addPlayer(player)
		if player.Parent ~= Players or levels[player] then return end
		local savedLevel = playerDataService.getValue(player, "explorerLicenseLevel")
		if savedLevel == nil then return end
		levels[player] = math.clamp(savedLevel, 1, #Config.licenseLevels)
		player:SetAttribute("ExplorerLicenseLevel", levels[player])
	end
	playerDataService.DataLoaded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(function(player)
		levels[player] = nil
		lastRequest[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if playerDataService.isLoaded(player) then addPlayer(player) end
	end
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
		local nextLevel = Config.licenseLevels[levels[player] + 1]
		if not nextLevel then
			remote:FireClient(player, false, "Открыты все зоны лабиринта")
			return
		end
		if not economyService.trySpendCoins(player, nextLevel.upgradePrice, "explorer_license") then
			remote:FireClient(player, false, "Недостаточно Coins")
			return
		end
		levels[player] = nextLevel.level
		player:SetAttribute("ExplorerLicenseLevel", levels[player])
		playerDataService.setValue(player, "explorerLicenseLevel", levels[player])
		remote:FireClient(player, true, "Открыта зона: " .. nextLevel.displayName)
	end)
end

return TreasureUpgradeService
