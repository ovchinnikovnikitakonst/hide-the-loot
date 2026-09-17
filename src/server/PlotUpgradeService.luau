local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(game:GetService("ReplicatedStorage").Shared.config.PlotConfig)

local PlotUpgradeService = {}
local started = false
local purchased = {}
local lastRequest = {}
local assetTemplates = {}
local failedAssets = {}

local TARGET_FENCE_HEIGHT = 3.8
local TARGET_LAMP_HEIGHT = 6
local TARGET_GATE_HEIGHT = 7.5
local GATE_HALF_WIDTH = 5

local function createPart(parent, ground, name, size, offset, color, material)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.Anchored = true
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	object.CFrame = ground.CFrame * CFrame.new(offset)
	object.Parent = parent
	return object
end

local function loadAssetTemplate(assetId, targetHeight)
	if assetTemplates[assetId] then return assetTemplates[assetId] end
	if failedAssets[assetId] then return nil end

	local success, asset = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not success or not asset then
		failedAssets[assetId] = true
		warn(string.format("Plot asset %d could not be loaded: %s", assetId, tostring(asset)))
		return nil
	end

	for _, descendant in asset:GetDescendants() do
		if descendant:IsA("LuaSourceContainer")
			or descendant:IsA("ClickDetector")
			or descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = true
			descendant.CanTouch = false
		end
	end

	if not asset:FindFirstChildWhichIsA("BasePart", true) then
		failedAssets[assetId] = true
		asset:Destroy()
		warn(string.format("Plot asset %d contains no geometry", assetId))
		return nil
	end

	asset.Name = "PlotAsset_" .. assetId
	local initialSize = asset:GetExtentsSize()
	if initialSize.Y <= 0 then
		failedAssets[assetId] = true
		asset:Destroy()
		return nil
	end
	asset:ScaleTo(asset:GetScale() * math.clamp(targetHeight / initialSize.Y, 0.02, 20))
	asset:PivotTo(CFrame.identity)
	asset.Parent = ServerStorage
	assetTemplates[assetId] = asset
	return asset
end

local function buildSimpleFence(fence, ground)
	local half = ground.Size.X / 2 + 0.5
	local wood = Color3.fromRGB(126, 89, 59)
	local function fencePart(name, size, x, y, z)
		return createPart(fence, ground, name, size, Vector3.new(x, y, z), wood, Enum.Material.Wood)
	end
	local function post(x, z, name)
		fencePart(name or "Post", Vector3.new(0.8, 3.4, 0.8), x, 1.7, z)
		local cap = fencePart("PostCap", Vector3.new(1.05, 1.05, 1.05), x, 3.55, z)
		cap.Shape = Enum.PartType.Ball
	end
	for x = -half, half, 8 do post(x, -half) end
	post(half, -half)
	for _, x in { -half, half } do
		for z = -half + 8, half, 8 do post(x, math.min(z, half)) end
	end
	for x = -half, -GATE_HALF_WIDTH - 2, 8 do post(x, half) end
	for x = GATE_HALF_WIDTH + 2, half, 8 do post(x, half) end
	post(-GATE_HALF_WIDTH, half, "GatePost")
	post(GATE_HALF_WIDTH, half, "GatePost")
	post(-half, half)
	post(half, half)
	for _, y in { 1.15, 2.55 } do
		fencePart("BackRail", Vector3.new(half * 2, 0.4, 0.4), 0, y, -half)
		for _, x in { -half, half } do fencePart("SideRail", Vector3.new(0.4, 0.4, half * 2), x, y, 0) end
		local length = half - GATE_HALF_WIDTH
		for _, direction in { -1, 1 } do
			fencePart("FrontRail", Vector3.new(length, 0.4, 0.4), direction * (half + GATE_HALF_WIDTH) / 2, y, half)
		end
	end
end

local function buildAssetFence(fence, ground, assetId)
	local template = loadAssetTemplate(assetId, TARGET_FENCE_HEIGHT)
	if not template then return false end

	local relativeBounds, boundsSize = template:GetBoundingBox()
	local segmentLength = math.max(boundsSize.X, boundsSize.Z)
	if segmentLength <= 0 then return false end
	local baseRotation = boundsSize.Z > boundsSize.X and math.pi / 2 or 0
	local half = ground.Size.X / 2 + 0.5
	local height = ground.Size.Y / 2 + boundsSize.Y / 2

	local function placeSpan(x1, z1, x2, z2)
		local dx = x2 - x1
		local dz = z2 - z1
		local length = math.sqrt(dx * dx + dz * dz)
		local count = math.max(1, math.ceil(length / (segmentLength * 0.94)))
		local angle = math.atan2(dz, dx) + baseRotation
		for index = 1, count do
			local alpha = (index - 0.5) / count
			local x = x1 + dx * alpha
			local z = z1 + dz * alpha
			local desiredBounds = ground.CFrame
				* CFrame.new(x, height, z)
				* CFrame.Angles(0, angle, 0)
			local segment = template:Clone()
			segment.Name = "FenceSegment"
			segment:PivotTo(desiredBounds * relativeBounds:Inverse())
			segment.Parent = fence
		end
	end

	placeSpan(-half, -half, half, -half)
	placeSpan(-half, -half, -half, half)
	placeSpan(half, -half, half, half)
	placeSpan(-half, half, -GATE_HALF_WIDTH, half)
	placeSpan(GATE_HALF_WIDTH, half, half, half)
	fence:SetAttribute("AssetId", assetId)
	return true
end

local function buildFence(plot, ground, level)
	local oldFence = plot:FindFirstChild("Fence")
	if oldFence then oldFence:Destroy() end
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	local assetId = Config.levels[level].fenceAssetId
	if not assetId or not buildAssetFence(fence, ground, assetId) then
		buildSimpleFence(fence, ground)
	end
	fence.Parent = plot
end

local function placeAsset(parent, ground, assetId, name, x, z, targetHeight, alignLongestWithX)
	local template = loadAssetTemplate(assetId, targetHeight)
	if not template then return nil end

	local relativeBounds, boundsSize = template:GetBoundingBox()
	local rotation = 0
	if alignLongestWithX and boundsSize.Z > boundsSize.X then
		rotation = math.pi / 2
	end
	local desiredBounds = ground.CFrame
		* CFrame.new(x, ground.Size.Y / 2 + boundsSize.Y / 2, z)
		* CFrame.Angles(0, rotation, 0)
	local instance = template:Clone()
	instance.Name = name
	instance:PivotTo(desiredBounds * relativeBounds:Inverse())
	instance.Parent = parent
	return instance
end

local function buildDecorations(plot, ground, level)
	local old = plot:FindFirstChild("Decorations")
	if old then old:Destroy() end
	local decorations = Instance.new("Model")
	decorations.Name = "Decorations"
	decorations:SetAttribute("BuiltForLevel", level)
	local edge = ground.Size.X / 2 - 3

	if level >= 3 then
		for _, x in { -edge + 2.5, edge - 2.5 } do
			for _, offset in { Vector3.new(-0.8, 0, 0), Vector3.new(0.8, 0, 0), Vector3.new(0, 0.7, 0.4) } do
				local bush = createPart(decorations, ground, "Bush", Vector3.new(2.2, 2.2, 2.2), Vector3.new(x, 1.1, -edge + 2) + offset, Color3.fromRGB(65, 135, 65), Enum.Material.Grass)
				bush.Shape = Enum.PartType.Ball
			end
		end
	end

	if level >= 5 then
		local treeX = edge - 7
		local treeZ = -edge + 9
		createPart(decorations, ground, "TreeTrunk", Vector3.new(2, 7, 2), Vector3.new(treeX, 3.5, treeZ), Color3.fromRGB(105, 70, 45), Enum.Material.Wood)
		for _, offset in { Vector3.new(0, 8, 0), Vector3.new(-2.5, 7, 0), Vector3.new(2.5, 7, 0) } do
			local crown = createPart(decorations, ground, "TreeCrown", Vector3.new(5.5, 5.5, 5.5), Vector3.new(treeX, 0, treeZ) + offset, Color3.fromRGB(55, 125, 55), Enum.Material.Grass)
			crown.Shape = Enum.PartType.Ball
		end
	end

	local levelConfig = Config.levels[level]
	local entranceZ = ground.Size.Z / 2 + 0.5
	local lampZ = ground.Size.Z / 2 - 2.5
	placeAsset(decorations, ground, levelConfig.gateAssetId, "EntranceGate", 0, entranceZ, TARGET_GATE_HEIGHT, true)
	for _, x in { -7, 7 } do
		placeAsset(decorations, ground, levelConfig.lampAssetId, "EntranceLamp", x, lampZ, TARGET_LAMP_HEIGHT, false)
	end
	decorations.Parent = plot
end

function PlotUpgradeService.start(plotService, economyService, remote, playerDataService)
	if started then return end
	started = true

	local function applyLevel(player, plot, level)
		if plotService.getPlot(player) ~= plot or not plot.Parent then return false end
		local ground = plot.PrimaryPart
		if not ground then return false end
		local size = Config.levels[level].size
		ground.Size = Vector3.new(size, ground.Size.Y, size)
		plot:SetAttribute("PlotLevel", level)
		plot:SetAttribute("TreasureCapacity", Config.levels[level].treasureCapacity)
		if plot:GetAttribute("TreasureCount") == nil then plot:SetAttribute("TreasureCount", 0) end
		if plot:GetAttribute("BuriedTreasureCount") == nil then plot:SetAttribute("BuriedTreasureCount", 0) end
		buildFence(plot, ground, level)
		buildDecorations(plot, ground, level)
		for _, name in { "ShopSign", "PlotUpgradeSign" } do
			local sign = plot:FindFirstChild(name)
			if sign then
				sign.CFrame = ground.CFrame * CFrame.new(name == "ShopSign" and -8 or 8, 2.75, size / 2 + 2.3) * CFrame.Angles(0, math.pi, 0)
			end
		end
		local depositPad = plot:FindFirstChild("DepositPad")
		if depositPad then
			depositPad.CFrame = ground.CFrame * CFrame.new(0, ground.Size.Y / 2 + 0.15, size / 2 - 6)
		end
		return true
	end

	function PlotUpgradeService.applyPending(player, plot)
		local level = purchased[player] or 1
		if plot:GetAttribute("PlotLevel") ~= level then applyLevel(player, plot, level) end
	end

	local function added(player)
		if purchased[player] then return end
		local savedLevel = playerDataService.getValue(player, "plotLevel")
		if savedLevel == nil then return end
		purchased[player] = math.clamp(savedLevel, 1, #Config.levels)
		player:SetAttribute("PurchasedPlotLevel", purchased[player])
	end
	playerDataService.DataLoaded:Connect(added)
	Players.PlayerRemoving:Connect(function(player)
		purchased[player] = nil
		lastRequest[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if playerDataService.isLoaded(player) then added(player) end
	end

	remote.OnServerEvent:Connect(function(player, sign)
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < 1 then
			remote:FireClient(player, false, "Подожди секунду") return
		end
		lastRequest[player] = now
		local plot = plotService.getPlot(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not plot or not sign or plot:FindFirstChild("PlotUpgradeSign") ~= sign
			or not root or not humanoid or humanoid.Health <= 0 or (root.Position - sign.Position).Magnitude > 16 then
			remote:FireClient(player, false, "Подойди к своей табличке") return
		end
		if plot:GetAttribute("SearchBusy") then
			remote:FireClient(player, false, "Дождись завершения поиска") return
		end
		local level = purchased[player]
		local nextLevel = level and Config.levels[level + 1]
		if not nextLevel then remote:FireClient(player, false, "Максимальный уровень") return end
		if not economyService.trySpendCoins(player, nextLevel.upgradePrice, "plot_upgrade") then
			remote:FireClient(player, false, "Недостаточно Coins") return
		end
		purchased[player] = level + 1
		player:SetAttribute("PurchasedPlotLevel", level + 1)
		playerDataService.setValue(player, "plotLevel", level + 1)
		if not applyLevel(player, plot, level + 1) then
			warn("Purchased plot level could not be applied for " .. player.Name)
		end
		remote:FireClient(player, true, "Участок улучшен до уровня " .. (level + 1))
	end)

	local function buildInitial(player, plot)
		applyLevel(player, plot, purchased[player] or 1)
	end
	plotService.PlotAssigned:Connect(buildInitial)
	for _, player in Players:GetPlayers() do
		local plot = plotService.getPlot(player)
		if plot then buildInitial(player, plot) end
	end
end

return PlotUpgradeService
