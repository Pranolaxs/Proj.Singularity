local Repel = {}
Repel.Name = "Repel"

function Repel.execute(context, player: Player)
	context.handleRepel(player)
end

return Repel
