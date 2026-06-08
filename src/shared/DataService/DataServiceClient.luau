local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networker"))

local DataServiceClient = {
	Data = {},
}
export type DataServiceClient = typeof(DataServiceClient) & {}

local initialized = false
local networker

function DataServiceClient.build()
	return DataServiceClient
end

function DataServiceClient.init()
	if initialized then
		return DataServiceClient
	end
	initialized = true

	networker = Networker.client.new("DataService", DataServiceClient)
	DataServiceClient.Data = networker:fetch("GetData") or {}

	return DataServiceClient
end

function DataServiceClient.DataUpdated(data)
	DataServiceClient.Data = data or {}
end

function DataServiceClient.getData()
	return DataServiceClient.Data
end

return DataServiceClient :: DataServiceClient
