local Ghost = {}
Ghost.Name = "Ghost"
Ghost.ServerCooldown = 20

function Ghost.execute(context, player: Player)
	context.handleGhost(player)
end

return Ghost
