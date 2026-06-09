local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local AnimationServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationService"):WaitForChild("AnimationServiceUtils"))
local MovementServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MovementService"):WaitForChild("MovementServiceUtils"))

local MovementServiceClient = {}
export type MovementServiceClient = typeof(MovementServiceClient) & {}

local initialized = false
local renderConnection: RBXScriptConnection? = nil

local function setupCharacter(character: Model)
	if renderConnection then
		renderConnection:Disconnect()
	end

	local player = Players.LocalPlayer
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local camera = workspace.CurrentCamera
	local movementRemote = MovementServiceUtils.getMovementStateRemote() or ReplicatedStorage:WaitForChild("MovementStateEvent", 5)

	AnimationServiceUtils.applyMovementAnimations(character)
	local lastSprintIntent = false
	local publishAccumulator = 0

	local function updateFOV(target: number)
		TweenService:Create(camera, TweenInfo.new(0.3), { FieldOfView = target }):Play()
	end

	renderConnection = RunService.RenderStepped:Connect(function(dt)
		if humanoid.Health <= 0 then
			return
		end

		local isGhost = character:GetAttribute("IsGhost") or false
		local stamina = player:GetAttribute("StaminaPercent") or 100
		local isExhausted = player:GetAttribute("IsStaminaExhausted") == true
		local sprintIntent = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
			and stamina > 0
			and humanoid.MoveDirection.Magnitude > 0
			and not isExhausted

		publishAccumulator += dt
		if movementRemote and movementRemote:IsA("RemoteEvent") and (sprintIntent ~= lastSprintIntent or publishAccumulator >= 0.2) then
			lastSprintIntent = sprintIntent
			publishAccumulator = 0
			movementRemote:FireServer({
				sprinting = sprintIntent,
			})
		end

		if isGhost then
			updateFOV(95)
		elseif sprintIntent then
			updateFOV(85)
		else
			updateFOV(70)
		end
	end)
end

function MovementServiceClient.build()
	return MovementServiceClient
end

function MovementServiceClient.init()
	if initialized then
		return MovementServiceClient
	end
	initialized = true

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		setupCharacter(player.Character)
	end

	return MovementServiceClient
end

return MovementServiceClient :: MovementServiceClient
