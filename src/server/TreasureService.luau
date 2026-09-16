local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local PlotConfig = require(ReplicatedStorage.Shared.config.PlotConfig)
local TreasureConfig = require(ReplicatedStorage.Shared.config.TreasureConfig)

local TREASURE_SIZE = Vector3.new(3, 2, 3)
local MIN_BURY_DISTANCE = 4
local treasureBuried = Instance.new("BindableEvent")
local treasureInactive = Instance.new("BindableEvent")
local storageChanged = Instance.new("BindableEvent")
local TreasureService = {
	TreasureBuried = treasureBuried.Event,
	TreasureInactive = treasureInactive.Event,
	StorageChanged = storageChanged.Event,
}
local dataByUserId = {}
local nextTreasureId = 0
local started = false

local function countTreasures(data)
	local count = 0
	for _ in data.treasures do count += 1 end
	return count
end

local function getDataForPlot(plot)
	if typeof(plot) ~= "Instance" or not plot:IsA("Model") then return nil end
	local data = dataByUserId[plot:GetAttribute("OwnerUserId")]
	return data and data.plot == plot and data or nil
end

local function updateBuriedAttribute(data)
	local hasBuried = false
	local buriedCount = 0
	local storedCount = 0
	local totalCount = 0
	for _, record in data.treasures do
		totalCount += 1
		if record.status == "buried" then
			hasBuried = true
			buriedCount += 1
		elseif record.status == "stored" or record.status == "selected" then
			storedCount += 1
		end
	end
	data.plot:SetAttribute("HasBuriedTreasure", hasBuried)
	data.plot:SetAttribute("TreasureCount", totalCount)
	data.plot:SetAttribute("BuriedTreasureCount", buriedCount)
	data.plot:SetAttribute("StoredTreasureCount", storedCount)
end

function TreasureService.getRaidTypeId(plot)
	local data = getDataForPlot(plot)
	local bestTypeId
	local bestReward = -1
	if data then
		for _, record in data.treasures do
			if record.status == "buried" then
				local definition = TreasureConfig.types[record.typeId]
				if definition and definition.ownerReward > bestReward then
					bestTypeId = record.typeId
					bestReward = definition.ownerReward
				end
			end
		end
	end
	return bestTypeId
end

function TreasureService.getTreasureTypeId(plot)
	return TreasureService.getRaidTypeId(plot)
end

function TreasureService.canSearch(plot)
	return TreasureService.getRaidTypeId(plot) ~= nil
end

function TreasureService.getBuriedSummary(plot)
	local summary = {
		count = 0,
		totalValue = 0,
		incomePerMinute = 0,
		highestRarity = nil,
	}
	local data = getDataForPlot(plot)
	local highestValue = -1
	if data then
		for _, record in data.treasures do
			if record.status == "buried" then
				local definition = TreasureConfig.types[record.typeId]
				if definition then
					summary.count += 1
					summary.totalValue += definition.seekerReward
					summary.incomePerMinute += definition.incomePerMinute
					if definition.seekerReward > highestValue then
						highestValue = definition.seekerReward
						summary.highestRarity = definition.rarity
					end
				end
			end
		end
	end
	return table.freeze(summary)
end

function TreasureService.getStoredTreasures(plot)
	local result = {}
	local data = getDataForPlot(plot)
	if data then
		for _, record in data.treasures do
			if record.status == "stored" or record.status == "selected" then
				table.insert(result, table.freeze({
					id = record.id,
					typeId = record.typeId,
					part = record.part,
					selected = record.status == "selected",
				}))
			end
		end
	end
	table.sort(result, function(a, b)
		return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
	end)
	return table.freeze(result)
end

function TreasureService.start(plotService, buryTreasure)
	if started then return end
	started = true
	local hidden = Instance.new("Folder")
	hidden.Name = "BuriedTreasures"
	hidden.Parent = ServerStorage

	local function getOrCreateData(player, plot)
		local data = dataByUserId[player.UserId]
		if data and data.plot == plot then return data end
		data = { player = player, plot = plot, treasures = {}, pendingId = nil }
		dataByUserId[player.UserId] = data
		return data
	end

	local function capacityFor(plot)
		local level = math.clamp(plot:GetAttribute("PlotLevel") or 1, 1, #PlotConfig.levels)
		return PlotConfig.levels[level].treasureCapacity
	end

	local function prepareStoredPart(part, player, record, plot)
		for _, child in part:GetChildren() do
			if child:IsA("WeldConstraint") or child:IsA("ProximityPrompt") then child:Destroy() end
		end
		local ground = plot.PrimaryPart
		part.Name = "Treasure_" .. record.id
		part.Size = TREASURE_SIZE
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = true
		part.CanQuery = true
		part.Massless = false
		part.Color = TreasureConfig.types[record.typeId].color
		part.Material = Enum.Material.Metal
		part.CFrame = ground.CFrame * CFrame.new(0, ground.Size.Y / 2 + TREASURE_SIZE.Y / 2, 0)
		part:SetAttribute("TreasureId", record.id)
		part:SetAttribute("OwnerUserId", player.UserId)
		part:SetAttribute("TreasureTypeId", record.typeId)
		part:SetAttribute("Rarity", TreasureConfig.types[record.typeId].rarity)
		part:SetAttribute("AcquisitionSource", record.source)
		part:SetAttribute("TreasureStatus", "Stored")
		part:SetAttribute("IsBuried", false)
		part:SetAttribute("IsFound", false)
		part.Parent = plot
	end

	function TreasureService.canAcceptDelivery(player)
		local plot = plotService.getPlot(player)
		if not plot or not plot.Parent or plot:GetAttribute("SearchBusy") then return false end
		local data = dataByUserId[player.UserId]
		if data and data.plot ~= plot then return false end
		return not data or countTreasures(data) < capacityFor(plot)
	end

	function TreasureService.acceptCarriedTreasure(player, payload)
		if not payload or payload.resolved or not TreasureConfig.types[payload.typeId]
			or not payload.part or not payload.part.Parent or not TreasureService.canAcceptDelivery(player) then
			return false
		end
		local plot = plotService.getPlot(player)
		local data = getOrCreateData(player, plot)
		nextTreasureId += 1
		local treasureId = tostring(nextTreasureId)
		local record = { id = treasureId, typeId = payload.typeId, part = payload.part, status = "stored", source = payload.kind }
		data.treasures[treasureId] = record
		payload.resolved = true
		prepareStoredPart(payload.part, player, record, plot)
		updateBuriedAttribute(data)
		storageChanged:Fire(player, plot)
		return true
	end

	function TreasureService.toggleStoredTreasure(player, plot, treasureId)
		local data = dataByUserId[player.UserId]
		if not data or data.plot ~= plot or plotService.getPlot(player) ~= plot
			or not plot.Parent or plot:GetAttribute("SearchBusy") then return false end
		local record = data.treasures[treasureId]
		if not record or (record.status ~= "stored" and record.status ~= "selected") then return false end
		if data.pendingId == treasureId then
			record.status = "stored"
			record.part:SetAttribute("TreasureStatus", "Stored")
			data.pendingId = nil
		else
			local previous = data.pendingId and data.treasures[data.pendingId]
			if previous and previous.status == "selected" then
				previous.status = "stored"
				previous.part:SetAttribute("TreasureStatus", "Stored")
			end
			record.status = "selected"
			record.part:SetAttribute("TreasureStatus", "Unburied")
			data.pendingId = treasureId
		end
		updateBuriedAttribute(data)
		storageChanged:Fire(player, plot)
		return true
	end

	function TreasureService.tryDig(player, plot, position)
		if typeof(position) ~= "Vector3" then return "rejected" end
		for _, value in { position.X, position.Y, position.Z } do
			if value ~= value or math.abs(value) == math.huge then return "rejected" end
		end
		local data = getDataForPlot(plot)
		local owner = data and data.player
		if not data or not owner or owner == player or plotService.getPlot(owner) ~= plot or not plot.Parent then return "rejected" end
		local ground = plot.PrimaryPart
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not ground or not root or not humanoid or humanoid.Health <= 0 then return "rejected" end
		local target = ground.CFrame:PointToObjectSpace(position)
		local standing = ground.CFrame:PointToObjectSpace(root.Position)
		local half = ground.Size / 2
		if math.abs(target.X) > half.X or math.abs(target.Z) > half.Z
			or math.abs(target.Y - half.Y) > 0.2
			or math.abs(standing.X) > half.X or math.abs(standing.Z) > half.Z
			or standing.Y < half.Y or standing.Y > half.Y + 10 then return "rejected" end
		local found
		local nearestDistance = math.huge
		for _, record in data.treasures do
			if record.status == "buried" then
				local offset = target - record.buriedPosition
				local distance = offset.X * offset.X + offset.Z * offset.Z
				if distance <= 3 * 3 and distance < nearestDistance then
					found = record
					nearestDistance = distance
				end
			end
		end
		if not found then return "miss" end
		data.treasures[found.id] = nil
		found.status = "carried"
		found.part.CFrame = ground.CFrame * CFrame.new(found.buriedPosition.X, half.Y + TREASURE_SIZE.Y / 2, found.buriedPosition.Z)
		found.part:SetAttribute("TreasureStatus", "Carried")
		found.part:SetAttribute("IsBuried", false)
		found.part:SetAttribute("IsFound", true)
		found.part.Parent = plot
		treasureInactive:Fire(owner, plot, found.id, found.typeId, "stolen")
		updateBuriedAttribute(data)
		return "found", {
			kind = "stolen",
			part = found.part,
			treasureId = found.id,
			typeId = found.typeId,
			originalOwner = owner,
			originalPlot = plot,
			buriedPosition = found.buriedPosition,
		}
	end

	function TreasureService.returnStolenTreasure(payload)
		if not payload or payload.resolved or payload.kind ~= "stolen" then return false end
		local owner = payload.originalOwner
		local plot = payload.originalPlot
		if not owner or owner.Parent ~= Players or not plot or not plot.Parent or plotService.getPlot(owner) ~= plot then
			payload.resolved = true
			if payload.part then payload.part:Destroy() end
			return false
		end
		local data = getOrCreateData(owner, plot)
		local record = {
			id = payload.treasureId,
			typeId = payload.typeId,
			part = payload.part,
			status = "buried",
			source = "stolen_return",
			buriedPosition = payload.buriedPosition,
		}
		data.treasures[record.id] = record
		local ground = plot.PrimaryPart
		for _, child in payload.part:GetChildren() do if child:IsA("WeldConstraint") then child:Destroy() end end
		payload.part.Anchored = true
		payload.part:SetAttribute("OwnerUserId", owner.UserId)
		payload.part:SetAttribute("TreasureStatus", "Buried")
		payload.part:SetAttribute("IsBuried", true)
		payload.part:SetAttribute("IsFound", false)
		payload.part.CFrame = ground.CFrame * CFrame.new(record.buriedPosition.X, ground.Size.Y / 2 - TREASURE_SIZE.Y / 2 - 0.5, record.buriedPosition.Z)
		payload.part.Parent = hidden
		payload.resolved = true
		updateBuriedAttribute(data)
		treasureBuried:Fire(owner, plot, record.id, record.typeId)
		return true
	end

	buryTreasure.OnServerEvent:Connect(function(player, position)
		local data = dataByUserId[player.UserId]
		local record = data and data.pendingId and data.treasures[data.pendingId]
		if not data or not record or record.status ~= "selected" then buryTreasure:FireClient(player, false) return end
		local now = os.clock()
		if record.lastRequest and now - record.lastRequest < 0.25 then return end
		record.lastRequest = now
		if typeof(position) ~= "Vector3" then buryTreasure:FireClient(player, false) return end
		for _, value in { position.X, position.Y, position.Z } do
			if value ~= value or math.abs(value) == math.huge then buryTreasure:FireClient(player, false) return end
		end
		local plot = plotService.getPlot(player)
		local ground = plot and plot.PrimaryPart
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if plot ~= data.plot or not ground or not root or not humanoid or humanoid.Health <= 0 or plot:GetAttribute("SearchBusy") then
			buryTreasure:FireClient(player, false) return
		end
		local target = ground.CFrame:PointToObjectSpace(position)
		local standing = ground.CFrame:PointToObjectSpace(root.Position)
		local half = ground.Size / 2
		if math.abs(target.X) > half.X - TREASURE_SIZE.X / 2 or math.abs(target.Z) > half.Z - TREASURE_SIZE.Z / 2
			or math.abs(target.Y - half.Y) > 0.2 or math.abs(standing.X) > half.X or math.abs(standing.Z) > half.Z
			or standing.Y < half.Y or standing.Y > half.Y + 10 then buryTreasure:FireClient(player, false) return end
		for _, other in data.treasures do
			if other.status == "buried" then
				local offset = target - other.buriedPosition
				if offset.X * offset.X + offset.Z * offset.Z < MIN_BURY_DISTANCE * MIN_BURY_DISTANCE then
					buryTreasure:FireClient(player, false) return
				end
			end
		end
		record.status = "buried"
		record.buriedPosition = target
		data.pendingId = nil
		record.part.Parent = hidden
		record.part.CFrame = ground.CFrame * CFrame.new(target.X, half.Y - TREASURE_SIZE.Y / 2 - 0.5, target.Z)
		record.part:SetAttribute("TreasureStatus", "Buried")
		record.part:SetAttribute("IsBuried", true)
		for _, child in record.part:GetChildren() do
			if child:IsA("ProximityPrompt") then child:Destroy() end
		end
		updateBuriedAttribute(data)
		storageChanged:Fire(player, plot)
		treasureBuried:Fire(player, plot, record.id, record.typeId)
		buryTreasure:FireClient(player, true)
	end)

	plotService.PlotRemoving:Connect(function(player, plot)
		local data = dataByUserId[player.UserId]
		if not data or data.plot ~= plot then return end
		for _, record in data.treasures do
			treasureInactive:Fire(player, plot, record.id, record.typeId, "plot_removed")
			record.part:Destroy()
		end
		dataByUserId[player.UserId] = nil
	end)
end

return TreasureService
