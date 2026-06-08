export type SkillPayload = {
	targetPosition: Vector3?,
}

export type ServerSkill = {
	Name: string,
	execute: (context: any, player: Player, payload: SkillPayload?) -> (),
}

export type ClientSkill = {
	SkillName: string,
	DefaultKeybind: Enum.KeyCode,
	BaseCooldown: number,
	CurrentCooldown: number,
	LastUsed: number,
	SkillIcon: string,
	Equip: ((player: Player, character: Model) -> ())?,
	Unequip: ((player: Player, character: Model) -> ())?,
	Execute: (player: Player, character: Model, networker: any?) -> (),
}

return {}
