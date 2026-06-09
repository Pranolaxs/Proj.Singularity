local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local e = React.createElement

local function WeaponMeshPreview(props)
	local viewportRef = React.useRef(nil)
	local modelRef = React.useRef(nil)
	local centerOffsetRef = React.useRef(CFrame.identity)
	local draggingRef = React.useRef(false)
	local lastInputXRef = React.useRef(0)
	local yaw, setYaw = React.useState(0)

	React.useEffect(function()
		local viewport = viewportRef.current
		if not viewport then
			return function() end
		end

		viewport:ClearAllChildren()
		modelRef.current = nil

		local previewFolder = ReplicatedStorage:FindFirstChild("WeaponPreviewModels")
		local source = previewFolder and previewFolder:FindFirstChild(props.WeaponName)
		if not source then
			return function() end
		end

		local world = Instance.new("WorldModel")
		world.Parent = viewport

		local model = source:Clone()
		model.Parent = world
		model:PivotTo(CFrame.identity)

		local boundsCFrame, size = model:GetBoundingBox()
		centerOffsetRef.current = CFrame.new(-boundsCFrame.Position)
		model:PivotTo(
			(props.BaseRotation or CFrame.Angles(math.rad(-8), math.rad(-36), math.rad(54)))
				* CFrame.Angles(0, math.rad(yaw), 0)
				* centerOffsetRef.current
		)
		modelRef.current = model

		local _, centeredSize = model:GetBoundingBox()
		size = centeredSize
		local maxSize = math.max(size.X, size.Y, size.Z, 1)

		local camera = Instance.new("Camera")
		camera.FieldOfView = 32
		camera.CFrame = CFrame.lookAt(Vector3.new(0, maxSize * 0.03, maxSize * 2), Vector3.new(0, 0, 0))
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		return function()
			if viewport then
				viewport:ClearAllChildren()
			end
			modelRef.current = nil
		end
	end, { props.WeaponName, props.BaseRotation })

	React.useEffect(function()
		local model = modelRef.current
		if model then
			model:PivotTo(
				(props.BaseRotation or CFrame.Angles(math.rad(-8), math.rad(-36), math.rad(54)))
					* CFrame.Angles(0, math.rad(yaw), 0)
					* centerOffsetRef.current
			)
		end
	end, { yaw, props.BaseRotation })

	React.useEffect(function()
		local changedConnection = UserInputService.InputChanged:Connect(function(input)
			if not draggingRef.current then
				return
			end

			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			local nextX = input.Position.X
			local delta = nextX - lastInputXRef.current
			lastInputXRef.current = nextX
			setYaw(function(current)
				return current + delta * 0.5
			end)
		end)

		local endedConnection = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				draggingRef.current = false
			end
		end)

		return function()
			changedConnection:Disconnect()
			endedConnection:Disconnect()
		end
	end, {})

	return e("ViewportFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(40, 180, 255),
		LightColor = Color3.fromRGB(180, 255, 255),
		LightDirection = Vector3.new(-0.4, -0.7, -0.3),
		Position = props.Position,
		Rotation = props.Rotation or -6,
		Size = props.Size,
		ZIndex = props.ZIndex or 16,
		ref = viewportRef,
		[React.Event.InputBegan] = function(_, input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			draggingRef.current = true
			lastInputXRef.current = input.Position.X
		end,
	}, {
		Stroke = if props.ShowStroke then e("UIStroke", {
			Color = Color3.fromRGB(110, 255, 255),
			Thickness = 4,
			Transparency = 0,
		}) else nil,
	})
end

return WeaponMeshPreview
