local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local DecorationConfig = require(ReplicatedStorage.Shared.config.DecorationConfig)

local DecorationController = {}

local PREVIEW_VALID_COLOR = Color3.fromRGB(64, 220, 104)
local PREVIEW_INVALID_COLOR = Color3.fromRGB(232, 67, 67)

local function buildDecorationVisual(itemId, isPlacementPreview)
	local model = Instance.new("Model")
	model.Name = isPlacementPreview and "DecorationPreview" or "DecorationDisplay"
	local parts = {}
	local function part(name, size, offset, color, material, shape)
		local object = Instance.new("Part")
		object.Name = name
		object.Size = size
		object.Anchored = true
		object.CanCollide = false
		object.CanTouch = false
		object.CanQuery = false
		object.CastShadow = false
		object.Color = color
		object.Material = isPlacementPreview and Enum.Material.ForceField or material
		object.Transparency = isPlacementPreview and 0.42 or 0
		object.CFrame = CFrame.new(offset)
		if shape then object.Shape = shape end
		object.Parent = model
		table.insert(parts, { object = object, offset = offset })
	end
	if itemId == "bush" then
		for _, offset in { Vector3.new(-0.8, 1.1, 0), Vector3.new(0.8, 1.1, 0), Vector3.new(0, 1.6, 0.4) } do
			part("Leaves", Vector3.new(2.4, 2.4, 2.4), offset, Color3.fromRGB(55, 132, 61), Enum.Material.Grass, Enum.PartType.Ball)
		end
	elseif itemId == "lamp" then
		part("Post", Vector3.new(0.55, 5, 0.55), Vector3.new(0, 2.5, 0), Color3.fromRGB(72, 61, 50), Enum.Material.Metal)
		part("Light", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 5.4, 0), Color3.fromRGB(255, 206, 92), Enum.Material.Neon)
	elseif itemId == "statue" then
		part("Base", Vector3.new(4, 1, 4), Vector3.new(0, 0.5, 0), Color3.fromRGB(105, 108, 115), Enum.Material.Slate)
		part("Pedestal", Vector3.new(2.5, 3, 2.5), Vector3.new(0, 2.5, 0), Color3.fromRGB(140, 143, 150), Enum.Material.Marble)
		part("Treasure", Vector3.new(2.8, 2.8, 2.8), Vector3.new(0, 5.1, 0), Color3.fromRGB(230, 174, 52), Enum.Material.Metal, Enum.PartType.Ball)
	else
		model:Destroy()
		return nil
	end
	return { model = model, parts = parts }
end

local function buildPreview(itemId)
	local visual = buildDecorationVisual(itemId, true)
	if visual then visual.model.Parent = Workspace end
	return visual
end

local function updatePreview(preview, ground, localX, localZ, isValid)
	local color = isValid and PREVIEW_VALID_COLOR or PREVIEW_INVALID_COLOR
	for _, entry in preview.parts do
		local offset = entry.offset
		entry.object.Color = color
		entry.object.CFrame = ground.CFrame * CFrame.new(
			localX + offset.X,
			ground.Size.Y / 2 + offset.Y,
			localZ + offset.Z
		)
	end
end

local function makeButton(parent, text, size, position)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.BackgroundColor3 = Color3.fromRGB(55, 126, 86)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = text
	button.TextSize = 16
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

local function makePanel(gui, name, titleText)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(480, 390)
	panel.BackgroundColor3 = Color3.fromRGB(25, 29, 36)
	panel.BackgroundTransparency = 0.04
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(20, 10)
	title.Size = UDim2.new(1, -75, 0, 44)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(255, 221, 125)
	title.TextSize = 23
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.Parent = panel

	local close = makeButton(panel, "×", UDim2.fromOffset(40, 40), UDim2.new(1, -52, 0, 10))
	close.BackgroundColor3 = Color3.fromRGB(109, 55, 58)

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(16, 64)
	list.Size = UDim2.new(1, -32, 1, -80)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 7
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.Parent = list
	close.Activated:Connect(function() panel.Visible = false end)
	return panel, list
end

local function addItemViewport(parent, itemId)
	local viewport = Instance.new("ViewportFrame")
	viewport.Position = UDim2.fromOffset(7, 6)
	viewport.Size = UDim2.fromOffset(64, 64)
	viewport.BackgroundColor3 = Color3.fromRGB(29, 34, 41)
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(185, 185, 185)
	viewport.LightColor = Color3.fromRGB(255, 244, 220)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = viewport

	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local visual = buildDecorationVisual(itemId, false)
	if not visual then return end
	visual.model.Parent = world
	local bounds, size = visual.model:GetBoundingBox()
	local distance = math.max(size.X, size.Y, size.Z) * 1.55
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(
		bounds.Position + Vector3.new(distance * 0.75, distance * 0.42, distance),
		bounds.Position
	)
	camera.FieldOfView = 38
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

local function makeItemRow(parent, definition, actionText)
	local row = Instance.new("Frame")
	row.Name = definition.id
	row.Size = UDim2.new(1, -8, 0, 76)
	row.BackgroundColor3 = Color3.fromRGB(39, 45, 54)
	row.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = row
	addItemViewport(row, definition.id)

	local name = Instance.new("TextLabel")
	name.Position = UDim2.fromOffset(82, 8)
	name.Size = UDim2.new(1, -242, 0, 30)
	name.BackgroundTransparency = 1
	name.Text = definition.displayName
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextSize = 18
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.GothamBold
	name.Parent = row

	local info = Instance.new("TextLabel")
	info.Name = "Info"
	info.Position = UDim2.fromOffset(82, 39)
	info.Size = UDim2.new(1, -242, 0, 25)
	info.BackgroundTransparency = 1
	info.TextColor3 = Color3.fromRGB(193, 199, 209)
	info.TextSize = 15
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.Font = Enum.Font.Gotham
	info.Parent = row

	local button = makeButton(row, actionText, UDim2.fromOffset(132, 44), UDim2.new(1, -146, 0.5, -22))
	return info, button
end

function DecorationController.start(onActivate)
	local player = Players.LocalPlayer
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DecorationAction")
	local mouse = player:GetMouse()
	local selectedItemId
	local placing = false
	local inventory = {}
	local preview
	local previewValid = false
	local previewPosition
	local previewValidityState
	local plots = Workspace:WaitForChild("Plots")

	local gui = Instance.new("ScreenGui")
	gui.Name = "DecorationInterface"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local message = Instance.new("TextLabel")
	message.AnchorPoint = Vector2.new(0.5, 0)
	message.Position = UDim2.fromScale(0.5, 0.08)
	message.Size = UDim2.fromOffset(520, 48)
	message.BackgroundColor3 = Color3.fromRGB(22, 25, 31)
	message.BackgroundTransparency = 0.12
	message.TextColor3 = Color3.new(1, 1, 1)
	message.TextSize = 20
	message.Font = Enum.Font.GothamBold
	message.Visible = false
	message.Parent = gui
	local messageCorner = Instance.new("UICorner")
	messageCorner.CornerRadius = UDim.new(0, 10)
	messageCorner.Parent = message

	local inventoryButton = makeButton(gui, "ДЕКОР", UDim2.fromOffset(126, 44), UDim2.new(1, -146, 1, -68))
	local shopPanel, shopList = makePanel(gui, "Shop", "МАГАЗИН ДЕКОРА")
	local inventoryPanel, inventoryList = makePanel(gui, "Inventory", "МОЙ ДЕКОР")
	local inventoryRows = {}

	local messageVersion = 0
	local function show(text, persistent)
		messageVersion += 1
		local version = messageVersion
		message.Text = text
		message.Visible = true
		if not persistent then
			task.delay(3, function()
				if messageVersion == version then message.Visible = false end
			end)
		end
	end
	local function clearPreview()
		if preview then preview.model:Destroy() end
		preview = nil
		previewValid = false
		previewPosition = nil
		previewValidityState = nil
	end

	local function stop()
		selectedItemId = nil
		placing = false
		clearPreview()
		shopPanel.Visible = false
		inventoryPanel.Visible = false
		message.Visible = false
	end
	DecorationController.stop = stop

	for _, itemId in DecorationConfig.order do
		local definition = DecorationConfig.items[itemId]
		local shopInfo, buyButton = makeItemRow(shopList, definition, "Купить")
		shopInfo.Text = string.format("Цена: %d Coins", definition.price)
		buyButton.Activated:Connect(function()
			remote:FireServer("Buy", itemId)
		end)

		local inventoryInfo, selectButton = makeItemRow(inventoryList, definition, "Выбрать")
		inventoryRows[itemId] = { info = inventoryInfo, button = selectButton }
		selectButton.Activated:Connect(function()
			if (inventory[itemId] or 0) <= 0 then return end
			if onActivate then onActivate() end
			clearPreview()
			selectedItemId = itemId
			preview = buildPreview(itemId)
			placing = false
			inventoryPanel.Visible = false
			shopPanel.Visible = false
			show("Кликни по своему участку: " .. definition.displayName .. " · Esc — отмена", true)
		end)
	end

	local function refreshInventory(newInventory)
		inventory = type(newInventory) == "table" and newInventory or {}
		for _, itemId in DecorationConfig.order do
			local count = inventory[itemId] or 0
			local row = inventoryRows[itemId]
			row.info.Text = "В наличии: " .. count
			row.button.Active = count > 0
			row.button.AutoButtonColor = count > 0
			row.button.BackgroundColor3 = count > 0 and Color3.fromRGB(55, 126, 86) or Color3.fromRGB(75, 78, 84)
		end
	end
	refreshInventory({})

	inventoryButton.Activated:Connect(function()
		selectedItemId = nil
		placing = false
		clearPreview()
		message.Visible = false
		shopPanel.Visible = false
		inventoryPanel.Visible = not inventoryPanel.Visible
		if inventoryPanel.Visible then remote:FireServer("GetInventory") end
	end)

	remote.OnClientEvent:Connect(function(action, first, second)
		if action == "OpenShop" then
			selectedItemId = nil
			placing = false
			clearPreview()
			message.Visible = false
			inventoryPanel.Visible = false
			shopPanel.Visible = true
			remote:FireServer("GetInventory")
		elseif action == "Inventory" then
			refreshInventory(first)
		elseif action == "PurchaseResult" then
			show(tostring(second), false)
		elseif action == "PickupResult" then
			show(tostring(second), false)
		elseif action == "PlacementResult" then
			placing = false
			if first then
				selectedItemId = nil
				clearPreview()
			end
			show(tostring(second), false)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if not selectedItemId or not preview then return end
		local plot = plots:FindFirstChild("Plot_" .. player.UserId)
		local ground = plot and plot.PrimaryPart
		if not ground then
			previewValid = false
			return
		end
		local localPosition = ground.CFrame:PointToObjectSpace(mouse.Hit.Position)
		local definition = DecorationConfig.items[selectedItemId]
		local margin = math.max(4, definition.previewRadius or 0)
		local isValid = math.abs(localPosition.X) <= ground.Size.X / 2 - margin
			and math.abs(localPosition.Z) <= ground.Size.Z / 2 - margin
		local decorations = plot:FindFirstChild("PlayerDecorations")
		if decorations then
			if #decorations:GetChildren() >= DecorationConfig.maxPlaced then isValid = false end
			for _, decoration in decorations:GetChildren() do
				local otherX = decoration:GetAttribute("LocalX")
				local otherZ = decoration:GetAttribute("LocalZ")
				if type(otherX) == "number" and type(otherZ) == "number" then
					local dx = otherX - localPosition.X
					local dz = otherZ - localPosition.Z
					if dx * dx + dz * dz < 16 then
						isValid = false
						break
					end
				end
			end
		end
		previewValid = isValid
		previewPosition = ground.CFrame:PointToWorldSpace(Vector3.new(localPosition.X, ground.Size.Y / 2, localPosition.Z))
		updatePreview(preview, ground, localPosition.X, localPosition.Z, isValid)
		if previewValidityState ~= isValid then
			previewValidityState = isValid
			if isValid then
				show("Зелёный — можно установить · кликни · Esc — отмена", true)
			else
				show("Красный — место недоступно или рядом другой декор", true)
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.Escape and selectedItemId then
			selectedItemId = nil
			placing = false
			clearPreview()
			show("Установка отменена", false)
			return
		end
		if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1
			or not selectedItemId or placing then return end
		if not previewValid or not previewPosition then
			show("Выбери зелёное место на своём участке", true)
			return
		end
		placing = true
		remote:FireServer("Place", selectedItemId, previewPosition)
	end)

	remote:FireServer("GetInventory")
end

return DecorationController
