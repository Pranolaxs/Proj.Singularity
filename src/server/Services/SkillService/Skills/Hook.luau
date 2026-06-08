local Hook = {}
Hook.Name = "Hook"

function Hook.execute(context, player: Player, payload)
	if typeof(payload) ~= "table" or typeof(payload.targetPosition) ~= "Vector3" then
		return
	end

	context.handleHook(player, payload.targetPosition)
end

return Hook
