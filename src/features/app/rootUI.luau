local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local useAttribute = require(script.Parent:WaitForChild("hooks"):WaitForChild("useAttribute"))
local useDamageTakenIndicators = require(script.Parent:WaitForChild("hooks"):WaitForChild("useDamageTakenIndicators"))
local useGameplayProjection = require(script.Parent:WaitForChild("hooks"):WaitForChild("useGameplayProjection"))
local useHitIndicators = require(script.Parent:WaitForChild("hooks"):WaitForChild("useHitIndicators"))
local useToggle = require(script.Parent:WaitForChild("hooks"):WaitForChild("useToggle"))
local useViewportScale = require(script.Parent:WaitForChild("hooks"):WaitForChild("useViewportScale"))
local GameplayView = require(script.Parent:WaitForChild("views"):WaitForChild("GameplayView"))
local InventoryView = require(script.Parent:WaitForChild("views"):WaitForChild("InventoryView"))

local e = React.createElement

local function RootUI()
	local player = Players.LocalPlayer
	local viewportScale = useViewportScale()
	local projection = useGameplayProjection(player, viewportScale)
	local visible, setVisible = useToggle(false)
	local hitIndicators = useHitIndicators()
	local damageTakenIndicators = useDamageTakenIndicators()
	local category, setCategory = React.useState("Skill")
	local selectedSlot, setSelectedSlot = React.useState("E")
	local selectedItem, setSelectedItem = React.useState("")

	local skillListData = useAttribute(player, "SkillInventoryData", "")
	local weaponListData = useAttribute(player, "WeaponInventoryData", "")
	local skinListData = useAttribute(player, "InventoryData", "")
	local equippedWeapon = useAttribute(player, "EquippedWeapon", "KnockbackStick")
	local equippedSkin = useAttribute(player, "EquippedHookSkin", "Default")
	local equippedQ = useAttribute(player, "EquippedSkill_Q", "Hook")
	local equippedE = useAttribute(player, "EquippedSkill_E", "Dash")
	local equippedR = useAttribute(player, "EquippedSkill_R", "Push")
	local equippedF = useAttribute(player, "EquippedSkill_F", "Repel")
	local staminaPercent = useAttribute(player, "StaminaPercent", 100)
	local isStaminaExhausted = useAttribute(player, "IsStaminaExhausted", false)
	local cooldownQ = useAttribute(player, "SkillCooldown_Q_Remaining", 0)
	local cooldownE = useAttribute(player, "SkillCooldown_E_Remaining", 0)
	local cooldownR = useAttribute(player, "SkillCooldown_R_Remaining", 0)
	local cooldownF = useAttribute(player, "SkillCooldown_F_Remaining", 0)
	local cooldownTotalQ = useAttribute(player, "SkillCooldown_Q_Total", 0)
	local cooldownTotalE = useAttribute(player, "SkillCooldown_E_Total", 0)
	local cooldownTotalR = useAttribute(player, "SkillCooldown_R_Total", 0)
	local cooldownTotalF = useAttribute(player, "SkillCooldown_F_Total", 0)
	local iconQ = useAttribute(player, "SkillHud_Q_Icon", "")
	local iconE = useAttribute(player, "SkillHud_E_Icon", "")
	local iconR = useAttribute(player, "SkillHud_R_Icon", "")
	local iconF = useAttribute(player, "SkillHud_F_Icon", "")
	local stateQ = useAttribute(player, "SkillHud_Q_State", "Ready")
	local stateE = useAttribute(player, "SkillHud_E_State", "Ready")
	local stateR = useAttribute(player, "SkillHud_R_State", "Ready")
	local stateF = useAttribute(player, "SkillHud_F_State", "Ready")

	local listData = { Skill = skillListData, Weapon = weaponListData, Skin = skinListData }
	local equippedSkills = { Q = equippedQ, E = equippedE, R = equippedR, F = equippedF }
	local gameplaySkills = {
		Q = { name = equippedQ, icon = iconQ, remaining = cooldownQ, total = cooldownTotalQ, state = stateQ },
		E = { name = equippedE, icon = iconE, remaining = cooldownE, total = cooldownTotalE, state = stateE },
		R = { name = equippedR, icon = iconR, remaining = cooldownR, total = cooldownTotalR, state = stateR },
		F = { name = equippedF, icon = iconF, remaining = cooldownF, total = cooldownTotalF, state = stateF },
	}

	if not visible then
		return e(GameplayView, { Projection = projection, Skills = gameplaySkills, StaminaPercent = staminaPercent, IsStaminaExhausted = isStaminaExhausted, HitIndicators = hitIndicators, DamageTakenIndicators = damageTakenIndicators })
	end

	return e(InventoryView, { Category = category, SetCategory = setCategory, SelectedSlot = selectedSlot, SetSelectedSlot = setSelectedSlot, SelectedItem = selectedItem, SetSelectedItem = setSelectedItem, ListData = listData, EquippedSkills = equippedSkills, EquippedWeapon = equippedWeapon, EquippedSkin = equippedSkin, HitIndicators = hitIndicators, DamageTakenIndicators = damageTakenIndicators, SetVisible = setVisible })
end

return RootUI
