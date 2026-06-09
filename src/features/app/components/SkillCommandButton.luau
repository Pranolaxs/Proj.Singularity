local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local ItemMeta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("ItemMeta"))
local CooldownMask = require(script.Parent:WaitForChild("CooldownMask"))
local SKILL_META = ItemMeta.SkillMeta
local e = React.createElement

local function SkillCommandButton(props)
	local meta = SKILL_META[props.SkillName] or {}
	local cooldownTotal = props.CooldownTotal or 0
	local cooldownRemaining = props.CooldownRemaining or 0
	local cooldownRatio = if cooldownTotal > 0 then cooldownRemaining / cooldownTotal else 0
	local isCoolingDown = cooldownRemaining > 0.05
	local isRecastReady = props.State == "Recast"
	local isArming = props.State == "Arming"
	local icon = props.Icon ~= "" and props.Icon or meta.icon or ""
	local color = meta.color or Color3.fromRGB(0, 210, 255)
	local pulse = (math.sin(os.clock() * 9) + 1) / 2

	return e("Frame", {
		BackgroundTransparency = 1,
		Position = props.Position,
		Rotation = props.Rotation,
		Size = UDim2.fromOffset(84, 84),
		ZIndex = 62,
	}, {
		RecastGlow = if isRecastReady then e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(120, 255, 235),
			BackgroundTransparency = 0.55 - pulse * 0.18,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(37, 37),
			Size = UDim2.fromOffset(82 + pulse * 10, 82 + pulse * 10),
			ZIndex = 61,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 255, 255),
				Thickness = 2 + pulse * 2,
				Transparency = 0.2,
			}),
		}) else nil,
		Key = e("TextLabel", {
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(46, 50),
			Rotation = -8,
			Size = UDim2.fromOffset(34, 26),
			Text = props.Slot,
			TextColor3 = Color3.fromRGB(0, 36, 120),
			TextScaled = true,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.65,
			ZIndex = 70,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
		IconBack = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 76, 255),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(66, 66),
			ZIndex = 64,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			Stroke = e("UIStroke", {
				Color = if isRecastReady then Color3.fromRGB(150, 255, 235) elseif isArming then Color3.fromRGB(255, 245, 130) else Color3.fromRGB(255, 255, 255),
				Thickness = if isRecastReady then 5 else 3,
			}),
			Accent = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = -18,
				Size = UDim2.fromScale(0.86, 0.22),
				ZIndex = 65,
			}),
			Icon = e("ImageLabel", {
				BackgroundTransparency = 1,
				Image = icon,
				ImageColor3 = if isRecastReady then Color3.fromRGB(170, 255, 240) elseif isCoolingDown and not isArming then Color3.fromRGB(130, 130, 130) else Color3.fromRGB(255, 255, 255),
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(50, 50),
				ZIndex = 66,
			}),
			Cooldown = e(CooldownMask, {
				Ratio = cooldownRatio,
				ZIndex = 67,
			}),
			Timer = if isCoolingDown then e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.08, 0.18),
				Size = UDim2.fromScale(0.84, 0.64),
				Text = string.format("%.1f", cooldownRemaining),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0,
				ZIndex = 68,
			}) else nil,
		}),
	})
end

return SkillCommandButton
