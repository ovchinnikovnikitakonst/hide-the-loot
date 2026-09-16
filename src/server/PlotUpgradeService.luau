local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.config.PlotConfig)

local PlotUpgradeService = {}
local started = false
local purchased = {}
local lastRequest = {}

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

local function buildFence(plot, ground)
	local oldFence = plot:FindFirstChild("Fence")
	if oldFence then oldFence:Destroy() end
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	local half = ground.Size.X / 2 + 0.5
	local wood = Color3.fromRGB(126, 89, 59)
	local function fencePart(name, size, x, y, z)
		createPart(fence, ground, name, size, Vector3.new(x, y, z), wood, Enum.Material.Wood)
	end
	for _, x in { -half, half } do
		for _, z in { -half, half } do fencePart("Post", Vector3.new(1, 4, 1), x, 2, z) end
	end
	for _, x in { -4.5, 4.5 } do fencePart("GatePost", Vector3.new(1, 4, 1), x, 2, half) end
	for _, y in { 1.3, 3 } do
		fencePart("BackRail", Vector3.new(half * 2, 0.6, 0.6), 0, y, -half)
		for _, x in { -half, half } do fencePart("SideRail", Vector3.new(0.6, 0.6, half * 2), x, y, 0) end
		local length = half - 4.5
		for _, direction in { -1, 1 } do
			fencePart("FrontRail", Vector3.new(length, 0.6, 0.6), direction * (half + 4.5) / 2, y, half)
		end
	end
	fence.Parent = plot
end

local function buildDecorations(plot, ground, level)
	local old = plot:FindFirstChild("Decorations")
	if old then old:Destroy() end
	local decorations = Instance.new("Model")
	decorations.Name = "Decorations"
	decorations:SetAttribute("BuiltForLevel", level)
	local edge = ground.Size.X / 2 - 3
	local wood = Color3.fromRGB(126, 89, 59)
	local stone = Color3.fromRGB(125, 130, 135)

	if level >= 2 then
		for _, x in { -7, 7 } do
			createPart(decorations, ground, "LampPost", Vector3.new(0.7, 5, 0.7), Vector3.new(x, 2.5, edge), wood, Enum.Material.Wood)
			local lamp = createPart(decorations, ground, "Lamp", Vector3.new(1.5, 1.5, 1.5), Vector3.new(x, 5.3, edge), Color3.fromRGB(255, 210, 90), Enum.Material.Neon)
			local light = Instance.new("PointLight")
			light.Range = 14
			light.Brightness = 1.5
			light.Parent = lamp
		end
		createPart(decorations, ground, "Crate", Vector3.new(3, 3, 3), Vector3.new(-edge, 1.5, -edge + 2), wood, Enum.Material.WoodPlanks)
		local barrel = createPart(decorations, ground, "Barrel", Vector3.new(3, 3, 3), Vector3.new(edge, 1.5, -edge + 2), Color3.fromRGB(105, 72, 48), Enum.Material.Wood)
		barrel.Shape = Enum.PartType.Cylinder
		barrel.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
	end

	if level >= 3 then
		for z = 4, math.max(4, edge - 5), 5 do
			createPart(decorations, ground, "PathStone", Vector3.new(4, 0.2, 3), Vector3.new(0, 0.6, z), stone, Enum.Material.Slate)
		end
		createPart(decorations, ground, "BenchSeat", Vector3.new(7, 0.6, 2), Vector3.new(-edge + 3, 2, 0), wood, Enum.Material.WoodPlanks)
		createPart(decorations, ground, "BenchBack", Vector3.new(7, 3, 0.5), Vector3.new(-edge + 3, 3.2, -1), wood, Enum.Material.WoodPlanks)
		for _, z in { -8, 8 } do
			local bush = createPart(decorations, ground, "Bush", Vector3.new(3.5, 3.5, 3.5), Vector3.new(edge - 1, 1.8, z), Color3.fromRGB(65, 135, 65), Enum.Material.Grass)
			bush.Shape = Enum.PartType.Ball
		end
	end

	if level >= 4 then
		local x = -edge + 5
		local z = -edge + 5
		for _, dx in { -4, 4 } do
			for _, dz in { -3, 3 } do
				createPart(decorations, ground, "CanopyPost", Vector3.new(0.6, 6, 0.6), Vector3.new(x + dx, 3, z + dz), wood, Enum.Material.Wood)
			end
		end
		createPart(decorations, ground, "CanopyRoof", Vector3.new(10, 0.7, 8), Vector3.new(x, 6.3, z), Color3.fromRGB(175, 70, 55), Enum.Material.Fabric)
		createPart(decorations, ground, "WorkTable", Vector3.new(6, 2.5, 3), Vector3.new(x, 1.3, z), wood, Enum.Material.WoodPlanks)
		createPart(decorations, ground, "ToolRack", Vector3.new(1, 5, 7), Vector3.new(edge - 1, 2.5, -8), Color3.fromRGB(80, 82, 86), Enum.Material.Metal)
	end

	if level >= 5 then
		createPart(decorations, ground, "FountainBase", Vector3.new(9, 1, 9), Vector3.new(0, 0.8, -edge + 6), stone, Enum.Material.Marble)
		local water = createPart(decorations, ground, "FountainWater", Vector3.new(6, 0.4, 6), Vector3.new(0, 1.5, -edge + 6), Color3.fromRGB(70, 170, 235), Enum.Material.Glass)
		water.Transparency = 0.25
		for _, x in { -edge + 4, edge - 4 } do
			createPart(decorations, ground, "TreeTrunk", Vector3.new(2, 7, 2), Vector3.new(x, 3.5, 10), Color3.fromRGB(105, 70, 45), Enum.Material.Wood)
			local crown = createPart(decorations, ground, "TreeCrown", Vector3.new(7, 7, 7), Vector3.new(x, 8, 10), Color3.fromRGB(55, 125, 55), Enum.Material.Grass)
			crown.Shape = Enum.PartType.Ball
		end
		for _, x in { -edge + 2, edge - 2 } do
			createPart(decorations, ground, "FlagPole", Vector3.new(0.5, 8, 0.5), Vector3.new(x, 4, edge - 1), Color3.fromRGB(80, 80, 85), Enum.Material.Metal)
			createPart(decorations, ground, "Flag", Vector3.new(3, 2, 0.2), Vector3.new(x + (x < 0 and 1.5 or -1.5), 7, edge - 1), Color3.fromRGB(245, 185, 35), Enum.Material.Fabric)
		end
	end

	if level >= 6 then
		for _, x in { -4.5, 4.5 } do
			createPart(decorations, ground, "GateTower", Vector3.new(2.5, 8, 2.5), Vector3.new(x, 4, edge + 0.5), stone, Enum.Material.Marble)
		end
		createPart(decorations, ground, "GateArch", Vector3.new(11, 2, 2), Vector3.new(0, 8, edge + 0.5), Color3.fromRGB(205, 175, 75), Enum.Material.Metal)
		for _, x in { -edge + 3, edge - 3 } do
			createPart(decorations, ground, "StatueBase", Vector3.new(4, 1.5, 4), Vector3.new(x, 0.8, -6), stone, Enum.Material.Marble)
			local statue = createPart(decorations, ground, "Statue", Vector3.new(3, 5, 3), Vector3.new(x, 4, -6), Color3.fromRGB(210, 190, 95), Enum.Material.Metal)
			statue.Shape = Enum.PartType.Ball
		end
		local jewel = createPart(decorations, ground, "CrownJewel", Vector3.new(3, 3, 3), Vector3.new(0, 4, -edge + 6), Color3.fromRGB(155, 70, 255), Enum.Material.Neon)
		jewel.Shape = Enum.PartType.Ball
	end
	decorations.Parent = plot
end

function PlotUpgradeService.start(plotService, economyService, remote)
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
		buildFence(plot, ground)
		buildDecorations(plot, ground, level)
		for _, name in { "ShopSign", "PlotUpgradeSign" } do
			local sign = plot:FindFirstChild(name)
			if sign then
				sign.CFrame = ground.CFrame * CFrame.new(name == "ShopSign" and -9 or 9, 3.5, size / 2 + 4) * CFrame.Angles(0, math.pi, 0)
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
		purchased[player] = 1
		player:SetAttribute("PurchasedPlotLevel", 1)
	end
	Players.PlayerAdded:Connect(added)
	Players.PlayerRemoving:Connect(function(player)
		purchased[player] = nil
		lastRequest[player] = nil
	end)
	for _, player in Players:GetPlayers() do added(player) end

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
