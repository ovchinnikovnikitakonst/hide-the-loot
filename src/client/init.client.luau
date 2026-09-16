local BuryController = require(script.BuryController)
local SearchController = require(script.SearchController)
local ShopController = require(script.ShopController)

BuryController.start(function()
	if SearchController.stop then
		SearchController.stop()
	end
end)
SearchController.start(function()
	BuryController.stop()
end)
ShopController.start()
