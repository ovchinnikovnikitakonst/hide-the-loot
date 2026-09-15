local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MESSAGE_DURATION = 4

local SearchController = {}
local started = false

function SearchController.start(onActivate)
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local plots = Workspace:WaitForChild("Plots")
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DigTreasure")
	local roundRemote = ReplicatedStorage.Remotes:WaitForChild("SearchRound")
	local roundPlot
	local deadline = 0
	local attempts = 0
	local maximum = 3
	local wantsMarker = false
	local gui = Instance.new("ScreenGui")
	gui.Name = "SearchStatus"
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.8, 0, 0, 44)
	label.Position = UDim2.new(0.1, 0, 0, 12)
	label.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	label.BackgroundTransparency = 0.2
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 20
	label.TextWrapped = true
	label.Visible = false
	label.Parent = gui
	local resultLabel = label:Clone()
	resultLabel.Position = UDim2.new(0.1, 0, 0, 60)
	resultLabel.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	local messageDeadlines = {}
	local function showMessage(targetLabel, message)
		targetLabel.Text = message
		targetLabel.Visible = true
		messageDeadlines[targetLabel] = os.clock() + MESSAGE_DURATION
	end
	local active = false
	local selectedPlot
	local target
	local lastRequest = -math.huge
	local flashUntil = 0
	local marker = Instance.new("Part")
	marker.Name = "DigMarker"
	marker.Size = Vector3.new(6, 0.1, 6)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Transparency = 0.5
	marker.Material = Enum.Material.Neon

	local function stop()
		wantsMarker = false
		active = false
		selectedPlot = nil
		target = nil
		marker.Parent = nil
	end
	SearchController.stop = stop
	SearchController.isActive = function()
		return active
	end

	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for targetLabel, expiresAt in messageDeadlines do
			if now >= expiresAt then
				targetLabel.Visible = false
				messageDeadlines[targetLabel] = nil
			end
		end
		if roundPlot then
			label.Visible = true
			label.Text = string.format("Время: %d с · Попытки: %d/%d", math.max(0, math.ceil(deadline - Workspace:GetServerTimeNow())), attempts, maximum)
		end
		if not active then
			return
		end
		target = nil
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			stop()
			return
		end
		if selectedPlot and (not selectedPlot.Parent or not selectedPlot:GetAttribute("HasBuriedTreasure")) then
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
		params.FilterDescendantsInstances = { character, marker }
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 2048, params)
		if not hit then
			marker.Parent = nil
			return
		end
		local plot = hit.Instance.Parent
		local valid = false
		if plot and plot.Parent == plots and plot:IsA("Model")
			and plot == roundPlot
			and plot.PrimaryPart == hit.Instance and plot:GetAttribute("OwnerUserId") ~= player.UserId
			and plot:GetAttribute("HasBuriedTreasure") then
			local ground = plot.PrimaryPart
			local half = ground.Size / 2
			local point = ground.CFrame:PointToObjectSpace(hit.Position)
			local standing = ground.CFrame:PointToObjectSpace(root.Position)
			valid = math.abs(point.X) <= half.X and math.abs(point.Z) <= half.Z
				and math.abs(point.Y - half.Y) <= 0.2
				and math.abs(standing.X) <= half.X and math.abs(standing.Z) <= half.Z
				and standing.Y >= half.Y and standing.Y <= half.Y + 10
			if valid then
				selectedPlot = plot
				target = hit.Position
			end
		end
		marker.Color = valid and os.clock() >= flashUntil
			and Color3.fromRGB(60, 255, 100) or Color3.fromRGB(255, 70, 70)
		marker.CFrame = CFrame.new(hit.Position + Vector3.new(0, 0.06, 0))
		marker.Parent = Workspace
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F then
			if active then
				stop()
			else
				onActivate()
				wantsMarker = true
				if roundPlot then
					active = true
					selectedPlot = roundPlot
				else
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					local candidate
					if root then
						for _, plot in plots:GetChildren() do
							local ground = plot:IsA("Model") and plot.PrimaryPart
							if ground and plot:GetAttribute("OwnerUserId") ~= player.UserId then
								local point = ground.CFrame:PointToObjectSpace(root.Position)
								if math.abs(point.X) <= ground.Size.X / 2 and math.abs(point.Z) <= ground.Size.Z / 2 then
									candidate = plot
									break
								end
							end
						end
					end
					roundRemote:FireServer(candidate)
				end
				flashUntil = 0
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and active and target then
			if os.clock() - lastRequest >= 1 then
				lastRequest = os.clock()
				remote:FireServer(selectedPlot, target)
			end
		end
	end)
	roundRemote.OnClientEvent:Connect(function(state, value, endTime, remaining, total)
		if state == "active" then
			messageDeadlines[label] = nil
			roundPlot = value
			deadline = endTime
			attempts = remaining
			maximum = total
			selectedPlot = value
			active = wantsMarker
		elseif state == "finished" then
			roundPlot = nil
			stop()
			showMessage(label, value)
		elseif state == "error" then
			stop()
			showMessage(label, value)
		elseif state == "result" or state == "ready" then
			showMessage(resultLabel, value)
		end
	end)
	remote.OnClientEvent:Connect(function(result, plot)
		if result == "found" then
			if selectedPlot == plot then
				stop()
			end
		elseif active then
			flashUntil = os.clock() + 0.4
		end
	end)
	player.CharacterRemoving:Connect(stop)
end

return SearchController
