local Cloak = {}
Cloak.Name = "Cloak"
Cloak.ServerCooldown = 3

function Cloak.execute(context, player: Player)
	context.handleCloak(player)
end

return Cloak
