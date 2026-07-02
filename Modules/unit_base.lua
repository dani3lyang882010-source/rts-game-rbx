local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local remotes = ReplicatedStorage.Remotes

local modules = ReplicatedStorage.Modules

local pathfinding = require(script.Parent.Pathfinding)
local updateLoop = require(script.Parent.UpdateLoop)

local module = {}
module.__index = module

function module.new(player : Player, model)
	local self = setmetatable({}, module)
	local id = workspace.Id
	
	self.Model = model
	self.Model:SetAttribute('Team', player.Team.Name)
	self.Model:SetAttribute('PlayerId', player.UserId)
	self.Model:SetAttribute("Id", id.Value)
	self.Model.PrimaryPart:SetNetworkOwner(nil)
	self.Root = model.HumanoidRootPart
	self.Humanoid = model.Humanoid
	
	local attachment = Instance.new("Attachment")
	attachment.Name = "RotationAttachment"
	attachment.Parent = self.Root

	local align = Instance.new("AlignOrientation")
	align.Name = "LookAlign"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.Responsiveness = 50
	align.RigidityEnabled = false
	align.MaxTorque = math.huge

	align.Parent = self.Root

	self.AlignOrientation = align
	
	self.Pathfinder = pathfinding.new(model, self, 
		{
			AgentRadius = 2; 
			AgentHeight = 3.2; 
			AgentCanJump = false; 
			AgentMaxSlope = 89;
			Costs = {
				Water = math.huge;
			}
		}
	)
	
	self.LastAttack = 0
	self.Team = player.Team.Name
	self.PlayerId = player.UserId
	self.Name =	model.Name
	self.Id = id.Value
	id.Value += 1
	
	self.Humanoid.Died:Once(function()
		self:Destroy()
	end)
	
	return self
end

function module:Destroy()
	self.Destroyed = true
	
	if self.AlignOrientation then
		self.AlignOrientation:Destroy()
		self.AlignOrientation = nil
	end

	if self.Root then
		local att = self.Root:FindFirstChild("RotationAttachment")
		
		if att then
			att:Destroy()
		end
	end

	if self.Pathfinder and self.Pathfinder.Destroy then
		self.Pathfinder:Destroy()
	end

	local unitInstances = require(modules.UnitInstances)
	unitInstances.remove(self.Name, self.Id, self.Team)
	
	local player = Players:GetPlayerByUserId(self.PlayerId)
	
	if player then
		ReplicatedStorage.Remotes.UnitDied:FireClient(player, self.Id)
	end
	
	if self.Model then
		for i, object in self.Model:GetDescendants() do
			if object:IsA("BasePart") then
				object.CollisionGroup = "DeadUnits"
			end
		end
		
		task.delay(1, function()
			self.Model:Destroy()
			self.Model = nil
		end)
	end
end

function module:FaceTarget(target)
	self.AlignOrientation.Enabled = target and true or false
	if not target then
		return
	end
	
	local myPos = self.Root.Position
	local targetPos = target.Model.HumanoidRootPart.Position

	local lookAt = Vector3.new(
		targetPos.X,
		myPos.Y,
		targetPos.Z
	)

	self.AlignOrientation.CFrame = CFrame.lookAt(myPos, lookAt)
end

function module:attack(target)
	if target.Model and target.Root then
		local humanoid = target.Model:FindFirstChildOfClass("Humanoid")
		local isAlive = humanoid and humanoid.Health > 0
		
		if isAlive then
			remotes.AnimateUnit:FireAllClients(self.Model, 'Attack', target.Root.Position)
			
			local damage = self.Model.Config.Damage.Value
			if humanoid then
				humanoid:TakeDamage(damage)
			end
		end
	end
end

function module:FindTarget()
	return updateLoop.FindTarget(
		self.Model,
		{}
	)
end

function module:update()
	if self.Destroyed then
		return
	end
	
	local target = self:FindTarget(self.Model)
	
	self:FaceTarget(target)
	
	if target and os.clock() - self.LastAttack > self.Model.Config.Cooldown.Value then
		--reset cooldown
		self.LastAttack = os.clock()
		
		self:attack(target)
	end
end

return module