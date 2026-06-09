local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local e = React.createElement

local function CategoryButton(props)
	return e("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(138, 48),
		Text = props.Text,
		TextColor3 = if props.Selected then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(0, 245, 255),
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		ZIndex = 20,
		[React.Event.Activated] = props.OnActivated,
	}, {
		Line = e("Frame", {
			BackgroundColor3 = if props.Selected then Color3.fromRGB(255, 0, 70) else Color3.fromRGB(0, 245, 255),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -5),
			Size = UDim2.new(1, 0, 0, 5),
			ZIndex = 19,
		}),
	})
end

return CategoryButton
