local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementServiceUtils = {}

function MovementServiceUtils.getMovementStateRemote(): RemoteEvent?
	local remote = ReplicatedStorage:FindFirstChild("MovementStateEvent")
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	if not RunService:IsServer() then
		return nil
	end

	if remote then
		remote:Destroy()
	end

	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = "MovementStateEvent"
	newRemote.Parent = ReplicatedStorage
	return newRemote
end

return MovementServiceUtils
