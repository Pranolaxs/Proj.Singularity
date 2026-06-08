local ReplicatedStorage = game:GetService("ReplicatedStorage")
local hookEvent = ReplicatedStorage:WaitForChild("HookEvent")

local HookSkill = {}
HookSkill.SkillName = "HOOK"
HookSkill.DefaultKeybind = Enum.KeyCode.Q
HookSkill.BaseCooldown = 2
HookSkill.CurrentCooldown = 2
HookSkill.LastUsed = 0
HookSkill.SkillIcon = "rbxassetid://71833534900512"

local mouse
local swingTrack: AnimationTrack? = nil
local toolConnection: RBXScriptConnection? = nil

local function loadSwingTrack(character: Model)
	if swingTrack then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local tool = character:FindFirstChildOfClass("Tool")
	local swingAnim = tool and tool:FindFirstChild("SwingAnim")
	if animator and swingAnim and swingAnim:IsA("Animation") then
		swingTrack = animator:LoadAnimation(swingAnim)
		swingTrack.Priority = Enum.AnimationPriority.Action
	end
end

function HookSkill.Equip(player, character)
	mouse = player:GetMouse()
	loadSwingTrack(character)

	if toolConnection then
		toolConnection:Disconnect()
	end

	toolConnection = character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			loadSwingTrack(character)
		end
	end)
end

function HookSkill.Unequip()
	mouse = nil
	if toolConnection then
		toolConnection:Disconnect()
		toolConnection = nil
	end
	if swingTrack then
		swingTrack:Stop()
		swingTrack = nil
	end
end

function HookSkill.Execute(player, character, networker)
	if tick() - HookSkill.LastUsed < HookSkill.CurrentCooldown then return end
	if character:GetAttribute("IsCasting") then return end

	HookSkill.LastUsed = tick()
	character:SetAttribute("IsCasting", true)
	character:SetAttribute("LastCombatTick", tick())
	if swingTrack then
		swingTrack:Play()
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
