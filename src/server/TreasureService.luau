local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local TREASURE_SIZE = Vector3.new(3, 2, 3)

local TreasureService = {}
local treasuresByUserId = {}
local started = false

function TreasureService.canSearch(plot)
	if typeof(plot) ~= "Instance" or not plot:IsA("Model") then
		return false
	end
	local record = treasuresByUserId[plot:GetAttribute("OwnerUserId")]
	return record ~= nil and record.plot == plot and plot.Parent ~= nil and record.buried == true and not record.found
end

function TreasureService.start(plotService, buryTreasure)
	if started then
		return
	end
	started = true
	local hidden = Instance.new("Folder")
	hidden.Name = "BuriedTreasures"
	hidden.Parent = ServerStorage
	function TreasureService.tryDig(player, plot, position)
		if typeof(plot) ~= "Instance" or not plot:IsA("Model") or typeof(position) ~= "Vector3" then
			return "rejected"
		end
		for _, value in { position.X, position.Y, position.Z } do
			if value ~= value or math.abs(value) == math.huge then
				return "rejected"
			end
		end
		local ownerId = plot:GetAttribute("OwnerUserId")
		local record = ownerId and treasuresByUserId[ownerId]
		local owner = typeof(ownerId) == "number" and Players:GetPlayerByUserId(ownerId)
		if not record or record.plot ~= plot or not owner or plotService.getPlot(owner) ~= plot
			or owner == player or not plot.Parent or not record.buried or record.found then
			return "rejected"
		end
		local ground = plot.PrimaryPart
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not ground or not root or not humanoid or humanoid.Health <= 0 then
			return "rejected"
		end
		local target = ground.CFrame:PointToObjectSpace(position)
		local standing = ground.CFrame:PointToObjectSpace(root.Position)
		local half = ground.Size / 2
		if math.abs(target.X) > half.X or math.abs(target.Z) > half.Z
			or math.abs(target.Y - half.Y) > 0.2
			or math.abs(standing.X) > half.X or math.abs(standing.Z) > half.Z
			or standing.Y < half.Y or standing.Y > half.Y + 10 then
			return "rejected"
		end
		local offset = target - record.buriedPosition
		if offset.X * offset.X + offset.Z * offset.Z > 3 * 3 then
			return "miss"
		end
		-- No yields between checking and marking found: only one attempt can win.
		record.found = true
		record.treasure.CFrame = ground.CFrame * CFrame.new(
			record.buriedPosition.X, half.Y + TREASURE_SIZE.Y / 2, record.buriedPosition.Z
		)
		record.treasure:SetAttribute("IsBuried", false)
		record.treasure:SetAttribute("IsFound", true)
		record.treasure.Parent = plot
		plot:SetAttribute("HasBuriedTreasure", false)
		return "found"
	end

	buryTreasure.OnServerEvent:Connect(function(player, position)
		local record = treasuresByUserId[player.UserId]
		if not record then
			buryTreasure:FireClient(player, false)
			return
		end
		local now = os.clock()
		if record.lastRequest and now - record.lastRequest < 0.25 then
			return
		end
		record.lastRequest = now

		local function reject()
			buryTreasure:FireClient(player, false)
		end
		if typeof(position) ~= "Vector3" then
			reject()
			return
		end
		for _, value in { position.X, position.Y, position.Z } do
			if value ~= value or math.abs(value) == math.huge then
				reject()
				return
			end
		end
		local plot = plotService.getPlot(player)
		if plot ~= record.plot or not plot.Parent or record.buried
			or record.treasure:GetAttribute("OwnerUserId") ~= player.UserId then
			reject()
			return
		end
		local ground = plot.PrimaryPart
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not ground or not root or not humanoid or humanoid.Health <= 0 then
			reject()
			return
		end
		local target = ground.CFrame:PointToObjectSpace(position)
		local standing = ground.CFrame:PointToObjectSpace(root.Position)
		local half = ground.Size / 2
		if math.abs(target.X) > half.X - TREASURE_SIZE.X / 2
			or math.abs(target.Z) > half.Z - TREASURE_SIZE.Z / 2
			or math.abs(target.Y - half.Y) > 0.2
			or math.abs(standing.X) > half.X or math.abs(standing.Z) > half.Z
			or standing.Y < half.Y or standing.Y > half.Y + 10 then
			reject()
			return
		end
		record.buried = true
		record.buriedPosition = target
		-- Remove from replication BEFORE writing the hidden coordinates.
		record.treasure.Parent = hidden
		record.treasure.CFrame = ground.CFrame * CFrame.new(
			target.X, half.Y - TREASURE_SIZE.Y / 2 - 0.5, target.Z
		)
		record.treasure:SetAttribute("IsBuried", true)
		plot:SetAttribute("HasBuriedTreasure", true)
		buryTreasure:FireClient(player, true)
	end)

	local function createTreasure(player, plot)
		-- An assignment notification can arrive after the plot has been removed.
		if not plot.Parent or plotService.getPlot(player) ~= plot then
			return
		end
		local existing = treasuresByUserId[player.UserId]
		if existing and existing.plot == plot then
			return
		end

		local ground = plot.PrimaryPart
		if not ground then
			return
		end

		local treasure = Instance.new("Part")
		treasure.Name = "Treasure"
		treasure.Size = TREASURE_SIZE
		treasure.Anchored = true
		-- The character also spawns at the center; the placeholder must not block it.
		treasure.CanCollide = false
		treasure.Color = Color3.fromRGB(255, 195, 45)
		treasure.Material = Enum.Material.Metal
		treasure.CFrame = ground.CFrame * CFrame.new(0, ground.Size.Y / 2 + TREASURE_SIZE.Y / 2, 0)
		treasure:SetAttribute("OwnerUserId", player.UserId)
		treasure:SetAttribute("IsBuried", false)
		treasure:SetAttribute("IsFound", false)
		plot:SetAttribute("HasBuriedTreasure", false)
		treasure.Parent = plot
		treasuresByUserId[player.UserId] = { plot = plot, treasure = treasure }
	end

	function TreasureService.resetTreasure(player, plot)
		if player.Parent ~= Players or not plot.Parent or plotService.getPlot(player) ~= plot
			or not plot.PrimaryPart then
			return false
		end
		local existing = treasuresByUserId[player.UserId]
		if not existing or existing.plot ~= plot then
			return false
		end
		existing.treasure:Destroy()
		treasuresByUserId[player.UserId] = nil
		createTreasure(player, plot)
		return treasuresByUserId[player.UserId] ~= nil
	end

	plotService.PlotAssigned:Connect(createTreasure)
	plotService.PlotRemoving:Connect(function(player, plot)
		local existing = treasuresByUserId[player.UserId]
		-- Only clear this plot's record, even if a newer assignment already exists.
		if existing and existing.plot == plot then
			existing.treasure:Destroy()
			treasuresByUserId[player.UserId] = nil
		end
		-- Hidden treasures live outside the plot and must also be destroyed.
	end)

	for _, player in Players:GetPlayers() do
		local plot = plotService.getPlot(player)
		if plot then
			createTreasure(player, plot)
		end
	end
end

return TreasureService
