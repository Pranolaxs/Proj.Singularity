local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")
local Workspace = game:GetService("Workspace")

local AnimationServiceUtils = {}

local ANIMATION_DEFINITIONS = {
	WeaponRun = {
		paths = {
			"ReplicatedStorage.Assests.Animations.Movement.run v4",
		},
		sequenceNames = { "run v4" },
		fallbackId = "rbxassetid://107533869470327",
		priority = Enum.AnimationPriority.Movement,
		looped = true,
	},
	WeaponWalk = {
		paths = {
			"ReplicatedStorage.Assests.Animations.Movement.walk v4",
		},
		sequenceNames = { "walk v4" },
		fallbackId = "http://www.roblox.com/asset/?id=180426354",
		priority = Enum.AnimationPriority.Movement,
		looped = true,
	},
	HookCast = {
		paths = {
			"Workspace.Lunge.AnimSaves.Automatic Save",
			"ServerStorage.WeaponInventory.FairyDagger.SwingAnim",
			"ServerStorage.WeaponInventory.FairyDagger.SwingAnim.SwingAnim",
			"ServerStorage.RBX_ANIMSAVES.Rig.Automatic Save",
			"StarterPack.KnockbackStick.SwingAnim",
			"StarterPack.KnockbackStick.SwingAnim.SwingAnim",
			"StarterPack.Scythe.SwingAnim",
			"StarterPack.Scythe.SwingAnim.SwingAnim",
		},
		sequenceNames = {
			"daggerswing",
			"DaggerSwing",
			"Dagger Swing",
			"dagger swing",
		},
		fallbackId = "rbxassetid://73696564448300",
		priority = Enum.AnimationPriority.Action,
		looped = false,
	},
	PushCast = {
		fallbackId = "rbxassetid://102260175085770",
		priority = Enum.AnimationPriority.Action,
		looped = false,
	},
	RepelCast = {
		fallbackId = "rbxassetid://102260175085770",
		priority = Enum.AnimationPriority.Action,
		looped = false,
	},
	DashForward = {
		paths = {
			"ReplicatedStorage.Assests.Animations.Movement.DashForward",
			"Workspace.DashStarterCharacterScripts.DashScript.AnimationFolder.ForwardDash",
			"Workspace.DashCharacterStarterScript.DashScript.AnimationFolder.ForwardDash",
		},
		fallbackId = "rbxassetid://15150585258",
		priority = Enum.AnimationPriority.Action,
		looped = false,
	},
	DashBack = {
		paths = {
			"ReplicatedStorage.Assests.Animations.Movement.DashBack",
			"Workspace.DashStarterCharacterScripts.DashScript.AnimationFolder.BackDash",
			"Workspace.DashCharacterStarterScript.DashScript.AnimationFolder.BackDash",
		},
		fallbackId = "rbxassetid://15150590991",
		priority = Enum.AnimationPriority.Action,
		looped = false,
	},
	DashLeft = {
		paths = {
			"ReplicatedStorage.Assests.Animations.Movement.DashLeft",
			"Workspace.DashStarterCharacterScripts.DashScript.AnimationFolder.LeftDash",
			"Workspace.DashCharacterStarterScript.DashScript.AnimationFolder.LeftDash",
		},
		fallbackId = "rbxassetid://15150593944",
		priority = Enum.AnimationPriority.Action,
		looped = false,
	},
	DashRight = {
		paths = {
			"ReplicatedStorage.Assests.Animations.Movement.DashRight",
			"Workspace.DashStarterCharacterScripts.DashScript.AnimationFolder.RightDash",
			"Workspace.DashCharacterStarterScript.DashScript.AnimationFolder.RightDash",
		},
		fallbackId = "rbxassetid://15150597277",
		priority = Enum.AnimationPriority.Action,
		looped = false,
	},
	ShadowRun = {
		paths = {
			"ReplicatedStorage.Assests.Animations.Movement.run v4",
		},
		sequenceNames = { "run v4" },
		fallbackId = "rbxassetid://107533869470327",
		priority = Enum.AnimationPriority.Movement,
		looped = true,
	},
}

local registeredSequences = {}

local function findByPath(path: string): Instance?
	local current: Instance = game
	for segment in string.gmatch(path, "[^%.]+") do
		if segment == "game" then
			current = game
		elseif segment == "ReplicatedStorage" then
			current = ReplicatedStorage
		elseif segment == "ServerStorage" then
			current = ServerStorage
		elseif segment == "StarterPack" then
			current = StarterPack
		elseif segment == "Workspace" or segment == "workspace" then
			current = Workspace
		else
			local nextInstance = current:FindFirstChild(segment)
			if not nextInstance then
				return nil
			end
			current = nextInstance
		end
	end

	return current
end

local function findKeyframeSequence(definition): KeyframeSequence?
	for _, path in ipairs(definition.paths or {}) do
		local instance = findByPath(path)
		if instance and instance:IsA("KeyframeSequence") then
			return instance
		end
	end

	for _, sequenceName in ipairs(definition.sequenceNames or {}) do
		local direct = Workspace:FindFirstChild(sequenceName)
		if direct and direct:IsA("KeyframeSequence") then
			return direct
		end

		local recursive = Workspace:FindFirstChild(sequenceName, true)
		if recursive and recursive:IsA("KeyframeSequence") then
			return recursive
		end
	end

	return nil
end

local function findAnimation(definition): Animation?
	for _, path in ipairs(definition.paths or {}) do
		local instance = findByPath(path)
		if instance and instance:IsA("Animation") then
			return instance
		end
	end

	return nil
end

local function makeAnimation(animationName: string, definition): Animation
	local sourceAnimation = findAnimation(definition)
	if sourceAnimation then
		local animation = sourceAnimation:Clone()
		animation.Name = animationName
		return animation
	end

	local animation = Instance.new("Animation")
	animation.Name = animationName

	local sequence = findKeyframeSequence(definition)
	if sequence then
		local cachedId = registeredSequences[sequence]
		if not cachedId then
			local success, contentId = pcall(function()
				return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
			end)
			if success then
				cachedId = contentId
				registeredSequences[sequence] = cachedId
			end
		end

		if cachedId then
			animation.AnimationId = cachedId
			return animation
		end
	end

	animation.AnimationId = definition.fallbackId or ""
	return animation
end

function AnimationServiceUtils.createAnimation(animationName: string): Animation?
	local definition = ANIMATION_DEFINITIONS[animationName]
	if not definition then
		return nil
	end

	return makeAnimation(animationName, definition)
end

function AnimationServiceUtils.loadTrack(animator: Animator, animationName: string): AnimationTrack?
	local definition = ANIMATION_DEFINITIONS[animationName]
	local animation = AnimationServiceUtils.createAnimation(animationName)
	if not definition or not animation or animation.AnimationId == "" then
		return nil
	end

	local track = animator:LoadAnimation(animation)
	track.Priority = definition.priority or Enum.AnimationPriority.Action
	track.Looped = definition.looped == true
	return track
end

function AnimationServiceUtils.getAnimator(character: Model): Animator?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		return animator
	end

	animator = Instance.new("Animator")
	animator.Parent = humanoid
	return animator
end

function AnimationServiceUtils.getAnimationControllerAnimator(model: Model): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			return animator
		end

		animator = Instance.new("Animator")
		animator.Parent = humanoid
		return animator
	end

	local controller = model:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = model
	end

	local animator = controller:FindFirstChildOfClass("Animator")
	if animator then
		return animator
	end

	animator = Instance.new("Animator")
	animator.Parent = controller
	return animator
end

function AnimationServiceUtils.playCharacterAnimation(character: Model, animationName: string, fadeTime: number?): AnimationTrack?
	local animator = AnimationServiceUtils.getAnimator(character)
	if not animator then
		return nil
	end

	local track = AnimationServiceUtils.loadTrack(animator, animationName)
	if not track then
		return nil
	end

	track:Play(fadeTime or 0.05)
	return track
end

function AnimationServiceUtils.applyMovementAnimations(character: Model)
	local animate = character:FindFirstChild("Animate") or character:WaitForChild("Animate", 5)
	if not animate then
		return
	end

	local runAnimation = AnimationServiceUtils.createAnimation("WeaponRun")
	local walkAnimation = AnimationServiceUtils.createAnimation("WeaponWalk")

	local runFolder = animate:FindFirstChild("run")
	local runAnim = runFolder and runFolder:FindFirstChild("RunAnim")
	if runAnimation and runAnim and runAnim:IsA("Animation") then
		runAnim.AnimationId = runAnimation.AnimationId
	end

	local walkFolder = animate:FindFirstChild("walk")
	local walkAnim = walkFolder and walkFolder:FindFirstChild("WalkAnim")
	if walkAnimation and walkAnim and walkAnim:IsA("Animation") then
		walkAnim.AnimationId = walkAnimation.AnimationId
	end

	if animate:IsA("LocalScript") then
		animate.Disabled = true
		task.defer(function()
			if animate.Parent then
				animate.Disabled = false
			end
		end)
	end
end

return AnimationServiceUtils
