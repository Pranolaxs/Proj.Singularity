local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local ItemMeta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("ItemMeta"))
local STAMINA_SEGMENTS = ItemMeta.StaminaSegments
local e = React.createElement

local function CurvedStaminaHud(props)
	local percent = math.clamp((props.Percent or 100) / 100, 0, 1)
	local children = {}
	local color = if props.Exhausted then Color3.fromRGB(255, 65, 65) else Color3.fromRGB(255, 234, 38)

	for index = 1, STAMINA_SEGMENTS do
		local progress = (index - 1) / math.max(1, STAMINA_SEGMENTS - 1)
		local angle = math.rad(-116 + progress * 232)
		local x = 76 - math.cos(angle) * 54
		local y = 128 + math.sin(angle) * 104
		local isActive = progress <= percent

		children["Segment" .. index] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = if isActive then color else Color3.fromRGB(14, 35, 130),
			BackgroundTransparency = if isActive then 0 else 0.35,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, y),
			Rotation = math.deg(angle) + 90,
			Size = UDim2.fromOffset(16, 32),
			ZIndex = 42,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		})
	end

	children.Label = e("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(6, 10),
		Rotation = -18,
		Size = UDim2.fromOffset(108, 34),
		Text = "STAMINA",
		TextColor3 = Color3.fromRGB(255, 25, 40),
		TextScaled = true,
		TextStrokeColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeTransparency = 0.12,
		ZIndex = 44,
	})

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = props.Position,
		Size = UDim2.fromOffset(160 * props.Scale, 270 * props.Scale),
		ZIndex = 40,
	}, {
		Scale = e("UIScale", {
			Scale = props.Scale,
		}),
		Content = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(160, 270),
			ZIndex = 40,
		}, children),
	})
end

return CurvedStaminaHud
