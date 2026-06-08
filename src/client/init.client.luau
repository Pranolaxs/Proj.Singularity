local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local serviceOrder = {
	"DataService",
	"QuestService",
	"InventoryService",
	"DamageCalcService",
	"RoundService",
	"MovementService",
	"CameraService",
	"SkillService",
}

for _, serviceName in ipairs(serviceOrder) do
	local serviceFolder = Shared:WaitForChild(serviceName)
	local service = require(serviceFolder:WaitForChild(serviceName .. "Client"))

	if type(service.build) == "function" then
		service.build()
	end

	if type(service.init) == "function" then
		service.init()
	end
end
