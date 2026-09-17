local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TreasureConfig = require(ReplicatedStorage.Shared.config.TreasureConfig)

local TreasureStorageService = {}
local records = {}
local started = false

local function createPart(parent, ground, name, size, offset, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = true
	part.Color = color
	part.Material = material
	part.CFrame = ground.CFrame * CFrame.new(offset)
	part.Parent = parent
	return part
end

local function disconnectRecord(record)
	for _, connection in record.connections do connection:Disconnect() end
	records[record.plot] = nil
end

function TreasureStorageService.start(plotService, treasureService)
	if started then return end
	started = true

	local function createStorage(player, plot)
		if records[plot] or plotService.getPlot(player) ~= plot or not plot.Parent then return end
		local record = { player = player, plot = plot, connections = {} }
		records[plot] = record

		local function rebuildRack()
			local old = plot:FindFirstChild("TreasureStorage")
			if old then old:Destroy() end
			local ground = plot.PrimaryPart
			if not ground then return end
			local rack = Instance.new("Model")
			rack.Name = "TreasureStorage"
			local backZ = -ground.Size.Z / 2 + 3
			local wood = Color3.fromRGB(126, 89, 59)
			for _, x in { -18, -9, 0, 9, 18 } do
				createPart(rack, ground, "RackPost", Vector3.new(0.6, 9, 0.6), Vector3.new(x, 4.5, backZ - 1.4), wood, Enum.Material.Wood)
			end
			for _, y in { 0.65, 3.65, 6.65 } do
				createPart(rack, ground, "Shelf", Vector3.new(36, 0.3, 3.6), Vector3.new(0, y, backZ), wood, Enum.Material.WoodPlanks)
				createPart(rack, ground, "BackRail", Vector3.new(36, 0.4, 0.4), Vector3.new(0, y + 1.35, backZ - 1.5), wood, Enum.Material.Wood)
			end
			local title = createPart(rack, ground, "Title", Vector3.new(12, 1.8, 0.5), Vector3.new(0, 9.5, backZ - 1.45), Color3.fromRGB(93, 66, 45), Enum.Material.WoodPlanks)
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Back
			gui.CanvasSize = Vector2.new(480, 90)
			gui.Parent = title
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = "СУНДУКИ"
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextSize = 36
			label.Font = Enum.Font.GothamBold
			label.Parent = gui
			rack.Parent = plot
			record.rack = rack
			record.backZ = backZ
		end

		local function refresh()
			local ground = plot.PrimaryPart
			if not ground or not plot.Parent then return end
			local storedSlot = 0
			for _, treasure in treasureService.getStoredTreasures(plot) do
				local part = treasure.part
				if part and part.Parent then
					local oldPrompt = part:FindFirstChild("TreasureStoragePrompt")
					if oldPrompt then oldPrompt:Destroy() end
					part.Anchored = true
					part.CanCollide = false
					part.CanTouch = true
					part.CanQuery = true
					part.Parent = plot
					if treasure.selected then
						part.CFrame = ground.CFrame * CFrame.new(0, ground.Size.Y / 2 + part.Size.Y / 2, ground.Size.Z / 2 - 14)
					else
						storedSlot += 1
						local column = (storedSlot - 1) % 8
						local row = math.floor((storedSlot - 1) / 8)
						part.CFrame = ground.CFrame * CFrame.new((column - 3.5) * 4.2, 1.75 + row * 3, record.backZ)
					end
					local definition = TreasureConfig.types[treasure.typeId]
					local prompt = Instance.new("ProximityPrompt")
					prompt.Name = "TreasureStoragePrompt"
					prompt.ActionText = treasure.selected and "Вернуть на стойку" or "Выбрать для закапывания"
					prompt.ObjectText = string.format("%s · %d Coins/min", definition.rarity, definition.incomePerMinute)
					prompt.HoldDuration = 0.35
					prompt.MaxActivationDistance = 10
					prompt.RequiresLineOfSight = true
					prompt.Enabled = not plot:GetAttribute("SearchBusy")
					prompt.Triggered:Connect(function(triggeringPlayer)
						if triggeringPlayer ~= player or player.Parent ~= Players then return end
						treasureService.toggleStoredTreasure(player, plot, treasure.id)
					end)
					prompt.Parent = part
				end
			end
		end

		record.refresh = refresh
		record.rebuildRack = rebuildRack
		table.insert(record.connections, plot:GetAttributeChangedSignal("PlotLevel"):Connect(function()
			rebuildRack()
			refresh()
		end))
		table.insert(record.connections, plot:GetAttributeChangedSignal("SearchBusy"):Connect(refresh))
		rebuildRack()
		refresh()
	end

	plotService.PlotAssigned:Connect(createStorage)
	plotService.PlotRemoving:Connect(function(_, plot)
		local record = records[plot]
		if record then disconnectRecord(record) end
	end)
	treasureService.StorageChanged:Connect(function(_, plot)
		local record = records[plot]
		if record then record.refresh() end
	end)
	for _, player in Players:GetPlayers() do
		local plot = plotService.getPlot(player)
		if plot then createStorage(player, plot) end
	end
end

return TreasureStorageService
