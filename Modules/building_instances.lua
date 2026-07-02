local module = {}

local data = {
	["Red"] = {};
	["Blue"] = {};
}

function module.add(building, team)
	data[team][building.Id] = building
end

function module.remove(name, id, team)
	if id then
		data[team][id] = nil
		return
	end

	for buildingId, building in pairs(data[team]) do
		if building.Name == name then
			data[team][buildingId] = nil
		end
	end
end

function module.get(name, id, team)
	for _, building in data[team] do
		if building.Name == name or building.Id == id then
			return building
		end
	end
end

function module.getEnemyList(team)
	local e = team == 'Red' and 'Blue' or 'Red'

	local list = {}

	for _, building in data[e] do
		table.insert(list, building)
	end

	return list
end

function module.getAllBuildings()
	local buildings = {}

	for _, teamData in pairs(data) do
		for _, building in pairs(teamData) do
			table.insert(buildings, building)
		end
	end

	return buildings
end

function module.getFromTeam(team)
	local list = {}

	for _, building in data[team] do
		table.insert(list, building) 
	end

	return list
end

return module