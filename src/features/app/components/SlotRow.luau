local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local e = React.createElement

local function SlotRow(props)
	local filled = props.Value and props.Value ~= ""
	return e("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = if props.Selected then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(42, 48, 104),
		BackgroundTransparency = if props.Selected then 0 else 0.05,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, 50),
		Text = "",
		ZIndex = 15,
		[React.Event.Activated] = props.OnActivated,
	}, {
		Key = e("TextLabel", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(48, 34),
			Text = props.Slot,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			ZIndex = 16,
		}),
		Name = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(68, 2),
			Size = UDim2.new(1, -116, 1, -4),
			Text = filled and props.Value or "-----",
			TextColor3 = if props.Selected then Color3.fromRGB(0, 0, 0) else Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 16,
		}),
		Check = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.new(1, -48, 0, 0),
			Size = UDim2.fromOffset(42, 50),
			Text = if filled then ">" else "",
			TextColor3 = Color3.fromRGB(0, 220, 255),
			TextScaled = true,
			ZIndex = 16,
		}),
	})
end

return SlotRow
