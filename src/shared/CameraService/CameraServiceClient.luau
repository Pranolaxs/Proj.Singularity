local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CameraServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CameraService"):WaitForChild("CameraServiceUtils"))

local CameraServiceClient = {}
export type CameraServiceClient = typeof(CameraServiceClient) & {}

local initialized = false
local isOTSActive = true
local humanoid: Humanoid? = nil
local rootPart: BasePart? = nil
local renderConnection: RBXScriptConnection? = nil
local crosshairGui: ScreenGui? = nil
local crosshairRoot: Frame? = nil
local crosshairImage: ImageLabel? = nil
local crosshairConfig = table.clone(CameraServiceUtils.DEFAULT_CROSSHAIR)

local function getPlayerCrosshairConfig(player: Player)
	local config = table.clone(crosshairConfig)
	local image = player:GetAttribute("OTS_CrosshairImage")
	local size = player:GetAttribute("OTS_CrosshairSize")
	local color = player:GetAttribute("OTS_CrosshairColor")
	local transparency = player:GetAttribute("OTS_CrosshairTransparency")

	if typeof(image) == "string" then
		config.Image = image
	end
	if typeof(size) == "number" then
		config.Size = size
	end
	if typeof(color) == "Color3" then
		config.Color = color
	end
	if typeof(transparency) == "number" then
		config.Transparency = math.clamp(transparency, 0, 1)
	end

	return config
end

local function applyCrosshairVisual(player: Player)
	if not crosshairRoot or not crosshairImage then
		return
	end

	local config = getPlayerCrosshairConfig(player)
	local size = config.Size or 34
	local lineLength = config.LineLength or 11
	local lineGap = config.LineGap or 5
	local lineThickness = config.LineThickness or 3
	local hasImage = config.Image and config.Image ~= ""

	crosshairRoot.Size = UDim2.fromOffset(size, size)
	crosshairRoot.Visible = isOTSActive
	crosshairImage.Image = if hasImage then config.Image else ""
	crosshairImage.ImageColor3 = config.Color
	crosshairImage.ImageTransparency = if hasImage then config.Transparency else 1

	for _, child in ipairs(crosshairRoot:GetChildren()) do
		if child:IsA("Frame") then
			child.BackgroundColor3 = config.Color
			child.BackgroundTransparency = if hasImage then 1 else config.Transparency
		end
	end

	local half = size / 2
	local center = UDim2.fromOffset(half, half)
	local lineSizeHorizontal = UDim2.fromOffset(lineLength, lineThickness)
	local lineSizeVertical = UDim2.fromOffset(lineThickness, lineLength)

	local left = crosshairRoot:FindFirstChild("LeftLine")
	if left and left:IsA("Frame") then
		left.Position = center + UDim2.fromOffset(-(lineGap + lineLength / 2), 0)
		left.Size = lineSizeHorizontal
	end

	local right = crosshairRoot:FindFirstChild("RightLine")
	if right and right:IsA("Frame") then
		right.Position = center + UDim2.fromOffset(lineGap + lineLength / 2, 0)
		right.Size = lineSizeHorizontal
	end

	local top = crosshairRoot:FindFirstChild("TopLine")
	if top and top:IsA("Frame") then
		top.Position = center + UDim2.fromOffset(0, -(lineGap + lineLength / 2))
		top.Size = lineSizeVertical
	end

	local bottom = crosshairRoot:FindFirstChild("BottomLine")
	if bottom and bottom:IsA("Frame") then
		bottom.Position = center + UDim2.fromOffset(0, lineGap + lineLength / 2)
		bottom.Size = lineSizeVertical
	end
end

local function ensureCrosshair(player: Player)
	local playerGui = player:WaitForChild("PlayerGui")
	crosshairGui = playerGui:FindFirstChild("OTSCrosshairGui") :: ScreenGui?
	if not crosshairGui then
		crosshairGui = Instance.new("ScreenGui")
		crosshairGui.Name = "OTSCrosshairGui"
		crosshairGui.IgnoreGuiInset = true
		crosshairGui.ResetOnSpawn = false
		crosshairGui.DisplayOrder = 75
		crosshairGui.Parent = playerGui
	end

	crosshairRoot = crosshairGui:FindFirstChild("Crosshair") :: Frame?
	if not crosshairRoot then
		crosshairRoot = Instance.new("Frame")
		crosshairRoot.Name = "Crosshair"
		crosshairRoot.AnchorPoint = Vector2.new(0.5, 0.5)
		crosshairRoot.BackgroundTransparency = 1
		crosshairRoot.Position = UDim2.fromScale(0.5, 0.5)
		crosshairRoot.Parent = crosshairGui

		crosshairImage = Instance.new("ImageLabel")
		crosshairImage.Name = "Image"
		crosshairImage.BackgroundTransparency = 1
		crosshairImage.Size = UDim2.fromScale(1, 1)
		crosshairImage.Parent = crosshairRoot

		for _, lineName in ipairs({ "LeftLine", "RightLine", "TopLine", "BottomLine" }) do
			local line = Instance.new("Frame")
			line.Name = lineName
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.BorderSizePixel = 0
			line.Parent = crosshairRoot
		end
	else
		crosshairImage = crosshairRoot:FindFirstChild("Image") :: ImageLabel?
		if not crosshairImage then
			crosshairImage = Instance.new("ImageLabel")
			crosshairImage.Name = "Image"
			crosshairImage.BackgroundTransparency = 1
			crosshairImage.Size = UDim2.fromScale(1, 1)
			crosshairImage.Parent = crosshairRoot
		end
	end

	applyCrosshairVisual(player)
end

local function updateCameraMode()
	if not humanoid then
		return
	end

	if isOTSActive then
		humanoid.CameraOffset = Vector3.new(2, 1.5, 0)
		humanoid.AutoRotate = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	else
		humanoid.CameraOffset = Vector3.zero
		humanoid.AutoRotate = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	local player = Players.LocalPlayer
	if crosshairRoot then
		applyCrosshairVisual(player)
	end
end

local function setupCharacter(character: Model)
	if renderConnection then
		renderConnection:Disconnect()
	end

	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	local camera = Workspace.CurrentCamera

	ensureCrosshair(Players.LocalPlayer)
	updateCameraMode()

	renderConnection = RunService.RenderStepped:Connect(function()
		if not humanoid or humanoid.Health <= 0 or not rootPart then
			return
		end

		if isOTSActive then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			local camLook = camera.CFrame.LookVector
			local targetPos = rootPart.Position + Vector3.new(camLook.X, 0, camLook.Z)
			rootPart.CFrame = CFrame.lookAt(rootPart.Position, targetPos)
		end
	end)
end

function CameraServiceClient.build()
	return CameraServiceClient
end

function CameraServiceClient.setCrosshair(config)
	for key, value in pairs(config) do
		crosshairConfig[key] = value
	end

	applyCrosshairVisual(Players.LocalPlayer)
end

function CameraServiceClient.setCrosshairImage(image: string)
	CameraServiceClient.setCrosshair({
		Image = image,
	})
end

function CameraServiceClient.init()
	if initialized then
		return CameraServiceClient
	end
	initialized = true

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		setupCharacter(player.Character)
	end

	for _, attributeName in ipairs({
		"OTS_CrosshairImage",
		"OTS_CrosshairSize",
		"OTS_CrosshairColor",
		"OTS_CrosshairTransparency",
	}) do
		player:GetAttributeChangedSignal(attributeName):Connect(function()
			applyCrosshairVisual(player)
		end)
	end

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.V then
			isOTSActive = not isOTSActive
			updateCameraMode()
		end
	end)

	return CameraServiceClient
end

return CameraServiceClient :: CameraServiceClient
