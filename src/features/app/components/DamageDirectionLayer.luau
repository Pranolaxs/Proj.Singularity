local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local e = React.createElement

local function DamageDirectionLayer(props)
	local children = {}

	for index, indicator in ipairs(props.Indicators or {}) do
		local baseZ = 840 + index * 6
		children[indicator.id] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = indicator.position,
			Rotation = indicator.rotation,
			Size = UDim2.fromOffset(96, 96),
			ZIndex = baseZ,
		}, {
			Glow = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				Text = ")",
				TextColor3 = Color3.fromRGB(255, 0, 35),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(255, 255, 255),
				TextStrokeTransparency = 0.18,
				TextTransparency = 0.08,
				ZIndex = baseZ + 1,
			}),
			Core = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.45, 0.5),
				Size = UDim2.fromScale(0.72, 0.72),
				Text = ")",
				TextColor3 = Color3.fromRGB(255, 245, 245),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(170, 0, 25),
				TextStrokeTransparency = 0.2,
				ZIndex = baseZ + 2,
			}),
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 840,
	}, children)
end

return DamageDirectionLayer
