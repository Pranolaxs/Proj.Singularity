local ReplicatedStorage = game:GetService("ReplicatedStorage")
local hookEvent = ReplicatedStorage:WaitForChild("HookEvent")
local AnimationServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationService"):WaitForChild("AnimationServiceUtils"))

local HookSkill = {}
HookSkill.SkillName = "HOOK"
HookSkill.DefaultKeybind = Enum.KeyCode.Q
HookSkill.BaseCooldown = 2
HookSkill.CurrentCooldown = 2
HookSkill.LastUsed = 0
HookSkill.SkillIcon = "rbxassetid://71833534900512"

local mouse
local hookTrack: AnimationTrack? = nil

local function loadHookTrack(character: Model)
	if hookTrack then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator then
		hookTrack = AnimationServiceUtils.loadTrack(animator, "HookCast")
	end
end

function HookSkill.Equip(player, character)
	mouse = player:GetMouse()
	loadHookTrack(character)
end

function HookSkill.Unequip()
	mouse = nil
	if hookTrack then
		hookTrack:Stop()
		hookTrack = nil
	end
end

function HookSkill.Execute(player, character, networker)
	if tick() - HookSkill.LastUsed < HookSkill.CurrentCooldown then return end
	if character:GetAttribute("IsCasting") then return end

	HookSkill.LastUsed = tick()
	character:SetAttribute("IsCasting", true)
	character:SetAttribute("LastCombatTick", tick())
	if hookTrack then
		hookTrack:Play()
	end

	if mouse then
		local payload = { targetPosition = mouse.Hit.Position }
		if networker then
			networker:fire("UseSkill", "Hook", payload)
		else
			hookEvent:FireServer(payload.targetPosition)
		end
	end

	task.delay(1, function()
		if character then character:SetAttribute("IsCasting", false) end
	end)
end

return HookSkill
