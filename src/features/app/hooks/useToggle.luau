local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local function useToggle(defaultValue: boolean)
	local visible, setVisible = React.useState(defaultValue)

	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end

			if input.KeyCode == Enum.KeyCode.I or input.KeyCode == Enum.KeyCode.B then
				setVisible(function(current)
					return not current
				end)
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	return visible, setVisible
end

return useToggle
