local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local e = React.createElement

local function CostBadge(props)
	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = props.Position,
		Size = props.Size or UDim2.fromOffset(118, 34),
		ZIndex = props.ZIndex or 20,
	}, {
		Cost = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Arcade,
			Position = UDim2.fromScale(0.08, 0),
			Size = UDim2.fromScale(0.54, 1),
			Text = tostring(props.Cost or 0),
			TextColor3 = Color3.fromRGB(255, 255, 0),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = (props.ZIndex or 20) + 1,
		}),
		SP = e("TextLabel", {
			BackgroundColor3 = Color3.fromRGB(255, 240, 20),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromScale(0.66, 0.12),
			Rotation = -12,
			Size = UDim2.fromScale(0.32, 0.76),
			Text = "SP",
			TextColor3 = Color3.fromRGB(0, 0, 0),
			TextScaled = true,
			ZIndex = (props.ZIndex or 20) + 1,
		}),
	})
end

return CostBadge
