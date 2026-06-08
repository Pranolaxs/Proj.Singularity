local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ghostEvent = ReplicatedStorage:WaitForChild("GhostSkillEvent")

local GhostSkill = {}
GhostSkill.SkillName = "GHOST"
GhostSkill.DefaultKeybind = Enum.KeyCode.E
GhostSkill.ReadyColor = Color3.fromRGB(180, 100, 255)
GhostSkill.BaseCooldown = 20
GhostSkill.CurrentCooldown = 20
GhostSkill.LastUsed = 0
GhostSkill.SkillIcon = "rbxassetid://112885944680569"

function GhostSkill.Equip() end
function GhostSkill.Unequip() end

function GhostSkill.Execute(player, character, networker)
	if tick() - GhostSkill.LastUsed < GhostSkill.CurrentCooldown then return end
	if character:GetAttribute("IsHooked") or character:GetAttribute("IsDashing") then return end

	GhostSkill.LastUsed = tick()
	character:SetAttribute("LastCombatTick", tick())

	if networker then
		networker:fire("UseSkill", "Ghost")
	else
		ghostEvent:FireServer()
	end
end

return GhostSkill
