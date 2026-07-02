local module = {}

local data = {
	["Red"] = {};
	["Blue"] = {};
}

function module.add(unit, team)
	data[team][unit.Id] = unit
end

function module.remove(name, id, team)
	if id then
		data[team][id] = nil
		return
	end

	for unitId, unit in pairs(data[team]) do
		if unit.Name == name then
			data[team][unitId] = nil
		end
	end
end

function module.get(name, id, team)
	for _, unit in data[team] do
		if unit.Name == name or unit.Id == id then
			return unit
		end
	end
end

function module.getEnemyList(team)
	local e = team == 'Red' and 'Blue' or 'Red'
	
	local list = {}
	
	for _, unit in data[e] do
		table.insert(list, unit)
	end
	
	return list
end

function module.getAllUnits()
	local units = {}

	for _, teamData in pairs(data) do
		for _, unit in pairs(teamData) do
			table.insert(units, unit)
		end
	end

	return units
end

function module.getFromTeam(team)
	local list = {}
	
	for _, unit in data[team] do
		table.insert(list, unit) 
	end
	
	return list
end

game.ReplicatedStorage.Remotes.GetUnitsFromTeam.OnServerInvoke = function(player, team)
	local list = {}
	for _, unit in data[team] do
		table.insert(list, unit.Model)
	end
	return list
end

return module