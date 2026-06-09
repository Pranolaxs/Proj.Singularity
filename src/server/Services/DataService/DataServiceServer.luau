local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Networker = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networker"))
local ProfileService = require(ServerScriptService:WaitForChild("ServerPackages"):WaitForChild("ProfileService"))
local DataServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DataService"):WaitForChild("DataServiceUtils"))

local DataServiceServer = {}
export type DataServiceServer = typeof(DataServiceServer) & {}

local initialized = false
local profiles = {}
local profileStore
local networker

local function playerKey(player: Player): string
	return "Player_" .. player.UserId
end

local function applyAttributes(player: Player, data)
	player:SetAttribute("Coins", data.Coins or 0)
	player:SetAttribute("EquippedHookSkin", data.EquippedHookSkin or "Default")
	player:SetAttribute("InventoryData", table.concat(data.Inventory or {}, ","))
	player:SetAttribute("EquippedSkill_Q", data.EquippedSkill_Q or "Hook")
	player:SetAttribute("EquippedSkill_E", data.EquippedSkill_E or "Dash")
	player:SetAttribute("EquippedSkill_R", data.EquippedSkill_R or "Push")
	player:SetAttribute("EquippedSkill_F", data.EquippedSkill_F or "Repel")
	player:SetAttribute("SkillInventoryData", table.concat(data.SkillInventory or {}, ","))
	player:SetAttribute("EquippedWeapon", data.EquippedWeapon or "KnockbackStick")
	player:SetAttribute("WeaponInventoryData", table.concat(data.WeaponInventory or {}, ","))
end

local function reconcileList(data, key: string)
	local defaults = DataServiceUtils.DEFAULT_DATA[key]
	local list = data[key]
	if type(defaults) ~= "table" then
		return
	end
	if type(list) ~= "table" then
		data[key] = DataServiceUtils.copy(defaults)
		return
	end

	for _, defaultItem in ipairs(defaults) do
		if table.find(list, defaultItem) == nil then
			table.insert(list, defaultItem)
		end
	end
end

local function reconcileData(data)
	reconcileList(data, "Inventory")
	reconcileList(data, "SkillInventory")
	reconcileList(data, "WeaponInventory")
end

local function syncPlayer(player: Player)
	local data = DataServiceServer.getData(player)
	if data then
		reconcileData(data)
		applyAttributes(player, data)
		if networker then
			networker:fire(player, "DataUpdated", data)
		end
	end
end

local function loadPlayer(player: Player)
	local store = profileStore
	if not store then
		return
	end

	local profile = store:LoadProfileAsync(playerKey(player), "ForceLoad")
	if not profile then
		player:Kick("Data failed to load. Please rejoin.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile:ListenToRelease(function()
		profiles[player] = nil
		if player.Parent then
			player:Kick("Data loaded in another server. Please rejoin.")
		end
	end)

	if not player.Parent then
		profile:Release()
		return
	end

	profiles[player] = profile
	syncPlayer(player)
end

function DataServiceServer.build()
	profileStore = ProfileService.GetProfileStore("PlayerInventory_v4", DataServiceUtils.copy(DataServiceUtils.DEFAULT_DATA))
	if not networker then
		networker = Networker.server.new("DataService", DataServiceServer, {
			DataServiceServer.GetData,
		})
	end

	return DataServiceServer
end

function DataServiceServer.init()
	if initialized then
		return DataServiceServer
	end
	initialized = true

	if not profileStore then
		DataServiceServer.build()
	end

	Players.PlayerAdded:Connect(loadPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(loadPlayer, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			profile:Release()
		end
	end)

	return DataServiceServer
end

function DataServiceServer.getData(player: Player)
	local profile = profiles[player]
	if profile then
		return profile.Data
	end

	return DataServiceUtils.copy(DataServiceUtils.DEFAULT_DATA)
end

function DataServiceServer.GetData(_self, player: Player)
	return DataServiceServer.getData(player)
end

function DataServiceServer.setValue(player: Player, key: string, value)
	local data = DataServiceServer.getData(player)
	data[key] = value
	syncPlayer(player)
	return value
end

function DataServiceServer.increment(player: Player, key: string, amount: number)
	local data = DataServiceServer.getData(player)
	data[key] = (data[key] or 0) + amount
	syncPlayer(player)
	return data[key]
end

function DataServiceServer.hasInList(player: Player, key: string, value: string): boolean
	local data = DataServiceServer.getData(player)
	local list = data[key]
	return type(list) == "table" and table.find(list, value) ~= nil
end

function DataServiceServer.syncPlayer(player: Player)
	syncPlayer(player)
end

return DataServiceServer :: DataServiceServer
