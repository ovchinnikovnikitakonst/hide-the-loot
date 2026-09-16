local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.config.MazeConfig)

local TreasureUpgradeService = {}
local levels = {}
local lastRequest = {}
local started = false

function TreasureUpgradeService.getLicenseLevel(player)
	return levels[player] or Config.defaultLicenseLevel
end

function TreasureUpgradeService.start(economyService, remote, shopService)
	if started then return end
	started = true
	local function addPlayer(player)
		if player.Parent ~= Players or levels[player] then return end
		levels[player] = Config.defaultLicenseLevel
		player:SetAttribute("ExplorerLicenseLevel", levels[player])
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
		remote:FireClient(player, true, "Открыта зона: " .. nextLevel.displayName)
	end)
end

return TreasureUpgradeService
