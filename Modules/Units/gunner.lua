local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modules = ReplicatedStorage.Modules

local unitBase = require(modules.UnitBase)
local buildingInstances = require(modules.BuildingInstances)

local module = {}
module.__index = module
setmetatable(module, unitBase)

function module.new(player, model)
	local self = setmetatable(unitBase.new(player, model), module)
	
	return self
end

return module
