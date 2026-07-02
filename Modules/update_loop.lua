local TargetUpdateRate = 0.2

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService('ReplicatedStorage')

local buildingInstances = require(ReplicatedStorage.Modules.BuildingInstances)
local unitInstances = require(ReplicatedStorage.Modules.UnitInstances)

local unitTimers = {}

local module = {}

local function makeList(team, config)
	local allied = config.GetFriendly
	local excludeBuildings = config.ExcludeBuildings
	local excludeUnits = config.ExcludeUnits

	local list = {}
	
	local units
	local buildings
	
	if allied then
		units = unitInstances.getFromTeam(team)
		buildings = buildingInstances.getFromTeam(team)
	else
		units = unitInstances.getEnemyList(team)
		buildings = buildingInstances.getEnemyList(team)
	end
	
	if not excludeUnits then
		for _, unit in units do
			table.insert(list, unit)
		end
	end
	
	if not excludeBuildings then
		for _, building in buildings do
			table.insert(list, building)
		end
	end

	return list
end

function module.FindTarget(unit, config)
	local myPos = unit.PrimaryPart.Position
	local closestTarget
	local closestDistSq = unit.Config.Range.Value * unit.Config.Range.Value

	local targetList = makeList(unit:GetAttribute('Team'), config)
	
	for _, enemy in ipairs(targetList) do
		if enemy.Destroyed then
			continue
		end

		local isAlive = enemy.Model.Humanoid.Health > 0
		
		if not isAlive then
			continue
		end
		
		if enemy.Model:GetAttribute("Id") == unit:GetAttribute("Id") then
			continue
		end
		
		local offset = enemy.Root.Position - myPos
		offset = Vector3.new(offset.X, 0, offset.Z)  -- ignore Y axis

		local distSq = offset:Dot(offset)

		if distSq < closestDistSq then
			closestDistSq = distSq
			closestTarget = enemy
		end
	end

	return closestTarget
end

local function getAllUnitsAndBuildings()
	local list = {}
	
	for _, unit in unitInstances.getAllUnits() do
		table.insert(list, unit)
	end
	
	for _, building in buildingInstances.getAllBuildings() do
		table.insert(list, building)
	end
	
	return list
end

RunService.Heartbeat:Connect(function(dt)
	local list = getAllUnitsAndBuildings()
	
	for _, unit in ipairs(list) do
		local id = unit.Id
		unitTimers[id] = (unitTimers[id] or 0) + dt

		if unitTimers[id] >= TargetUpdateRate then
			unitTimers[id] = unitTimers[id] - TargetUpdateRate
			task.spawn(function()
				unit:update()
			end)
		end
	end

	-- clean up timers for removed units
	local activeIds = {}
	
	for _, unit in ipairs(list) do
		activeIds[unit.Id] = true
	end
	
	for id in pairs(unitTimers) do
		if not activeIds[id] then
			unitTimers[id] = nil
		end
	end
end)

return module