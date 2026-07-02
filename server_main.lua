local ReplicatedStorage=  game:GetService('ReplicatedStorage')

local modules = ReplicatedStorage.Modules
local remotes = ReplicatedStorage.Remotes

local unitInstances = require(modules.UnitInstances)
local unitBase = require(modules.UnitBase)
local buildBase = require(modules.Buildbase)
local buildInstances = require(modules.BuildingInstances)

local pathfinding = require(modules.Pathfinding)

remotes.NewBuilding.OnServerInvoke = function(player, cframe, name)
	local newBuilding = ReplicatedStorage.Buildings:FindFirstChild(name)
	
	if not newBuilding then
		warn('building does not exist:', name)
		return
	end
	
	if player.leaderstats.Money.Value < newBuilding.Config.Price.Value then
		remotes.ErrorMessage:FireClient(player, 'You cannot afford this!')
		warn('not enough money')
		return
	end
	
	local friendlyUnits = unitInstances.getFromTeam(player.Team.Name)
	
	local builderWasFound = false
	for _, unit in friendlyUnits do
		if unit.Name == 'Builder' then
			builderWasFound = true
			break
		end
	end
	
	if not builderWasFound then
		warn('no builder found nearby')
		return
	end
	
	player.leaderstats.Money.Value -= newBuilding.Config.Price.Value
	
	newBuilding = newBuilding:Clone()
	newBuilding.Parent = workspace.Buildings
	newBuilding:PivotTo(cframe)
	
	for _, part in newBuilding:GetDescendants() do
		if part:IsA('BasePart') then
			if part:HasTag('ColorPart') then
				part.Color = player.Team.TeamColor.Color
			end
			
			part.CollisionGroup = 'Buildings'
		end
	end
	
	local module = ReplicatedStorage.Modules.Buildings:FindFirstChild(name)
	if module then
		module = require(module)
	else
		return
	end
	
	coroutine.wrap(buildInstances.add)(module.new(player, newBuilding), player.Team.Name)
	
	return true
end

remotes.NewUnit.OnServerInvoke = function(player, name, spawnPos, spawnCooldown, building)
	local template = ReplicatedStorage.Units:FindFirstChild(name)

	if not template then
		warn("unit does not exist:", name)
		return false
	end

	local price = template.Config.Price.Value

	if player.leaderstats.Money.Value < price then
		remotes.ErrorMessage:FireClient(player, "You cannot afford this!")
		return false
	end
	
	local success = true

	task.spawn(function()
		if spawnCooldown and building then
			local buildingInstance = buildInstances.get(nil, building:GetAttribute("Id"), player.Team.Name)

			if not buildingInstance then
				warn("building instance missing")
				success = false
				return
			end
			
			if buildingInstance.LastSpawn and os.clock() - buildingInstance.LastSpawn < spawnCooldown then
				success = false
				return
			end
			
			buildingInstance.LastSpawn = os.clock()
			
			task.wait(spawnCooldown)
			
			--if the player left
			if not player or not player.Parent then
				success = false
				return
			end
			
			-- safety re-check (building might die during wait)
			if not building or not building.Parent or building.Humanoid.Health <= 0 then
				warn("spawn cancelled: building destroyed")
				success = false
				return
			end
		end

		local unit = template:Clone()
		unit.Parent = workspace.Units
		unit:PivotTo(spawnPos)

		for _, part in unit:GetDescendants() do
			if part:IsA("BasePart") then
				if part:HasTag("ColorPart") then
					part.Color = player.Team.TeamColor.Color
				end
				part.CollisionGroup = "Units"
			end
		end

		local unitModule = ReplicatedStorage.Modules.Units:FindFirstChild(unit.Name)
		if unitModule then
			local instance = require(unitModule).new(player, unit)
			unitInstances.add(instance, player.Team.Name)
		end
	end)

	if success then
		player.leaderstats.Money.Value -= price
	end

	return success
end

--[[remotes.CanSelect.OnServerInvoke = function(player, list)
	local newList =  {}
	
	for i, object in list do
		if object:GetAttribute('PlayerId') == player.UserId then
			table.insert(newList, object)
		end
	end
	
	return newList
end]]