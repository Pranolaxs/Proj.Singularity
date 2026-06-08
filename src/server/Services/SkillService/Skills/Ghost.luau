local Ghost = {}
Ghost.Name = "Ghost"

function Ghost.execute(context, player: Player)
	context.handleGhost(player)
end

return Ghost
