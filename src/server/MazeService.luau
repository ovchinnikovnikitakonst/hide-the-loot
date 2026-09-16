local Workspace = game:GetService("Workspace")

local RESPAWN_TIME = 20
local lootRequested = Instance.new("BindableEvent")
local MazeService = { LootRequested = lootRequested.Event }
local availableLoot = {}
local spawnPoints = {}
local mazeModel
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
	local chest = Instance.new("Part")
	chest.Name = "MazeTreasure"
	chest.Size = Vector3.new(3, 2, 3)
	chest.Anchored = true
	chest.CanCollide = false
	chest.Color = Color3.fromRGB(255, 195, 45)
	chest.Material = Enum.Material.Metal
	chest.CFrame = point
	chest:SetAttribute("TreasureTypeId", "common")
	chest:SetAttribute("Rarity", "Common")
	chest:SetAttribute("MazeSpawnIndex", index)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Взять сундук"
	prompt.ObjectText = "Common Treasure"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = true
	prompt.Triggered:Connect(function(player)
		lootRequested:Fire(player, chest)
	end)
	prompt.Parent = chest
	availableLoot[chest] = index
	chest.Parent = mazeModel
end

function MazeService.claimLoot(chest)
	local index = availableLoot[chest]
	if not index or chest.Parent ~= mazeModel then return nil end
	availableLoot[chest] = nil
	local prompt = chest:FindFirstChildOfClass("ProximityPrompt")
	if prompt then prompt:Destroy() end
	task.delay(RESPAWN_TIME, function()
		spawnLoot(index)
	end)
	return chest:GetAttribute("TreasureTypeId")
end

function MazeService.start()
	if started then return end
	started = true
	local baseplate = Workspace:WaitForChild("Baseplate")
	mazeModel = Instance.new("Model")
	mazeModel.Name = "CentralMaze"
	mazeModel.Parent = Workspace
	local floor = createPart("MazeFloor", Vector3.new(82, 1, 82), Vector3.new(0, 10.5, 0), Color3.fromRGB(82, 94, 75), Enum.Material.Slate, baseplate)
	local wallColor = Color3.fromRGB(65, 75, 60)
	local function wall(name, size, x, z)
		createPart(name, size, Vector3.new(x, 17, z), wallColor, Enum.Material.Rock, baseplate)
	end
	-- Four entrances and a few readable corridors are enough for the first gameplay test.
	for _, side in { -1, 1 } do
		wall("OuterWall", Vector3.new(32, 12, 2), side * 25, -41)
		wall("OuterWall", Vector3.new(32, 12, 2), side * 25, 41)
		wall("OuterWall", Vector3.new(2, 12, 32), -41, side * 25)
		wall("OuterWall", Vector3.new(2, 12, 32), 41, side * 25)
	end
	wall("InnerWall", Vector3.new(28, 12, 2), -25, -18)
	wall("InnerWall", Vector3.new(30, 12, 2), 20, -18)
	wall("InnerWall", Vector3.new(2, 12, 28), -12, 3)
	wall("InnerWall", Vector3.new(2, 12, 24), 15, 5)
	wall("InnerWall", Vector3.new(30, 12, 2), -23, 20)
	wall("InnerWall", Vector3.new(28, 12, 2), 20, 20)
	local floorTop = floor.Position.Y + floor.Size.Y / 2
	for index, position in {
		Vector3.new(-30, floorTop + 1, -30),
		Vector3.new(30, floorTop + 1, -30),
		Vector3.new(-30, floorTop + 1, 30),
		Vector3.new(30, floorTop + 1, 30),
		Vector3.new(0, floorTop + 1, -30),
		Vector3.new(0, floorTop + 1, 30),
	} do
		spawnPoints[index] = CFrame.new(position)
		spawnLoot(index)
	end
end

return MazeService
