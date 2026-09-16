local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local DURATION = 30
local ATTEMPTS = 3
local COOLDOWN = 5
local roundFinished = Instance.new("BindableEvent")
local SearchService = { RoundFinished = roundFinished.Event }
local started = false

function SearchService.start(plotService, treasureService, carryService, digRemote, roundRemote)
	if started then return end
	started = true
	local rounds = {}
	local busy = {}
	local completed = {}
	local lastStart = {}
	local nextRoundId = 0

	local function send(player, ...)
		if player.Parent == Players then roundRemote:FireClient(player, ...) end
	end
	local function update(round)
		send(round.seeker, "active", round.plot, round.deadline, round.attempts, ATTEMPTS)
	end
	local function finish(round, outcome, reason)
		if rounds[round.seeker] ~= round then return end
		rounds[round.seeker] = nil
		busy[round.plot] = nil
		completed[round.plot] = round
		round.seeker:SetAttribute("SearchRoundActive", false)
		roundFinished:Fire(table.freeze({
			roundId = round.id,
			seeker = round.seeker,
			owner = round.owner,
			treasureTypeId = round.treasureTypeId,
			outcome = outcome,
			reason = reason,
		}))
		if round.death then round.death:Disconnect() end
		if round.removing then round.removing:Disconnect() end
		if round.plot.Parent then
			round.plot:SetAttribute("SearchFinished", true)
			round.plot:SetAttribute("SearchBusy", false)
		end
		local winner = outcome == "seeker" and round.seeker or round.owner
		local message = outcome == "cancelled" and reason or ("Победил " .. winner.Name .. ": " .. reason)
		send(round.seeker, "finished", message)
		send(round.owner, "result", message)
		if outcome ~= "cancelled" then
			task.delay(COOLDOWN, function()
				if completed[round.plot] ~= round or round.owner.Parent ~= Players
					or not round.plot.Parent or plotService.getPlot(round.owner) ~= round.plot then return end
				completed[round.plot] = nil
				round.plot:SetAttribute("SearchFinished", false)
				send(round.owner, "ready", outcome == "seeker"
					and "Один клад унесён искателем" or "Клады защищены")
			end)
		end
	end

	local function standingOn(player, plot)
		local ground = plot.PrimaryPart
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not ground or not root or not humanoid or humanoid.Health <= 0 then return false end
		local point = ground.CFrame:PointToObjectSpace(root.Position)
		local half = ground.Size / 2
		return math.abs(point.X) <= half.X and math.abs(point.Z) <= half.Z
			and point.Y >= half.Y and point.Y <= half.Y + 10, humanoid
	end

	roundRemote.OnServerEvent:Connect(function(player, plot)
		local now = Workspace:GetServerTimeNow()
		if lastStart[player] and now - lastStart[player] < 0.25 then return end
		lastStart[player] = now
		local current = rounds[player]
		if current then
			if now >= current.deadline then finish(current, "owner", "время истекло") else update(current) end
			return
		end
		if not carryService.canReceiveTreasure(player) then
			send(player, "error", "Освободи руки и место для нового сундука") return
		end
		if not treasureService.canSearch(plot) then send(player, "error", "Здесь нет доступного клада") return end
		local owner = Players:GetPlayerByUserId(plot:GetAttribute("OwnerUserId"))
		local onPlot, humanoid = standingOn(player, plot)
		if not owner or owner == player or plotService.getPlot(owner) ~= plot or not onPlot then
			send(player, "error", "Встань на чужой участок с закопанным кладом") return
		end
		if completed[plot] or busy[plot] then send(player, "error", "Поиск уже завершён или участок занят") return end
		local typeId = treasureService.getRaidTypeId(plot)
		if not typeId then return end
		nextRoundId += 1
		local round = { id = nextRoundId, treasureTypeId = typeId,
			seeker = player, owner = owner, plot = plot, attempts = ATTEMPTS,
			deadline = now + DURATION, lastDig = -math.huge }
		rounds[player] = round
		busy[plot] = round
		player:SetAttribute("SearchRoundActive", true)
		plot:SetAttribute("SearchBusy", true)
		round.death = humanoid.Died:Connect(function() finish(round, "owner", "искатель погиб") end)
		round.removing = player.CharacterRemoving:Connect(function() finish(round, "owner", "искатель сбросил персонажа") end)
		update(round)
		task.delay(DURATION, function()
			if rounds[player] == round then finish(round, "owner", "время истекло") end
		end)
	end)

	digRemote.OnServerEvent:Connect(function(player, plot, position)
		local round = rounds[player]
		if not round then return end
		local now = Workspace:GetServerTimeNow()
		if now >= round.deadline then finish(round, "owner", "время истекло") return end
		if plot ~= round.plot or now - round.lastDig < 1 then return end
		round.lastDig = now
		local result, payload = treasureService.tryDig(player, plot, position)
		if result == "rejected" then digRemote:FireClient(player, result) return end
		if result == "found" then
			if not carryService.carryStolen(player, payload) then
				treasureService.returnStolenTreasure(payload)
				digRemote:FireClient(player, "rejected")
				return
			end
			round.treasureTypeId = payload.typeId
			round.attempts -= 1
			finish(round, "seeker", "клад найден и унесён")
			return
		end
		round.attempts -= 1
		if round.attempts == 0 then finish(round, "owner", "попытки закончились")
		else
			update(round)
			digRemote:FireClient(player, "miss")
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastStart[player] = nil
		if rounds[player] then finish(rounds[player], "owner", "искатель вышел") end
		local owned = {}
		for _, round in rounds do if round.owner == player then table.insert(owned, round) end end
		for _, round in owned do finish(round, "cancelled", "Поиск отменён: владелец вышел") end
	end)
	plotService.PlotRemoving:Connect(function(_, plot)
		if busy[plot] then finish(busy[plot], "cancelled", "Поиск отменён: участок удалён") end
		completed[plot] = nil
	end)
end

return SearchService
