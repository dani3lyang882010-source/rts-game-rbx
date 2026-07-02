local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local modules = ReplicatedStorage.Modules

local SimplePath = require(ReplicatedStorage.Modules.SimplePath)
local unitInstances = require(modules.UnitInstances)

local module = {}
module.__index = module

local PATHS_PER_FRAME = 5 --if you make it lower then its gonna lag less, but the paths are slower
local COOLDOWN = 0.2

local pathQueue = {}
local pathCooldowns = {}

local pendingClears = {} -- [player] = {unitId, unitId, ...}
local pendingPaths = {} -- [player] = {[unitId] = waypoints, ...}

local function QueueClear(player, unitId)
	local clears = pendingClears[player]

	if not clears then
		clears = {}
		pendingClears[player] = clears
	end

	table.insert(clears, unitId)
end

local function QueueReplicatePath(player, unitId, waypoints)
	local paths = pendingPaths[player]

	if not paths then
		paths = {}
		pendingPaths[player] = paths
	end

	paths[unitId] = waypoints
end

local function FlushBatches()
	for player, clears in pairs(pendingClears) do
		if player.Parent then
			ReplicatedStorage.Remotes.ClearPath:FireClient(player, clears)
		end
	end
	pendingClears = {}

	for player, paths in pairs(pendingPaths) do
		if player.Parent then
			ReplicatedStorage.Remotes.ReplicatePath:FireClient(player, paths)
		end
	end
	pendingPaths = {}
end

local flushScheduled = false

RunService.Heartbeat:Connect(function()
	local processed = 0
	
	while #pathQueue > 0 and processed < PATHS_PER_FRAME do
		local request = table.remove(pathQueue, 1)
		request.fn()
		processed += 1
	end

	if not flushScheduled then
		flushScheduled = true

		task.delay(0.05, function()
			FlushBatches()
			flushScheduled = false
		end)
	end
end)

function module.new(model : Model, unitInstance, agentParams)
	local self = setmetatable({}, module)

	self.Model = model
	self.Root = model.HumanoidRootPart

	self.Unit = unitInstance
	self.Path = SimplePath.new(model, agentParams)
	self.PreviewPath = PathfindingService:CreatePath(agentParams)
	self.PathId = 0

	self.Reached = false
	self.Destroyed = false

	self.Path.Reached:Connect(function()
		self.Reached = true
	end)

	self.Destinations = {}
	self.CachedWaypoints = {}

	return self
end

function module:Destroy()
	self.Destroyed = true

	self.Reached = true
	self.Destinations = {}
	self.CachedWaypoints = {}

	-- stop simplepath if it has connections
	if self.Path and self.Destroy then
		self.Path:Destroy()
	end

	self.Model = nil
	self.Root = nil
end

function module:AddSegment(startPos, endPos)
	self.PreviewPath:ComputeAsync(startPos, endPos)

	if self.PreviewPath.Status == Enum.PathStatus.Success then
		local waypoints = self.PreviewPath:GetWaypoints()

		for i = 1, #waypoints do
			table.insert(self.CachedWaypoints, waypoints[i])
		end

		return true
	else
		warn('path error')
	end

	return false
end

function module:MoveTo(destination, index, player, waypoints)
	if self.Destroyed then
		warn('PATH DESTROYED')
		return
	end

	if not destination then
		warn('Invalid destination')
		return
	end

	if not self.Path then
		return
	end

	self.PathId += 1
	index = index or 1
	self.Reached = false

	local destinations = self.Destinations
	local currentId = self.PathId

	if waypoints then
		-- follower: walk the given waypoints manually instead of using simplepath
		local humanoid = self.Model.Humanoid

		for _, wp in waypoints do
			if currentId ~= self.PathId or self.Destroyed or not self.Model or not self.Model.Parent then
				return
			end

			if wp.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end

			humanoid:MoveTo(wp.Position)

			local reachedWaypoint = humanoid.MoveToFinished:Wait()

			if currentId ~= self.PathId then
				return
			end

			if not reachedWaypoint then
				-- couldn't reach this waypoint, bail so the recursion below can still fire
				break
			end
		end

		self.Reached = true
	else
		local success = self.Path:Run(destination)
		if not success then
			return
		end

		local lastPos = self.Root.Position
		local stuckTime = 0

		repeat
			task.wait(.1)

			if self.Destroyed or not self.Model or not self.Model.Parent then
				return
			end

			if currentId ~= self.PathId then
				return
			end

			--[[local delta = self.Root.Position - lastPos

			if delta:Dot(delta) < 0.09 then
				stuckTime += 0.1
			else
				stuckTime = 0
				lastPos = self.Root.Position
			end

			if stuckTime >= 1 then
				local backDir = (self.Root.Position - destination).Unit
				local side = Vector3.new(-backDir.Z, 0, backDir.X)
				local backPos = self.Root.Position + backDir * 5 + side * (math.random(0, 1) * 2 - 1) * 3

				self.Model.Humanoid:MoveTo(backPos)
				
				task.wait(0.5)
				
				self.Path:Run(destination)
				
				stuckTime = 0
				lastPos = self.Root.Position
			end]]

			local destDelta = self.Root.Position - destination
		until (self.Reached and destDelta:Dot(destDelta) <= 4) or currentId ~= self.PathId
	end

	if currentId ~= self.PathId then
		return
	end

	if index == #destinations then
		self.Destinations = {}
		self.CachedWaypoints = {}

		if player then
			QueueClear(player, self.Unit.Id)
		end
	else
		local Next = self.Destinations[index + 1]

		if Next then
			self:MoveTo(Next, index + 1, player)
		end
	end
end

local function QueuePath(unitInstance, destination, override, player, waypoints) --the waypoints override if the unit needs to follow the leader
	local pathId = unitInstance.Pathfinder.PathId

	table.insert(pathQueue, {
		fn = function()
			local pathfinder = unitInstance.Pathfinder

			if pathfinder.Destroyed
				or not unitInstance.Model
				or not unitInstance.Root
				or not unitInstance.Model.Parent then
				return
			end

			if pathfinder.PathId ~= pathId then
				return
			end

			local root = unitInstance.Root

			if override then
				pathfinder.PathId += 1
				pathfinder.Destinations = {destination}
				pathfinder.CachedWaypoints = {}

				local success = waypoints or pathfinder:AddSegment(root.Position, destination)
				
				if success then
					if waypoints then
						pathfinder.CachedWaypoints = table.clone(waypoints)
					end
					
					task.spawn(function()
						pathfinder:MoveTo(destination, 1, player, waypoints)
					end)

					QueueClear(player, unitInstance.Id)
					QueueReplicatePath(player, unitInstance.Id, table.clone(pathfinder.CachedWaypoints))
				end

				--exit out if overriding the path
				return
			end

			local doneMoving = #pathfinder.Destinations == 0

			local from =
				doneMoving
				and root.Position
				or pathfinder.Destinations[#pathfinder.Destinations]

			pathfinder.CachedWaypoints = {}

			local success = waypoints or pathfinder:AddSegment(from, destination)

			if success then
				if waypoints then
					pathfinder.CachedWaypoints = table.clone(waypoints)
				end

				QueueReplicatePath(player, unitInstance.Id, table.clone(pathfinder.CachedWaypoints))
				table.insert(pathfinder.Destinations, destination)

				if doneMoving then
					task.spawn(function()
						pathfinder:MoveTo(pathfinder.Destinations[1], 1, player, waypoints)
					end)
				end
			end
		end
	})
end

local function getLeader(selectedUnits, destination)
	local leader = nil
	local closest = math.huge
	
	for _, unit in selectedUnits do
		local delta = unit.HumanoidRootPart.Position - destination
		local dist2 = delta:Dot(delta)

		if dist2 < closest then
			closest = dist2
			leader = unit
		end
	end
	
	return leader
end

local function canSee(unit, leader)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {leader, workspace.Map.Build}
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	
	local origin = unit.HumanoidRootPart.Position
	local direction = (leader.HumanoidRootPart.Position - origin).Unit * 1000
	
	local result = workspace:Raycast(origin, direction, raycastParams)
	
	return result and result.Instance:IsDescendantOf(leader)
end

--remove waypoints that move the unit "backwards" from the destination
local function trimWaypointsForFollower(waypoints, fromPos)
	local closestIndex = 1
	local closestDist = math.huge

	for i, wp in waypoints do
		local delta = wp.Position - fromPos
		local dist2 = delta:Dot(delta)
		
		if dist2 < closestDist then
			closestDist = dist2
			closestIndex = i
		end
	end

	local trimmed = {}
	table.insert(trimmed, {Position = fromPos, Action = Enum.PathWaypointAction.Walk})

	for i = closestIndex, #waypoints do
		table.insert(trimmed, waypoints[i])
	end

	return trimmed
end

ReplicatedStorage.Remotes.Move.OnServerEvent:Connect(function(player, selectedUnits, position, override)
	local leader = getLeader(selectedUnits, position)
	if not leader then return end

	local leaderInstance = unitInstances.get(nil, leader:GetAttribute('Id'), player.Team.Name)
	if not leaderInstance then return end

	local lastMove = pathCooldowns[leaderInstance.Id]
	
	if lastMove and os.clock() - lastMove < COOLDOWN then
		return
	end
	
	pathCooldowns[leaderInstance.Id] = os.clock()

	-- compute the leader's path ONCE before queuing anything
	local leaderDestinations = leaderInstance.Pathfinder.Destinations
	local leaderFrom =
		(override or #leaderDestinations == 0)
		and leaderInstance.Root.Position
		or leaderDestinations[#leaderDestinations]
	
	leaderInstance.Pathfinder.CachedWaypoints = {}
	
	local success = leaderInstance.Pathfinder:AddSegment(leaderFrom, position)

	if not success then return end

	local leaderWaypoints = table.clone(leaderInstance.Pathfinder.CachedWaypoints)

	-- move the leader using the path that just got computed
	QueuePath(leaderInstance, position, override, player, leaderWaypoints)

	--the followers use the same waypoints
	for _, unit in selectedUnits do
		if unit == leader then continue end

		local id = unit:GetAttribute("Id")
		local unitInstance = unitInstances.get(nil, id, player.Team.Name)
		if not unitInstance then continue end

		if unit:GetAttribute("PlayerId") ~= player.UserId then continue end

		local followerLastMove = pathCooldowns[unitInstance.Id]
		
		if followerLastMove and os.clock() - followerLastMove < COOLDOWN then
			continue
		end
		pathCooldowns[unitInstance.Id] = os.clock()
		
		--check to see where the new path should start from
		local followerDestinations = unitInstance.Pathfinder.Destinations
		local followerFrom =
			(override or #followerDestinations == 0)
			and unitInstance.Root.Position
			or followerDestinations[#followerDestinations]
		
		local hasLineOfSight = canSee(unitInstance.Model, leaderInstance.Model)

		if hasLineOfSight then
			local followerWaypoints = trimWaypointsForFollower(leaderWaypoints, followerFrom)
			QueuePath(unitInstance, position, override, player, followerWaypoints)
		else
			QueuePath(unitInstance, position, override, player)
		end
	end
end)

return module