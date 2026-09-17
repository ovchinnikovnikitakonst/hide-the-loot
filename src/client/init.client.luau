local BuryController = require(script.BuryController)
local SearchController = require(script.SearchController)
local ShopController = require(script.ShopController)
local StatusController = require(script.StatusController)
local DecorationController = require(script.DecorationController)

BuryController.start(function()
	if SearchController.stop then
		SearchController.stop()
	end
	if DecorationController.stop then
		DecorationController.stop()
	end
end)
SearchController.start(function()
	BuryController.stop()
	if DecorationController.stop then
		DecorationController.stop()
	end
end)
ShopController.start()
StatusController.start()
DecorationController.start(function()
	BuryController.stop()
	if SearchController.stop then SearchController.stop() end
end)
