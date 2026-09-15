local PlotService = require(script.PlotService)
local TreasureService = require(script.TreasureService)
local SearchService = require(script.SearchService)

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
remotes.Parent = game:GetService("ReplicatedStorage")

TreasureService.start(PlotService, buryTreasure)
SearchService.start(PlotService, TreasureService, digTreasure, searchRound)
PlotService.start()
