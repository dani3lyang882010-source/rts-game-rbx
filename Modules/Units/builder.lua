local ReplicatedStorage = game:GetService("ReplicatedStorage")

local modules = ReplicatedStorage.Modules

local remotes = ReplicatedStorage.Remotes

local unitBase = require(modules.UnitBase)
local buildingInstances = require(modules.BuildingInstances)
local updateLoop = require(modules.UpdateLoop)

local module = {}
module.__index = module
setmetatable(module, unitBase)

function module.new(player, model)
	local self = setmetatable(unitBase.new(player, model), module)
	
	return self
end

function module:FindTarget()
	local target = updateLoop.FindTarget(
		self.Model,
		{
			ExcludeUnits = true;
			GetFriendly = true;
		}
	)
	
	if target and target.BuildProgress < target.MaxBuildProgress then
		return target 
	end
end

function module:attack(target)
	remotes.AnimateUnit:FireAllClients(self.Model, 'Build')

	target:addBuildProgress(self.Id, self.Model.Config.Damage.Value)
end

return module
