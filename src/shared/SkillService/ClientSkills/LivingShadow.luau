local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shadowEvent = ReplicatedStorage:WaitForChild("LivingShadowSkillEvent", 5)

local LivingShadowSkill = {}
LivingShadowSkill.SkillName = "LIVING SHADOW"
LivingShadowSkill.DefaultKeybind = Enum.KeyCode.F
LivingShadowSkill.ReadyColor = Color3.fromRGB(35, 35, 45)
LivingShadowSkill.BaseCooldown = 3
LivingShadowSkill.CurrentCooldown = 3
LivingShadowSkill.LastUsed = 0
LivingShadowSkill.SkillIcon = "rbxassetid://112885944680569"

local ACTIVE_DURATION = 5
local INITIAL_RECAST_DELAY = 0.5
local REAL_COOLDOWN = 3
local localCooldownReadyAt = 0
local localCooldownHoldUntil = 0

local function fireSkill(networker)
	if networker then
		networker:fire("UseSkill", "LivingShadow")
	elseif shadowEvent then
		shadowEvent:FireServer()
	end
end

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function setLocalState(player: Player, stateName: string, activeUntil: number?, recastAt: number?, readyAt: number?)
	player:SetAttribute("LivingShadowState", stateName)
	player:SetAttribute("LivingShadowActiveUntil", activeUntil or 0)
	player:SetAttribute("LivingShadowRecastAt", recastAt or 0)
	player:SetAttribute("LivingShadowReadyAt", readyAt or 0)
end

function LivingShadowSkill.Equip() end

function LivingShadowSkill.Unequip() end

function LivingShadowSkill.GetHudState(player: Player)
	local now = serverNow()
	local stateName = player:GetAttribute("LivingShadowState")
	local activeUntil = player:GetAttribute("LivingShadowActiveUntil") or 0
	local recastAt = player:GetAttribute("LivingShadowRecastAt") or 0
	local readyAt = player:GetAttribute("LivingShadowReadyAt") or 0

	if stateName == "Arming" and activeUntil > now then
		if recastAt > now then
			return {
				name = "ARMING",
				state = "Arming",
				total = INITIAL_RECAST_DELAY,
				remaining = recastAt - now,
			}
		end

		return {
			name = "RECAST",
			state = "Recast",
			total = math.max(activeUntil - recastAt, 0.1),
			remaining = math.max(activeUntil - now, 0),
		}
	elseif stateName == "Cooldown" and readyAt > now then
		local displayedRemaining = readyAt - now
		if localCooldownReadyAt > now then
			displayedRemaining = math.max(displayedRemaining, localCooldownReadyAt - now)
		end
		if now < localCooldownHoldUntil then
			displayedRemaining = REAL_COOLDOWN
		end

		return {
			name = "LIVING SHADOW",
			state = "Cooldown",
			total = REAL_COOLDOWN,
			remaining = displayedRemaining,
		}
	end

	localCooldownReadyAt = 0
	localCooldownHoldUntil = 0

	return {
		name = "LIVING SHADOW",
		state = "Ready",
		total = REAL_COOLDOWN,
		remaining = 0,
	}
end

function LivingShadowSkill.Execute(player, character, networker)
	local now = serverNow()
	if character:GetAttribute("IsCasting") or character:GetAttribute("IsDashing") or character:GetAttribute("IsHooked") then
		return
	end

	local stateName = player:GetAttribute("LivingShadowState")
	local activeUntil = player:GetAttribute("LivingShadowActiveUntil") or 0
	local recastAt = player:GetAttribute("LivingShadowRecastAt") or 0
	local readyAt = player:GetAttribute("LivingShadowReadyAt") or 0

	if stateName == "Arming" and activeUntil > now then
		if recastAt > now then
			return
		end

		fireSkill(networker)
		localCooldownReadyAt = now + REAL_COOLDOWN
		localCooldownHoldUntil = now + 0.22
		setLocalState(player, "Cooldown", 0, 0, now + REAL_COOLDOWN)
		return
	end

	if stateName == "Cooldown" and readyAt > now then
		return
	end

	fireSkill(networker)
	setLocalState(player, "Arming", now + ACTIVE_DURATION, now + INITIAL_RECAST_DELAY, 0)
end

return LivingShadowSkill
