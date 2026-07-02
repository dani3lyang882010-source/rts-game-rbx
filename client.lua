local DOUBLE_CLICK_TIME = 0.3

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local Debris = game:GetService('Debris')

local remotes = ReplicatedStorage:WaitForChild('Remotes')

local player = game.Players.LocalPlayer
local camera = workspace.CurrentCamera

local gui = player.PlayerGui:WaitForChild('GameGui')
local selectionBox = gui:WaitForChild('SelectionBox')
local buildErrFrm = gui:WaitForChild('BuildError')
local buildInstructions = gui:WaitForChild('Instructions')
local buildingInfo = gui:WaitForChild('BuildingInfo')

local startPos = nil
local selectedBuilding = nil
local currentBuildingCheck = nil
local templateBuilding = nil
local dragging = false
local canPlace = false

local rotation = 0

local lastClick = os.clock()

local selectedUnits = {}
local waypointParts = {}

local function getTopLevelModel(instance)
	local model = instance:FindFirstAncestorOfClass('Model')
	while model do
		if model.Parent == workspace.Units or model.Parent == workspace.Buildings then
			return model
		end
		model = model:FindFirstAncestorOfClass('Model')
	end
end

local function createRangePart(model)
	if model and model.Parent == workspace.Buildings then
		if not model:GetAttribute('Completed') then
			return
		end
	end
	
	local root = model:WaitForChild('HumanoidRootPart')

	local range = model.Config.Range.Value
	local height = root.Size.Y * .5

	local p = Instance.new('Part')
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.CanCollide = false
	p.CollisionGroup = 'Units'
	p.Transparency = 1
	p.Color = Color3.new(1, 1, 1)
	p.Name = 'Range'
	p.Size = Vector3.new(1, range * 2, range * 2)
	p:SetAttribute('Id', model:GetAttribute('Id'))

	local surfaceGui = Instance.new('SurfaceGui')
	surfaceGui.Parent = p
	surfaceGui.LightInfluence = 0
	surfaceGui.AlwaysOnTop = true
	surfaceGui.Face = Enum.NormalId.Right
	surfaceGui.CanvasSize = Vector2.new(512, 512)
	
	local frame = Instance.new('Frame')
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.Parent = surfaceGui
	frame.BackgroundTransparency = 1
	
	local uiCorner = Instance.new('UICorner')
	uiCorner.CornerRadius = UDim.new(1, 0)
	uiCorner.Parent = frame
	
	local uiStroke = Instance.new('UIStroke')
	uiStroke.Thickness = 4
	uiStroke.Parent = frame
	uiStroke.Color = Color3.new(1, 1, 1)
	
	--[[local image = Instance.new('ImageLabel')
	image.Size = UDim2.new(1, 0, 1, 0)
	image.Parent = surfaceGui
	image.BackgroundTransparency = 1
	image.Image = 'rbxassetid://89500773035001']]

	local offset = CFrame.new(0, -height, 0) * CFrame.Angles(0, 0, math.rad(90))
	p.CFrame = CFrame.new(root.Position) * offset

	local weld = Instance.new('WeldConstraint')
	weld.Part0 = p
	weld.Part1 = root
	weld.Parent = p
	p.Parent = model
end

local function clearRangePart(model)
	if model:FindFirstChild('Range') then
		model.Range:Destroy()
	end
end

local function setPathVisible(model, visible)
	if not model then return end
	local id = model:GetAttribute("Id")
	
	local folder = workspace.Waypoints:FindFirstChild(tostring(id))
	if not folder then return end
	
	local container = folder:FindFirstChild('Container')
	if not container then return end
	
	for _, att in container:GetChildren() do
		if att:IsA('Attachment') then
			local beam = att:FindFirstChildWhichIsA('Beam')
			if beam then
				beam.Enabled = visible
			end
		end
	end
end

local function toggleBuildingInfo(model)
	if not model then return end
	if model.Parent ~= workspace.Buildings then return end
	
	if model:GetAttribute("PlayerId") ~= player.UserId then
		return
	end
	
	buildingInfo.Visible = not buildingInfo.Visible
	
	local config = model.Config
	local upgrade = config:FindFirstChild('Upgrade')
	local playerId = model:GetAttribute('PlayerId')
	
	buildingInfo.Title.Text = model.Name .. ' ' .. '[Lv.' .. model.Config.Level.Value .. ']'
	buildingInfo.Items.Upgrade.Visible = playerId == player.UserId and upgrade and upgrade.Value
	buildingInfo.Items.Sell.Visible = playerId == player.UserId
end

local function selectBuilding(model)
	if model then
		local isAlive = model.Humanoid.Health > 0

		if not isAlive then
			return
		end
	end
	
	toggleBuildingInfo(model)
	
	if selectedBuilding == model then
		selectedBuilding = nil
		
		if model then
			destroyHighlight(model)
			clearRangePart(model)
		end
		
		return
	end
	
	if model and model.Parent == workspace.Buildings then
		if model:GetAttribute("PlayerId") ~= player.UserId then
			return
		end
		
		selectedBuilding = model
		
		createHighlight(model)
		
		createRangePart(model)
	end
end

local function selectUnit(model)
	if not model or model.Parent ~= workspace.Units then
		return
	end

	if model:GetAttribute("PlayerId") ~= player.UserId then
		return
	end

	selectBuilding(selectedBuilding)

	local index = table.find(selectedUnits, model)

	if index then
		destroyHighlight(model)
		setPathVisible(model, false)
		clearRangePart(model)

		table.remove(selectedUnits, index)
	else
		local isAlive =
			model:FindFirstChild("Humanoid")
			and model.Humanoid.Health > 0

		if not isAlive then
			return
		end

		createHighlight(model)
		setPathVisible(model, true)
		createRangePart(model)

		table.insert(selectedUnits, model)
	end
end

local function deselectUnits()
	selectBuilding(selectedBuilding)
	
	for i, unit in table.clone(selectedUnits) do
		selectUnit(unit)
	end

	selectedUnits = {}
end

local function moveUnits(pos)
	for i=#selectedUnits, 1, -1 do
		local unit = selectedUnits[i]
		
		if unit:GetAttribute('PlayerId') ~= player.UserId then
			table.remove(selectedUnits, i)
		end
	end
	
	remotes.Move:FireServer(selectedUnits, pos, not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift))
end

local function selectPartsInBox(p1, p2)
	local min = Vector2.new(math.min(p1.X, p2.X), math.min(p1.Y, p2.Y))
	local max = Vector2.new(math.max(p1.X, p2.X), math.max(p1.Y, p2.Y))

	local list = {}

	for _, unit : Model in workspace.Units:GetChildren() do
		local root = unit:FindFirstChild('HumanoidRootPart')
		
		if unit:GetAttribute('PlayerId') ~= player.UserId then
			continue
		end
		
		if not root or table.find(selectedUnits, unit) then
			continue
		end
		
		local screenPoint, onScreen = camera:WorldToViewportPoint(root.Position)
		
		if onScreen then
			if screenPoint.X >= min.X and screenPoint.X <= max.X and
				screenPoint.Y >= min.Y and screenPoint.Y <= max.Y then
				
				table.insert(list, unit)
			end
		end
	end
	
	for _, unit in list do
		selectUnit(unit)
	end
end

local function mouseRaycast()
	local ignore = {workspace.Camera, player.Character, workspace.Placeholder, workspace.Waypoints}
	
	for i, unit in selectedUnits do
		if unit:FindFirstChild('Range') then
			table.insert(ignore, unit.Range)
		end
	end
	
	local mousePos = UserInputService:GetMouseLocation()

	local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignore

	return workspace:Raycast(ray.Origin, ray.Direction * 1000, rayParams)
end

function createHighlight(model)
	if not model then
		return
	end
	
	if model:FindFirstChild('UnitHighlight') then
		return
	end
	
	local highlight = Instance.new("Highlight")
	highlight.Name = 'UnitHighlight'
	highlight.Parent = model
	highlight.FillTransparency = .75
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0.25
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	
	return highlight
end

function destroyHighlight(model)
	if not model then
		return
	end
	
	local highlight = model:FindFirstChild('UnitHighlight')
	if highlight then
		highlight:Destroy()
	end
end

UserInputService.InputBegan:Connect(function(input, proc)
	if proc then
		return
	end

	if input.KeyCode == Enum.KeyCode.E then
		deselectUnits()
	end

	if input.KeyCode == Enum.KeyCode.Q then
		removePlaceholderBuilding()
	end

	if input.KeyCode == Enum.KeyCode.R then
		rotation += 45
	end

	if input.KeyCode == Enum.KeyCode.F then
		remotes.NewUnit:InvokeServer('Builder', player.Character:WaitForChild('HumanoidRootPart').CFrame)
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if templateBuilding then
			if canPlace then
				placeBuilding()
			end

			return
		end

		local result = mouseRaycast()

		if result then
			local model = getTopLevelModel(result.Instance)

			--if you clicked on a unit
			if model and (model.Parent == workspace.Units or model.Parent == workspace.Buildings) then
				if model.Parent == workspace.Units then
					local now = os.clock()
					local isDoubleClick = (now - lastClick) < DOUBLE_CLICK_TIME

					lastClick = now

					if isDoubleClick then
						-- select all units of this type, deselect everything else
						deselectUnits()

						for _, unit in workspace.Units:GetChildren() do
							if unit.Name == model.Name
								and unit:GetAttribute('PlayerId') == player.UserId then
								selectUnit(unit)
							end
						end
					else
						selectBuilding(selectedBuilding)
						selectUnit(model)
					end
				elseif model.Parent == workspace.Buildings then
					if #selectedUnits == 0 then
						if selectedBuilding ~= model then
							deselectUnits()
						end
						selectBuilding(model)
					end
				end
			else
				if #selectedUnits > 0 then
					moveUnits(result.Position)
				end
			end
		end

		local mousePos = UserInputService:GetMouseLocation()

		dragging = true

		startPos = Vector2.new(mousePos.X, mousePos.Y)

		selectionBox.Visible = true
		selectionBox.Position = UDim2.fromOffset(startPos.X, startPos.Y)
		selectionBox.Size = UDim2.fromOffset(0, 0)
	end
end)

UserInputService.InputEnded:Connect(function(input, proc)
	if proc then
		return
	end
	
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if dragging then
			dragging = false
			
			selectionBox.Visible = false
			
			selectPartsInBox(startPos, UserInputService:GetMouseLocation())
		end
	end
end)

local function getGroundPosition(position)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {workspace.Camera, player.Character, workspace.Waypoints, workspace.Units, workspace.Buildings}
	
	local result = workspace:Raycast(
		position + Vector3.new(0, 5, 0),
		Vector3.new(0, -100, 0),
		rayParams
	)
	
	return result and result.Position or position
end

remotes.ReplicatePath.OnClientEvent:Connect(function(waypointInfo)
	for unitId, waypoints in waypointInfo do
		local angle = (unitId * 137.5) % 360
		local offset = Vector3.new(
			math.cos(math.rad(angle)),
			0.75,
			math.sin(math.rad(angle))
		) * 1.5

		local folder = workspace.Waypoints:FindFirstChild(tostring(unitId))
		
		if not folder then
			folder = Instance.new('Folder')
			folder.Name = tostring(unitId)
			folder.Parent = workspace.Waypoints
			folder:SetAttribute('UnitId', unitId)
		end

		local container = folder:FindFirstChild('Container')
		
		if not container then
			container = Instance.new('Part')
			container.Name = 'Container'
			container.Anchored = true
			container.CanCollide = false
			container.Transparency = 1
			container.Size = Vector3.new(0.1, 0.1, 0.1)
			container.Position = Vector3.new(0, 0, 0)
			container.Parent = folder
		end

		if not waypointParts[unitId] then
			waypointParts[unitId] = {}
		end
		
		local parts = waypointParts[unitId]

		for i, waypoint in waypoints do
			local pos
			
			if #parts == 0 then --if its the first part
				pos = getGroundPosition(waypoint.Position)
			else
				pos = waypoint.Position + offset
			end

			local groundPos = getGroundPosition(waypoint.Position + offset)
				+ Vector3.new(0, 0.5, 0)

			local att = Instance.new("Attachment")
			att.WorldPosition = groundPos
			att.Parent = container
			att.Orientation = Vector3.new(0, 0, 90)

			table.insert(parts, {Attachment = att, Pos = groundPos})
		end

		for i, current in parts do
			local nextPart = parts[i + 1]
			if current.Attachment:FindFirstChildWhichIsA('Beam') then continue end

			local beam = ReplicatedStorage.Effects.PathBeam:Clone()
			beam.Parent = current.Attachment  
			beam.Attachment1 = current.Attachment
			beam.Enabled = false

			if nextPart then
				beam.Attachment0 = nextPart.Attachment
			end
		end

		local model
		
		for _, unit in workspace.Units:GetChildren() do
			if unit:GetAttribute("Id") == tonumber(unitId) then
				model = unit
				break
			end
		end

		setPathVisible(model, table.find(selectedUnits, model) ~= nil)
	end
end)

remotes.ClearPath.OnClientEvent:Connect(function(ids)
	for _, unitId in ids do
		local folder = workspace.Waypoints:FindFirstChild(tostring(unitId))
		
		if folder then
			folder:Destroy()
		end
		
		waypointParts[unitId] = nil
	end
end)

function removePlaceholderBuilding()
	if templateBuilding then
		clearRangePart(templateBuilding)
		
		templateBuilding:Destroy()
		templateBuilding = nil
		currentBuildingCheck = nil
		
		rotation = 0
		buildInstructions.Visible = false
		buildErrFrm.Visible = false
	end
end

local function colorPlaceholderBuilding(color)
	if not templateBuilding then
		return
	end
	
	for i, object in templateBuilding:GetDescendants() do
		if object:IsA('BasePart') then
			object.Color = color
		end
	end
end

local function addPlaceholderBuilding(name)
	local buildingExists = ReplicatedStorage.Buildings:FindFirstChild(name)
	
	if buildingExists then
		deselectUnits()
		
		removePlaceholderBuilding()
		
		templateBuilding = buildingExists:Clone()
		templateBuilding.Parent = workspace.Placeholder
		
		local module = ReplicatedStorage.Modules.Buildings:FindFirstChild(name)
		if module then
			currentBuildingCheck = require(module)
		end
		
		createRangePart(templateBuilding)

		for i, object in templateBuilding:GetDescendants() do
			if object:IsA('BasePart') then
				
				object.Material = Enum.Material.Neon
				object.Transparency = object.Transparency < 1 and .7 or 1
				object.CanCollide = false
				
				if object:IsA('MeshPart') then
					object.TextureID = ''
				end
			end
		end
		
		buildInstructions.Visible = true
		buildErrFrm.Visible = true
	else
		warn('building does not exist:', name)
	end
end

local buildings = ReplicatedStorage.Buildings:GetChildren()
for _, building in buildings do
	local price = building.Config.Price.Value

	local button = gui.BuildingSpawner.Template:Clone()
	button.Name = building.Name
	button.Price.Text = "$"..price
	button.Visible = true
	button.Parent = gui.BuildingSpawner
	button.LayoutOrder = price
	button.Image = building.Config.Icon.Image
	
	button.Activated:Connect(function()
		addPlaceholderBuilding(building.Name)
	end)
end

function placeBuilding()
	if not templateBuilding or not canPlace then
		return
	end
	
	local success = remotes.NewBuilding:InvokeServer(templateBuilding.PrimaryPart.CFrame, templateBuilding.Name)
	
	if success then
		removePlaceholderBuilding()
	end
end

local function getFriendlyBuilders()
	local list = {}
	
	for _, unit in workspace.Units:GetChildren() do
		if unit.Name == 'Builder' 
			and unit:GetAttribute('Team') == player.Team.Name
			and unit:GetAttribute('PlayerId') == player.UserId
			then
			table.insert(list, unit)
		end
	end
	
	return list
end

local function isBuilderNearby(pos)
	for _, unit in getFriendlyBuilders() do
		local range = unit.Config.Range.Value
		
		local distSquared = (unit.PrimaryPart.Position - pos):Dot(unit.PrimaryPart.Position - pos)
		
		if distSquared < range * range then
			return true
		end
	end

	return false
end

local function checkCustomConditions(model)
	if currentBuildingCheck then
		if currentBuildingCheck.getCustomConditions then
			return currentBuildingCheck.getCustomConditions(model)
		end
		
		return true
	end
end

remotes.ErrorMessage.OnClientEvent:Connect(function(msg)
	local newTxt = gui.ErrorMessages.Template:Clone()
	newTxt.Text = msg
	newTxt.Visible = true
	newTxt.Parent = gui.ErrorMessages
	newTxt.LayoutOrder = os.clock()
	
	Debris:AddItem(newTxt, 2)
end)

remotes.SetupBillboard.OnClientEvent:Connect(function(model)
	local module = ReplicatedStorage.Modules.Buildings:FindFirstChild(model.Name)
	if module then
		module = require(module)
		if module.setupBillboard then
			module.setupBillboard(model)
		end
	end
end)

remotes.BuildProgress.OnClientEvent:Connect(function(model, max)
	local newBillboard = ReplicatedStorage.Billboards.BuildProgress:Clone()
	newBillboard.Parent = player.PlayerGui.Billboards
	newBillboard.Adornee = model
	newBillboard.Enabled = true

	local owner = game.Players:GetPlayerByUserId(model:GetAttribute("PlayerId"))

	if owner and owner.Team then
		local color = owner.Team.TeamColor.Color:ToHex()

		newBillboard.Container.Title.Text =
			'<font color="#' .. color .. '">' ..
			owner.Name ..
			'</font> - ' ..
			model.Name
	else
		newBillboard.Container.Title.Text = model.Name
	end

	repeat
		task.wait(.1)

		newBillboard.Container.BarContainer.Fill.Size =
			UDim2.new(model:GetAttribute("BuildProgress") / max, 0, 1, 0)

	until model:GetAttribute("BuildProgress") >= max or not model.Parent

	newBillboard:Destroy()
end)

remotes.UnitDied.OnClientEvent:Connect(function(id, isBuilding)
	if isBuilding then
		if selectedBuilding then
			if selectedBuilding:GetAttribute('Id') == id then
				selectBuilding(selectedBuilding)
				return
			end
		end
	end
	
	--clear the path of that unit
	local folder = workspace.Waypoints:FindFirstChild(tostring(id))
	
	if folder then
		folder:Destroy()
		waypointParts[id] = nil
	end
	
	for i = #selectedUnits, 1, -1 do
		local unit = selectedUnits[i]
		
		if not unit or unit:GetAttribute("Id") == id then
			table.remove(selectedUnits, i)
		end
		
		if unit and not unit.Parent then
			table.remove(selectedUnits, i)
			continue
		end
	end
end)

gui.BuildingInfo.Items.Sell.Activated:Connect(function()
	local sell = remotes.Sell:InvokeServer()
end)

RunService.RenderStepped:Connect(function(dt)
	local result = mouseRaycast()
	local building = templateBuilding
	local mousePos = UserInputService:GetMouseLocation()

	if result and result.Instance then
		if building then
			local builderNearby = isBuilderNearby(result.Position)
			local isSpawnArea = result.Instance.Parent.Name == 'SpawnArea' 
			local conditionSatisfied, customMsg = checkCustomConditions(building)
			
			buildErrFrm.Position = UDim2.fromOffset(mousePos.X + 20, mousePos.Y - 20)
			buildErrFrm.NoBuilder.Visible = not builderNearby
			buildErrFrm.CannotBuild.Visible = not isSpawnArea
			buildErrFrm.Custom.Visible = not conditionSatisfied
			if not conditionSatisfied and customMsg then
				buildErrFrm.Custom.Text = customMsg
			end
			
			if isSpawnArea and builderNearby and conditionSatisfied then
				canPlace = true
				colorPlaceholderBuilding(Color3.new(0, 1, 0))
			else
				canPlace = false
				colorPlaceholderBuilding(Color3.new(1, 0, 0))
			end
			
			local x = result.Position.X
			local y = result.Position.Y + building.HumanoidRootPart.Size.Y / 2
			local z = result.Position.Z

			local cframe = CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(rotation), 0)
			building:PivotTo(cframe)
		end
	end

	if dragging then
		local currentPos = UserInputService:GetMouseLocation()
		local size = currentPos - startPos

		selectionBox.Position = UDim2.fromOffset(
			math.min(startPos.X, currentPos.X),
			math.min(startPos.Y, currentPos.Y)
		)
		selectionBox.Size = UDim2.fromOffset(
			math.abs(size.X),
			math.abs(size.Y)
		)
	end
end)
