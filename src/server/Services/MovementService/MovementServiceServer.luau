local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationService"):WaitForChild("AnimationServiceUtils"))
local MovementServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MovementService"):WaitForChild("MovementServiceUtils"))

local MovementServiceServer = {}
export type MovementServiceServer = typeof(MovementServiceServer) & {}

local initialized = false
local movementStates = {}

local BASE_SPEED = 16
local OUT_OF_COMBAT_BONUS = 6
local SPRINT_BONUS = 10
local CLOAK_SPRINT_BONUS = 20
local GHOST_MAX_SPEED = 42
local COMBAT_COOLDOWN = 8
local STAMINA_DRAIN = 15
local STAMINA_REGEN = 10

local function setupCharacter(character: Model)
	task.defer(function()
		if character.Parent then
			AnimationServiceUtils.applyMovementAnimations(character)
		end
	end)

	character.ChildAdded:Connect(function(child)
		if child.Name == "Animate" then
			task.defer(function()
				if character.Parent then
					AnimationServiceUtils.applyMovementAnimations(character)
				end
			end)
		end
	end)
end

local function getState(player: Player)
	local state = movementStates[player]
	if state then
		return state
	end

	state = {
		sprintIntent = false,
		stamina = 100,
		isExhausted = false,
		ghostSpeed = BASE_SPEED,
	}
	movementStates[player] = state
	player:SetAttribute("StaminaPercent", state.stamina)
	player:SetAttribute("IsStaminaExhausted", false)
	return state
end

local function updatePlayerMovement(player: Player, dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end

	local state = getState(player)
	local lastCombat = character:GetAttribute("LastCombatTick") or 0
	local timeSinceCombat = tick() - lastCombat
	local isOutOfCombat = timeSinceCombat > COMBAT_COOLDOWN
	local isGhost = character:GetAttribute("IsGhost") == true
	local isCloaked = character:GetAttribute("IsCloaked") == true
	local currentBaseSpeed = BASE_SPEED + (if isOutOfCombat then OUT_OF_COMBAT_BONUS else 0)

	if isOutOfCombat then
		player:SetAttribute("CombatStatusText", "OUT OF COMBAT")
		player:SetAttribute("CombatRemaining", 0)
	else
		local remainingCombat = math.max(0, COMBAT_COOLDOWN - timeSinceCombat)
		player:SetAttribute("CombatStatusText", string.format("IN COMBAT (%.1fs)", remainingCombat))
		player:SetAttribute("CombatRemaining", remainingCombat)
	end

	if state.stamina <= 0 then
		state.isExhausted = true
	elseif state.stamina >= 25 then
		state.isExhausted = false
	end

	local targetSpeed = currentBaseSpeed
	if isGhost then
		state.ghostSpeed = math.min(GHOST_MAX_SPEED, state.ghostSpeed + (25 * dt))
		targetSpeed = state.ghostSpeed
	else
		state.ghostSpeed = currentBaseSpeed
		local sprinting = state.sprintIntent
			and state.stamina > 0
			and humanoid.MoveDirection.Magnitude > 0
			and not state.isExhausted

		if sprinting then
			state.stamina = math.max(0, state.stamina - (STAMINA_DRAIN * dt))
			targetSpeed = currentBaseSpeed + SPRINT_BONUS
			if isCloaked then
				targetSpeed += CLOAK_SPRINT_BONUS
			end
		else
			state.stamina = math.min(100, state.stamina + (STAMINA_REGEN * dt))
		end
	end

	humanoid.WalkSpeed = targetSpeed
	player:SetAttribute("StaminaPercent", state.stamina)
	player:SetAttribute("IsStaminaExhausted", state.isExhausted)
	player:SetAttribute("IsSprinting", state.sprintIntent and state.stamina > 0 and not state.isExhausted)
end

function MovementServiceServer.build()
	MovementServiceUtils.getMovementStateRemote()
	return MovementServiceServer
end

function MovementServiceServer.init()
	if initialized then
		return MovementServiceServer
	end
	initialized = true
	MovementServiceServer.build()

	local movementRemote = MovementServiceUtils.getMovementStateRemote()
	if movementRemote then
		movementRemote.OnServerEvent:Connect(function(player, payload)
			local state = getState(player)
			if type(payload) == "table" then
				state.sprintIntent = payload.sprinting == true
			else
				state.sprintIntent = payload == true
			end
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		getState(player)
		player.CharacterAdded:Connect(setupCharacter)
		if player.Character then
			setupCharacter(player.Character)
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		getState(player)
		player.CharacterAdded:Connect(setupCharacter)
		if player.Character then
			setupCharacter(player.Character)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		movementStates[player] = nil
	end)

	RunService.Heartbeat:Connect(function(dt)
		for _, player in ipairs(Players:GetPlayers()) do
			updatePlayerMovement(player, dt)
		end
	end)

	return MovementServiceServer
end

return MovementServiceServer :: MovementServiceServer
