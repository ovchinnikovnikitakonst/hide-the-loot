local Players = game:GetService("Players")
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local DecorationConfig = require(ReplicatedStorage.Shared.config.DecorationConfig)

local DecorationService = {}
local started = false
local lastPlacement = {}
local lastPurchase = {}
local lastPickup = {}
local shopPromptPart

local function createPart(parent, name, size, cframe, color, material, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then part.Shape = shape end
	part.Parent = parent
	return part
end

local function buildDecoration(parent, itemId, ground, x, z, onPickup)
	local model = Instance.new("Model")
	model.Name = "Decoration_" .. itemId
	model:SetAttribute("DecorationId", itemId)
	model:SetAttribute("LocalX", x)
	model:SetAttribute("LocalZ", z)
	local function at(offset)
		return ground.CFrame * CFrame.new(x + offset.X, ground.Size.Y / 2 + offset.Y, z + offset.Z)
	end
	if itemId == "bush" then
		for _, offset in { Vector3.new(-0.8, 1.1, 0), Vector3.new(0.8, 1.1, 0), Vector3.new(0, 1.6, 0.4) } do
			createPart(model, "Leaves", Vector3.new(2.4, 2.4, 2.4), at(offset), Color3.fromRGB(55, 132, 61), Enum.Material.Grass, Enum.PartType.Ball)
		end
	elseif itemId == "lamp" then
		createPart(model, "Post", Vector3.new(0.55, 5, 0.55), at(Vector3.new(0, 2.5, 0)), Color3.fromRGB(72, 61, 50), Enum.Material.Metal)
		local lightPart = createPart(model, "Light", Vector3.new(1.4, 1.4, 1.4), at(Vector3.new(0, 5.4, 0)), Color3.fromRGB(255, 206, 92), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Range = 16
		light.Brightness = 1.5
		light.Parent = lightPart
	elseif itemId == "statue" then
		createPart(model, "Base", Vector3.new(4, 1, 4), at(Vector3.new(0, 0.5, 0)), Color3.fromRGB(105, 108, 115), Enum.Material.Slate)
		createPart(model, "Pedestal", Vector3.new(2.5, 3, 2.5), at(Vector3.new(0, 2.5, 0)), Color3.fromRGB(140, 143, 150), Enum.Material.Marble)
		createPart(model, "Treasure", Vector3.new(2.8, 2.8, 2.8), at(Vector3.new(0, 5.1, 0)), Color3.fromRGB(230, 174, 52), Enum.Material.Metal, Enum.PartType.Ball)
	else
		model:Destroy()
		return nil
	end
	if onPickup then
		local interaction = createPart(model, "Interaction", Vector3.new(5, 6, 5), at(Vector3.new(0, 3, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		interaction.Transparency = 1
		interaction.CanCollide = false
		interaction.CanTouch = false
		interaction.CanQuery = false
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Забрать"
		prompt.ObjectText = DecorationConfig.items[itemId].displayName
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(player)
			onPickup(player, model)
		end)
		prompt.Parent = interaction
	end
	model.Parent = parent
	return model
end

local function getOrCreatePlayerFolder(plot)
	local folder = plot:FindFirstChild("PlayerDecorations")
	if folder then return folder end
	folder = Instance.new("Folder")
	folder.Name = "PlayerDecorations"
	folder.Parent = plot
	return folder
end

local function loadShopTemplate()
	local success, asset = pcall(function()
		return InsertService:LoadAsset(DecorationConfig.shopAssetId)
	end)
	if not success or not asset then
		warn(string.format("Decoration shop asset %d could not be loaded: %s", DecorationConfig.shopAssetId, tostring(asset)))
		return nil
	end
	for _, descendant in asset:GetDescendants() do
		if descendant:IsA("LuaSourceContainer")
			or descendant:IsA("ClickDetector")
			or descendant:IsA("ProximityPrompt") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanTouch = false
		end
	end
	if not asset:FindFirstChildWhichIsA("BasePart", true) then
		asset:Destroy()
		return nil
	end
	local size = asset:GetExtentsSize()
	if size.Y > 0 then
		asset:ScaleTo(asset:GetScale() * math.clamp(16 / size.Y, 0.02, 20))
	end
	asset:PivotTo(CFrame.identity)
	asset.Name = "DecorationShopTemplate"
	asset.Parent = ServerStorage
	return asset
end

local function buildStore(remote)
	local baseplate = Workspace:WaitForChild("Baseplate")
	local store = Instance.new("Model")
	store.Name = "DecorationStore"
	local template = loadShopTemplate()
	if template then
		local shop = template:Clone()
		local relativeBounds, size = shop:GetBoundingBox()
		local desiredBounds = baseplate.CFrame
			* CFrame.new(-250, baseplate.Size.Y / 2 + size.Y / 2, 108)
		shop.Name = "ShopModel"
		shop:PivotTo(desiredBounds * relativeBounds:Inverse())
		shop.Parent = store
	else
		local fallback = createPart(store, "FallbackShop", Vector3.new(22, 12, 18), baseplate.CFrame * CFrame.new(-250, baseplate.Size.Y / 2 + 6, 108), Color3.fromRGB(126, 89, 59), Enum.Material.WoodPlanks)
		fallback:SetAttribute("AssetLoadFailed", true)
	end

	-- This imported model faces east, so its counter/entrance is on the
	-- positive-X side.
	shopPromptPart = createPart(store, "Interaction", Vector3.new(10, 0.5, 10), baseplate.CFrame * CFrame.new(-234, baseplate.Size.Y / 2 + 0.25, 108), Color3.fromRGB(65, 164, 97), Enum.Material.Neon)
	shopPromptPart.CanCollide = false
	local marker = Instance.new("BillboardGui")
	marker.Name = "ShopMarker"
	marker.Size = UDim2.fromOffset(250, 58)
	marker.StudsOffset = Vector3.new(0, 4, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 80
	marker.Parent = shopPromptPart
	local markerText = Instance.new("TextLabel")
	markerText.Size = UDim2.fromScale(1, 1)
	markerText.BackgroundColor3 = Color3.fromRGB(24, 29, 35)
	markerText.BackgroundTransparency = 0.12
	markerText.Text = "МАГАЗИН ДЕКОРА · [E]"
	markerText.TextColor3 = Color3.fromRGB(255, 224, 126)
	markerText.TextSize = 20
	markerText.Font = Enum.Font.GothamBold
	markerText.Parent = marker
	local markerCorner = Instance.new("UICorner")
	markerCorner.CornerRadius = UDim.new(0, 9)
	markerCorner.Parent = markerText
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Открыть магазин"
	prompt.ObjectText = "Магазин декора"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - shopPromptPart.Position).Magnitude <= 22 then
			remote:FireClient(player, "OpenShop")
		end
	end)
	prompt.Parent = shopPromptPart
	store.Parent = Workspace
end

local function copyInventory(inventory)
	local copy = {}
	if type(inventory) ~= "table" then return copy end
	for _, itemId in DecorationConfig.order do
		copy[itemId] = inventory[itemId] or 0
	end
	return copy
end

function DecorationService.start(plotService, economyService, playerDataService, remote)
	if started then return end
	started = true

	local function pickupDecoration(player, model)
		local now = os.clock()
		if lastPickup[player] and now - lastPickup[player] < 0.5 then return end
		lastPickup[player] = now
		local plot = plotService.getPlot(player)
		local folder = plot and plot:FindFirstChild("PlayerDecorations")
		local interaction = model and model:FindFirstChild("Interaction")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not plot or not folder or not model or model.Parent ~= folder
			or not interaction or not root or (root.Position - interaction.Position).Magnitude > 14 then
			remote:FireClient(player, "PickupResult", false, "Можно забирать только декор со своего участка")
			return
		end
		local itemId = model:GetAttribute("DecorationId")
		local localX = model:GetAttribute("LocalX")
		local localZ = model:GetAttribute("LocalZ")
		local inventory = playerDataService.getValue(player, "decorInventory")
		local placed = playerDataService.getValue(player, "placedDecorations")
		if type(itemId) ~= "string" or not DecorationConfig.items[itemId]
			or type(localX) ~= "number" or type(localZ) ~= "number"
			or type(inventory) ~= "table" or type(placed) ~= "table" then return end
		if (inventory[itemId] or 0) >= DecorationConfig.maxOwnedPerType then
			remote:FireClient(player, "PickupResult", false, "В инвентаре уже максимум таких предметов")
			return
		end
		local recordIndex
		for index, record in placed do
			if record.id == itemId and math.abs(record.x - localX) < 0.01 and math.abs(record.z - localZ) < 0.01 then
				recordIndex = index
				break
			end
		end
		if not recordIndex then return end
		table.remove(placed, recordIndex)
		inventory[itemId] = (inventory[itemId] or 0) + 1
		playerDataService.setValue(player, "decorInventory", inventory)
		playerDataService.setValue(player, "placedDecorations", placed)
		model:Destroy()
		remote:FireClient(player, "Inventory", copyInventory(inventory))
		remote:FireClient(player, "PickupResult", true, DecorationConfig.items[itemId].displayName .. " возвращён в инвентарь")
	end

	local function restore(player, plot)
		local ground = plot.PrimaryPart
		local placed = playerDataService.getValue(player, "placedDecorations")
		if not ground or type(placed) ~= "table" then return end
		local folder = getOrCreatePlayerFolder(plot)
		for _, record in placed do
			if DecorationConfig.items[record.id] then
				buildDecoration(folder, record.id, ground, record.x, record.z, pickupDecoration)
			end
		end
	end
	plotService.PlotAssigned:Connect(restore)
	Players.PlayerRemoving:Connect(function(player)
		lastPlacement[player] = nil
		lastPurchase[player] = nil
		lastPickup[player] = nil
	end)

	remote.OnServerEvent:Connect(function(player, action, itemId, worldPosition)
		if action == "GetInventory" then
			remote:FireClient(player, "Inventory", copyInventory(playerDataService.getValue(player, "decorInventory")))
			return
		end
		if action == "Buy" then
			local now = os.clock()
			if lastPurchase[player] and now - lastPurchase[player] < 0.5 then return end
			lastPurchase[player] = now
			local definition = type(itemId) == "string" and DecorationConfig.items[itemId]
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local inventory = playerDataService.getValue(player, "decorInventory")
			if not definition or not shopPromptPart or not root
				or (root.Position - shopPromptPart.Position).Magnitude > 24 or type(inventory) ~= "table" then
				remote:FireClient(player, "PurchaseResult", false, "Подойди к магазину")
				return
			end
			local owned = inventory[itemId] or 0
			if owned >= DecorationConfig.maxOwnedPerType then
				remote:FireClient(player, "PurchaseResult", false, "Достигнут лимит этого предмета")
				return
			end
			if not economyService.trySpendCoins(player, definition.price, "decoration_purchase") then
				remote:FireClient(player, "PurchaseResult", false, "Недостаточно Coins")
				return
			end
			inventory[itemId] = owned + 1
			playerDataService.setValue(player, "decorInventory", inventory)
			remote:FireClient(player, "Inventory", copyInventory(inventory))
			remote:FireClient(player, "PurchaseResult", true, "Куплено: " .. definition.displayName)
			return
		end
		if action ~= "Place" or type(itemId) ~= "string" or typeof(worldPosition) ~= "Vector3" then return end
		local now = os.clock()
		if lastPlacement[player] and now - lastPlacement[player] < 0.5 then return end
		lastPlacement[player] = now
		local definition = DecorationConfig.items[itemId]
		local plot = plotService.getPlot(player)
		local ground = plot and plot.PrimaryPart
		local inventory = playerDataService.getValue(player, "decorInventory")
		local placed = playerDataService.getValue(player, "placedDecorations")
		if not definition or not ground or type(inventory) ~= "table" or type(placed) ~= "table" or (inventory[itemId] or 0) <= 0 then
			remote:FireClient(player, "PlacementResult", false, "Предмет недоступен")
			return
		end
		if #placed >= DecorationConfig.maxPlaced then
			remote:FireClient(player, "PlacementResult", false, "На участке уже максимум декора")
			return
		end
		local localPosition = ground.CFrame:PointToObjectSpace(worldPosition)
		local margin = 4
		if math.abs(localPosition.X) > ground.Size.X / 2 - margin or math.abs(localPosition.Z) > ground.Size.Z / 2 - margin then
			remote:FireClient(player, "PlacementResult", false, "Выбери место внутри своего участка")
			return
		end
		for _, record in placed do
			local dx = record.x - localPosition.X
			local dz = record.z - localPosition.Z
			if dx * dx + dz * dz < 16 then
				remote:FireClient(player, "PlacementResult", false, "Здесь слишком близко другой предмет")
				return
			end
		end
		local folder = getOrCreatePlayerFolder(plot)
		if not buildDecoration(folder, itemId, ground, localPosition.X, localPosition.Z, pickupDecoration) then return end
		inventory[itemId] -= 1
		table.insert(placed, { id = itemId, x = localPosition.X, z = localPosition.Z })
		playerDataService.setValue(player, "decorInventory", inventory)
		playerDataService.setValue(player, "placedDecorations", placed)
		remote:FireClient(player, "Inventory", copyInventory(inventory))
		remote:FireClient(player, "PlacementResult", true, definition.displayName .. " установлен")
	end)

	buildStore(remote)
	for _, player in Players:GetPlayers() do
		local plot = plotService.getPlot(player)
		if plot then restore(player, plot) end
	end
end

return DecorationService
