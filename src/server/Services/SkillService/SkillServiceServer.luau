local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Networker = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networker"))
local AnimationServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationService"):WaitForChild("AnimationServiceUtils"))
local DamageUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DamageCalcService"):WaitForChild("DamageCalcServiceUtils"))
local SkillServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkillService"):WaitForChild("SkillServiceUtils"))
local WeaponRegistry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponRegistry"))

local SkillServiceServer = {}
export type SkillServiceServer = typeof(SkillServiceServer) & {}

local initialized = false
local networker
local skillModules = {}
local context = {}
local activeCloaks = {}
local activeLivingShadows = {}
local livingShadowCooldowns = {}
local serverCooldowns = {}

local CLOAK_DURATION = 7
local CLOAK_FADE_TIME = 0.5
local CLOAK_TRANSPARENCY = 1
local CLOAK_TRAIL_INTERVAL = 1
local CLOAK_TRAIL_LIFETIME = 1.15
local CLOAK_STEP_SOUND_ID = "rbxasset://sounds/action_footsteps_plastic.mp3"
local DASH_EFFECT_CLONES = 7
local DASH_EFFECT_INTERVAL = 0.05
local DASH_EFFECT_LIFETIME = 0.85
local GHOST_TRAIL_INTERVAL = 0.45
local GHOST_TRAIL_LIFETIME = 1.2
local LIVING_SHADOW_DURATION = 5
local LIVING_SHADOW_INITIAL_RECAST = 0.5
local LIVING_SHADOW_RETURN_SPEED = 70
local LIVING_SHADOW_HIT_RADIUS = 4
local LIVING_SHADOW_DAMAGE = 12
local LIVING_SHADOW_BASE_KNOCKBACK = 42
local HOOK_MAX_DISTANCE = 80
local HOOK_SPEED = 95
local HOOK_STOP_DISTANCE = 4
local HOOK_GRAB_SIZE = Vector3.new(4.5, 4.5, 4.5)
local HOOK_ROPE_WIDTH = 0.18
local HOOK_LASSO_SEGMENTS = 18
local HOOK_LASSO_RADIUS = 2.35

local function flatUnit(vector: Vector3): Vector3?
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.001 then
		return nil
	end

	return flat.Unit
end

local function makeHookPart(name: string, size: Vector3, transparency: number, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = transparency
	part.Color = color
	part.Material = Enum.Material.Neon
	return part
end

local function setHookVisualCFrame(instance: Instance, cframe: CFrame)
	if instance:IsA("BasePart") then
		instance.CFrame = cframe
	elseif instance:IsA("Model") then
		instance:PivotTo(cframe)
	end
end

local function prepareHookVisual(instance: Instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
end

local function getHookOriginPart(character: Model): BasePart?
	local candidates = {
		"RightHand",
		"RightLowerArm",
		"RightUpperArm",
		"Right Arm",
		"RightHandAttachment",
	}

	for _, name in ipairs(candidates) do
		local instance = character:FindFirstChild(name, true)
		if instance and instance:IsA("BasePart") then
			return instance
		end
	end

	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getHookOriginPosition(character: Model, direction: Vector3): Vector3?
	local originPart = getHookOriginPart(character)
	if not originPart then
		return nil
	end

	return originPart.Position + direction * 0.45
end

local function updateHookTether(character: Model, ropePart: BasePart, weaponVisual: Instance, endPos: Vector3, direction: Vector3)
	local startPos = getHookOriginPosition(character, direction)
	if not startPos then
		return
	end

	local length = math.max((endPos - startPos).Magnitude, 0.1)
	local midpoint = (startPos + endPos) / 2

	ropePart.Size = Vector3.new(HOOK_ROPE_WIDTH, HOOK_ROPE_WIDTH, length)
	ropePart.CFrame = CFrame.lookAt(midpoint, endPos)
	setHookVisualCFrame(weaponVisual, CFrame.lookAt(endPos, endPos + direction) * CFrame.Angles(0, math.rad(-90), 0))
end

local function makeLassoVisual(parent: Instance): { Part }
	local parts = {}
	for index = 1, HOOK_LASSO_SEGMENTS do
		local part = makeHookPart("HookLassoArc" .. index, Vector3.new(0.16, 0.16, 0.1), 0.02, Color3.fromRGB(255, 232, 45))
		part.Parent = parent
		table.insert(parts, part)
	end
	return parts
end

local function updateLassoVisual(lassoParts: { Part }, endPos: Vector3, direction: Vector3)
	local forward = direction.Unit
	local side = forward:Cross(Vector3.yAxis)
	if side.Magnitude < 0.01 then
		side = Vector3.xAxis
	else
		side = side.Unit
	end

	local forwardAxis = forward
	local startAngle = 0
	local endAngle = math.pi * 2

	for index, part in ipairs(lassoParts) do
		local a0 = startAngle + (endAngle - startAngle) * ((index - 1) / HOOK_LASSO_SEGMENTS)
		local a1 = startAngle + (endAngle - startAngle) * (index / HOOK_LASSO_SEGMENTS)
		local p0 = endPos + side * math.cos(a0) * HOOK_LASSO_RADIUS + forwardAxis * math.sin(a0) * HOOK_LASSO_RADIUS
		local p1 = endPos + side * math.cos(a1) * HOOK_LASSO_RADIUS + forwardAxis * math.sin(a1) * HOOK_LASSO_RADIUS
		local midpoint = (p0 + p1) / 2
		local length = math.max((p1 - p0).Magnitude, 0.1)
		part.Size = Vector3.new(0.18, 0.18, length)
		part.CFrame = CFrame.lookAt(midpoint, p1)
	end
end

local function findHookVisual(tool: Tool): Instance?
	local visualName = tool.Name
	local weaponConfig = WeaponRegistry.get(tool.Name)
	if weaponConfig then
		visualName = weaponConfig.VisualName or visualName
	end

	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant.Name == visualName and (descendant:IsA("BasePart") or descendant:IsA("Model")) and descendant.Name ~= "Handle" then
			return descendant
		end
	end

	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("MeshPart") and descendant.Name ~= "Handle" then
			return descendant
		end
	end

	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name ~= "Handle" then
			return descendant
		end
	end

	return tool:FindFirstChild("Handle")
end

local function setVisualTransparency(visual: Instance, transparency: number): { [BasePart]: number }
	local original = {}
	if visual:IsA("BasePart") then
		original[visual] = visual.Transparency
		visual.Transparency = transparency
		return original
	end

	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("BasePart") then
			original[descendant] = descendant.Transparency
			descendant.Transparency = transparency
		end
	end

	return original
end

local function restoreVisualTransparency(original: { [BasePart]: number })
	for part, transparency in pairs(original) do
		if part.Parent then
			part.Transparency = transparency
		end
	end
end

local function getRestoreTransparency(instance: Instance, originalTransparency: number): number
	if instance:IsA("BasePart") then
		local tool = instance:FindFirstAncestorOfClass("Tool")
		if tool then
			if instance.Name == "Handle" then
				return originalTransparency
			end

			return 0
		end
	end

	return originalTransparency
end

local function getDashCloneTemplate(): Model?
	local vfxFolder = ReplicatedStorage:FindFirstChild("VfxFolder")
	local dashClone = vfxFolder and vfxFolder:FindFirstChild("DashClone")
	if dashClone and dashClone:IsA("Model") then
		return dashClone
	end

	return nil
end

local function prepareAfterimageClone(clone: Model)
	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Transparency = math.max(descendant.Transparency, 0.25)
			descendant.Material = Enum.Material.Neon
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
end

local function alignAfterimageClone(character: Model, clone: Model)
	for _, clonePart in ipairs(clone:GetDescendants()) do
		if clonePart:IsA("BasePart") then
			local sourcePart = character:FindFirstChild(clonePart.Name, true)
			if sourcePart and sourcePart:IsA("BasePart") then
				clonePart.CFrame = sourcePart.CFrame
			end
		end
	end
end

local function fadeAfterimageClone(clone: Model, lifetime: number)
	local steps = 12
	for step = 1, steps do
		if not clone.Parent then
			return
		end

		local alpha = step / steps
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Transparency = math.clamp(0.25 + alpha * 0.75, 0, 1)
				descendant.Reflectance = math.clamp(alpha, 0, 1)
			end
		end

		task.wait(lifetime / steps)
	end

	if clone.Parent then
		clone:Destroy()
	end
end

local function emitAfterimage(character: Model, rootPart: BasePart, lifetime: number)
	local dashClone = getDashCloneTemplate()
	if not dashClone then
		return
	end

	local clone = dashClone:Clone()
	if clone.PrimaryPart then
		clone:SetPrimaryPartCFrame(rootPart.CFrame)
	else
		clone:PivotTo(rootPart.CFrame)
	end
	prepareAfterimageClone(clone)
	alignAfterimageClone(character, clone)
	clone.Parent = workspace
	Debris:AddItem(clone, lifetime + 0.2)
	task.spawn(fadeAfterimageClone, clone, lifetime)
end

local function playDashAfterimages(character: Model, rootPart: BasePart)
	task.spawn(function()
		for _ = 1, DASH_EFFECT_CLONES do
			if not character.Parent or not rootPart.Parent then
				return
			end

			emitAfterimage(character, rootPart, DASH_EFFECT_LIFETIME)
			task.wait(DASH_EFFECT_INTERVAL)
		end
	end)
end

local function createCloakSound(rootPart: BasePart): Sound
	local sound = Instance.new("Sound")
	sound.Name = "CloakRunSound"
	sound.SoundId = CLOAK_STEP_SOUND_ID
	sound.Volume = 1.45
	sound.PlaybackSpeed = 1.08
	sound.Looped = true
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 90
	sound.Parent = rootPart
	return sound
end

local function getCharacterRoot(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function prepareLivingShadowClone(clone: Model)
	clone.Name = "LivingShadowClone"

	for _, descendant in ipairs(clone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Color = Color3.fromRGB(0, 0, 0)
			descendant.Material = Enum.Material.Neon
			descendant.Transparency = math.min(descendant.Transparency, 0.12)
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			descendant.Transparency = 1
		elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") or descendant:IsA("Beam") then
			descendant.Enabled = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
end

local function playLivingShadowRun(clone: Model): AnimationTrack?
	local animator = AnimationServiceUtils.getAnimationControllerAnimator(clone)
	if not animator then
		return nil
	end

	local track = AnimationServiceUtils.loadTrack(animator, "ShadowRun")
	if track then
		track:Play(0.1)
	end

	return track
end

local function setLivingShadowHudState(player: Player, stateName: string, activeUntil: number?, recastAt: number?, readyAt: number?)
	player:SetAttribute("LivingShadowState", stateName)
	player:SetAttribute("LivingShadowActiveUntil", activeUntil or 0)
	player:SetAttribute("LivingShadowRecastAt", recastAt or 0)
	player:SetAttribute("LivingShadowReadyAt", readyAt or 0)
end

local function hitLivingShadowTargets(player: Player, state, position: Vector3, direction: Vector3)
	local character = player.Character
	if not character then
		return
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = { character, state.clone }
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	for _, part in ipairs(workspace:GetPartBoundsInRadius(position, LIVING_SHADOW_HIT_RADIUS, overlapParams)) do
		local targetCharacter = part:FindFirstAncestorOfClass("Model")
		if not targetCharacter or targetCharacter == character or state.hitCharacters[targetCharacter] then
			continue
		end

		local humanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
		local targetRoot = getCharacterRoot(targetCharacter)
		if not humanoid or humanoid.Health <= 0 or not targetRoot then
			continue
		end

		state.hitCharacters[targetCharacter] = true
		DamageUtils.tagCombat(targetCharacter, player.Name)
		DamageUtils.addDamage(targetCharacter, LIVING_SHADOW_DAMAGE)

		local currentDamage = targetCharacter:GetAttribute("DamagePercent") or 0
		local pushDirection = flatUnit(targetRoot.Position - position) or direction
		humanoid.PlatformStand = true

		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Velocity = DamageUtils.knockback(pushDirection, currentDamage, LIVING_SHADOW_BASE_KNOCKBACK, 1.1, 22)
		bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
		bodyVelocity.Parent = targetRoot

		local bodyGyro = Instance.new("BodyGyro")
		bodyGyro.MaxTorque = Vector3.new(400000, 400000, 400000)
		bodyGyro.CFrame = targetRoot.CFrame
		bodyGyro.Parent = targetRoot

		Debris:AddItem(bodyVelocity, 0.22)
		Debris:AddItem(bodyGyro, 0.45)
		targetCharacter:SetAttribute("KnockbackImmunity", tick() + 0.4)

		task.delay(0.8, function()
			if targetCharacter.Parent and humanoid.Health > 0 then
				humanoid.PlatformStand = false
			end
		end)
	end
end

local function destroyLivingShadow(player: Player, state)
	if activeLivingShadows[player] ~= state then
		return
	end

	activeLivingShadows[player] = nil
	local cooldownStartedAt = state.cooldownStartedAt or os.clock()
	local cooldownReadyAt = state.cooldownReadyAt or (workspace:GetServerTimeNow() + 3)
	livingShadowCooldowns[player] = cooldownStartedAt
	setLivingShadowHudState(player, "Cooldown", 0, 0, cooldownReadyAt)
	task.delay(3, function()
		if player.Parent and activeLivingShadows[player] == nil and livingShadowCooldowns[player] == cooldownStartedAt then
			setLivingShadowHudState(player, "Ready", 0, 0, 0)
		end
	end)
	if state.track then
		state.track:Stop(0.1)
	end
	if state.clone and state.clone.Parent then
		state.clone:Destroy()
	end
end

local function returnLivingShadow(player: Player, state)
	if state.returning then
		return
	end
	if os.clock() - state.spawnedAt < LIVING_SHADOW_INITIAL_RECAST then
		local serverNow = workspace:GetServerTimeNow()
		setLivingShadowHudState(player, "Arming", serverNow + LIVING_SHADOW_DURATION, serverNow + LIVING_SHADOW_INITIAL_RECAST, 0)
		return
	end

	local character = player.Character
	local rootPart = character and getCharacterRoot(character)
	if not rootPart or not state.clone or not state.clone.Parent then
		destroyLivingShadow(player, state)
		return
	end

	state.returning = true
	state.cooldownStartedAt = os.clock()
	state.cooldownReadyAt = workspace:GetServerTimeNow() + 3
	livingShadowCooldowns[player] = state.cooldownStartedAt
	setLivingShadowHudState(player, "Cooldown", 0, 0, state.cooldownReadyAt)
	if player.Character then
		player.Character:SetAttribute("LastCombatTick", tick())
	end
	table.clear(state.hitCharacters)
	if not state.track then
		state.track = playLivingShadowRun(state.clone)
	end

	while activeLivingShadows[player] == state and state.clone.Parent and rootPart.Parent do
		local dt = RunService.Heartbeat:Wait()
		local pivot = state.clone:GetPivot()
		local targetPosition = rootPart.Position
		local delta = targetPosition - pivot.Position
		local distance = delta.Magnitude
		if distance <= 2.2 then
			break
		end

		local direction = delta.Unit
		local step = math.min(distance, LIVING_SHADOW_RETURN_SPEED * dt)
		local nextPosition = pivot.Position + direction * step
		state.clone:PivotTo(CFrame.lookAt(nextPosition, nextPosition + direction))
		hitLivingShadowTargets(player, state, nextPosition, direction)
	end

	destroyLivingShadow(player, state)
end

local function collectCloakTargets(character: Model)
	local targets = {}

	local function addTargets(instance: Instance)
		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
				targets[descendant] = descendant.Transparency
			elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
				targets[descendant] = descendant.Transparency
			end
		end
	end

	addTargets(character)
	return targets
end

local function cancelCloakTweens(state)
	for _, tween in ipairs(state.tweens or {}) do
		pcall(function()
			tween:Cancel()
		end)
	end
	if state.tweens then
		table.clear(state.tweens)
	end
end

local function tweenCloakTargets(state, targets, transparency: number, duration: number)
	cancelCloakTweens(state)

	for instance, originalTransparency in pairs(targets) do
		if instance.Parent then
			local targetTransparency = transparency
			if originalTransparency >= 1 then
				targetTransparency = 1
			end

			local tween = TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = targetTransparency,
			})
			table.insert(state.tweens, tween)
			tween:Play()
		end
	end
end

local function restoreCloakTargets(state, targets, duration: number)
	cancelCloakTweens(state)

	for instance, originalTransparency in pairs(targets) do
		if instance.Parent then
			local restoreTransparency = getRestoreTransparency(instance, originalTransparency)
			if duration <= 0 then
				instance.Transparency = restoreTransparency
			else
				local tween = TweenService:Create(instance, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = restoreTransparency,
				})
				table.insert(state.tweens, tween)
				tween:Play()
			end
		end
	end
end

local function cancelCloak(character: Model?, reason: string?)
	if not character then
		return
	end

	local state = activeCloaks[character]
	if not state then
		character:SetAttribute("IsCloaked", false)
		return
	end

	for _, connection in ipairs(state.connections) do
		connection:Disconnect()
	end

	if state.sound then
		state.sound:Destroy()
	end

	activeCloaks[character] = nil
	local restoreDuration = if reason == "Expired" then 0.18 else 0
	restoreCloakTargets(state, state.targets, restoreDuration)
	character:SetAttribute("CloakCancelReason", reason or "")

	local function finishCancel()
		if character.Parent and activeCloaks[character] == nil then
			character:SetAttribute("IsCloaked", false)
		end
	end

	if restoreDuration > 0 then
		task.delay(restoreDuration, finishCancel)
	else
		finishCancel()
	end
end

local function connectCloakCancel(character: Model, state)
	local function cancel(reason: string)
		cancelCloak(character, reason)
	end

	table.insert(state.connections, character:GetAttributeChangedSignal("LastCombatTick"):Connect(function()
		if os.clock() - state.startedAt < 0.2 then
			return
		end
		if character:GetAttribute("IsCloaked") then
			cancel("Combat")
		end
	end))

	table.insert(state.connections, character:GetAttributeChangedSignal("DamagePercent"):Connect(function()
		if character:GetAttribute("IsCloaked") then
			cancel("Damage")
		end
	end))

	table.insert(state.connections, character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			cancel("Removed")
		end
	end))
end

local function runCloakMovementEffects(character: Model, state)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not rootPart:IsA("BasePart") or not humanoid then
		return
	end

	state.sound = createCloakSound(rootPart)
	state.lastTrailTime = 0

	while activeCloaks[character] == state and character.Parent and humanoid.Health > 0 do
		local isMoving = humanoid.MoveDirection.Magnitude > 0.05
		if isMoving then
			if state.sound and not state.sound.IsPlaying then
				state.sound:Play()
			end

			local now = os.clock()
			if now - state.lastTrailTime >= CLOAK_TRAIL_INTERVAL then
				state.lastTrailTime = now
				emitAfterimage(character, rootPart, CLOAK_TRAIL_LIFETIME)
			end
		elseif state.sound and state.sound.IsPlaying then
			state.sound:Stop()
		end

		task.wait(0.1)
	end

	if state.sound then
		state.sound:Destroy()
		state.sound = nil
	end
end

local function handlePush(player: Player, targetPosition: Vector3)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	AnimationServiceUtils.playCharacterAnimation(character, "PushCast")
	task.wait(0.3)
	if not character.Parent or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local rootPart = character.HumanoidRootPart
	local direction = flatUnit(targetPosition - rootPart.Position) or rootPart.CFrame.LookVector

	local hitboxSize = Vector3.new(12, 5, 15)
	local hitboxCFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + direction) * CFrame.new(0, 0, -hitboxSize.Z / 2)

	local visualBox = Instance.new("Part")
	visualBox.Size = hitboxSize
	visualBox.CFrame = hitboxCFrame
	visualBox.Anchored = true
	visualBox.CanCollide = false
	visualBox.Transparency = 0.5
	visualBox.Color = Color3.fromRGB(0, 255, 255)
	visualBox.Material = Enum.Material.Neon
	visualBox.Parent = workspace
	game.Debris:AddItem(visualBox, 0.2)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	local hitCharacters = {}
	local hasHitSomeone = false
	for _, part in ipairs(workspace:GetPartBoundsInBox(hitboxCFrame, hitboxSize, overlapParams)) do
		local hitModel = part:FindFirstAncestorOfClass("Model")
		if hitModel and hitModel:FindFirstChildOfClass("Humanoid") and not hitCharacters[hitModel] then
			hitCharacters[hitModel] = true

			local targetRoot = hitModel:FindFirstChild("HumanoidRootPart")
			local targetHumanoid = hitModel:FindFirstChildOfClass("Humanoid")
			if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
				hasHitSomeone = true
				DamageUtils.tagCombat(hitModel, player.Name)

				local currentDamage = hitModel:GetAttribute("DamagePercent") or 0
				local knockbackVector = DamageUtils.knockback(direction, currentDamage, 50, 1.5, 20 + currentDamage * 0.1)
				targetHumanoid.PlatformStand = true

				local bodyVelocity = Instance.new("BodyVelocity")
				bodyVelocity.Velocity = knockbackVector
				bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
				bodyVelocity.Parent = targetRoot

				local bodyGyro = Instance.new("BodyGyro")
				bodyGyro.MaxTorque = Vector3.new(400000, 400000, 400000)
				bodyGyro.CFrame = targetRoot.CFrame
				bodyGyro.Parent = targetRoot

				game.Debris:AddItem(bodyVelocity, 0.2)
				game.Debris:AddItem(bodyGyro, 0.5)
				DamageUtils.addDamage(hitModel, 15)
				hitModel:SetAttribute("KnockbackImmunity", tick() + 0.4)

				task.delay(1, function()
					if hitModel.Parent and targetHumanoid.Health > 0 then
						targetHumanoid.PlatformStand = false
					end
				end)
			end
		end
	end

	if hasHitSomeone then
		character:SetAttribute("LastCombatTick", tick())
	end
end

local function handleRepel(player: Player)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	AnimationServiceUtils.playCharacterAnimation(character, "RepelCast")

	local rootPart = character.HumanoidRootPart
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	for _, child in ipairs(rootPart:GetChildren()) do
		if child:IsA("BodyVelocity") or child:IsA("BodyGyro") then
			child:Destroy()
		end
	end

	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.Anchored = true
	task.delay(0.05, function()
		if rootPart then rootPart.Anchored = false end
	end)

	humanoid.PlatformStand = false
	character:SetAttribute("IsHooked", false)
	character:SetAttribute("KnockbackImmunity", tick() + 0.5)
	character:SetAttribute("LastCombatTick", tick())

	local shockwave = Instance.new("Part")
	shockwave.Shape = Enum.PartType.Ball
	shockwave.Size = Vector3.new(2, 2, 2)
	shockwave.Position = rootPart.Position
	shockwave.Anchored = true
	shockwave.CanCollide = false
	shockwave.Material = Enum.Material.ForceField
	shockwave.Color = Color3.fromRGB(255, 200, 50)
	shockwave.Parent = workspace
	TweenService:Create(shockwave, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(36, 36, 36),
		Transparency = 1,
	}):Play()
	game.Debris:AddItem(shockwave, 0.4)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = { character }
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	local hitCharacters = {}
	for _, part in ipairs(workspace:GetPartBoundsInRadius(rootPart.Position, 18, overlapParams)) do
		local hitModel = part:FindFirstAncestorOfClass("Model")
		if hitModel and hitModel:FindFirstChildOfClass("Humanoid") and not hitCharacters[hitModel] then
			hitCharacters[hitModel] = true

			local targetRoot = hitModel:FindFirstChild("HumanoidRootPart")
			local targetHumanoid = hitModel:FindFirstChildOfClass("Humanoid")
			if targetRoot and targetHumanoid and targetHumanoid.Health > 0 then
				local pushDir = (targetRoot.Position - rootPart.Position).Unit
				pushDir = Vector3.new(pushDir.X, 0, pushDir.Z).Unit

				local currentDamage = hitModel:GetAttribute("DamagePercent") or 0
				targetHumanoid.PlatformStand = true

				local bodyVelocity = Instance.new("BodyVelocity")
				bodyVelocity.Velocity = DamageUtils.knockback(pushDir, currentDamage, 30, 0.5, 25)
				bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
				bodyVelocity.Parent = targetRoot

				local bodyGyro = Instance.new("BodyGyro")
				bodyGyro.MaxTorque = Vector3.new(400000, 400000, 400000)
				bodyGyro.CFrame = targetRoot.CFrame
				bodyGyro.Parent = targetRoot

				game.Debris:AddItem(bodyVelocity, 0.25)
				game.Debris:AddItem(bodyGyro, 0.5)
				DamageUtils.tagCombat(hitModel, player.Name)
				DamageUtils.addDamage(hitModel, 5)
				hitModel:SetAttribute("KnockbackImmunity", tick() + 0.4)

				task.delay(1, function()
					if hitModel.Parent and targetHumanoid.Health > 0 then
						targetHumanoid.PlatformStand = false
					end
				end)
			end
		end
	end
end

local function handleGhost(player: Player)
	local character = player.Character
	if not character or character:GetAttribute("IsGhost") then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	character:SetAttribute("IsGhost", true)
	local collisionConnection
	collisionConnection = RunService.Stepped:Connect(function()
		if not character.Parent then
			collisionConnection:Disconnect()
			return
		end

		for _, part in ipairs(character:GetChildren()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.CanCollide = false
			end
		end
	end)

	local originalTransparencies = {}
	local function applyGhostTransparency(obj: Instance)
		for _, part in ipairs(obj:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				originalTransparencies[part] = part.Transparency
				part.Transparency = 0.7
			end
		end
	end

	applyGhostTransparency(character)
	local toolConnection = character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			applyGhostTransparency(child)
		end
	end)

	local clonedEffects = {}
	local auraPreset = ReplicatedStorage:FindFirstChild("Water-Aura-01")
	if auraPreset then
		for _, obj in ipairs(auraPreset:GetDescendants()) do
			if obj:IsA("Attachment") or obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
				if obj:IsA("ParticleEmitter") and obj.Parent and obj.Parent:IsA("Attachment") then
					continue
				end

				local charPart = obj.Parent and character:FindFirstChild(obj.Parent.Name)
				if charPart then
					local cloneEffect = obj:Clone()
					cloneEffect.Parent = charPart
					table.insert(clonedEffects, cloneEffect)
				end
			end
		end
	end

	local ghostTrailRunning = true
	task.spawn(function()
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart or not rootPart:IsA("BasePart") then
			return
		end

		while ghostTrailRunning and character.Parent and character:GetAttribute("IsGhost") == true do
			emitAfterimage(character, rootPart, GHOST_TRAIL_LIFETIME)
			task.wait(GHOST_TRAIL_INTERVAL)
		end
	end)

	task.wait(5)
	ghostTrailRunning = false
	if character.Parent then
		character:SetAttribute("IsGhost", false)
		toolConnection:Disconnect()
		if collisionConnection then collisionConnection:Disconnect() end

		for part, originalValue in pairs(originalTransparencies) do
			if part.Parent then
				part.Transparency = getRestoreTransparency(part, originalValue)
			end
		end

		for _, effect in ipairs(clonedEffects) do
			effect:Destroy()
		end
	end
end

local function handleCloak(player: Player)
	local character = player.Character
	if not character or character:GetAttribute("IsCloaked") then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local state = {
		token = os.clock(),
		startedAt = os.clock(),
		targets = collectCloakTargets(character),
		connections = {},
		tweens = {},
		sound = nil,
		lastTrailTime = 0,
	}
	activeCloaks[character] = state
	character:SetAttribute("IsCloaked", true)
	character:SetAttribute("CloakStartedAt", os.clock())
	character:SetAttribute("CloakCancelReason", "")

	connectCloakCancel(character, state)
	tweenCloakTargets(state, state.targets, CLOAK_TRANSPARENCY, CLOAK_FADE_TIME)
	task.spawn(runCloakMovementEffects, character, state)

	task.delay(CLOAK_DURATION, function()
		if activeCloaks[character] == state then
			cancelCloak(character, "Expired")
		end
	end)
end

local DASH_ANIMATION_BY_DIRECTION = {
	Forward = "DashForward",
	Back = "DashBack",
	Left = "DashLeft",
	Right = "DashRight",
}

local function getDashDirectionName(payload): string
	local directionName
	if typeof(payload) == "table" then
		directionName = payload.directionName
	elseif typeof(payload) == "string" then
		directionName = payload
	end

	if typeof(directionName) ~= "string" or not DASH_ANIMATION_BY_DIRECTION[directionName] then
		return "Forward"
	end

	return directionName
end

local function getPlayerCooldowns(player: Player)
	local cooldowns = serverCooldowns[player]
	if not cooldowns then
		cooldowns = {}
		serverCooldowns[player] = cooldowns
	end
	return cooldowns
end

local function canUseSkill(player: Player, skillName: string, skill): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end

	if character:GetAttribute("IsHooked") and not skill.AllowWhileHooked then
		return false
	end

	if character:GetAttribute("IsCasting") and not skill.AllowWhileCasting then
		return false
	end

	if character:GetAttribute("IsDashing") and not skill.AllowWhileDashing then
		return false
	end

	local cooldown = skill.ServerCooldown or 0
	if cooldown <= 0 then
		return true
	end

	local now = os.clock()
	local cooldowns = getPlayerCooldowns(player)
	local readyAt = cooldowns[skillName] or 0
	if readyAt > now then
		return false
	end

	cooldowns[skillName] = now + cooldown
	return true
end

local function handleDash(player: Player, payload)
	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not rootPart:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end

	local directionName = getDashDirectionName(payload)
	character:SetAttribute("IsDashing", true)
	character:SetAttribute("LastCombatTick", tick())
	AnimationServiceUtils.playCharacterAnimation(character, DASH_ANIMATION_BY_DIRECTION[directionName])
	playDashAfterimages(character, rootPart)

	task.delay(0.25, function()
		if character.Parent then
			character:SetAttribute("IsDashing", false)
		end
	end)
end

local function handleLivingShadow(player: Player)
	local existingState = activeLivingShadows[player]
	if existingState then
		task.spawn(returnLivingShadow, player, existingState)
		return
	end

	local lastFinishedAt = livingShadowCooldowns[player]
	if lastFinishedAt and os.clock() - lastFinishedAt < 3 then
		setLivingShadowHudState(player, "Cooldown", 0, 0, workspace:GetServerTimeNow() + (3 - (os.clock() - lastFinishedAt)))
		return
	end

	local character = player.Character
	local rootPart = character and getCharacterRoot(character)
	if not character or not rootPart then
		return
	end

	local dashClone = getDashCloneTemplate()
	if not dashClone then
		warn("LivingShadow: missing ReplicatedStorage.VfxFolder.DashClone")
		return
	end

	local clone = dashClone:Clone()
	prepareLivingShadowClone(clone)
	local spawnPosition = rootPart.Position + rootPart.CFrame.LookVector * 3
	clone:PivotTo(CFrame.lookAt(spawnPosition, spawnPosition + rootPart.CFrame.LookVector))
	clone.Parent = workspace

	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	local state = {
		clone = clone,
		spawnedAt = now,
		returning = false,
		hitCharacters = {},
		track = nil,
		cooldownStartedAt = nil,
		cooldownReadyAt = nil,
	}
	activeLivingShadows[player] = state
	setLivingShadowHudState(player, "Arming", serverNow + LIVING_SHADOW_DURATION, serverNow + LIVING_SHADOW_INITIAL_RECAST, 0)
	character:SetAttribute("LastCombatTick", tick())

	task.delay(LIVING_SHADOW_DURATION, function()
		if activeLivingShadows[player] == state and not state.returning then
			destroyLivingShadow(player, state)
		end
	end)
end

local function handleHook(player: Player, targetPos: Vector3)
	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	AnimationServiceUtils.playCharacterAnimation(character, "HookCast")

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return
	end

	local visualWeapon = findHookVisual(tool)
	if not visualWeapon then
		warn("HookServer: missing visual weapon for " .. tool.Name)
		return
	end

	local flatDir = flatUnit(targetPos - rootPart.Position) or rootPart.CFrame.LookVector
	local originalTransparency = setVisualTransparency(visualWeapon, 1)
	local hookFolder = Instance.new("Folder")
	hookFolder.Name = "HookCast"
	hookFolder.Parent = workspace

	local grabPart = makeHookPart("HookGrabPart", HOOK_GRAB_SIZE, 1, Color3.fromRGB(255, 255, 255))
	grabPart.Parent = hookFolder

	local ropePart = makeHookPart("HookRopePart", Vector3.new(HOOK_ROPE_WIDTH, HOOK_ROPE_WIDTH, 0.1), 0.05, Color3.fromRGB(255, 245, 180))
	ropePart.Parent = hookFolder

	local fakeWeapon = visualWeapon:Clone()
	fakeWeapon.Name = "HookWeaponVisual"
	prepareHookVisual(fakeWeapon)
	fakeWeapon.Parent = hookFolder
	local lassoParts = makeLassoVisual(hookFolder)

	local overlapParams = OverlapParams.new()
	overlapParams.FilterDescendantsInstances = { character, hookFolder }
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude

	local hitEnemy: Model? = nil
	local startTime = tick()
	local traveled = 0

	while character.Parent and rootPart.Parent and traveled < HOOK_MAX_DISTANCE and not hitEnemy do
		local dt = RunService.Heartbeat:Wait()
		traveled = math.min(HOOK_MAX_DISTANCE, traveled + HOOK_SPEED * dt)

		local startPos = getHookOriginPosition(character, flatDir) or (rootPart.Position + flatDir * 2)
		local grabPos = startPos + flatDir * traveled
		grabPart.CFrame = CFrame.new(grabPos)
		updateHookTether(character, ropePart, fakeWeapon, grabPos, flatDir)
		updateLassoVisual(lassoParts, grabPos, flatDir)

		for _, part in ipairs(workspace:GetPartBoundsInBox(grabPart.CFrame, HOOK_GRAB_SIZE, overlapParams)) do
			local enemy = part:FindFirstAncestorOfClass("Model")
			local enemyHumanoid = enemy and enemy:FindFirstChildOfClass("Humanoid")
			if enemy and enemy ~= character and enemyHumanoid and enemyHumanoid.Health > 0 then
				hitEnemy = enemy
				break
			end
		end
	end

	if hitEnemy then
		local enemyRoot = hitEnemy:FindFirstChild("HumanoidRootPart")
		local enemyHumanoid = hitEnemy:FindFirstChildOfClass("Humanoid")
		if enemyRoot and enemyHumanoid and enemyHumanoid.Health > 0 and rootPart.Parent then
			DamageUtils.tagCombat(hitEnemy, player.Name)
			DamageUtils.addDamage(hitEnemy, 10)
			character:SetAttribute("LastCombatTick", tick())
			hitEnemy:SetAttribute("IsHooked", true)

			local wasAnchored = enemyRoot.Anchored
			local wasPlatformStand = enemyHumanoid.PlatformStand
			enemyRoot.AssemblyLinearVelocity = Vector3.zero
			enemyRoot.AssemblyAngularVelocity = Vector3.zero
			enemyRoot.Anchored = true
			enemyHumanoid.PlatformStand = true

			local pullStart = tick()
			while hitEnemy.Parent and rootPart.Parent and tick() - pullStart < 0.65 do
				local pullerPos = rootPart.Position
				local stopDir = flatUnit(enemyRoot.Position - pullerPos) or flatDir
				local stopPos = pullerPos + stopDir * HOOK_STOP_DISTANCE
				stopPos = Vector3.new(stopPos.X, enemyRoot.Position.Y, stopPos.Z)
				local distance = (enemyRoot.Position - stopPos).Magnitude
				local alpha = math.clamp(RunService.Heartbeat:Wait() * 9, 0, 1)
				enemyRoot.CFrame = enemyRoot.CFrame:Lerp(CFrame.lookAt(stopPos, Vector3.new(pullerPos.X, stopPos.Y, pullerPos.Z)), alpha)
				updateHookTether(character, ropePart, fakeWeapon, enemyRoot.Position, flatDir)
				updateLassoVisual(lassoParts, enemyRoot.Position, flatDir)
				if distance <= 0.35 then
					break
				end
			end

			if enemyRoot.Parent then
				enemyRoot.AssemblyLinearVelocity = Vector3.zero
				enemyRoot.AssemblyAngularVelocity = Vector3.zero
				enemyRoot.Anchored = wasAnchored
			end
			if enemyHumanoid.Parent then
				enemyHumanoid.PlatformStand = wasPlatformStand
			end
			if hitEnemy.Parent then
				hitEnemy:SetAttribute("IsHooked", false)
			end
		end
	end

	if tick() - startTime < 0.15 then
		task.wait(0.15 - (tick() - startTime))
	end
	restoreVisualTransparency(originalTransparency)
	hookFolder:Destroy()
end

function SkillServiceServer.build()
	SkillServiceUtils.getOrCreateRemote("HookEvent")
	SkillServiceUtils.getOrCreateRemote("DashSkillEvent")
	SkillServiceUtils.getOrCreateRemote("LivingShadowSkillEvent")
	SkillServiceUtils.getOrCreateRemote("PushSkillEvent")
	SkillServiceUtils.getOrCreateRemote("RepelSkillEvent")
	SkillServiceUtils.getOrCreateRemote("GhostSkillEvent")
	SkillServiceUtils.getOrCreateRemote("CloakSkillEvent")
	SkillServiceUtils.getOrCreateRemote("ReduceDashCooldown")

	context = {
		handleDash = handleDash,
		handleHook = handleHook,
		handleLivingShadow = handleLivingShadow,
		handlePush = handlePush,
		handleRepel = handleRepel,
		handleGhost = handleGhost,
		handleCloak = handleCloak,
	}

	table.clear(skillModules)
	for _, moduleScript in ipairs(script.Parent:WaitForChild("Skills"):GetChildren()) do
		if moduleScript:IsA("ModuleScript") then
			local skill = require(moduleScript)
			skillModules[skill.Name] = skill
		end
	end

	if not networker then
		networker = Networker.server.new("SkillService", SkillServiceServer, {
			SkillServiceServer.UseSkill,
		})
	end

	return SkillServiceServer
end

function SkillServiceServer.init()
	if initialized then
		return SkillServiceServer
	end
	initialized = true
	SkillServiceServer.build()

	ReplicatedStorage.HookEvent.OnServerEvent:Connect(function(player, targetPos)
		SkillServiceServer.dispatch(player, "Hook", { targetPosition = targetPos })
	end)

	ReplicatedStorage.DashSkillEvent.OnServerEvent:Connect(function(player, directionName)
		SkillServiceServer.dispatch(player, "Dash", directionName)
	end)

	ReplicatedStorage.LivingShadowSkillEvent.OnServerEvent:Connect(function(player)
		SkillServiceServer.dispatch(player, "LivingShadow")
	end)

	ReplicatedStorage.PushSkillEvent.OnServerEvent:Connect(function(player, targetPos)
		SkillServiceServer.dispatch(player, "Push", { targetPosition = targetPos })
	end)

	ReplicatedStorage.RepelSkillEvent.OnServerEvent:Connect(function(player)
		SkillServiceServer.dispatch(player, "Repel")
	end)

	ReplicatedStorage.GhostSkillEvent.OnServerEvent:Connect(function(player)
		SkillServiceServer.dispatch(player, "Ghost")
	end)

	ReplicatedStorage.CloakSkillEvent.OnServerEvent:Connect(function(player)
		SkillServiceServer.dispatch(player, "Cloak")
	end)

	Players.PlayerRemoving:Connect(function(player)
		local shadowState = activeLivingShadows[player]
		if shadowState and shadowState.clone and shadowState.clone.Parent then
			shadowState.clone:Destroy()
		end
		activeLivingShadows[player] = nil
		livingShadowCooldowns[player] = nil
		serverCooldowns[player] = nil
	end)

	return SkillServiceServer
end

function SkillServiceServer.dispatch(player: Player, skillName: string, payload)
	local skill = skillModules[skillName]
	if not skill then
		warn("Missing server skill: " .. tostring(skillName))
		return
	end

	if not canUseSkill(player, skillName, skill) then
		return
	end

	if skillName ~= "Cloak" and player.Character then
		cancelCloak(player.Character, "Skill")
	end

	skill.execute(context, player, payload)
end

function SkillServiceServer.UseSkill(_self, player: Player, skillName: string, payload)
	SkillServiceServer.dispatch(player, skillName, payload)
end

return SkillServiceServer :: SkillServiceServer
