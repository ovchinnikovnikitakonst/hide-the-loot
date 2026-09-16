local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.config.TreasureConfig)

local IncomeService = {}
local active = {}
local started = false

local function updateIndicator(plot)
	local ground = plot and plot.PrimaryPart
	if not ground then return end
	local totalRate = 0
	local count = 0
	for _, record in active do
		if record.plot == plot then
			local definition = Config.types[record.typeId]
			if definition then
				totalRate += definition.incomePerMinute
				count += 1
			end
		end
	end
	local gui = ground:FindFirstChild("TreasureIncomeGui")
	if count == 0 then
		if gui then gui:Destroy() end
		return
	end
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "TreasureIncomeGui"
		gui.Size = UDim2.fromOffset(320, 58)
		gui.StudsOffset = Vector3.new(0, 6, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 120
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
		label.BackgroundTransparency = 0.2
		label.TextColor3 = Color3.fromRGB(255, 215, 80)
		label.TextStrokeTransparency = 0.5
		label.TextScaled = true
		label.Parent = gui
		gui.Parent = ground
	end
	gui.Label.Text = string.format("Сундуков: %d · +%d Coins/min", count, totalRate)
end

function IncomeService.start(treasureService, economyService)
	if started then return end
	started = true
	treasureService.TreasureBuried:Connect(function(player, plot, treasureId, typeId)
		if not Config.types[typeId] then return end
		active[treasureId] = { player = player, plot = plot, typeId = typeId, accrued = 0 }
		updateIndicator(plot)
	end)
	treasureService.TreasureInactive:Connect(function(_, plot, treasureId)
		active[treasureId] = nil
		updateIndicator(plot)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local affected = {}
		for treasureId, record in active do
			if record.player == player then
				active[treasureId] = nil
				affected[record.plot] = true
			end
		end
		for plot in affected do updateIndicator(plot) end
	end)
	RunService.Heartbeat:Connect(function(deltaTime)
		local affected = {}
		for treasureId, record in active do
			local definition = Config.types[record.typeId]
			if record.player.Parent ~= Players or not record.plot.Parent or not definition then
				active[treasureId] = nil
				affected[record.plot] = true
			else
				record.accrued += definition.incomePerMinute * deltaTime / 60
				local wholeCoins = math.floor(record.accrued)
				if wholeCoins > 0 and economyService.addCoins(record.player, wholeCoins, "buried_treasure_income") then
					record.accrued -= wholeCoins
				end
			end
		end
		for plot in affected do updateIndicator(plot) end
	end)
end

return IncomeService
