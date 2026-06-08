local SkillServiceUtils = {}

function SkillServiceUtils.getOrCreateRemote(name: string): RemoteEvent
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end

	return remote :: RemoteEvent
end

return SkillServiceUtils
