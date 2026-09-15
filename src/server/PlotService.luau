local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PLOT_SIZE = Vector3.new(48, 1, 48)
local GAP = 12
local GRID_SIZE = 8
local GRID_WIDTH = GRID_SIZE * PLOT_SIZE.X + (GRID_SIZE - 1) * GAP

local PlotService = {}
local plotsByUserId = {}
local occupiedSlots = {}
local characterConnections = {}
local started = false
local plotsFolder
local baseplate

local function placeCharacter(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local plot = plotsByUserId[player.UserId]
	-- The player may have left or respawned while we waited for the character.
	if not root or not plot or player.Parent ~= Players or player.Character ~= character then
		return
	end

	character:PivotTo(plot.PrimaryPart.CFrame * CFrame.new(0, PLOT_SIZE.Y / 2 + 4, 0))
end

local function assignPlot(player)
	if plotsByUserId[player.UserId] or player.Parent ~= Players then
		return
	end

	local slot
	for index = 1, GRID_SIZE * GRID_SIZE do
		if not occupiedSlots[index] then
			slot = index
			break
		end
	end
	if not slot then
		warn("No free plots for " .. player.Name .. "; waiting for a free slot.")
		return
	end

	local column = (slot - 1) % GRID_SIZE
	local row = math.floor((slot - 1) / GRID_SIZE)
	local firstCenter = -GRID_WIDTH / 2 + PLOT_SIZE.X / 2
	local plot = Instance.new("Model")
	plot.Name = "Plot_" .. player.UserId
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("SlotIndex", slot)

	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Size = PLOT_SIZE
	ground.Anchored = true
	ground.Color = Color3.fromRGB(100, 160, 90)
	ground.CFrame = baseplate.CFrame * CFrame.new(
		firstCenter + column * (PLOT_SIZE.X + GAP),
		baseplate.Size.Y / 2 + PLOT_SIZE.Y / 2,
		firstCenter + row * (PLOT_SIZE.Z + GAP)
	)
	ground.Parent = plot
	plot.PrimaryPart = ground
	plot.Parent = plotsFolder
	plotsByUserId[player.UserId] = plot
	occupiedSlots[slot] = true

	if player.Character then
		task.spawn(placeCharacter, player, player.Character)
	end
end

local function onPlayerAdded(player)
	if characterConnections[player] then
		return
	end
	characterConnections[player] = player.CharacterAdded:Connect(function(character)
		placeCharacter(player, character)
	end)
	assignPlot(player)
end

local function onPlayerRemoving(player)
	local connection = characterConnections[player]
	if connection then
		connection:Disconnect()
		characterConnections[player] = nil
	end

	local plot = plotsByUserId[player.UserId]
	if plot then
		occupiedSlots[plot:GetAttribute("SlotIndex")] = nil
		plotsByUserId[player.UserId] = nil
		plot:Destroy()
	end

	for _, remainingPlayer in Players:GetPlayers() do
		if remainingPlayer ~= player and not plotsByUserId[remainingPlayer.UserId] then
			assignPlot(remainingPlayer)
		end
	end
end

function PlotService.start()
	if started then
		return
	end
	baseplate = Workspace:WaitForChild("Baseplate")
	assert(baseplate:IsA("BasePart"), "Workspace.Baseplate must be a BasePart")
	assert(baseplate.Size.X >= GRID_WIDTH and baseplate.Size.Z >= GRID_WIDTH,
		"Baseplate is too small for the plot grid")
	started = true

	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = Workspace

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return PlotService
