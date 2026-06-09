local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local e = React.createElement

local function SkillOrb(props)
	local meta = props.Meta or {}
	return e("ImageButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Image = meta.icon or "",
		ImageColor3 = Color3.fromRGB(255, 255, 255),
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = UDim2.fromOffset(58, 58),
		ZIndex = 14,
		[React.Event.Activated] = props.OnActivated,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		Stroke = e("UIStroke", {
			Color = if props.Selected then Color3.fromRGB(255, 255, 255) else meta.color or Color3.fromRGB(0, 30, 255),
			Thickness = if props.Selected then 4 else 2,
		}),
		Accent = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = meta.color or Color3.fromRGB(0, 255, 255),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Rotation = -20,
			Size = UDim2.fromScale(0.85, 0.22),
			ZIndex = 13,
		}),
	})
end

return SkillOrb
