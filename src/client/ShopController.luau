local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local MazeConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("config"):WaitForChild("MazeConfig"))
local PlotConfig = require(ReplicatedStorage.Shared.config:WaitForChild("PlotConfig"))

local ShopController = {}
local started = false

function ShopController.start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UpgradeExplorerLicense")
	local plotRemote = ReplicatedStorage.Remotes:WaitForChild("UpgradePlot")
	local plots = Workspace:WaitForChild("Plots")
	local boards = {}

	local function attach(sign)
		if not sign:IsA("BasePart") or (sign.Name ~= "ShopSign" and sign.Name ~= "PlotUpgradeSign") or boards[sign] then return end
		local owner = Players:GetPlayerByUserId(sign:GetAttribute("OwnerUserId"))
		if not owner then return end
		local gui = Instance.new("SurfaceGui")
		gui.Name = "TreasureShop"
		gui.Adornee = sign
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(600, 400)
		gui.AlwaysOnTop = false
		gui.MaxDistance = 80
		gui.Active = true
		gui.ResetOnSpawn = false
		-- Interactive SurfaceGuis live in PlayerGui and adorn a world Part.
		gui.Parent = playerGui
		local function text(y, height, size)
			local label = Instance.new("TextLabel")
			label.Position = UDim2.fromOffset(16, y)
			label.Size = UDim2.new(1, -32, 0, height)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextSize = size
			label.TextWrapped = true
			label.Parent = gui
			return label
		end
		local isPlot = sign.Name == "PlotUpgradeSign"
		text(8, 40, 28).Text = (isPlot and "Участок · " or "Лицензия · ") .. owner.Name
		local details = text(50, 140, 25)
		text(192, 54, 20).Text = isPlot and "Применяется сразу\nНедоступно во время поиска" or "Открывает более глубокие зоны\nДействует до выхода"
		local button = Instance.new("TextButton")
		button.Position = UDim2.fromOffset(24, 260)
		button.Size = UDim2.new(1, -48, 0, 58)
		button.TextSize = 25
		button.Parent = gui
		local status = text(326, 64, 21)
		status.Text = ""
		local board = { gui = gui, connections = {}, pending = false, revision = 0 }
		boards[sign] = board
		local canBuy = false
		local function refresh()
			if isPlot then
				local level = owner:GetAttribute("PurchasedPlotLevel") or 1
				local nextLevel = PlotConfig.levels[level + 1]
				local stats = owner:FindFirstChild("leaderstats")
				local coins = stats and stats:FindFirstChild("Coins")
				local balance = coins and coins.Value or 0
				local searchBusy = sign.Parent and sign.Parent:GetAttribute("SearchBusy") == true
				canBuy = owner == player and nextLevel ~= nil and balance >= nextLevel.upgradePrice and not board.pending and not searchBusy
				details.Text = nextLevel and string.format("Уровень: %d → %d\nРазмер: %d×%d · Сундуков: %d\nЦена: %d Coins · Баланс: %d", level, level + 1, nextLevel.size, nextLevel.size, nextLevel.treasureCapacity, nextLevel.upgradePrice, balance)
					or string.format("Уровень %d · Максимум\nСундуков: %d · Баланс: %d Coins", level, PlotConfig.levels[level].treasureCapacity, balance)
				button.Text = not nextLevel and "Максимальный уровень" or (owner ~= player and "Только для владельца" or (searchBusy and "Дождись конца поиска" or (board.pending and "Покупка…" or (canBuy and "Купить улучшение" or "Недостаточно Coins"))))
				button.Active = canBuy
				button.AutoButtonColor = canBuy
				button.BackgroundColor3 = canBuy and Color3.fromRGB(90, 180, 110) or Color3.fromRGB(110, 110, 110)
				return
			end
			local level = owner:GetAttribute("ExplorerLicenseLevel") or MazeConfig.defaultLicenseLevel
			local current = MazeConfig.licenseLevels[level]
			local nextLevel = MazeConfig.licenseLevels[level + 1]
			local stats = owner:FindFirstChild("leaderstats")
			local coins = stats and stats:FindFirstChild("Coins")
			local balance = coins and coins.Value or 0
			canBuy = owner == player and nextLevel ~= nil and balance >= nextLevel.upgradePrice and not board.pending
			if nextLevel then
				details.Text = string.format("Уровень %d → %d\nОткроется: %s\nЦена: %d Coins · Баланс: %d", level, level + 1, nextLevel.displayName, nextLevel.upgradePrice, balance)
				button.Text = owner ~= player and "Только для владельца" or (board.pending and "Покупка…" or (canBuy and "Купить улучшение" or "Недостаточно Coins"))
			else
				details.Text = string.format("Уровень %d · Все зоны открыты\n%s\nБаланс: %d Coins", level, current.displayName, balance)
				button.Text = "Максимальный уровень"
			end
			button.Active = canBuy
			button.AutoButtonColor = canBuy
			button.BackgroundColor3 = canBuy and Color3.fromRGB(90, 180, 110) or Color3.fromRGB(110, 110, 110)
		end
		board.reply = function(message)
			board.pending = false
			status.Text = message
			board.revision += 1
			local revision = board.revision
			task.delay(4, function()
				if boards[sign] == board and revision == board.revision then status.Text = "" end
			end)
			refresh()
		end
		table.insert(board.connections, button.Activated:Connect(function()
			if not canBuy then return end
			board.pending = true
			refresh()
			if isPlot then plotRemote:FireServer(sign) else remote:FireServer(sign) end
		end))
		table.insert(board.connections, owner:GetAttributeChangedSignal("ExplorerLicenseLevel"):Connect(refresh))
		table.insert(board.connections, owner:GetAttributeChangedSignal("PurchasedPlotLevel"):Connect(refresh))
		if isPlot and sign.Parent then
			table.insert(board.connections, sign.Parent:GetAttributeChangedSignal("SearchBusy"):Connect(refresh))
		end
		local boundCoins
		local function bindCoins()
			local stats = owner:FindFirstChild("leaderstats")
			local coins = stats and stats:FindFirstChild("Coins")
			if coins and coins ~= boundCoins then
				boundCoins = coins
				table.insert(board.connections, coins.Changed:Connect(refresh))
			end
			refresh()
		end
		table.insert(board.connections, owner.DescendantAdded:Connect(bindCoins))
		bindCoins()
	end
	plots.DescendantAdded:Connect(attach)
	plots.DescendantRemoving:Connect(function(sign)
		local board = boards[sign]
		if not board then return end
		boards[sign] = nil
		for _, connection in board.connections do connection:Disconnect() end
		board.gui:Destroy()
	end)
	Players.PlayerAdded:Connect(function()
		for _, descendant in plots:GetDescendants() do attach(descendant) end
	end)
	remote.OnClientEvent:Connect(function(_, message)
		for sign, board in boards do
			if sign.Name == "ShopSign" and board.reply and sign:GetAttribute("OwnerUserId") == player.UserId then board.reply(message) end
		end
	end)
	plotRemote.OnClientEvent:Connect(function(_, message)
		for sign, board in boards do
			if sign.Name == "PlotUpgradeSign" and sign:GetAttribute("OwnerUserId") == player.UserId then board.reply(message) end
		end
	end)
	for _, descendant in plots:GetDescendants() do attach(descendant) end
end

return ShopController
