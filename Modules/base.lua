local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService('Players')

local remotes = ReplicatedStorage.Remotes
local modules = ReplicatedStorage.Modules

local player

local buildingBase
local billboardBase

if RunService:IsClient() then
	player = game.Players.LocalPlayer
	billboardBase = require(modules.SpawnerBillboard)
end

if RunService:IsServer() then
	buildingBase = require(modules.Buildbase)
end

local module = {}
module.__index = module
setmetatable(module, buildingBase)

local units = {
	'Builder'
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
