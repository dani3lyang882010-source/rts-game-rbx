local Players = game:GetService('Players')

local modules = game.ReplicatedStorage:WaitForChild("Modules")
--local resources = require(modules.Resources)

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new('Folder')
	leaderstats.Parent = player
	leaderstats.Name = 'leaderstats'
	
	local money = Instance.new('IntValue')
	money.Parent = leaderstats
	money.Name = 'Money'
	money.Value = 250
	
	--resources.init(player)
	
	player.CharacterAdded:Connect(function(character)
		for i, object in character:GetDescendants() do
			if object:IsA('BasePart') then
				--object.Transparency = 1
				object.CollisionGroup = 'Players'
			end
		end
	end)
end)