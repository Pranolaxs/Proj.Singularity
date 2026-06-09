local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local function calculateViewportScale(): number
	local camera = Workspace.CurrentCamera
	local viewportSize = if camera then camera.ViewportSize else Vector2.new(1366, 768)
	local scale = math.min(viewportSize.X / 1366, viewportSize.Y / 768)
	return math.clamp(scale, 0.72, 1.12)
end

local function useViewportScale()
	local scale, setScale = React.useState(calculateViewportScale())

	React.useEffect(function()
		local lastScale = scale
		local connection = RunService.RenderStepped:Connect(function()
			local nextScale = calculateViewportScale()
			if math.abs(nextScale - lastScale) > 0.01 then
				lastScale = nextScale
				setScale(nextScale)
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	return scale
end

return useViewportScale
