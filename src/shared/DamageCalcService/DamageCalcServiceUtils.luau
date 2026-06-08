local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local DamageCalcServiceUtils = {}

local function getOrCreateRemote(remoteName: string): RemoteEvent?
	if not RunService:IsServer() then
		return nil
	end

	local remote = ReplicatedStorage:FindFirstChild(remoteName)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = remoteName
		remote.Parent = ReplicatedStorage
		return remote
	end

	return nil
end

local function getCharacterRoot(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end

	return nil
end

local function emitHitParticles(character: Model)
	local root = getCharacterRoot(character)
	if not root then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Name = "HitParticleBurst"
	attachment.Parent = root

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "HitSparks"
	sparks.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 255, 255)),
		ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 40, 180)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	sparks.LightEmission = 0.75
	sparks.Lifetime = NumberRange.new(0.22, 0.42)
	sparks.Rate = 0
	sparks.Speed = NumberRange.new(12, 22)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.32),
		NumberSequenceKeypoint.new(0.5, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Parent = attachment
	sparks:Emit(24)

	Debris:AddItem(attachment, 0.8)
end

local function flashCharacterRed(character: Model)
	local highlight = Instance.new("Highlight")
	highlight.Name = "DamageFlash"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = Color3.fromRGB(255, 35, 35)
	highlight.FillTransparency = 0.35
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0.25
	highlight.Parent = character

	local fade = TweenService:Create(highlight, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	})
	fade:Play()

	Debris:AddItem(highlight, 0.5)
end

local function fireHitIndicator(character: Model, amount: number, newDamage: number)
	local attackerName = character:GetAttribute("LastAttacker")
	if typeof(attackerName) ~= "string" then
		return
	end

	local attacker = Players:FindFirstChild(attackerName)
	if not attacker then
		return
	end

	local remote = getOrCreateRemote("HitIndicatorEvent")
	if not remote then
		return
	end

	local root = getCharacterRoot(character)
	local text = if amount >= 20 then "WEAK!" else "HIT!"
	remote:FireClient(attacker, {
		text = text,
		damage = amount,
		totalDamage = newDamage,
		targetName = character.Name,
		targetPosition = if root then root.Position + Vector3.new(0, 2.1, 0) else nil,
	})
end

local function fireDamageTakenIndicator(character: Model, amount: number)
	local victim = Players:GetPlayerFromCharacter(character)
	if not victim then
		return
	end

	local remote = getOrCreateRemote("DamageTakenIndicatorEvent")
	if not remote then
		return
	end

	local root = getCharacterRoot(character)
	local attackerName = character:GetAttribute("LastAttacker")
	local attacker = if typeof(attackerName) == "string" then Players:FindFirstChild(attackerName) else nil
	local attackerRoot = if attacker and attacker.Character then getCharacterRoot(attacker.Character) else nil
	local direction = if root then root.CFrame.LookVector else Vector3.new(0, 0, -1)

	if root and attackerRoot then
		local delta = attackerRoot.Position - root.Position
		if delta.Magnitude > 0.01 then
			direction = delta.Unit
		end
	end

	remote:FireClient(victim, {
		damage = amount,
		attackerName = attackerName,
		attackDirection = direction,
		sourcePosition = if attackerRoot then attackerRoot.Position else nil,
	})
end

function DamageCalcServiceUtils.addDamage(character: Model, amount: number): number
	local currentDamage = character:GetAttribute("DamagePercent") or 0
	local newDamage = currentDamage + amount
	character:SetAttribute("DamagePercent", newDamage)

	if RunService:IsServer() then
		emitHitParticles(character)
		flashCharacterRed(character)
		fireHitIndicator(character, amount, newDamage)
		fireDamageTakenIndicator(character, amount)
	end

	return newDamage
end

function DamageCalcServiceUtils.knockback(
	direction: Vector3,
	currentDamage: number,
	baseForce: number,
	multiplier: number,
	verticalForce: number
): Vector3
	local horizontalForce = baseForce + (currentDamage * multiplier)
	return Vector3.new(direction.X * horizontalForce, verticalForce, direction.Z * horizontalForce)
end

function DamageCalcServiceUtils.tagCombat(character: Model, attackerName: string?)
	character:SetAttribute("LastCombatTick", tick())

	if not attackerName then
		return
	end

	character:SetAttribute("LastAttacker", attackerName)
	task.delay(5, function()
		if character.Parent and character:GetAttribute("LastAttacker") == attackerName then
			character:SetAttribute("LastAttacker", nil)
		end
	end)
end

return DamageCalcServiceUtils
