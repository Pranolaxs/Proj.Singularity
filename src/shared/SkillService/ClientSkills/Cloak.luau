local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local cloakEvent = ReplicatedStorage:WaitForChild("CloakSkillEvent")

local CloakSkill = {}
CloakSkill.SkillName = "CLOAK"
CloakSkill.DefaultKeybind = Enum.KeyCode.F
CloakSkill.ReadyColor = Color3.fromRGB(120, 255, 210)
CloakSkill.BaseCooldown = 3
CloakSkill.CurrentCooldown = 3
CloakSkill.LastUsed = 0
CloakSkill.SkillIcon = "rbxassetid://112885944680569"

local renderConnection: RBXScriptConnection? = nil

local function shouldKeepHidden(instance: Instance): boolean
	if instance:IsA("BasePart") then
		local tool = instance:FindFirstAncestorOfClass("Tool")
		return tool ~= nil and instance.Name == "Handle"
	end

	return false
end

function CloakSkill.Equip(_player, character)
	if renderConnection then
		renderConnection:Disconnect()
	end

	renderConnection = RunService.RenderStepped:Connect(function()
		if not character.Parent or character:GetAttribute("IsCloaked") ~= true then
			return
		end

		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
				descendant.Transparency = if shouldKeepHidden(descendant) then 1 else 0.75
			elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
				descendant.Transparency = 0.75
			end
		end
	end)
end

function CloakSkill.Unequip()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
end

function CloakSkill.Execute(_player, character, networker)
	if tick() - CloakSkill.LastUsed < CloakSkill.CurrentCooldown then return end
	if character:GetAttribute("IsCasting") or character:GetAttribute("IsDashing") or character:GetAttribute("IsHooked") then return end
	if character:GetAttribute("IsCloaked") then return end

	CloakSkill.LastUsed = tick()

	if networker then
		networker:fire("UseSkill", "Cloak")
	else
		cloakEvent:FireServer()
	end
end

return CloakSkill
