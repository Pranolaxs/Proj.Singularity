local Repel = {}
Repel.Name = "Repel"
Repel.ServerCooldown = 5
Repel.AllowWhileHooked = true

function Repel.execute(context, player: Player)
	context.handleRepel(player)
end

return Repel
