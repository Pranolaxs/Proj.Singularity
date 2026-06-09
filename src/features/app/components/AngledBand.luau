local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local e = React.createElement

local function AngledBand(props)
	return e("Frame", {
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		BackgroundColor3 = props.Color,
		BorderSizePixel = 0,
		Position = props.Position,
		Rotation = props.Rotation,
		Size = props.Size,
		ZIndex = props.ZIndex or 1,
	})
end

return AngledBand
