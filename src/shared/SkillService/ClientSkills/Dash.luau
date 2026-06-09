local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AnimationServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationService"):WaitForChild("AnimationServiceUtils"))
local dashEvent = ReplicatedStorage:WaitForChild("DashSkillEvent")

local DashSkill = {}
DashSkill.SkillName = "DASH"
DashSkill.DefaultKeybind = Enum.KeyCode.E
DashSkill.ReadyColor = Color3.fromRGB(50, 255, 50)
DashSkill.BaseCooldown = 5
DashSkill.CurrentCooldown = 5
DashSkill.LastUsed = 0
DashSkill.SkillIcon = "rbxassetid://111690592544646"

local DASH_SPEED = 75
local DASH_DURATION = 0.2
local REDUCE_AMOUNT = 3
local reduceConnection: RBXScriptConnection? = nil
local dashTracks: { [string]: AnimationTrack } = {}

local function stopDashTracks()
	for _, track in pairs(dashTracks) do
		if track.IsPlaying then
			track:Stop(0.1)
		end
	end
end

local function getDashDirection(rootPart: BasePart)
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		return "Back", -rootPart.CFrame.LookVector
	elseif UserInputService:IsKeyDown(Enum.KeyCode.A) then
		return "Left", -rootPart.CFrame.RightVector
	elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
		return "Right", rootPart.CFrame.RightVector
	end

	return "Forward", rootPart.CFrame.LookVector
end

function DashSkill.Equip(_player, _character)
	if reduceConnection then
		reduceConnection:Disconnect()
	end

	table.clear(dashTracks)

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
	stopDashTracks()
	table.clear(dashTracks)
end

local function playDashTrack(directionName: string)
	stopDashTracks()
	local track = dashTracks[directionName] or dashTracks.Forward
	if track then
		track:Play(0.05)
	end
end

local function getDashTrack(character: Model, directionName: string): AnimationTrack?
	local existingTrack = dashTracks[directionName]
	if existingTrack then
		return existingTrack
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end

	local trackNames = {
		Forward = "DashForward",
		Back = "DashBack",
		Left = "DashLeft",
		Right = "DashRight",
	}

	local animationName = trackNames[directionName] or "DashForward"
	local track = AnimationServiceUtils.loadTrack(animator, animationName)
	if track then
		dashTracks[directionName] = track
	end

	return track
end

function DashSkill.Execute(_player, character, networker)
	if tick() - DashSkill.LastUsed < DashSkill.CurrentCooldown then return end
	if character:GetAttribute("IsCasting") or character:GetAttribute("IsHooked") then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	DashSkill.LastUsed = tick()
	character:SetAttribute("IsDashing", true)
	character:SetAttribute("LastCombatTick", tick())

	local directionName, direction = getDashDirection(rootPart)
	getDashTrack(character, directionName)
	playDashTrack(directionName)

	local payload = { directionName = directionName }
	if networker then
		networker:fire("UseSkill", "Dash", payload)
	else
		dashEvent:FireServer(directionName)
	end

	direction = Vector3.new(direction.X, 0, direction.Z).Unit

	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = direction * DASH_SPEED
	bodyVelocity.MaxForce = Vector3.new(100000, 0, 100000)
	bodyVelocity.Parent = rootPart
	Debris:AddItem(bodyVelocity, DASH_DURATION)

	task.delay(DASH_DURATION, function()
		if character then
			character:SetAttribute("IsDashing", false)
		end
		stopDashTracks()
	end)
end

return DashSkill
