local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local e = React.createElement

local function HitIndicatorLayer(props)
	local children = {}

	for index, indicator in ipairs(props.Indicators or {}) do
		local baseZ = 900 + index * 10
		local accentColor = if indicator.text == "WEAK!" then Color3.fromRGB(170, 255, 255) else Color3.fromRGB(75, 255, 255)
		local shadowColor = if indicator.text == "WEAK!" then Color3.fromRGB(105, 80, 255) else Color3.fromRGB(255, 45, 175)
		local scale = indicator.scale or 0.64
		local size = Vector2.new(188 * scale, 74 * scale)
		local position = indicator.position or Vector2.new(0, 0)

		local particleChildren = {}
		for particleIndex = 1, 5 do
			local side = if particleIndex % 2 == 0 then 1 else -1
			particleChildren["Particle" .. particleIndex] = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = if particleIndex % 3 == 0 then Color3.fromRGB(255, 255, 255) else shadowColor,
				BorderSizePixel = 0,
				Position = UDim2.new(0.5, side * (22 + particleIndex * 7) * scale, 0.5, (-18 + particleIndex * 7) * scale),
				Rotation = -28 + particleIndex * 17,
				Size = UDim2.fromOffset((18 + particleIndex * 2) * scale, math.max(2, 4 * scale)),
				ZIndex = baseZ + 1,
			})
		end

		children[indicator.id] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(position.X, position.Y),
			Rotation = indicator.rotation,
			Size = UDim2.fromOffset(size.X, size.Y),
			ZIndex = baseZ,
		}, {
			Particles = e("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = baseZ,
			}, particleChildren),
			BackText = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.51, 0.54),
				Rotation = -8,
				Size = UDim2.fromScale(0.9, 0.78),
				Text = indicator.text,
				TextColor3 = Color3.fromRGB(0, 0, 80),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0,
				ZIndex = baseZ + 1,
			}),
			MainText = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.48, 0.48),
				Rotation = -8,
				Size = UDim2.fromScale(0.9, 0.78),
				Text = indicator.text,
				TextColor3 = accentColor,
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(255, 255, 255),
				TextStrokeTransparency = 0.1,
				ZIndex = baseZ + 2,
			}),
			Damage = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.15,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.74, 0.83),
				Rotation = -8,
				Size = UDim2.fromScale(0.5, 0.26),
				Text = "+" .. tostring(indicator.damage) .. "%  / " .. tostring(indicator.totalDamage) .. "%",
				TextColor3 = Color3.fromRGB(255, 255, 0),
				TextScaled = true,
				ZIndex = baseZ + 3,
			}),
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 900,
	}, children)
end

return HitIndicatorLayer
