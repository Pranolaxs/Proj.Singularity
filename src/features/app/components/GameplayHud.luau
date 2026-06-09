local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local CurvedStaminaHud = require(script.Parent:WaitForChild("CurvedStaminaHud"))
local SkillCommandHud = require(script.Parent:WaitForChild("SkillCommandHud"))
local e = React.createElement

local function GameplayHud(props)
	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 35,
	}, {
		Stamina = e(CurvedStaminaHud, {
			Percent = props.StaminaPercent,
			Exhausted = props.IsStaminaExhausted,
			Position = props.Projection.staminaPosition,
			Scale = props.Projection.scale,
		}),
		Skills = e(SkillCommandHud, {
			Position = props.Projection.hudPosition,
			Scale = props.Projection.scale,
			Skills = props.Skills,
		}),
	})
end

return GameplayHud
