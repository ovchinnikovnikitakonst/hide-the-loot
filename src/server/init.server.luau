local PlotService = require(script.PlotService)
local TreasureService = require(script.TreasureService)
local SearchService = require(script.SearchService)
local EconomyService = require(script.EconomyService)
local RewardService = require(script.RewardService)
local TreasureUpgradeService = require(script.TreasureUpgradeService)
local ShopService = require(script.ShopService)
local PlotUpgradeService = require(script.PlotUpgradeService)
local MazeService = require(script.MazeService)
local CarryService = require(script.CarryService)
local IncomeService = require(script.IncomeService)

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
local buryTreasure = Instance.new("RemoteEvent")
buryTreasure.Name = "BuryTreasure"
buryTreasure.Parent = remotes
local digTreasure = Instance.new("RemoteEvent")
digTreasure.Name = "DigTreasure"
digTreasure.Parent = remotes
local searchRound = Instance.new("RemoteEvent")
searchRound.Name = "SearchRound"
searchRound.Parent = remotes
local upgradeTreasure = Instance.new("RemoteEvent")
upgradeTreasure.Name = "UpgradeTreasure"
upgradeTreasure.Parent = remotes
local upgradePlot = Instance.new("RemoteEvent")
upgradePlot.Name = "UpgradePlot"
upgradePlot.Parent = remotes
remotes.Parent = game:GetService("ReplicatedStorage")

EconomyService.start()
MazeService.start()
ShopService.start(PlotService)
PlotUpgradeService.start(PlotService, EconomyService, upgradePlot)
TreasureUpgradeService.start(EconomyService, upgradeTreasure, ShopService)
RewardService.start(SearchService, EconomyService)
TreasureService.start(PlotService, buryTreasure)
IncomeService.start(TreasureService, EconomyService)
CarryService.start(PlotService, TreasureService, MazeService)
SearchService.start(PlotService, TreasureService, CarryService, digTreasure, searchRound)
PlotService.start()
