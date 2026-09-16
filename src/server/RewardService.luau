local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TreasureConfig = require(ReplicatedStorage.Shared.config.TreasureConfig)

local RewardService = {}
local processedRoundIds = {}
local started = false

function RewardService.start(searchService, economyService)
	if started then return end
	started = true
	searchService.RoundFinished:Connect(function(result)
		if processedRoundIds[result.roundId] then return end
		-- Mark before calling the economy. This handler and addCoins do not yield.
		processedRoundIds[result.roundId] = true
		if result.outcome == "cancelled" then return end
		local definition = TreasureConfig.types[result.treasureTypeId]
		if not definition then
			warn("Unknown treasure type in round " .. result.roundId)
			return
		end
		local recipient, amount, reason
		if result.outcome == "seeker" then
			recipient, amount, reason = result.seeker, definition.seekerReward, "search_found"
		elseif result.outcome == "owner" then
			recipient, amount, reason = result.owner, definition.ownerReward, "search_defended"
		else
			return
		end
		economyService.addCoins(recipient, amount, reason)
	end)
end

return RewardService
