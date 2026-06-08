local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Networker = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networker"))
local DamageUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DamageCalcService"):WaitForChild("DamageCalcServiceUtils"))
local SkillServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SkillService"):WaitForChild("SkillServiceUtils"))

local SkillServiceServer = {}
export type SkillServiceServer = typeof(SkillServiceServer) & {}

local initialized = false
local networker
local skillModules = {}
local context = {}

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

local function updateHookTether(rootPart: BasePart, ropePart: BasePart, weaponVisual: Instance, endPos: Vector3, direction: Vector3)
	local startPos = rootPart.Position + Vector3.new(0, 0.8, 0) + direction * 1.5
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
	local configModule = tool:FindFirstChild("WeaponConfig")
	local visualName = tool.Name
	if configModule then
		local weaponConfig = require(configModule)
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

local function handlePush(player: Player, targetPosition: Vector3)
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end

	local rootPart = character.HumanoidRootPart
	local direction = (targetPosition - rootPart.Position).Unit
	direction = Vector3.new(direction.X, 0, direction.Z).Unit

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

	task.wait(5)
	if character.Parent then
		character:SetAttribute("IsGhost", false)
		toolConnection:Disconnect()
		if collisionConnection then collisionConnection:Disconnect() end

		for part, originalValue in pairs(originalTransparencies) do
			if part.Parent then
				part.Transparency = originalValue
			end
		end

		for _, effect in ipairs(clonedEffects) do
			effect:Destroy()
		end
	end
end

local function handleHook(player: Player, targetPos: Vector3)
	local character = player.Character
	if not character then
		return
	end

	local tool = character:FindFirstChildOfClass("Tool")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not tool or not rootPart then
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

		local startPos = rootPart.Position + flatDir * 2
		local grabPos = startPos + flatDir * traveled
		grabPart.CFrame = CFrame.new(grabPos)
		updateHookTether(rootPart, ropePart, fakeWeapon, grabPos, flatDir)
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
				updateHookTether(rootPart, ropePart, fakeWeapon, enemyRoot.Position, flatDir)
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
	SkillServiceUtils.getOrCreateRemote("PushSkillEvent")
	SkillServiceUtils.getOrCreateRemote("RepelSkillEvent")
	SkillServiceUtils.getOrCreateRemote("GhostSkillEvent")
	SkillServiceUtils.getOrCreateRemote("ReduceDashCooldown")

	context = {
		handleHook = handleHook,
		handlePush = handlePush,
		handleRepel = handleRepel,
		handleGhost = handleGhost,
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

	ReplicatedStorage.PushSkillEvent.OnServerEvent:Connect(function(player, targetPos)
		SkillServiceServer.dispatch(player, "Push", { targetPosition = targetPos })
	end)

	ReplicatedStorage.RepelSkillEvent.OnServerEvent:Connect(function(player)
		SkillServiceServer.dispatch(player, "Repel")
	end)

	ReplicatedStorage.GhostSkillEvent.OnServerEvent:Connect(function(player)
		SkillServiceServer.dispatch(player, "Ghost")
	end)

	return SkillServiceServer
end

function SkillServiceServer.dispatch(player: Player, skillName: string, payload)
	local skill = skillModules[skillName]
	if not skill then
		warn("Missing server skill: " .. tostring(skillName))
		return
	end

	skill.execute(context, player, payload)
end

function SkillServiceServer.UseSkill(_self, player: Player, skillName: string, payload)
	SkillServiceServer.dispatch(player, skillName, payload)
end

return SkillServiceServer :: SkillServiceServer
