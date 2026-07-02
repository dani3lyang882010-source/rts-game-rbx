local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local modules = ReplicatedStorage.Modules

local buildingBase

if RunService:IsServer() then
	buildingBase = require(modules.Buildbase)
end

local module = {}
module.__index = module
setmetatable(module, buildingBase)

function module.getCustomConditions(model)
	local pos = model.HumanoidRootPart.Position
	local range = model.Config.Range.Value
	local rangeSquared = range * range

	for _, crystal : Model in workspace.Map.Crystals:GetChildren() do
		local distSquared = (crystal:GetPivot().Position - pos):Dot(crystal:GetPivot().Position - pos)
		local pos
		
		if crystal:IsA('Model') then
			pos = crystal:GetPivot().Position
		else
			pos = crystal.Position
		end
		
		if distSquared <= rangeSquared then
			for _, building in workspace.Buildings:GetChildren() do
				if building.Name == model.Name then
					local buildingDist = (pos - building.HumanoidRootPart.Position):Dot(pos - building.HumanoidRootPart.Position)
					
					if buildingDist <= rangeSquared then
						return false, "- Another factory is already near this crystal"
					end
				end
			end

			return true
		end
	end

	return false, "- Must be placed near a crystal"
end

function module.new(player, model)
	local self = setmetatable(buildingBase.new(player, model), module)
	
	return self
end

function module:onCompleted()
	while self.Model and self.Model.Parent do
		task.wait(1)
		self:generateIncome()
	end
end

function module:generateIncome()
	if self.BuildProgress < self.MaxBuildProgress then
		return
	end
	
	if self.Destroyed then
		return
	end
	
	local player = Players:GetPlayerByUserId(self.PlayerId)
	
	if player and self.Model then
		player.leaderstats.Money.Value += self.Model.Config.Income.Value
	end
end

return module
