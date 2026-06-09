local Dash = {}
Dash.Name = "Dash"
Dash.ServerCooldown = 5

function Dash.execute(context, player: Player, payload)
	context.handleDash(player, payload)
end

return Dash
