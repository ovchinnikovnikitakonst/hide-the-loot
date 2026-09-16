local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MazeConfig = require(ReplicatedStorage.Shared.config.MazeConfig)

local THINK_INTERVAL = 0.45
local ATTACK_DISTANCE = 4.5
local PICKUP_INTERRUPT_TIME = 0.9
local KNOCKBACK_SPEED = 46
local KNOCKBACK_UPWARD_SPEED = 24
local KNOCKBACK_DURATION = 0.28
local EnemyService = {}
local started = false
local enemiesFolder
local mazeService
local baseplate

local function getLivingCharacter(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return nil end
	return root, humanoid
end

local function findTarget(zoneId, position, aggroDistance)
	local bestPlayer
	local bestRoot
	local bestHumanoid
	local bestDistance = aggroDistance
	for _, player in Players:GetPlayers() do
		local root, humanoid = getLivingCharacter(player)
		if root and mazeService.getZoneIdAtPosition(root.Position) == zoneId then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				bestPlayer = player
				bestRoot = root
				bestHumanoid = humanoid
				bestDistance = distance
			end
		end
	end
	return bestPlayer, bestRoot, bestHumanoid, bestDistance
end

local function moveToward(humanoid, root, destination, zoneId)
	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 6,
	})
	local success = pcall(function()
		path:ComputeAsync(root.Position, destination)
	end)
	if not success or path.Status ~= Enum.PathStatus.Success then
		humanoid:MoveTo(root.Position)
		return
	end
	local waypoints = path:GetWaypoints()
	local waypoint = waypoints[math.min(2, #waypoints)]
	if waypoint and mazeService.getZoneIdAtPosition(waypoint.Position) == zoneId then
		humanoid:MoveTo(waypoint.Position)
	else
		humanoid:MoveTo(root.Position)
	end
end

local function createEnemy(zoneId, definition, spawnOffset)
	local center = MazeConfig.centerOffset
	local spawnCFrame = baseplate.CFrame * CFrame.new(center.X + spawnOffset.X, 12.75, center.Z + spawnOffset.Z)
	local model = Instance.new("Model")
	model.Name = definition.displayName
	model:SetAttribute("MazeZoneId", zoneId)

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3.5, 3.5, 3.5)
	root.Color = definition.color
	root.Material = Enum.Material.Slate
	root.CanCollide = true
	root.CFrame = spawnCFrame
	root.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.4, 2.4, 2.4)
	head.Color = definition.color:Lerp(Color3.new(1, 1, 1), 0.15)
	head.Material = Enum.Material.Slate
	head.CanCollide = false
	head.CFrame = spawnCFrame * CFrame.new(0, 2.8, 0)
	head.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = head
	weld.Parent = head

	local humanoid = Instance.new("Humanoid")
	humanoid.WalkSpeed = definition.walkSpeed
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.DisplayName = definition.displayName
	humanoid.Parent = model
	model.PrimaryPart = root
	model.Parent = enemiesFolder
	root:SetNetworkOwner(nil)

	local alive = true
	local lastAttack = 0
	humanoid.Died:Connect(function()
		alive = false
		model:Destroy()
		task.delay(definition.respawnTime, function()
			if started and enemiesFolder.Parent then
				createEnemy(zoneId, definition, spawnOffset)
			end
		end)
	end)

	task.spawn(function()
		while alive and model.Parent and humanoid.Health > 0 do
			if mazeService.getZoneIdAtPosition(root.Position) ~= zoneId then
				model:PivotTo(spawnCFrame)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
			end

			local targetPlayer, targetRoot, targetHumanoid, distance = findTarget(zoneId, root.Position, definition.aggroDistance)
			if targetPlayer and targetRoot and targetHumanoid then
				if distance <= ATTACK_DISTANCE then
					humanoid:MoveTo(root.Position)
					local now = os.clock()
					if now - lastAttack >= definition.attackCooldown
						and mazeService.getZoneIdAtPosition(targetRoot.Position) == zoneId then
						lastAttack = now
						mazeService.interruptTreasurePickup(targetPlayer, PICKUP_INTERRUPT_TIME)
						local knockbackDirection = Vector3.new(
							targetRoot.Position.X - root.Position.X,
							0,
							targetRoot.Position.Z - root.Position.Z
						)
						if knockbackDirection.Magnitude < 0.01 then
							knockbackDirection = Vector3.new(0, 0, -1)
						else
							knockbackDirection = knockbackDirection.Unit
						end
						local velocityChange = knockbackDirection * KNOCKBACK_SPEED
							+ Vector3.new(0, KNOCKBACK_UPWARD_SPEED, 0)
						targetHumanoid:ChangeState(Enum.HumanoidStateType.Freefall)
						targetRoot.AssemblyLinearVelocity = velocityChange
						local attachment = Instance.new("Attachment")
						attachment.Name = "MonsterKnockbackAttachment"
						attachment.Parent = targetRoot
						local velocity = Instance.new("LinearVelocity")
						velocity.Name = "MonsterKnockback"
						velocity.Attachment0 = attachment
						velocity.RelativeTo = Enum.ActuatorRelativeTo.World
						velocity.VectorVelocity = velocityChange
						velocity.MaxForce = math.huge
						velocity.Parent = targetRoot
						Debris:AddItem(velocity, KNOCKBACK_DURATION)
						Debris:AddItem(attachment, KNOCKBACK_DURATION)
						targetHumanoid:TakeDamage(definition.damage)
					end
				else
					moveToward(humanoid, root, targetRoot.Position, zoneId)
				end
			elseif (root.Position - spawnCFrame.Position).Magnitude > 4 then
				moveToward(humanoid, root, spawnCFrame.Position, zoneId)
			else
				humanoid:MoveTo(root.Position)
			end
			task.wait(THINK_INTERVAL)
		end
	end)
end

function EnemyService.start(resolvedMazeService)
	if started then return end
	started = true
	mazeService = resolvedMazeService
	baseplate = Workspace:WaitForChild("Baseplate")
	enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "MazeEnemies"
	enemiesFolder.Parent = Workspace
	for zoneId, zone in MazeConfig.zones do
		if zone.enemy then
			for _, spawnOffset in zone.enemy.spawns do
				createEnemy(zoneId, zone.enemy, spawnOffset)
			end
		end
	end
end

return EnemyService
