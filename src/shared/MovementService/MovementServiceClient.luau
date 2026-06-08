local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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
	local animator = humanoid:WaitForChild("Animator") :: Animator
	local camera = workspace.CurrentCamera

	local runAnim = Instance.new("Animation")
	runAnim.AnimationId = "rbxassetid://107533869470327"
	local runTrack = animator:LoadAnimation(runAnim)

	local baseSpeed = 16
	local combatCooldown = 8
	local energy = 100
	local isExhausted = false
	local currentGhostSpeed = baseSpeed
	local lastPublishedEnergy = -1

	local function updateFOV(target: number)
		TweenService:Create(camera, TweenInfo.new(0.3), { FieldOfView = target }):Play()
	end

	renderConnection = RunService.RenderStepped:Connect(function(dt)
		if humanoid.Health <= 0 then
			return
		end

		local lastCombat = character:GetAttribute("LastCombatTick") or 0
		local timeSinceCombat = tick() - lastCombat
		local isOutOfCombat = timeSinceCombat > combatCooldown
		local isGhost = character:GetAttribute("IsGhost") or false
		local currentBaseSpeed = isOutOfCombat and baseSpeed + 6 or baseSpeed

		if isOutOfCombat then
			player:SetAttribute("CombatStatusText", "OUT OF COMBAT")
			player:SetAttribute("CombatRemaining", 0)
		else
			local remainingCombat = math.max(0, combatCooldown - timeSinceCombat)
			player:SetAttribute("CombatStatusText", string.format("IN COMBAT (%.1fs)", remainingCombat))
			player:SetAttribute("CombatRemaining", remainingCombat)
		end

		if energy <= 0 then
			isExhausted = true
		elseif energy >= 25 then
			isExhausted = false
		end

		local targetSpeed = currentBaseSpeed
		if isGhost then
			currentGhostSpeed = math.min(42, currentGhostSpeed + (25 * dt))
			targetSpeed = currentGhostSpeed
			updateFOV(95)
		else
			currentGhostSpeed = currentBaseSpeed
			local sprinting = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
				and energy > 0
				and humanoid.MoveDirection.Magnitude > 0
				and not isExhausted

			if sprinting then
				energy = math.max(0, energy - (15 * dt))
				targetSpeed = currentBaseSpeed + 10
				if not runTrack.IsPlaying then runTrack:Play(0.3) end
				updateFOV(85)
			else
				energy = math.min(100, energy + (10 * dt))
				if runTrack.IsPlaying then runTrack:Stop(0.3) end
				updateFOV(70)
			end
		end

		humanoid.WalkSpeed = targetSpeed
		if math.abs(energy - lastPublishedEnergy) > 0.2 then
			lastPublishedEnergy = energy
			player:SetAttribute("StaminaPercent", energy)
		end
		player:SetAttribute("IsStaminaExhausted", isExhausted)
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
