local StarterGui = game:GetService("StarterGui")

local InventoryServiceClient = {}
export type InventoryServiceClient = typeof(InventoryServiceClient) & {}

local initialized = false

function InventoryServiceClient.build()
	return InventoryServiceClient
end

function InventoryServiceClient.init()
	if initialized then
		return InventoryServiceClient
	end
	initialized = true

	task.spawn(function()
		local success = false
		while not success do
			success = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
			task.wait(0.1)
		end
	end)

	return InventoryServiceClient
end

return InventoryServiceClient :: InventoryServiceClient
