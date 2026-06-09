--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WeaponRegistry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponRegistry"))

local WeaponFactory = {}

function WeaponFactory.createWeapon(weaponId: string): Tool?
	local config = WeaponRegistry.get(weaponId)
	if not config then
		warn("WeaponFactory: unknown weapon id " .. tostring(weaponId))
		return nil
	end

	local weaponFolder = ServerStorage:FindFirstChild("WeaponInventory")
	if not weaponFolder then
		warn("WeaponFactory: missing ServerStorage.WeaponInventory")
		return nil
	end

	local template = weaponFolder:FindFirstChild(config.ModelName)
	if not template or not template:IsA("Tool") then
		warn("WeaponFactory: missing weapon model " .. config.ModelName)
		return nil
	end

	return template:Clone()
end

return WeaponFactory
