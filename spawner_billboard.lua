local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild('Remotes')

local module = {}
local cooldownBars = {}

function module.addCooldownBar(model, spawnTime, unitBillboard)
	if model and unitBillboard then
		unitBillboard.Bar.Fill.Size = UDim2.new(0, 0, 1, 0)
		unitBillboard.Bar.Visible = true

		local endTime = os.clock() + spawnTime

		cooldownBars[model:GetAttribute('Id')] = {
			StartTime = os.clock();
			EndTime = endTime;
			Model = model;
			Bar = unitBillboard.Bar;
		}
	end
end

function module.updateCooldownBars()
	for id, object in cooldownBars do
		if not object.Model or (object.Model and object.Model.Humanoid.Health <= 0) then
			cooldownBars[id] = nil
			continue
		end
		
		local totalTime = object.EndTime - object.StartTime
		local elapsed = os.clock() - object.StartTime
		local percent = math.clamp(elapsed / totalTime, 0, 1)
		
		if percent >= 1 then
			object.Bar.Visible = false
			cooldownBars[id] = nil
			continue
		end
		
		object.Bar.Fill.Size = UDim2.new(percent, 0, 1, 0)
	end
end

function module.setupBillboard(model, units)
	local newBillboard = ReplicatedStorage.Billboards.UnitSpawner:Clone()
	newBillboard.Parent = player.PlayerGui.Billboards
	newBillboard.Adornee = model.HumanoidRootPart
	newBillboard.Enabled = true
	newBillboard:SetAttribute('Id', model:GetAttribute('Id'))
	newBillboard.Container.Title.Text = model.Name
	
	newBillboard.Activate.Activated:Connect(function()
		if player.UserId ~= model:GetAttribute('PlayerId') or not model:GetAttribute('Completed') then
			return
		end

		module.toggleBillboard(model)
	end)

	newBillboard.Container.Exit.Activated:Connect(function()
		if player.UserId ~= model:GetAttribute('PlayerId') or not model:GetAttribute('Completed') then
			return
		end

		module.toggleBillboard(model)
	end)

	for _, name in units do
		local unitExists = ReplicatedStorage.Units:FindFirstChild(name)

		if unitExists then
			local newBtn = newBillboard.Container.Items.Template:Clone()
			newBtn.Parent = newBillboard.Container.Items
			newBtn.Name = name
			newBtn.Visible = true
			newBtn.Price.Text = '$'..unitExists.Config.Price.Value
			newBtn.Icon.Image = unitExists.Config.Icon.Image
			newBtn.UnitName.Text = name

			newBtn.Activated:Connect(function()
				if player.UserId ~= model:GetAttribute('PlayerId') or not 
					model:GetAttribute('Completed') or not 
					model or 
					(model and model.Humanoid.Health <= 0) then
					return
				end

				local radius = model:GetExtentsSize().Magnitude / 2
				local rand = math.random(0, 1) * 2 - 1
				local CF = model:GetPivot()
				local pos = CF * CFrame.new(rand * radius, 2, rand * radius)
				 
				local spawnCooldown = model.Config.SpawnCooldown.Value
				local success = remotes.NewUnit:InvokeServer(name, pos, spawnCooldown, model)
				
				if success then
					module.addCooldownBar(model, spawnCooldown, newBillboard)
				end
			end)
		end
	end
end

function module.toggleBillboard(model)
	if model:GetAttribute('Completed') and player.UserId == model:GetAttribute('PlayerId') then
		for _, billboard in player.PlayerGui.Billboards:GetChildren() do
			if billboard:GetAttribute('Id') == model:GetAttribute('Id') then
				billboard.Container.Visible = not billboard.Container.Visible
				billboard.Activate.Visible = not billboard.Activate.Visible
				break
			end
		end
	end
end

RunService.RenderStepped:Connect(function(dt)
	module.updateCooldownBars()
end)

return module