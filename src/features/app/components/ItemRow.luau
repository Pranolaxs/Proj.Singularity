local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local CostBadge = require(script.Parent:WaitForChild("CostBadge"))
local e = React.createElement

local function ItemRow(props)
	local meta = props.Meta or {}
	return e("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = if props.Selected then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = if props.Selected then 0 else 0.55,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, -28, 0, 56),
		Text = "",
		ZIndex = 18,
		[React.Event.Activated] = props.OnActivated,
	}, {
		ColorSlash = e("Frame", {
			BackgroundColor3 = meta.color or Color3.fromRGB(0, 220, 255),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(14, 12),
			Rotation = -12,
			Size = UDim2.fromOffset(84, 28),
			ZIndex = 19,
		}),
		Icon = e("ImageLabel", {
			BackgroundTransparency = 1,
			Image = meta.icon or "",
			Position = UDim2.fromOffset(18, 6),
			Size = UDim2.fromOffset(48, 48),
			ZIndex = 20,
		}),
		Name = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(104, 0),
			Size = UDim2.new(1, -250, 1, 0),
			Text = props.Name,
			TextColor3 = if props.Selected then Color3.fromRGB(0, 0, 0) else Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 20,
		}),
		Cost = e(CostBadge, {
			Cost = meta.cost or 0,
			Position = UDim2.new(1, -138, 0.5, -17),
			Size = UDim2.fromOffset(112, 34),
			ZIndex = 21,
		}),
	})
end

return ItemRow
