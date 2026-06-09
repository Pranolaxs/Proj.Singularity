local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local function safeClamp(value: number, minimum: number, maximum: number): number
	if maximum < minimum then
		return (minimum + maximum) / 2
	end

	return math.clamp(value, minimum, maximum)
end

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function useGameplayProjection(player: Player, viewportScale: number)
	local projection, setProjection = React.useState({
		hudPosition = UDim2.fromScale(0.58, 0.64),
		staminaPosition = UDim2.fromScale(0.42, 0.52),
		scale = viewportScale,
	})

	React.useEffect(function()
		local lastX = -1
		local lastY = -1
		local lastScale = -1

		local connection = RunService.RenderStepped:Connect(function()
			local camera = Workspace.CurrentCamera
			if not camera then
				return
			end

			local viewportSize = camera.ViewportSize
			local root = getCharacterRoot(player)
			local hudX = viewportSize.X - 230 * viewportScale
			local hudY = viewportSize.Y - 185 * viewportScale
			local staminaX = 118 * viewportScale
			local staminaY = viewportSize.Y * 0.54
			local distanceScale = viewportScale

			if root then
				local lowerPoint = root.Position + Vector3.new(0, -1.75, 0)
				local centerPoint = root.Position + Vector3.new(0, 0.3, 0)
				local lowerViewport = camera:WorldToViewportPoint(lowerPoint)
				local centerViewport = camera:WorldToViewportPoint(centerPoint)
				local distance = (camera.CFrame.Position - root.Position).Magnitude

				distanceScale = math.clamp(1 - ((distance - 14) / 120) * 0.25, 0.78, 1.05) * viewportScale

				if lowerViewport.Z > 0 then
					hudX = lowerViewport.X + 118 * distanceScale
					hudY = lowerViewport.Y + 34 * distanceScale
					hudX = safeClamp(hudX, 160 * distanceScale, viewportSize.X - 155 * distanceScale)
					hudY = safeClamp(hudY, 170 * distanceScale, viewportSize.Y - 78 * distanceScale)
				end

				if centerViewport.Z > 0 then
					staminaX = centerViewport.X - 118 * distanceScale
					staminaY = centerViewport.Y + 4 * distanceScale
					staminaX = safeClamp(staminaX, 52 * distanceScale, viewportSize.X - 70 * distanceScale)
					staminaY = safeClamp(staminaY, 130 * distanceScale, viewportSize.Y - 126 * distanceScale)
				end
			end

			if math.abs(hudX - lastX) > 1 or math.abs(hudY - lastY) > 1 or math.abs(distanceScale - lastScale) > 0.01 then
				lastX = hudX
				lastY = hudY
				lastScale = distanceScale
				setProjection({
					hudPosition = UDim2.fromOffset(hudX, hudY),
					staminaPosition = UDim2.fromOffset(staminaX, staminaY),
					scale = distanceScale,
				})
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, { player, viewportScale })

	return projection
end

return useGameplayProjection
