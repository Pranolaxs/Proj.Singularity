local ReplicatedStorage = game:GetService("ReplicatedStorage")
local repelEvent = ReplicatedStorage:WaitForChild("RepelSkillEvent")
local AnimationServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationService"):WaitForChild("AnimationServiceUtils"))

local RepelSkill = {}
RepelSkill.SkillName = "REPEL"
RepelSkill.DefaultKeybind = Enum.KeyCode.F
RepelSkill.ReadyColor = Color3.fromRGB(255, 200, 50)
RepelSkill.BaseCooldown = 5
RepelSkill.CurrentCooldown = 5
RepelSkill.LastUsed = 0
RepelSkill.SkillIcon = "rbxassetid://103963230014073"

function RepelSkill.Equip(_player, _character) end

function RepelSkill.Unequip() end

function RepelSkill.Execute(_player, character, networker)
	if tick() - RepelSkill.LastUsed < RepelSkill.CurrentCooldown then return end
	if character:GetAttribute("IsCasting") or character:GetAttribute("IsDashing") then return end

	RepelSkill.LastUsed = tick()
	character:SetAttribute("IsCasting", true)
	character:SetAttribute("LastCombatTick", tick())
	AnimationServiceUtils.playCharacterAnimation(character, "RepelCast")
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
