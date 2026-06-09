local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local GameplayHud = require(script.Parent.Parent:WaitForChild("components"):WaitForChild("GameplayHud"))
local HitIndicatorLayer = require(script.Parent.Parent:WaitForChild("components"):WaitForChild("HitIndicatorLayer"))
local DamageDirectionLayer = require(script.Parent.Parent:WaitForChild("components"):WaitForChild("DamageDirectionLayer"))
local e = React.createElement

local function GameplayView(props)
	return e("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, {
		Gameplay = e(GameplayHud, { Projection = props.Projection, Skills = props.Skills, StaminaPercent = props.StaminaPercent, IsStaminaExhausted = props.IsStaminaExhausted }),
		HitIndicators = e(HitIndicatorLayer, { Indicators = props.HitIndicators }),
		DamageDirections = e(DamageDirectionLayer, { Indicators = props.DamageTakenIndicators }),
		Hint = e("TextLabel", { AnchorPoint = Vector2.new(1, 1), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Position = UDim2.new(1, -24, 1, -18), Size = UDim2.fromOffset(250, 28), Text = "I / B Inventory", TextColor3 = Color3.fromRGB(255, 255, 255), TextScaled = true, TextTransparency = 0.35, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 50 }),
	})
end

return GameplayView
