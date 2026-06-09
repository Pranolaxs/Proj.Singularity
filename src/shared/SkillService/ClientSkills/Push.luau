local ReplicatedStorage = game:GetService("ReplicatedStorage")
local pushEvent = ReplicatedStorage:WaitForChild("PushSkillEvent")
local AnimationServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationService"):WaitForChild("AnimationServiceUtils"))

local PushSkill = {}
PushSkill.SkillName = "PUSH"
PushSkill.DefaultKeybind = Enum.KeyCode.R
PushSkill.ReadyColor = Color3.fromRGB(150, 255, 150)
PushSkill.BaseCooldown = 2
PushSkill.CurrentCooldown = 2
PushSkill.LastUsed = 0
PushSkill.SkillIcon = "rbxassetid://93847486089506"

local mouse

function PushSkill.Equip(player, _character)
	mouse = player:GetMouse()
end

function PushSkill.Unequip()
	mouse = nil
end

function PushSkill.Execute(_player, character, networker)
	if tick() - PushSkill.LastUsed < PushSkill.CurrentCooldown then return end
	if character:GetAttribute("IsCasting") or character:GetAttribute("IsDashing") then return end

	PushSkill.LastUsed = tick()
	character:SetAttribute("IsCasting", true)
	character:SetAttribute("LastCombatTick", tick())
	AnimationServiceUtils.playCharacterAnimation(character, "PushCast")

	if mouse then
		local payload = { targetPosition = mouse.Hit.Position }
		if networker then
			networker:fire("UseSkill", "Push", payload)
		else
			pushEvent:FireServer(payload.targetPosition)
		end
	end

	task.delay(0.35, function()
		if character then character:SetAttribute("IsCasting", false) end
	end)
end

return PushSkill
