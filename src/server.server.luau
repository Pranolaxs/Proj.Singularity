local Services = script.Parent:WaitForChild("Services")

local serviceOrder = {
	"DataService",
	"QuestService",
	"InventoryService",
	"DamageCalcService",
	"SkillService",
	"RoundService",
	"MovementService",
	"CameraService",
}

for _, serviceName in ipairs(serviceOrder) do
	local serviceFolder = Services:WaitForChild(serviceName)
	local service = require(serviceFolder:WaitForChild(serviceName .. "Server"))

	if type(service.build) == "function" then
		service.build()
	end

	if type(service.init) == "function" then
		service.init()
	end
end
