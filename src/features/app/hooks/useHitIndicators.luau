local Debris = game:GetService("Debris")
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

local function getHitScreenPlacement(targetPosition: Vector3?, stackIndex: number?)
	local camera = Workspace.CurrentCamera
	if not camera or not targetPosition then
		return Vector2.new(camera and camera.ViewportSize.X * 0.58 or 960, camera and camera.ViewportSize.Y * 0.42 or 360), 0.62
	end

	local viewportPoint = camera:WorldToViewportPoint(targetPosition)
	local viewportSize = camera.ViewportSize
	local distance = (camera.CFrame.Position - targetPosition).Magnitude
	local scale = math.clamp(1 - ((distance - 14) / 115) * 0.42, 0.56, 0.92)
	local x = viewportPoint.X + 92 * scale
	local y = viewportPoint.Y - (22 + (stackIndex or 0) * 42) * scale

	if viewportPoint.Z < 0 then
		x = viewportSize.X * 0.62
		y = viewportSize.Y * 0.42
	end

	x = safeClamp(x, 86, viewportSize.X - 86)
	y = safeClamp(y, 68, viewportSize.Y - 68)

	return Vector2.new(x, y), scale
end

local function useHitIndicators()
	local indicators, setIndicators = React.useState({})

	React.useEffect(function()
		local remote = ReplicatedStorage:WaitForChild("HitIndicatorEvent", 10)
		if not remote or not remote:IsA("RemoteEvent") then
			return function() end
		end

		local connection = remote.OnClientEvent:Connect(function(payload)
			payload = if type(payload) == "table" then payload else {}
			playLocalHitSound(0.28, HIT_RANDOM:NextNumber(0.95, 1.08))

			local id = tostring(os.clock()) .. "-" .. tostring(HIT_RANDOM:NextInteger(1000, 9999))
			local targetName = payload.targetName or "Target"

			setIndicators(function(current)
				local nextIndicators = table.clone(current)
				local stackIndex = 0
				for _, item in ipairs(nextIndicators) do
					if item.targetName == targetName then
						stackIndex += 1
					end
				end

				local screenPosition, scale = getHitScreenPlacement(payload.targetPosition, stackIndex)
				local indicator = {
					id = id,
					targetName = targetName,
					text = payload.text or "HIT!",
					damage = payload.damage or 0,
					totalDamage = payload.totalDamage or 0,
					position = screenPosition,
					scale = scale,
					rotation = HIT_RANDOM:NextInteger(-5, 3),
				}

				table.insert(nextIndicators, indicator)
				if #nextIndicators > 5 then
					table.remove(nextIndicators, 1)
				end
				return nextIndicators
			end)

			task.delay(0.82, function()
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

return useHitIndicators
