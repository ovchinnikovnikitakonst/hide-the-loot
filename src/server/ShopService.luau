local ShopService = {}
local signs = {}
local started = false
local PURCHASE_DISTANCE = 16

function ShopService.canUse(player, sign)
	if signs[player] ~= sign or not sign or not sign.Parent then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return root ~= nil and humanoid ~= nil and humanoid.Health > 0
		and (root.Position - sign.Position).Magnitude <= PURCHASE_DISTANCE
end

function ShopService.start(plotService)
	if started then return end
	started = true
	local function create(player, plot)
		if signs[player] or plotService.getPlot(player) ~= plot or not plot.Parent then return end
		local ground = plot.PrimaryPart
		if not ground then return end
		local sign = Instance.new("Part")
		sign.Name = "ShopSign"
		sign.Size = Vector3.new(8, 5, 1)
		sign.Anchored = true
		sign.Color = Color3.fromRGB(30, 30, 35)
		-- Front face points outward toward approaching visitors.
		sign.CFrame = ground.CFrame * CFrame.new(-9, 3.5, ground.Size.Z / 2 + 4) * CFrame.Angles(0, math.pi, 0)
		sign:SetAttribute("OwnerUserId", player.UserId)
		signs[player] = sign
		sign.Parent = plot
		local plotSign = sign:Clone()
		plotSign.Name = "PlotUpgradeSign"
		plotSign.CFrame = ground.CFrame * CFrame.new(9, 3.5, ground.Size.Z / 2 + 4) * CFrame.Angles(0, math.pi, 0)
		plotSign.Parent = plot
	end
	plotService.PlotAssigned:Connect(create)
	plotService.PlotRemoving:Connect(function(player, plot)
		local sign = signs[player]
		if sign and (not sign.Parent or sign.Parent == plot) then signs[player] = nil end
	end)
	for _, player in game:GetService("Players"):GetPlayers() do
		local plot = plotService.getPlot(player)
		if plot then create(player, plot) end
	end
end

return ShopService
