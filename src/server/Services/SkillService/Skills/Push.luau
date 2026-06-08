local Push = {}
Push.Name = "Push"

function Push.execute(context, player: Player, payload)
	if typeof(payload) ~= "table" or typeof(payload.targetPosition) ~= "Vector3" then
		return
	end

	context.handlePush(player, payload.targetPosition)
end

return Push
