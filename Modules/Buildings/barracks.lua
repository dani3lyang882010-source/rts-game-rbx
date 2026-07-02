local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService('Players')

local remotes = ReplicatedStorage.Remotes
local modules = ReplicatedStorage.Modules

local buildingBase
local billboardBase

if RunService:IsServer() then
	buildingBase = require(modules.Buildbase)
end

if RunService:IsClient() then
	billboardBase = require(modules.SpawnerBillboard)
end

local module = {}
module.__index = module
setmetatable(module, buildingBase)

local units = {
	"Gunner"
}

function module.new(player, model)
	local self = setmetatable(buildingBase.new(player, model), module)
	
	return self
end

function module.setupBillboard(model)
	billboardBase.setupBillboard(model, units)
end

function module.toggleBillboard(model)
	billboardBase.toggleBillboard(model)
end

function module:onCompleted()
	local player = Players:GetPlayerByUserId(self.PlayerId)

	if player then
		remotes.SetupBillboard:FireClient(player, self.Model)
	end
end

return module
