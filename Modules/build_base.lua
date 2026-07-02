local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local modules = ReplicatedStorage.Modules

local updateLoop = require(modules.UpdateLoop)

local module = {}
module.__index = module

function module.new(player : Player, model : Model)
	local self = setmetatable({}, module)

	local id = workspace.Id

	self.Model = model
	self.Model:SetAttribute('BuildProgress', 0)
	self.Model:SetAttribute('PlayerId', player.UserId)
	self.Model:SetAttribute("Id", id.Value)
	self.Model:SetAttribute('Team', player.Team.Name)
	
	local size = model:GetExtentsSize()
	local primaryCF = model.PrimaryPart.CFrame
	local sunkenCF = primaryCF * CFrame.new(0, -model:GetExtentsSize().Y, 0)
	
	self.OriginalCF = primaryCF
	self.Model:PivotTo(sunkenCF)
	self.StartCF = sunkenCF
	
	--create the base thing
	local base = Instance.new("Part")
	self.Base = base
	
	base.Color = Color3.fromRGB(85, 85, 127)
	base.TopSurface = Enum.SurfaceType.Smooth
	base.CanCollide = true
	base.Anchored = true
	base.Size = Vector3.new(size.X * 1.2, .1, size.Z * 1.2)
	base.Parent = model
	base.Name = 'Base'
	
	local baseCF = primaryCF * CFrame.new(0, (-size.Y / 2) + base.Size.Y/2, 0)
	self.BaseCF = baseCF
	base.CFrame = baseCF
	
	self.Root = model.HumanoidRootPart
	
	self.LastAttack = os.clock()
	self.BuildProgress = 0
	self.MaxBuildProgress = model.Config.BuildTime.Value
	
	self.PlayerId = player.UserId
	self.Team = player.Team.Name
	self.Name =	model.Name
	self.Id = id.Value
	id.Value += 1
	
	if model.Config:FindFirstChild("Trail") then
		model.Config.Trail.Value = player.TeamColor.Color
	end
	
	ReplicatedStorage.Remotes.BuildProgress:FireAllClients(model, self.MaxBuildProgress)
	
	self.Model.Humanoid.Died:Connect(function()
		self:Destroy()
	end)
	
	self:yieldUntilCompletion()
	
	return self
end

function module:yieldUntilCompletion()
	task.spawn(function()
		repeat task.wait(1)
		until self.BuildProgress >= self.MaxBuildProgress or not self.Model or self.Destroyed
		
		if self.Model and self.Model:GetAttribute('Completed') then
			self:onCompleted()
		end
	end)
end

function module:onCompleted()
	print('Completed building', self.Model.Name)
end

function module:Destroy()
	self.Destroyed = true

	local buildingInstances = require(modules.BuildingInstances)
	buildingInstances.remove(self.Name, self.Id, self.Team)

	local player = Players:GetPlayerByUserId(self.PlayerId)

	if player then
		ReplicatedStorage.Remotes.UnitDied:FireClient(player, self.Id)
	end

	if self.Model then
		for i, object in self.Model:GetDescendants() do
			if object:IsA("BasePart") then
				if object:IsA('MeshPart') then
					object.TextureID = ""
					object.Color = Color3.fromRGB(0, 0, 0)
				end
				
				object.Material = Enum.Material.Rock
				object.CollisionGroup = "DeadUnits"
				
				task.delay(1, function()
					TweenService:Create(object, TweenInfo.new(1.5), {Transparency = 1;}):Play()
				end)
			end
		end

		task.delay(2.5, function()
			self.Model:Destroy()
			self.Model = nil
		end)
	end
end

function module:addBuildProgress(builderId, amount)
	if self.BuildProgress >= self.MaxBuildProgress then return end
	self.BuildProgress += amount or 1
	self.Model:SetAttribute('BuildProgress', self.BuildProgress)

	self.Model:PivotTo(self.StartCF:Lerp(self.OriginalCF, self.BuildProgress / self.MaxBuildProgress))
	self.Base.CFrame = self.BaseCF  --restore the base original position

	if self.BuildProgress >= self.MaxBuildProgress then
		self.Base:Destroy()
		self.Model:SetAttribute("Completed", true)
	end
end

function module:attack(target)
	local unitBase = require(modules.UnitBase)
	unitBase.attack(self, target)
end

function module:update()
	if self.Destroyed or self.BuildProgress < self.MaxBuildProgress then
		return
	end

	local target = updateLoop.FindTarget(self.Model, {})

	if target and os.clock() - self.LastAttack > self.Model.Config.Cooldown.Value then
		self:attack(target)
	end
end

return module