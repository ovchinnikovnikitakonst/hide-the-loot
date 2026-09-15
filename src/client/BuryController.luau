local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BuryController = {}
local started = false

function BuryController.start(onActivate)
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuryTreasure")
	local plots = Workspace:WaitForChild("Plots")
	local active = false
	local target
	local lastRequest = -math.huge
	local marker = Instance.new("Part")
	marker.Name = "BuryMarker"
	marker.Size = Vector3.new(3, 0.1, 3)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Transparency = 0.5
	marker.Material = Enum.Material.Neon

	local function stop()
		active = false
		target = nil
		marker.Parent = nil
	end
	BuryController.stop = stop
	BuryController.isActive = function()
		return active
	end

	local function getTreasure()
		local plot = plots:FindFirstChild("Plot_" .. player.UserId)
		return plot, plot and plot:FindFirstChild("Treasure")
	end

	RunService.RenderStepped:Connect(function()
		if not active then
			return
		end
		target = nil
		local plot, treasure = getTreasure()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not treasure or treasure:GetAttribute("IsBuried") or treasure:GetAttribute("IsFound") or not humanoid or humanoid.Health <= 0 then
			stop()
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			marker.Parent = nil
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character, treasure, marker }
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 2048, params)
		if not hit then
			marker.Parent = nil
			return
		end
		local ground = plot.PrimaryPart
		local valid = false
		if ground and root and hit.Instance == ground then
			local point = ground.CFrame:PointToObjectSpace(hit.Position)
			local standing = ground.CFrame:PointToObjectSpace(root.Position)
			local half = ground.Size / 2
			valid = math.abs(point.X) <= half.X - treasure.Size.X / 2
				and math.abs(point.Z) <= half.Z - treasure.Size.Z / 2
				and math.abs(point.Y - half.Y) <= 0.2
				and math.abs(standing.X) <= half.X and math.abs(standing.Z) <= half.Z
				and standing.Y >= half.Y and standing.Y <= half.Y + 10
		end
		if valid then
			target = hit.Position
		end
		marker.Color = valid and Color3.fromRGB(60, 255, 100) or Color3.fromRGB(255, 70, 70)
		marker.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.06, 0))
		marker.Parent = Workspace
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.B then
			if active then
				stop()
			else
				onActivate()
				local _, treasure = getTreasure()
				active = treasure ~= nil and not treasure:GetAttribute("IsBuried") and not treasure:GetAttribute("IsFound")
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and active and target then
			if os.clock() - lastRequest >= 0.3 then
				lastRequest = os.clock()
				remote:FireServer(target)
			end
		end
	end)
	remote.OnClientEvent:Connect(function(success)
		if success then
			stop()
		else
			warn("Burial rejected. Stand on your plot and choose a spot inside its edges.")
		end
	end)
	player.CharacterRemoving:Connect(stop)
end

return BuryController
