local Players = game:GetService("Players")

local CarryService = {}
local carrying = {}
local treasureService
local started = false

local function disconnectRecord(record)
	if record.death then record.death:Disconnect() end
	if record.removing then record.removing:Disconnect() end
end

local function removeWelds(part)
	for _, child in part:GetChildren() do
		if child:IsA("WeldConstraint") then child:Destroy() end
	end
end

local function cancelCarry(player)
	local record = carrying[player]
	if not record then return end
	carrying[player] = nil
	player:SetAttribute("CarryingTreasureTypeId", nil)
	disconnectRecord(record)
	removeWelds(record.part)
	if record.kind == "stolen" then
		treasureService.returnStolenTreasure(record)
	elseif record.part then
		record.resolved = true
		record.part:Destroy()
	end
end

local function attach(player, payload)
	if carrying[player] or not payload or not payload.part or not payload.part.Parent then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return false end
	local part = payload.part
	removeWelds(part)
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(0, 1, -3)
	part.Parent = character
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	carrying[player] = payload
	player:SetAttribute("CarryingTreasureTypeId", payload.typeId)
	payload.death = humanoid.Died:Connect(function() cancelCarry(player) end)
	payload.removing = player.CharacterRemoving:Connect(function() cancelCarry(player) end)
	return true
end

function CarryService.canReceiveTreasure(player)
	return not carrying[player] and not player:GetAttribute("SearchRoundActive")
		and treasureService.canAcceptDelivery(player)
end

function CarryService.carryStolen(player, payload)
	if carrying[player] or not treasureService.canAcceptDelivery(player) then return false end
	return attach(player, payload)
end

function CarryService.start(plotService, resolvedTreasureService, mazeService)
	if started then return end
	started = true
	treasureService = resolvedTreasureService

	mazeService.LootRequested:Connect(function(player, chest)
		if not CarryService.canReceiveTreasure(player) then return end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 or (root.Position - chest.Position).Magnitude > 12 then return end
		local typeId = mazeService.claimLoot(player, chest)
		if not typeId then return end
		local payload = { kind = "maze", part = chest, typeId = typeId }
		if not attach(player, payload) then
			payload.resolved = true
			chest:Destroy()
		end
	end)

	local function createDepositPad(player, plot)
		if plot:FindFirstChild("DepositPad") or plotService.getPlot(player) ~= plot then return end
		local ground = plot.PrimaryPart
		if not ground then return end
		local pad = Instance.new("Part")
		pad.Name = "DepositPad"
		pad.Size = Vector3.new(8, 0.3, 6)
		pad.Anchored = true
		pad.Color = Color3.fromRGB(70, 145, 220)
		pad.Material = Enum.Material.Neon
		pad.CFrame = ground.CFrame * CFrame.new(0, ground.Size.Y / 2 + 0.15, ground.Size.Z / 2 - 6)
		pad:SetAttribute("OwnerUserId", player.UserId)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Оставить сундук"
		prompt.ObjectText = "Твой участок"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.Triggered:Connect(function(triggeringPlayer)
			if triggeringPlayer ~= player or plotService.getPlot(player) ~= plot then return end
			local record = carrying[player]
			if not record or not treasureService.acceptCarriedTreasure(player, record) then return end
			carrying[player] = nil
			player:SetAttribute("CarryingTreasureTypeId", nil)
			disconnectRecord(record)
		end)
		prompt.Parent = pad
		pad.Parent = plot
	end
	plotService.PlotAssigned:Connect(createDepositPad)
	Players.PlayerRemoving:Connect(cancelCarry)
	for _, player in Players:GetPlayers() do
		local plot = plotService.getPlot(player)
		if plot then createDepositPad(player, plot) end
	end
end

return CarryService
