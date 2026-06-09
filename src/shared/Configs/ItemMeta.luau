local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponRegistry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponRegistry"))

local ItemMeta = {}

ItemMeta.PlayerName = "Alice"
ItemMeta.Arcana = "Death"
ItemMeta.SkillMeta = {
	Hook = {
		cost = 3,
		color = Color3.fromRGB(160, 0, 255),
		icon = "rbxassetid://71833534900512",
		description = "Launches your weapon forward and pulls 1 foe to your current position.",
	},
	Dash = {
		cost = 4,
		color = Color3.fromRGB(0, 220, 255),
		icon = "rbxassetid://111690592544646",
		description = "Bursts in the chosen direction. Reduces downtime after clean movement.",
	},
	Push = {
		cost = 6,
		color = Color3.fromRGB(255, 70, 60),
		icon = "rbxassetid://93847486089506",
		description = "After a short windup, pushes enemies in front of you.",
	},
	Repel = {
		cost = 8,
		color = Color3.fromRGB(255, 220, 35),
		icon = "rbxassetid://103963230014073",
		description = "Breaks pull and knockback pressure around you.",
	},
	Ghost = {
		cost = 10,
		color = Color3.fromRGB(90, 255, 150),
		icon = "rbxassetid://112885944680569",
		description = "Phases briefly, lowering collision pressure and visibility.",
	},
	Cloak = {
		cost = 7,
		color = Color3.fromRGB(130, 255, 210),
		icon = "rbxassetid://112885944680569",
		description = "Fades invisible, runs faster, but breaks on combat, skills, attacks, or taking damage.",
	},
	LivingShadow = {
		cost = 9,
		color = Color3.fromRGB(20, 20, 35),
		icon = "rbxassetid://112885944680569",
		description = "Creates a black shadow for 5 seconds. Recast after 0.5s to pull it back and knock enemies in its path.",
	},
}

ItemMeta.WeaponMeta = WeaponRegistry.getUiMetaMap()

ItemMeta.SkinMeta = {
	Default = {
		cost = 0,
		color = Color3.fromRGB(80, 180, 255),
		description = "Default hook skin.",
	},
	NeonRuin = {
		cost = 0,
		color = Color3.fromRGB(255, 40, 190),
		description = "High contrast neon hook skin.",
	},
}

ItemMeta.CategoryConfig = {
	Skill = {
		title = "SELECT SKILL",
		listAttribute = "SkillInventoryData",
		fallback = { "Hook", "Dash", "Push", "Repel", "Ghost", "Cloak", "LivingShadow" },
		meta = ItemMeta.SkillMeta,
	},
	Weapon = {
		title = "SELECT WEAPON",
		listAttribute = "WeaponInventoryData",
		fallback = WeaponRegistry.listIds(),
		meta = ItemMeta.WeaponMeta,
	},
	Skin = {
		title = "SELECT SKIN",
		listAttribute = "InventoryData",
		fallback = { "Default", "NeonRuin" },
		meta = ItemMeta.SkinMeta,
	},
}

ItemMeta.SlotAttributes = {
	Q = "EquippedSkill_Q",
	E = "EquippedSkill_E",
	R = "EquippedSkill_R",
	F = "EquippedSkill_F",
}

ItemMeta.HudSlots = {
	{
		slot = "Q",
		position = UDim2.fromOffset(10, 64),
		rotation = -8,
	},
	{
		slot = "E",
		position = UDim2.fromOffset(88, 18),
		rotation = -4,
	},
	{
		slot = "R",
		position = UDim2.fromOffset(104, 104),
		rotation = 4,
	},
	{
		slot = "F",
		position = UDim2.fromOffset(182, 60),
		rotation = 8,
	},
}

ItemMeta.StaminaSegments = 20

return ItemMeta
