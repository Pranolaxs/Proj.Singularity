local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local DashSkill = {}
DashSkill.SkillName = "DASH"
DashSkill.DefaultKeybind = Enum.KeyCode.E
DashSkill.ReadyColor = Color3.fromRGB(50, 255, 50)
DashSkill.BaseCooldown = 5
DashSkill.CurrentCooldown = 5
DashSkill.LastUsed = 0
DashSkill.SkillIcon = "rbxassetid://111690592544646"

local DASH_SPEED = 75
local REDUCE_AMOUNT = 3
local reduceConnection: RBXScriptConnection? = nil
local dashTrack: AnimationTrack? = nil

local function findPriorDashKeyframes(): KeyframeSequence?
	local localKeyframes = script:FindFirstChild("DashAnim")
	if localKeyframes and localKeyframes:IsA("KeyframeSequence") then
		return localKeyframes
	end

	local savedKeyframes = workspace:FindFirstChild("Automatic Save")
	if savedKeyframes and savedKeyframes:IsA("KeyframeSequence") then
		return savedKeyframes
	end

	return nil
end

local function loadAnimation(character: Model, animationId: string): AnimationTrack?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local track = animator:LoadAnimation(animation)
	track.Priority = Enum.AnimationPriority.Action
	return track
end

local function loadDashAnimation(character: Model): AnimationTrack?
	local keyframes = findPriorDashKeyframes()
	if keyframes then
		local ok, contentId = pcall(function()
			return KeyframeSequenceProvider:RegisterKeyframeSequence(keyframes)
		end)
		if ok and contentId then
			return loadAnimation(character, contentId)
		end
	end

	return loadAnimation(character, "rbxassetid://107533869470327")
end

function DashSkill.Equip(player, character)
	if reduceConnection then
		reduceConnection:Disconnect()
	end

	dashTrack = loadDashAnimation(character)

	local reduceEvent = ReplicatedStorage:WaitForChild("ReduceDashCooldown", 5)
	if reduceEvent then
		reduceConnection = reduceEvent.OnClientEvent:Connect(function()
			DashSkill.LastUsed -= REDUCE_AMOUNT
		end)
	end
end

function DashSkill.Unequip()
	if reduceConnection then
		reduceConnection:Disconnect()
		reduceConnection = nil
	end
	if dashTrack then
		dashTrack:Stop()
		dashTrack = nil
	end
end

function DashSkill.Execute(player, character)
	if tick() - DashSkill.LastUsed < DashSkill.CurrentCooldown then return end
	if character:GetAttribute("IsCasting") or character:GetAttribute("IsHooked") then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	DashSkill.LastUsed = tick()
	character:SetAttribute("IsDashing", true)
	character:SetAttribute("LastCombatTick", tick())
	if dashTrack then
		dashTrack:Play(0.05)
	end

	local direction = rootPart.CFrame.LookVector
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		direction = -rootPart.CFrame.LookVector
	elseif UserInputService:IsKeyDown(Enum.KeyCode.A) then
		direction = -rootPart.CFrame.RightVector
	elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
		direction = rootPart.CFrame.RightVector
	end

	direction = Vector3.new(direction.X, 0, direction.Z).Unit

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = direction * DASH_SPEED
	bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
	bodyVelocity.Parent = rootPart
	game.Debris:AddItem(bodyVelocity, 0.2)

	task.delay(0.2, function()
		if character then
			character:SetAttribute("IsDashing", false)
		end
		if dashTrack then
			dashTrack:Stop(0.1)
		end
	end)
end

return DashSkill
