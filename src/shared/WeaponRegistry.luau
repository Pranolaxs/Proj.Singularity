--!strict

export type WeaponConfig = {
	Id: string,
	DisplayName: string,
	ModelName: string,
	VisualName: string,
	Cost: number,
	Color: Color3,
	Description: string,
	BaseKnockback: number,
	DamageMultiplier: number,
	DamagePerHit: number,
	HitCooldown: number,
	PreviewRotation: CFrame?,
}

export type WeaponUiMeta = {
	cost: number,
	color: Color3,
	description: string,
	hitDamage: number,
	hitCooldown: number,
	displayName: string,
	previewRotation: CFrame?,
}

local weaponConfigsFolder = script.Parent:WaitForChild("Configs"):WaitForChild("Weapons")

local ORDER = {
	"KnockbackStick",
	"Scythe",
	"FairyDagger",
}

local WeaponRegistry = {}
WeaponRegistry.DEFAULT_WEAPON_ID = "KnockbackStick"

local configsById: { [string]: WeaponConfig } = {}

for _, weaponId in ipairs(ORDER) do
	local configModule = weaponConfigsFolder:WaitForChild(weaponId)
	local config = require(configModule) :: WeaponConfig
	configsById[weaponId] = config
end

function WeaponRegistry.listIds(): { string }
	return table.clone(ORDER)
end

function WeaponRegistry.get(weaponId: string): WeaponConfig?
	return configsById[weaponId]
end

function WeaponRegistry.getOrDefault(weaponId: string?): WeaponConfig
	return configsById[weaponId or ""] or configsById[WeaponRegistry.DEFAULT_WEAPON_ID]
end

function WeaponRegistry.getUiMetaMap(): { [string]: WeaponUiMeta }
	local metaById = {}
	for _, weaponId in ipairs(ORDER) do
		local config = configsById[weaponId]
		metaById[weaponId] = {
			cost = config.Cost,
			color = config.Color,
			description = config.Description,
			hitDamage = config.DamagePerHit,
			hitCooldown = config.HitCooldown,
			displayName = config.DisplayName,
			previewRotation = config.PreviewRotation,
		}
	end
	return metaById
end

return WeaponRegistry
