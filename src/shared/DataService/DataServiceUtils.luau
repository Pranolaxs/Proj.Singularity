local DataServiceUtils = {}

DataServiceUtils.DEFAULT_DATA = {
	Coins = 0,
	EquippedHookSkin = "Default",
	Inventory = { "Default", "NeonRuin" },
	EquippedSkill_Q = "Hook",
	EquippedSkill_E = "Dash",
	EquippedSkill_R = "Push",
	EquippedSkill_F = "Repel",
	SkillInventory = { "Dash", "Ghost", "Hook", "Push", "Repel" },
	EquippedWeapon = "KnockbackStick",
	WeaponInventory = { "KnockbackStick", "Scythe" },
}

function DataServiceUtils.copy(value)
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, child in pairs(value) do
		clone[key] = DataServiceUtils.copy(child)
	end
	return clone
end

return DataServiceUtils
