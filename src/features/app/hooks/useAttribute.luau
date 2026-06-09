local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local e = React.createElement

local function useAttribute(player: Player, attributeName: string, fallback)
	local value, setValue = React.useState(player:GetAttribute(attributeName) or fallback)

	React.useEffect(function()
		local function refresh()
			local nextValue = player:GetAttribute(attributeName)
			if nextValue == nil then
				nextValue = fallback
			end
			setValue(nextValue)
		end

		refresh()
		local connection = player:GetAttributeChangedSignal(attributeName):Connect(refresh)
		return function()
			connection:Disconnect()
		end
	end, { player, attributeName, fallback })

	return value
end

return useAttribute
