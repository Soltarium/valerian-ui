local player = game.Players.LocalPlayer
local rp = game:GetService("ReplicatedStorage")
local net = require(rp.SharedModules.Networking)
local notif = require(player.PlayerScripts.Controllers.NotificationController)
local function safeRequire(path)
local ok, res = pcall(require, path)
return ok and res or {}
end
local seedData = safeRequire(rp.SharedModules.SeedData)
local petData = safeRequire(rp.SharedData.PetData)
local sprinklerData = safeRequire(rp.SharedModules.SprinklerData)
local canData = safeRequire(rp.SharedModules.WateringcanData)
local mushroomData = safeRequire(rp.SharedModules.MushroomData)
local raccoonData = safeRequire(rp.SharedModules.RaccoonData)
local gnomeData = safeRequire(rp.SharedModules.GnomeData)
local crateData = safeRequire(rp.SharedModules.CrateData)
local seedPackData = safeRequire(rp.SharedModules.SeedPackData)
local fakeInventory = {
	Pets = {}, Seeds = {}, HarvestedFruits = {}, Sprinklers = {}, WateringCans = {},
	Mushrooms = {}, Raccoons = {}, Gnomes = {}, Crates = {}, SeedPacks = {},
	Trowels = {}, Props = {}, EmptyPots = {}
}
for name, info in pairs(petData) do
	if type(info) == "table" and info.DisplayName then
		table.insert(fakeInventory.Pets, { Id = "fake_" .. name, Name = name, Equipped = false, Type = "", Size = "Normal" })
	end
end
for _, s in ipairs(seedData) do
	if s.SeedName then
		fakeInventory.Seeds[s.SeedName] = 999		table.insert(fakeInventory.HarvestedFruits, { Id = "fake_fruit_" .. s.SeedName, FruitName = s.SeedName, Mutation = nil, SizeMultiplier = 1 })
	end
end
for _, item in ipairs(sprinklerData) do if item.SprinklerName then fakeInventory.Sprinklers[item.SprinklerName] = 999 end end
for _, item in ipairs(canData) do if item.Name then fakeInventory.WateringCans[item.Name] = 999 end end
for _, item in ipairs(mushroomData) do if item.Name then fakeInventory.Mushrooms[item.Name] = 999 end end
for _, item in ipairs(raccoonData) do if item.Name then fakeInventory.Raccoons[item.Name] = 999 end end
for _, item in ipairs(gnomeData) do if item.Name then fakeInventory.Gnomes[item.Name] = 999 end end
if crateData.Data then for _, item in ipairs(crateData.Data) do if item.Name then fakeInventory.Crates[item.Name] = 999 end end end
for _, item in ipairs(seedPackData) do if item.PackName then fakeInventory.SeedPacks[item.PackName] = 999 end end
fakeInventory.Trowels["Trowel"] = 999
local propsFolder = rp.Assets:FindFirstChild("Props")
if propsFolder then for _, obj in ipairs(propsFolder:GetChildren()) do if obj:IsA("Model") or obj:IsA("BasePart") then fakeInventory.Props[obj.Name] = 999 end end end
fakeInventory.EmptyPots["Empty Pot"] = 999
local PlayerStateClient = require(rp.ClientModules.PlayerStateClient)
local origGetReplica = PlayerStateClient.GetLocalReplica
PlayerStateClient.GetLocalReplica = function()
	local repl = origGetReplica()
	if not repl then return nil end
	local proxy = { Data = { Inventory = fakeInventory } }
	return setmetatable(proxy, { __index = repl })
end
local MailboxController
repeat
	task.wait()
	MailboxController = pcall(require, player.PlayerScripts.Controllers.MailboxController) and require(player.PlayerScripts.Controllers.MailboxController)
until MailboxController
net.Mailbox.SendBatch.Fire = function(toUserId, items, note)
	notif:CreateNotification("Gift sent!")
	MailboxController:_resetToPlayerList()
end
print("Loaded")
