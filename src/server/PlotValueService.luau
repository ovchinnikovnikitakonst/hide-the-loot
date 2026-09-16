local PlotValueService = {}
local records = {}
local started = false

local function disconnectRecord(record)
	for _, connection in record.connections do connection:Disconnect() end
	records[record.plot] = nil
end

function PlotValueService.start(plotService, treasureService)
	if started then return end
	started = true

	local function createBoard(player, plot)
		if records[plot] or plotService.getPlot(player) ~= plot or not plot.Parent then return end
		local ground = plot.PrimaryPart
		if not ground then return end
		local board = Instance.new("Part")
		board.Name = "PlotValueSign"
		board.Size = Vector3.new(18, 6, 1)
		board.Anchored = true
		board.CanCollide = false
		board.Color = Color3.fromRGB(24, 28, 34)
		board.Material = Enum.Material.Slate
		board:SetAttribute("OwnerUserId", player.UserId)
		board.Parent = plot

		local gui = Instance.new("SurfaceGui")
		gui.Name = "PublicValue"
		gui.Face = Enum.NormalId.Front
		gui.CanvasSize = Vector2.new(720, 280)
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(245, 245, 245)
		label.TextSize = 30
		label.TextWrapped = true
		label.Font = Enum.Font.GothamBold
		label.Parent = gui

		local record = { plot = plot, board = board, label = label, connections = {} }
		records[plot] = record
		local function reposition()
			if not plot.Parent or not ground.Parent then return end
			board.CFrame = ground.CFrame * CFrame.new(0, 9.5, ground.Size.Z / 2 + 4)
				* CFrame.Angles(0, math.pi, 0)
		end
		local function refresh()
			if not plot.Parent then return end
			local summary = treasureService.getBuriedSummary(plot)
			local status
			if plot:GetAttribute("SearchBusy") then
				status = "ИДЁТ ПОИСК"
			elseif plot:GetAttribute("SearchFinished") then
				status = "ПЕРЕРЫВ ПОСЛЕ ПОИСКА"
			elseif summary.count == 0 then
				status = "НЕТ ЗАКОПАННЫХ КЛАДОВ"
			else
				status = "МОЖНО АТАКОВАТЬ"
			end
			label.Text = string.format(
				"Хранилище · %s\nСундуков: %d  ·  Лучшая редкость: %s\nЦенность рейда: %d Coins  ·  Доход: %d Coins/min\n%s",
				player.Name,
				summary.count,
				summary.highestRarity or "—",
				summary.totalValue,
				summary.incomePerMinute,
				status
			)
		end
		table.insert(record.connections, plot:GetAttributeChangedSignal("PlotLevel"):Connect(reposition))
		table.insert(record.connections, plot:GetAttributeChangedSignal("SearchBusy"):Connect(refresh))
		table.insert(record.connections, plot:GetAttributeChangedSignal("SearchFinished"):Connect(refresh))
		record.reposition = reposition
		record.refresh = refresh
		reposition()
		refresh()
	end

	plotService.PlotAssigned:Connect(createBoard)
	plotService.PlotRemoving:Connect(function(_, plot)
		local record = records[plot]
		if record then disconnectRecord(record) end
	end)
	treasureService.TreasureBuried:Connect(function(_, plot)
		local record = records[plot]
		if record then record.refresh() end
	end)
	treasureService.TreasureInactive:Connect(function(_, plot)
		local record = records[plot]
		if record then record.refresh() end
	end)
	for _, player in game:GetService("Players"):GetPlayers() do
		local plot = plotService.getPlot(player)
		if plot then createBoard(player, plot) end
	end
end

return PlotValueService
