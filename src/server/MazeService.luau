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
	local mazeWidth = MazeConfig.gridSizeX * MazeConfig.cellSize
	local mazeDepth = MazeConfig.gridSizeZ * MazeConfig.cellSize
	local relativeX = localPosition.X - center.X
	local relativeZ = localPosition.Z - center.Z
	if math.abs(relativeZ) >= mazeDepth / 2 - 1
		or relativeX <= -mazeWidth / 2 + 1
		or relativeX >= mazeWidth / 2 - 1 then
		return nil
	end
	local depth = relativeX + mazeWidth / 2
	for _, zoneId in MazeConfig.zoneOrder do
		if depth < MazeConfig.zones[zoneId].maxDepth then return zoneId end
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
	local gridSizeX = MazeConfig.gridSizeX
	local gridSizeZ = MazeConfig.gridSizeZ
	local cellSize = MazeConfig.cellSize
	local wallHeight = MazeConfig.wallHeight
	local halfSizeX = gridSizeX * cellSize / 2
	local halfSizeZ = gridSizeZ * cellSize / 2
	local random = Random.new(481516)
	local vertical = {}
	local horizontal = {}
	local visited = {}
	for x = 0, gridSizeX do
		vertical[x] = {}
		for z = 1, gridSizeZ do vertical[x][z] = true end
	end
	for x = 1, gridSizeX do
		horizontal[x] = {}
		visited[x] = {}
		for z = 0, gridSizeZ do horizontal[x][z] = true end
	end

	-- Build each difficulty band as its own connected maze. The walls between
	-- bands are opened only at the configured gates below.
	local zoneBands = {
		{ 1, 7 }, { 8, 14 }, { 15, 21 },
		{ 22, 28 }, { 29, 35 }, { 36, gridSizeX },
	}
	local entranceRow = math.ceil(gridSizeZ / 2)
	for _, band in zoneBands do
		local firstX = band[1]
		local lastX = band[2]
		local stack = { { x = firstX, z = entranceRow } }
		visited[firstX][entranceRow] = true
		while #stack > 0 do
			local current = stack[#stack]
			local neighbors = {}
			for _, direction in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local x = current.x + direction[1]
				local z = current.z + direction[2]
				if x >= firstX and x <= lastX and z >= 1 and z <= gridSizeZ and not visited[x][z] then
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
	end

	-- The entrance area has more alternative routes; deeper zones keep more walls.
	local function openingChance(x)
		local depthRatio = math.clamp(x / gridSizeX, 0, 1)
		return 0.28 - depthRatio * 0.18
	end
	for _, band in zoneBands do
		for x = band[1], band[2] - 1 do
			for z = 1, gridSizeZ do
				if vertical[x][z] and random:NextNumber() < openingChance(x) then vertical[x][z] = false end
			end
		end
	end
	for x = 1, gridSizeX do
		for z = 1, gridSizeZ - 1 do
			if horizontal[x][z] and random:NextNumber() < openingChance(x) then horizontal[x][z] = false end
		end
	end
	for _, zOffset in MazeConfig.entranceZOffsets do
		local row = math.clamp(math.floor((zOffset + halfSizeZ) / cellSize) + 1, 1, gridSizeZ)
		vertical[0][row] = false
	end
	for boundaryIndex, rows in MazeConfig.zoneTransitionRows do
		local boundaryX = zoneBands[boundaryIndex][2]
		for _, row in rows do
			vertical[boundaryX][math.clamp(row, 1, gridSizeZ)] = false
		end
	end

	local wallColor = Color3.fromRGB(65, 75, 60)
	local function wall(size, x, z)
		createPart("MazeWall", size, Vector3.new(center.X + x, 11 + wallHeight / 2, center.Z + z), wallColor, Enum.Material.Rock, baseplate)
	end
	for x = 0, gridSizeX do
		local z = 1
		while z <= gridSizeZ do
			if not vertical[x][z] then
				z += 1
				continue
			end
			local first = z
			while z <= gridSizeZ and vertical[x][z] do z += 1 end
			local count = z - first
			wall(Vector3.new(2, wallHeight, count * cellSize), -halfSizeX + x * cellSize, -halfSizeZ + (first - 1) * cellSize + count * cellSize / 2)
		end
	end
	for z = 0, gridSizeZ do
		local x = 1
		while x <= gridSizeX do
			if not horizontal[x][z] then
				x += 1
				continue
			end
			local first = x
			while x <= gridSizeX and horizontal[x][z] do x += 1 end
			local count = x - first
			wall(Vector3.new(count * cellSize, wallHeight, 2), -halfSizeX + (first - 1) * cellSize + count * cellSize / 2, -halfSizeZ + z * cellSize)
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
	local mazeWidth = MazeConfig.gridSizeX * MazeConfig.cellSize
	local mazeDepth = MazeConfig.gridSizeZ * MazeConfig.cellSize
	mazeModel = Instance.new("Model")
	mazeModel.Name = "CentralMaze"
	mazeModel.Parent = Workspace
	createPart("MazeFloor", Vector3.new(mazeWidth, 1, mazeDepth), Vector3.new(center.X, 10.5, center.Z), Color3.fromRGB(82, 94, 75), Enum.Material.Slate, baseplate)

	local function zoneFloor(zoneId, size, x, z)
		local zone = MazeConfig.zones[zoneId]
		local part = createPart(zoneId .. "ZoneFloor", size, Vector3.new(center.X + x, 11.06, center.Z + z), zone.color, Enum.Material.SmoothPlastic, baseplate)
		part.Transparency = 0.18
	end
	local previousDepth = 0
	for _, zoneId in MazeConfig.zoneOrder do
		local zone = MazeConfig.zones[zoneId]
		local bandWidth = zone.maxDepth - previousDepth
		local middleDepth = (previousDepth + zone.maxDepth) / 2
		local x = -mazeWidth / 2 + middleDepth
		zoneFloor(zoneId, Vector3.new(bandWidth, 0.12, mazeDepth), x, 0)
		createZoneLabel(zone, Vector3.new(center.X + x, 15, center.Z), baseplate)
		previousDepth = zone.maxDepth
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
