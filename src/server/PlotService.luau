local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PlotConfig = require(game:GetService("ReplicatedStorage").Shared.config.PlotConfig)
local PLOT_SIZE = Vector3.new(PlotConfig.levels[1].size, 1, PlotConfig.levels[1].size)

local plotAssigned = Instance.new("BindableEvent")
local plotRemoving = Instance.new("BindableEvent")

local PlotService = {
	PlotAssigned = plotAssigned.Event,
	PlotRemoving = plotRemoving.Event,
}
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
	for index = 1, #PlotConfig.positions do
		if not occupiedSlots[index] then
			slot = index
			break
		end
	end
	if not slot then
		warn("No free plots for " .. player.Name .. "; waiting for a free slot.")
		return
	end

	local position = PlotConfig.positions[slot]
	local plot = Instance.new("Model")
	plot.Name = "Plot_" .. player.UserId
	plot:SetAttribute("OwnerUserId", player.UserId)
	plot:SetAttribute("SlotIndex", slot)
	plot:SetAttribute("PlotLevel", 1)

	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Size = PLOT_SIZE
	ground.Anchored = true
	ground.Color = Color3.fromRGB(100, 160, 90)
	ground.CFrame = baseplate.CFrame * CFrame.new(
		position.X,
		baseplate.Size.Y / 2 + PLOT_SIZE.Y / 2,
		position.Z
	) * CFrame.Angles(0, math.pi / 2, 0)
	ground.Parent = plot
	plot.PrimaryPart = ground
	plot.Parent = plotsFolder
	plotsByUserId[player.UserId] = plot
	occupiedSlots[slot] = true
	plotAssigned:Fire(player, plot)

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
		plotRemoving:Fire(player, plot)
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

function PlotService.getPlot(player)
	return plotsByUserId[player.UserId]
end

function PlotService.start()
	if started then
		return
	end
	baseplate = Workspace:WaitForChild("Baseplate")
	assert(baseplate:IsA("BasePart"), "Workspace.Baseplate must be a BasePart")
	-- Studio can start a test before a changed project property finishes syncing.
	-- Enforce the gameplay map size on the server before validating plot positions.
	baseplate.Size = Vector3.new(PlotConfig.mapSize.X, baseplate.Size.Y, PlotConfig.mapSize.Y)
	local requiredHalfSize = PlotConfig.levels[#PlotConfig.levels].size / 2 + 8
	for _, position in PlotConfig.positions do
		assert(math.abs(position.X) + requiredHalfSize <= baseplate.Size.X / 2
			and math.abs(position.Z) + requiredHalfSize <= baseplate.Size.Z / 2,
			"Baseplate is too small for the configured plot positions")
	end
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
