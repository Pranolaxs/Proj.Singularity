local ReplicatedStorage = game:GetService("ReplicatedStorage")
local repelEvent = ReplicatedStorage:WaitForChild("RepelSkillEvent")

local RepelSkill = {}
RepelSkill.SkillName = "REPEL"
RepelSkill.DefaultKeybind = Enum.KeyCode.F
RepelSkill.ReadyColor = Color3.fromRGB(255, 200, 50)
RepelSkill.BaseCooldown = 5
RepelSkill.CurrentCooldown = 5
RepelSkill.LastUsed = 0
RepelSkill.SkillIcon = "rbxassetid://103963230014073"

local repelTrack: AnimationTrack? = nil

function RepelSkill.Equip(player, character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		local animation = Instance.new("Animation")
		animation.AnimationId = "rbxassetid://102260175085770"
		repelTrack = animator:LoadAnimation(animation)
		repelTrack.Priority = Enum.AnimationPriority.Action
	end
end

function RepelSkill.Unequip()
	if repelTrack then
		repelTrack:Stop()
		repelTrack = nil
	end
end

function RepelSkill.Execute(player, character, networker)
	if tick() - RepelSkill.LastUsed < RepelSkill.CurrentCooldown then return end
	if character:GetAttribute("IsCasting") or character:GetAttribute("IsDashing") then return end

	RepelSkill.LastUsed = tick()
	character:SetAttribute("IsCasting", true)
	character:SetAttribute("LastCombatTick", tick())
	if repelTrack then
		repelTrack:Play()
	end
	if networker then
		networker:fire("UseSkill", "Repel")
	else
		repelEvent:FireServer()
	end

	task.delay(0.5, function()
		if character then character:SetAttribute("IsCasting", false) end
	end)
end

return RepelSkill
