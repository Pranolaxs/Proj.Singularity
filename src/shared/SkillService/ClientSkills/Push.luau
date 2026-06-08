local ReplicatedStorage = game:GetService("ReplicatedStorage")
local pushEvent = ReplicatedStorage:WaitForChild("PushSkillEvent")

local PushSkill = {}
PushSkill.SkillName = "PUSH"
PushSkill.DefaultKeybind = Enum.KeyCode.R
PushSkill.ReadyColor = Color3.fromRGB(150, 255, 150)
PushSkill.BaseCooldown = 2
PushSkill.CurrentCooldown = 2
PushSkill.LastUsed = 0
PushSkill.SkillIcon = "rbxassetid://93847486089506"

local mouse
local pushTrack: AnimationTrack? = nil

function PushSkill.Equip(player, character)
	mouse = player:GetMouse()

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://102260175085770"
		pushTrack = animator:LoadAnimation(animation)
		pushTrack.Priority = Enum.AnimationPriority.Action
	end
end

function PushSkill.Unequip()
	mouse = nil
	if pushTrack then
		pushTrack:Stop()
		pushTrack = nil
	end
end

function PushSkill.Execute(player, character, networker)
	if tick() - PushSkill.LastUsed < PushSkill.CurrentCooldown then return end
	if character:GetAttribute("IsCasting") or character:GetAttribute("IsDashing") then return end

	PushSkill.LastUsed = tick()
	character:SetAttribute("IsCasting", true)
	character:SetAttribute("LastCombatTick", tick())
	if pushTrack then
		pushTrack:Play()
	end

	task.delay(0.3, function()
		if mouse then
			local payload = { targetPosition = mouse.Hit.Position }
			if networker then
				networker:fire("UseSkill", "Push", payload)
			else
				pushEvent:FireServer(payload.targetPosition)
			end
		end

		if character then character:SetAttribute("IsCasting", false) end
	end)
end

return PushSkill
