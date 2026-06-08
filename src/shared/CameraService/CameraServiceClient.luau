local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CameraServiceClient = {}
export type CameraServiceClient = typeof(CameraServiceClient) & {}

local initialized = false
local isOTSActive = true
local humanoid: Humanoid? = nil
local rootPart: BasePart? = nil
local renderConnection: RBXScriptConnection? = nil

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
end

local function setupCharacter(character: Model)
	if renderConnection then
		renderConnection:Disconnect()
	end

	humanoid = character:WaitForChild("Humanoid") :: Humanoid
	rootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
	local camera = Workspace.CurrentCamera

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
