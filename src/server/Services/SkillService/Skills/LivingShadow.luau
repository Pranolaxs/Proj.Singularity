local LivingShadow = {}
LivingShadow.Name = "LivingShadow"
LivingShadow.ServerCooldown = 0
LivingShadow.UsesOwnState = true

function LivingShadow.execute(context, player: Player)
	context.handleLivingShadow(player)
end

return LivingShadow
