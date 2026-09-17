local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TreasureConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("config"):WaitForChild("TreasureConfig"))

local StatusController = {}
local started = false

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function createLabel(parent, position, size, textSize, color)
	local label = Instance.new("TextLabel")
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Font = Enum.Font.GothamMedium
	label.Parent = parent
	return label
end

function StatusController.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local plots = Workspace:WaitForChild("Plots")
	local gui = Instance.new("ScreenGui")
	gui.Name = "GameplayStatus"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5

	local frame = Instance.new("Frame")
	frame.Name = "TreasureStatus"
	frame.AnchorPoint = Vector2.new(1, 0.5)
	frame.Position = UDim2.new(1, -18, 0.5, 50)
	frame.Size = UDim2.fromOffset(350, 146)
	frame.BackgroundColor3 = Color3.fromRGB(24, 27, 32)
	frame.BackgroundTransparency = 0.12
	frame.Parent = gui
	addCorner(frame, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(90, 98, 110)
	stroke.Transparency = 0.35
	stroke.Parent = frame

	local title = createLabel(frame, UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 28), 22, Color3.fromRGB(255, 219, 105))
	title.Font = Enum.Font.GothamBold
	local details = createLabel(frame, UDim2.fromOffset(16, 42), UDim2.new(1, -32, 0, 40), 18, Color3.fromRGB(240, 240, 242))
	local hint = createLabel(frame, UDim2.fromOffset(16, 88), UDim2.new(1, -32, 0, 46), 17, Color3.fromRGB(151, 211, 255))

	local notification = Instance.new("TextLabel")
	notification.AnchorPoint = Vector2.new(1, 1)
	notification.Position = UDim2.new(1, -18, 0.5, -31)
	notification.Size = UDim2.fromOffset(350, 42)
	notification.BackgroundColor3 = Color3.fromRGB(50, 125, 76)
	notification.BackgroundTransparency = 0.08
	notification.TextColor3 = Color3.new(1, 1, 1)
	notification.TextSize = 17
	notification.Font = Enum.Font.GothamBold
	notification.Visible = false
	notification.Parent = gui
	addCorner(notification, 9)
	gui.Parent = player:WaitForChild("PlayerGui")

	local plot
	local plotConnections = {}
	local previousTotal = 0
	local previousBuried = 0
	local notificationRevision = 0

	local function showNotification(message)
		notificationRevision += 1
		local revision = notificationRevision
		notification.Text = message
		notification.Visible = true
		task.delay(3, function()
			if notificationRevision == revision then notification.Visible = false end
		end)
	end

	local function describe(typeId, prefix)
		local definition = typeId and TreasureConfig.types[typeId]
		if not definition then return nil end
		return string.format("%s: %s · +%d Coins/min", prefix, definition.rarity, definition.incomePerMinute)
	end

	local function refresh()
		if not plot or not plot.Parent then
			title.Text = "СУНДУКИ"
			details.Text = "Участок загружается…"
			hint.Text = ""
			return
		end
		local total = plot:GetAttribute("TreasureCount") or 0
		local capacity = plot:GetAttribute("TreasureCapacity") or 0
		local stored = plot:GetAttribute("StoredTreasureCount") or 0
		local buried = plot:GetAttribute("BuriedTreasureCount") or 0
		local carriedTypeId = player:GetAttribute("CarryingTreasureTypeId")
		local selectedTypeId = player:GetAttribute("SelectedTreasureTypeId")
		title.Text = string.format("СУНДУКИ  %d / %d", total, capacity)
		details.Text = describe(carriedTypeId, "Несёшь")
			or describe(selectedTypeId, "Выбран")
			or string.format("На стойке: %d  ·  Закопано: %d", stored, buried)
		if carriedTypeId then
			hint.Text = "Отнеси сундук на синюю площадку участка [E]"
		elseif player:GetAttribute("SearchRoundActive") then
			hint.Text = "Идёт поиск чужого клада · копать [F]"
		elseif plot:GetAttribute("SearchBusy") then
			hint.Text = "На участке идёт поиск · хранилище временно закрыто"
		elseif selectedTypeId then
			hint.Text = "Нажми [B], выбери место на участке и кликни"
		elseif total >= capacity and capacity > 0 then
			hint.Text = "Участок заполнен · закопай клад или улучши участок"
		elseif stored > 0 then
			hint.Text = "Подойди к стойке и выбери сундук [E]"
		else
			hint.Text = "Найди сундук в лабиринте и принеси домой"
		end
	end

	local function disconnectPlot()
		for _, connection in plotConnections do connection:Disconnect() end
		table.clear(plotConnections)
		plot = nil
	end

	local function bindPlot(candidate)
		if plot == candidate or not candidate:IsA("Model") or candidate:GetAttribute("OwnerUserId") ~= player.UserId then return end
		disconnectPlot()
		plot = candidate
		previousTotal = plot:GetAttribute("TreasureCount") or 0
		previousBuried = plot:GetAttribute("BuriedTreasureCount") or 0
		local function plotChanged()
			local total = plot:GetAttribute("TreasureCount") or 0
			local buried = plot:GetAttribute("BuriedTreasureCount") or 0
			if total > previousTotal then
				showNotification("Сундук добавлен в хранилище")
			elseif buried > previousBuried then
				showNotification("Сундук успешно закопан")
			end
			previousTotal = total
			previousBuried = buried
			refresh()
		end
		for _, attribute in { "TreasureCount", "TreasureCapacity", "StoredTreasureCount", "BuriedTreasureCount", "SearchBusy" } do
			table.insert(plotConnections, plot:GetAttributeChangedSignal(attribute):Connect(plotChanged))
		end
		table.insert(plotConnections, plot.AncestryChanged:Connect(function(_, parent)
			if not parent then
				disconnectPlot()
				refresh()
			end
		end))
		refresh()
	end

	player:GetAttributeChangedSignal("CarryingTreasureTypeId"):Connect(refresh)
	player:GetAttributeChangedSignal("SearchRoundActive"):Connect(refresh)
	player:GetAttributeChangedSignal("SelectedTreasureTypeId"):Connect(function()
		if player:GetAttribute("SelectedTreasureTypeId") then
			showNotification("Сундук выбран для закапывания")
		end
		refresh()
	end)
	plots.ChildAdded:Connect(bindPlot)
	plots.ChildRemoved:Connect(function(candidate)
		if candidate == plot then
			disconnectPlot()
			refresh()
		end
	end)
	local current = plots:FindFirstChild("Plot_" .. player.UserId)
	if current then bindPlot(current) else refresh() end
end

return StatusController
