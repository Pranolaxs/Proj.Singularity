local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local HIT_RANDOM = Random.new()
local HIT_SOUND_ID = "rbxasset://sounds/swordslash.wav"

local function playLocalHitSound(volume: number, playbackSpeed: number)
	local sound = Instance.new("Sound")
	sound.Name = "HitFeedbackSound"
	sound.SoundId = HIT_SOUND_ID
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed
	sound.Parent = SoundService
	SoundService:PlayLocalSound(sound)
	Debris:AddItem(sound, 1.2)
end

local function safeClamp(value: number, minimum: number, maximum: number): number
	if maximum < minimum then
		return (minimum + maximum) / 2
	end

	return math.clamp(value, minimum, maximum)
end

local function getDamageDirectionPlacement(payload)
	local camera = Workspace.CurrentCamera
	if not camera then
		return UDim2.fromScale(0.5, 0.34), 0
	end

	local viewportSize = camera.ViewportSize
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
	local sourcePosition = payload.sourcePosition

	if typeof(sourcePosition) == "Vector3" and root and root:IsA("BasePart") then
		local rootViewport = camera:WorldToViewportPoint(root.Position)
		local sourceViewport = camera:WorldToViewportPoint(sourcePosition)
		if rootViewport.Z > 0 and sourceViewport.Z > 0 then
			center = Vector2.new(rootViewport.X, rootViewport.Y)
			local delta = Vector2.new(sourceViewport.X, sourceViewport.Y) - center
			if delta.Magnitude > 0.01 then
				local unit = delta.Unit
				local radius = math.min(viewportSize.X, viewportSize.Y) * 0.28
				local x = safeClamp(center.X + unit.X * radius, 64, viewportSize.X - 64)
				local y = safeClamp(center.Y + unit.Y * radius, 64, viewportSize.Y - 64)
				return UDim2.fromOffset(x, y), math.deg(math.atan2(unit.Y, unit.X))
			end
		end
	end

	local direction = payload.attackDirection
	if typeof(direction) ~= "Vector3" or direction.Magnitude <= 0.01 then
		direction = camera.CFrame.LookVector
	end
	local localDirection = camera.CFrame:VectorToObjectSpace(direction.Unit)
	local screenDirection = Vector2.new(localDirection.X, -localDirection.Z)
	if screenDirection.Magnitude <= 0.01 then
		screenDirection = Vector2.new(1, 0)
	else
		screenDirection = screenDirection.Unit
	end
	local radius = math.min(viewportSize.X, viewportSize.Y) * 0.28
	local x = safeClamp(center.X + screenDirection.X * radius, 64, viewportSize.X - 64)
	local y = safeClamp(center.Y + screenDirection.Y * radius, 64, viewportSize.Y - 64)

	return UDim2.fromOffset(x, y), math.deg(math.atan2(screenDirection.Y, screenDirection.X))
end

local function useDamageTakenIndicators()
	local indicators, setIndicators = React.useState({})

	React.useEffect(function()
		local remote = ReplicatedStorage:WaitForChild("DamageTakenIndicatorEvent", 10)
		if not remote or not remote:IsA("RemoteEvent") then
			return function() end
		end

		local connection = remote.OnClientEvent:Connect(function(payload)
			payload = if type(payload) == "table" then payload else {}
			local position, rotation = getDamageDirectionPlacement(payload)
			playLocalHitSound(0.36, HIT_RANDOM:NextNumber(0.82, 0.96))

			local id = tostring(os.clock()) .. "-damage-" .. tostring(HIT_RANDOM:NextInteger(1000, 9999))
			local indicator = {
				id = id,
				position = position,
				rotation = rotation,
			}

			setIndicators(function(current)
				local nextIndicators = table.clone(current)
				table.insert(nextIndicators, indicator)
				if #nextIndicators > 3 then
					table.remove(nextIndicators, 1)
				end
				return nextIndicators
			end)

			task.delay(0.56, function()
				setIndicators(function(current)
					local nextIndicators = {}
					for _, item in ipairs(current) do
						if item.id ~= id then
							table.insert(nextIndicators, item)
						end
					end
					return nextIndicators
				end)
			end)
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	return indicators
end

return useDamageTakenIndicators
