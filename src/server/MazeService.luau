local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MazeConfig = require(ReplicatedStorage.Shared.config.MazeConfig)
local TreasureConfig = require(ReplicatedStorage.Shared.config.TreasureConfig)

local lootRequested = Instance.new("BindableEvent")
local MazeService = { LootRequested = lootRequested.Event }
local availableLoot = {}
local spawnPoints = {}
local pickupBlockedUntil = setmetatable({}, { __mode = "k" })
local activePickupPrompt = setmetatable({}, { __mode = "k" })
local mazeModel
local mazeBaseplate
local explorerService
local started = false

local function createPart(name, size, offset, color, material, baseplate)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.Color = color
	part.Material = material
	part.CFrame = baseplate.CFrame * CFrame.new(offset)
	part.Parent = mazeModel
	return part
end

local function spawnLoot(index)
	local point = spawnPoints[index]
	if not point or not mazeModel.Parent then return end
	local zone = MazeConfig.zones[point.zoneId]
	local totalWeight = 0
	for _, drop in zone.drops do totalWeight += drop.weight end
	local roll = math.random(1, totalWeight)
	local total = 0
	local typeId = zone.drops[#zone.drops].typeId
	for _, drop in zone.drops do
		total += drop.weight
		if roll <= total then
			typeId = drop.typeId
			break
		end
	end
	local definition = TreasureConfig.types[typeId]
	local chest = Instance.new("Part")
	chest.Name = "MazeTreasure"
	chest.Size = Vector3.new(3, 2, 3)
	chest.Anchored = true
	chest.CanCollide = false
	chest.Color = definition.color
	chest.Material = Enum.Material.Metal
	chest.CFrame = point.cframe
	chest:SetAttribute("TreasureTypeId", typeId)
	chest:SetAttribute("Rarity", definition.rarity)
	chest:SetAttribute("MazeZoneId", zone.id)
	chest:SetAttribute("RequiredLicenseLevel", zone.requiredLicenseLevel)
	chest:SetAttribute("MazeSpawnIndex", index)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять сундук"
	prompt.ObjectText = string.format("%s · %s · лицензия %d", definition.rarity, zone.displayName, zone.requiredLicenseLevel)
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = true
	prompt.PromptButtonHoldBegan:Connect(function(player)
		activePickupPrompt[player] = prompt
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		if activePickupPrompt[player] == prompt then activePickupPrompt[player] = nil end
	end)
	prompt.Triggered:Connect(function(player)
		if activePickupPrompt[player] == prompt then activePickupPrompt[player] = nil end
		lootRequested:Fire(player, chest)
	end)
	prompt.Parent = chest
	availableLoot[chest] = index
	chest.Parent = mazeModel
end

function MazeService.claimLoot(player, chest)
	if (pickupBlockedUntil[player] or 0) > os.clock() then return nil end
	local index = availableLoot[chest]
	if not index or chest.Parent ~= mazeModel then return nil end
	local point = spawnPoints[index]
	local zone = point and MazeConfig.zones[point.zoneId]
	if not zone or explorerService.getLicenseLevel(player) < zone.requiredLicenseLevel then return nil end
	availableLoot[chest] = nil
	local prompt = chest:FindFirstChildOfClass("ProximityPrompt")
	if prompt then prompt:Destroy() end
	task.delay(zone.respawnTime, function()
		spawnLoot(index)
	end)
	return chest:GetAttribute("TreasureTypeId")
end

function MazeService.interruptTreasurePickup(player, duration)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	pickupBlockedUntil[player] = math.max(pickupBlockedUntil[player] or 0, os.clock() + duration)
	local prompt = activePickupPrompt[player]
	activePickupPrompt[player] = nil
	if prompt and prompt.Parent and prompt.Enabled then
		prompt.Enabled = false
		task.delay(0.15, function()
			if prompt.Parent then prompt.Enabled = true end
		end)
	end
end

function MazeService.getZoneIdAtPosition(position)
	if typeof(position) ~= "Vector3" or not mazeBaseplate then return nil end
	local localPosition = mazeBaseplate.CFrame:PointToObjectSpace(position)
	local center = MazeConfig.centerOffset
	local radius = math.max(math.abs(localPosition.X - center.X), math.abs(localPosition.Z - center.Z))
	for index = #MazeConfig.zoneOrder, 1, -1 do
		local zoneId = MazeConfig.zoneOrder[index]
		if radius < MazeConfig.zones[zoneId].maxRadius - 1 then return zoneId end
	end
	return nil
end

local function createZoneLabel(zone, position, baseplate)
	local marker = createPart(zone.id .. "ZoneMarker", Vector3.new(10, 4, 1), position, zone.color, Enum.Material.Slate, baseplate)
	marker.CanCollide = false
	marker.Transparency = 0.35
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180, 64)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Parent = marker
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 18
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Text = string.format("%s\nЛицензия %d", zone.displayName, zone.requiredLicenseLevel)
	label.Parent = gui
end

local function createMazeWalls(baseplate, center)
	local gridSize = MazeConfig.gridSize
	local cellSize = MazeConfig.cellSize
	local halfSize = gridSize * cellSize / 2
	local random = Random.new(481516)
	local vertical = {}
	local horizontal = {}
	local visited = {}
	for x = 0, gridSize do
		vertical[x] = {}
		for z = 1, gridSize do vertical[x][z] = true end
	end
	for x = 1, gridSize do
		horizontal[x] = {}
		visited[x] = {}
		for z = 0, gridSize do horizontal[x][z] = true end
	end

	local middle = math.ceil(gridSize / 2)
	local stack = { { x = middle, z = middle } }
	visited[middle][middle] = true
	while #stack > 0 do
		local current = stack[#stack]
		local neighbors = {}
		for _, direction in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local x = current.x + direction[1]
			local z = current.z + direction[2]
			if x >= 1 and x <= gridSize and z >= 1 and z <= gridSize and not visited[x][z] then
				table.insert(neighbors, { x = x, z = z })
			end
		end
		if #neighbors == 0 then
			table.remove(stack)
		else
			local nextCell = neighbors[random:NextInteger(1, #neighbors)]
			if nextCell.x > current.x then vertical[current.x][current.z] = false
			elseif nextCell.x < current.x then vertical[current.x - 1][current.z] = false
			elseif nextCell.z > current.z then horizontal[current.x][current.z] = false
			else horizontal[current.x][current.z - 1] = false end
			visited[nextCell.x][nextCell.z] = true
			table.insert(stack, nextCell)
		end
	end

	-- Extra openings turn the perfect maze into a network with alternative routes.
	for x = 1, gridSize - 1 do
		for z = 1, gridSize do
			if vertical[x][z] and random:NextNumber() < 0.18 then vertical[x][z] = false end
		end
	end
	for x = 1, gridSize do
		for z = 1, gridSize - 1 do
			if horizontal[x][z] and random:NextNumber() < 0.18 then horizontal[x][z] = false end
		end
	end
	vertical[0][middle] = false
	vertical[gridSize][middle] = false
	horizontal[middle][0] = false
	horizontal[middle][gridSize] = false

	local wallColor = Color3.fromRGB(65, 75, 60)
	local function wall(size, x, z)
		createPart("MazeWall", size, Vector3.new(center.X + x, 17, center.Z + z), wallColor, Enum.Material.Rock, baseplate)
	end
	for x = 0, gridSize do
		local z = 1
		while z <= gridSize do
			if not vertical[x][z] then
				z += 1
				continue
			end
			local first = z
			while z <= gridSize and vertical[x][z] do z += 1 end
			local count = z - first
			wall(Vector3.new(2, 12, count * cellSize), -halfSize + x * cellSize, -halfSize + (first - 1) * cellSize + count * cellSize / 2)
		end
	end
	for z = 0, gridSize do
		local x = 1
		while x <= gridSize do
			if not horizontal[x][z] then
				x += 1
				continue
			end
			local first = x
			while x <= gridSize and horizontal[x][z] do x += 1 end
			local count = x - first
			wall(Vector3.new(count * cellSize, 12, 2), -halfSize + (first - 1) * cellSize + count * cellSize / 2, -halfSize + z * cellSize)
		end
	end
end

function MazeService.start(resolvedExplorerService)
	if started then return end
	started = true
	explorerService = resolvedExplorerService
	local baseplate = Workspace:WaitForChild("Baseplate")
	mazeBaseplate = baseplate
	local center = MazeConfig.centerOffset
	local mazeSize = MazeConfig.gridSize * MazeConfig.cellSize
	mazeModel = Instance.new("Model")
	mazeModel.Name = "CentralMaze"
	mazeModel.Parent = Workspace
	createPart("MazeFloor", Vector3.new(mazeSize, 1, mazeSize), Vector3.new(center.X, 10.5, center.Z), Color3.fromRGB(82, 94, 75), Enum.Material.Slate, baseplate)

	local function zoneFloor(zoneId, size, x, z)
		local zone = MazeConfig.zones[zoneId]
		local part = createPart(zoneId .. "ZoneFloor", size, Vector3.new(center.X + x, 11.06, center.Z + z), zone.color, Enum.Material.SmoothPlastic, baseplate)
		part.Transparency = 0.18
	end
	for index, zoneId in MazeConfig.zoneOrder do
		local zone = MazeConfig.zones[zoneId]
		local innerZoneId = MazeConfig.zoneOrder[index + 1]
		local innerRadius = innerZoneId and MazeConfig.zones[innerZoneId].maxRadius or 0
		if innerRadius == 0 then
			zoneFloor(zoneId, Vector3.new(zone.maxRadius * 2, 0.12, zone.maxRadius * 2), 0, 0)
		else
			local band = zone.maxRadius - innerRadius
			local middle = (zone.maxRadius + innerRadius) / 2
			zoneFloor(zoneId, Vector3.new(zone.maxRadius * 2, 0.12, band), 0, -middle)
			zoneFloor(zoneId, Vector3.new(zone.maxRadius * 2, 0.12, band), 0, middle)
			zoneFloor(zoneId, Vector3.new(band, 0.12, innerRadius * 2), -middle, 0)
			zoneFloor(zoneId, Vector3.new(band, 0.12, innerRadius * 2), middle, 0)
		end
		local labelRadius = (zone.maxRadius + innerRadius) / 2
		createZoneLabel(zone, Vector3.new(center.X - labelRadius, 15, center.Z), baseplate)
	end

	createMazeWalls(baseplate, center)
	local spawnIndex = 0
	for _, zoneId in MazeConfig.zoneOrder do
		for _, position in MazeConfig.zones[zoneId].lootSpawns do
			spawnIndex += 1
			spawnPoints[spawnIndex] = {
				zoneId = zoneId,
				cframe = baseplate.CFrame * CFrame.new(center.X + position.X, 12, center.Z + position.Y),
			}
			spawnLoot(spawnIndex)
		end
	end
end

return MazeService
