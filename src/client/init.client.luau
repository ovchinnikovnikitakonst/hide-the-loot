local BuryController = require(script.BuryController)
local SearchController = require(script.SearchController)

BuryController.start(function()
	if SearchController.stop then
		SearchController.stop()
	end
end)
SearchController.start(function()
	BuryController.stop()
end)
