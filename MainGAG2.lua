_G.harvest = false
_G.sell = false
_G.autoseed = false
_G.autopickseed = false
_G.autosteal = false
_G.autoplant = false
_G.plantmode = "Random Plot"
_G.harvestfilter = "All"

local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local Networking = require(RS:WaitForChild("SharedModules"):WaitForChild("Networking"))
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local hide = LP:FindFirstChild("HideCollectProximityPrompts")
if hide then hide.Value = false end

local function getModel(prompt)
	local model = prompt.Parent
	while model and not model:IsA("Model") do
		model = model.Parent
	end
	return model
end

local TweenSpeed = 300

local function tweento(targetPos)
	local char = LP.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local part = Instance.new("Part")
	part.Name = "trieu"
	part.Size = Vector3.new(0.1, 0.1, 0.1)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = hrp.CFrame
	part.Parent = char

	local alignPos = Instance.new("AlignPosition")
	alignPos.Attachment0 = part:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", part)
	alignPos.Attachment1 = hrp:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", hrp)
	alignPos.RigidityEnabled = true
	alignPos.Responsiveness = 200
	alignPos.Parent = part

	local distance = (part.Position - targetPos).Magnitude
	local duration = distance / TweenSpeed
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
	local goal = {CFrame = CFrame.new(targetPos)}
	local tween = TweenService:Create(part, tweenInfo, goal)

	local connection
	local cleanup = function()
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if tween then
			tween:Cancel()
			tween = nil
		end
		part:Destroy()
	end

	connection = tween.Completed:Connect(function()
		cleanup()
	end)

	tween:Play()
	tween.Completed:Wait()
	hrp.CFrame = CFrame.new(targetPos)
	cleanup()
end

local function getSeedLocations()
	local seeds = {}
	local map = workspace:FindFirstChild("Map")
	if map then
		local serverLocs = map:FindFirstChild("SeedPackSpawnServerLocations")
		if serverLocs then
			for _, part in ipairs(serverLocs:GetChildren()) do
				if part:IsA("BasePart") then
					local prompt = part:FindFirstChildWhichIsA("ProximityPrompt")
					if prompt and prompt.Enabled then
						local pos = part.Position + Vector3.new(0, part.Size.Y / 2 + 3, 0)
						table.insert(seeds, {model = part, pos = pos})
					end
				end
			end
		end
	end
	if #seeds == 0 then
		for _, tag in ipairs({"SeedPrompt", "CollectSeed", "SeedPackPrompt"}) do
			for _, prompt in ipairs(CollectionService:GetTagged(tag)) do
				if prompt:IsA("ProximityPrompt") and prompt.Enabled then
					local parent = prompt.Parent
					if parent:IsA("BasePart") then
						local pos = parent.Position + Vector3.new(0, parent.Size.Y / 2 + 3, 0)
						table.insert(seeds, {model = parent, pos = pos})
					end
				end
			end
		end
	end
	if #seeds == 0 then
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("ProximityPrompt") and obj.Enabled and (obj.Name:lower():find("seed") or obj.Name:lower():find("pickup")) then
				local parent = obj.Parent
				if parent:IsA("BasePart") then
					local pos = parent.Position + Vector3.new(0, parent.Size.Y / 2 + 3, 0)
					table.insert(seeds, {model = parent, pos = pos})
				end
			end
		end
	end
	return seeds
end

local function collectSeedAt(model)
	local prompt = model:FindFirstChildWhichIsA("ProximityPrompt")
	if not prompt then
		for _, child in ipairs(model:GetDescendants()) do
			if child:IsA("ProximityPrompt") then
				prompt = child
				break
			end
		end
	end
	if prompt then
		local oldDist = prompt.MaxActivationDistance
		prompt.MaxActivationDistance = math.huge
		prompt.Enabled = true
		local holdTime = math.max(prompt.HoldDuration, 0.05)
		prompt:InputHoldBegin()
		task.wait(holdTime + 0.03)
		prompt:InputHoldEnd()
		prompt.MaxActivationDistance = oldDist
		return true
	end
	return false
end

local function autoPickSeedTween()
	while true do
		if _G.autopickseed then
			local seeds = getSeedLocations()
			if #seeds > 0 then
				table.sort(seeds, function(a, b)
					local char = LP.Character
					if char and char:FindFirstChild("HumanoidRootPart") then
						local rootPos = char.HumanoidRootPart.Position
						return (a.pos - rootPos).Magnitude < (b.pos - rootPos).Magnitude
					end
					return false
				end)
				local target = seeds[1]
				tweento(target.pos)
				task.wait(0.3)
				collectSeedAt(target.model)
			end
		end
		task.wait(0.5)
	end
end

local function getStealTargets()
	local targets = {}
	local night = RS:FindFirstChild("Night")
	if not night or night.Value ~= true then return targets end
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LP and player.Character then
			local plotId = player:GetAttribute("PlotId")
			if plotId then
				local garden = workspace.Gardens:FindFirstChild("Plot" .. tostring(plotId))
				if garden then
					local plants = garden:FindFirstChild("Plants")
					if plants then
						for _, plant in ipairs(plants:GetChildren()) do
							local fruits = plant:FindFirstChild("Fruits")
							if fruits then
								for _, fruit in ipairs(fruits:GetChildren()) do
									local fruitId = fruit:GetAttribute("FruitId")
									local plantId = fruit:GetAttribute("PlantId")
									if fruitId and plantId then
										local pos = fruit.PrimaryPart and fruit.PrimaryPart.Position or fruit:GetPivot().Position
										table.insert(targets, {fruit = fruit, pos = pos, player = player, plantId = plantId, fruitId = fruitId})
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return targets
end

local function stealAt(target)
	local prompt = target.fruit:FindFirstChildWhichIsA("ProximityPrompt")
	if not prompt or not prompt.Enabled then return false end
	local oldDist = prompt.MaxActivationDistance
	prompt.MaxActivationDistance = math.huge
	local holdTime = math.max(prompt.HoldDuration, 0.5)
	prompt:InputHoldBegin()
	task.wait(holdTime + 0.1)
	prompt:InputHoldEnd()
	prompt.MaxActivationDistance = oldDist
	return true
end

local function returnToHomePlot()
	local plotId = LP:GetAttribute("PlotId")
	if plotId then
		local garden = workspace.Gardens:FindFirstChild("Plot" .. tostring(plotId))
		if garden then
			local spawn = garden:FindFirstChild("SpawnPoint")
			if spawn then
				tweento(spawn.Position)
				return
			end
		end
	end
	tweento(Vector3.new(0, 10, 0))
end

local function autoStealTween()
	while true do
		if _G.autosteal then
			local targets = getStealTargets()
			if #targets > 0 then
				local target = targets[math.random(1, #targets)]
				tweento(target.pos)
				task.wait(0.2)
				if stealAt(target) then
					task.wait(0.2)
					returnToHomePlot()
					task.wait(0.2)
				end
			else
				task.wait(0.3)
			end
		else
			task.wait(0.5)
		end
	end
end

local function harvestLoop()
	while true do
		if _G.harvest then
			local prompts = CollectionService:GetTagged("HarvestPrompt")
			for _, prompt in ipairs(prompts) do
				if not _G.harvest then break end
				if prompt:IsA("ProximityPrompt") and prompt.Enabled then
					local fruitModel = nil
					local cur = prompt.Parent
					while cur do
						if cur:IsA("Model") and cur:GetAttribute("FruitId") then
							fruitModel = cur
							break
						end
						cur = cur.Parent
					end
					if fruitModel then
						local plantName = fruitModel:GetAttribute("CorePartName") or fruitModel:GetAttribute("SeedName")
						if _G.harvestfilter == "All" or plantName == _G.harvestfilter then
							task.spawn(function()
								if not _G.harvest then return end
								if not prompt:IsDescendantOf(workspace) or not prompt.Enabled then return end
								if not fruitModel:IsDescendantOf(workspace) then return end
								local plantId = fruitModel:GetAttribute("PlantId")
								local fruitId = fruitModel:GetAttribute("FruitId") or ""
								if plantId then
									local oldDist = prompt.MaxActivationDistance
									prompt.MaxActivationDistance = math.huge
									local holdTime = math.max(prompt.HoldDuration, 0.05)
									prompt:InputHoldBegin()
									task.wait(holdTime + 0.03)
									prompt:InputHoldEnd()
									Networking.Garden.CollectFruit:Fire(plantId, fruitId)
									prompt.MaxActivationDistance = oldDist
								end
							end)
						end
					end
				end
			end
		end
		task.wait(0.1)
	end
end

local function sellLoop()
	while true do
		if _G.sell then
			pcall(function()
				Networking.NPCS.SellAll:Fire()
			end)
		end
		task.wait(0.5)
	end
end

local function seedLoop()
	while true do
		if _G.autoseed then
			local seedPrompts = {}
			for _, tag in ipairs({"SeedPrompt", "CollectSeed", "SeedPackPrompt"}) do
				for _, p in ipairs(CollectionService:GetTagged(tag)) do
					if p:IsA("ProximityPrompt") and p.Enabled then
						table.insert(seedPrompts, p)
					end
				end
			end
			if #seedPrompts == 0 then
				for _, obj in ipairs(workspace:GetDescendants()) do
					if obj:IsA("ProximityPrompt") and obj.Enabled and (obj.Name:lower():find("seed") or obj.Name:lower():find("pickup")) then
						table.insert(seedPrompts, obj)
					end
				end
			end
			for _, prompt in ipairs(seedPrompts) do
				local oldDist = prompt.MaxActivationDistance
				prompt.MaxActivationDistance = math.huge
				local holdTime = math.max(prompt.HoldDuration, 0.05)
				prompt:InputHoldBegin()
				task.wait(holdTime + 0.03)
				prompt:InputHoldEnd()
				prompt.MaxActivationDistance = oldDist
				task.wait(0.01)
			end
		end
		task.wait(0.2)
	end
end

local function getPlantAreaGround(position)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = CollectionService:GetTagged("PlantArea")
	local result = workspace:Raycast(position + Vector3.new(0, 10, 0), Vector3.new(0, -20, 0), rayParams)
	if result then
		return result.Position
	end
	return nil
end

local function plantSeedAtPosition(position)
	local backpack = LP:FindFirstChildOfClass("Backpack")
	if not backpack then return false end
	local seedTool = nil
	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") and tool:GetAttribute("SeedTool") then
			seedTool = tool
			break
		end
	end
	if not seedTool then return false end
	local seedName = seedTool:GetAttribute("SeedTool")
	Networking.Plant.PlantSeed:Fire(position, seedName, seedTool)
	return true
end

local function autoPlantLoop()
	while true do
		if _G.autoplant then
			local plot = workspace.Gardens:FindFirstChild("Plot" .. LP:GetAttribute("PlotId"))
			if plot then
				local targetPos
				if _G.plantmode == "Under Player" then
					local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
					if hrp then
						local groundPos = getPlantAreaGround(hrp.Position)
						if groundPos then
							targetPos = groundPos
						end
					end
				else
					local plantAreas = CollectionService:GetTagged("PlantArea")
					local plotPlantAreas = {}
					for _, area in ipairs(plantAreas) do
						if area:IsDescendantOf(plot) then
							table.insert(plotPlantAreas, area)
						end
					end
					if #plotPlantAreas > 0 then
						local area = plotPlantAreas[math.random(1, #plotPlantAreas)]
						local pos = area.Position
						local size = area.Size
						local randX = pos.X + (math.random() - 0.5) * size.X
						local randZ = pos.Z + (math.random() - 0.5) * size.Z
						targetPos = Vector3.new(randX, pos.Y + size.Y/2 + 0.1, randZ)
					end
				end
				if targetPos then
					tweento(targetPos)
					task.wait(0.2)
					plantSeedAtPosition(targetPos)
					task.wait(1)
				end
			end
		end
		task.wait(0.5)
	end
end

local function getPlantNamesInPlot()
	local names = {"All"}
	local plotId = LP:GetAttribute("PlotId")
	if plotId then
		local plot = workspace.Gardens:FindFirstChild("Plot" .. tostring(plotId))
		if plot then
			local plantsFolder = plot:FindFirstChild("Plants")
			if plantsFolder then
				local seen = {}
				for _, plant in ipairs(plantsFolder:GetChildren()) do
					local name = plant:GetAttribute("SeedName")
					if name and not seen[name] then
						seen[name] = true
						table.insert(names, name)
					end
				end
			end
		end
	end
	return names
end

task.spawn(harvestLoop)
task.spawn(sellLoop)
task.spawn(seedLoop)
task.spawn(autoPickSeedTween)
task.spawn(autoStealTween)
task.spawn(autoPlantLoop)

local redzlib = loadstring(game:HttpGet("https://raw.githubusercontent.com/tlredz/Library/refs/heads/main/redz-V5-remake/main.luau"))()
local Window = redzlib:MakeWindow({
    Title = "Wanyoui Free",
    SubTitle = "[ MAIN ]",
    SaveFolder = "SaveGAG2"
})

local Minimizer = Window:NewMinimizer({
  KeyCode = Enum.KeyCode.LeftControl
})

local MobileButton = Minimizer:CreateMobileMinimizer({
  Image = "rbxassetid://6681824686",
  BackgroundColor3 = Color3.fromRGB(0, 255, 254)
})

local TabFarm = Window:MakeTab({Title = "FARM", Icon = ""})
local harvestDropdown = TabFarm:AddDropdown({
	Name = "Harvest Filter",
	Options = getPlantNamesInPlot(),
	Default = "All",
	Callback = function(v)
		_G.harvestfilter = v
	end
})
task.spawn(function()
	while true do
		task.wait(3)
		local options = getPlantNamesInPlot()
		if not table.find(options, _G.harvestfilter) then
			_G.harvestfilter = "All"
		end
		pcall(function()
			harvestDropdown:SetOptions(options)
		end)
	end
end)
TabFarm:AddToggle({Name = "harvest fruits", Description = "harvest", Icon = "", Default = false, Callback = function(v) _G.harvest = v end})
TabFarm:AddToggle({Name = "sell", Description = "sell", Icon = "", Default = false, Flag = "sell", Callback = function(v) _G.sell = v end})
TabFarm:AddToggle({Name = "seed pick (no tp)", Description = "pick seed nearby", Icon = "", Default = false, Callback = function(v) _G.autoseed = v end})
TabFarm:AddToggle({Name = "auto pick seed (tp)", Description = "tween to seed packs", Icon = "", Default = false, Callback = function(v) _G.autopickseed = v end})
TabFarm:AddToggle({Name = "auto steal (tp)", Description = "tween steal fruits", Icon = "", Default = false, Callback = function(v) _G.autosteal = v end})
TabFarm:AddToggle({Name = "auto plant", Description = "auto plant seeds", Icon = "", Default = false, Callback = function(v) _G.autoplant = v end})
TabFarm:AddDropdown({Name = "Plant Mode", Options = {"Random Plot", "Under Player"}, Default = "Random Plot", Callback = function(v) _G.plantmode = v end})