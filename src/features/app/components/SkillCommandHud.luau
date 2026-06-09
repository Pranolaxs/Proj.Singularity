local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local ItemMeta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("ItemMeta"))
local SkillCommandButton = require(script.Parent:WaitForChild("SkillCommandButton"))
local HUD_SLOTS = ItemMeta.HudSlots
local e = React.createElement

local function SkillCommandHud(props)
	local children = {}

	for _, slotConfig in ipairs(HUD_SLOTS) do
		local slot = slotConfig.slot
		local skillData = props.Skills[slot] or {}
		children[slot] = e(SkillCommandButton, {
			Slot = slot,
			SkillName = skillData.name,
			Icon = skillData.icon,
			CooldownRemaining = skillData.remaining,
			CooldownTotal = skillData.total,
			State = skillData.state,
			Position = slotConfig.position,
			Rotation = slotConfig.rotation,
		})
	end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = props.Position,
		Size = UDim2.fromOffset(276 * props.Scale, 190 * props.Scale),
		ZIndex = 50,
	}, {
		Scale = e("UIScale", {
			Scale = props.Scale,
		}),
		Content = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(276, 190),
			ZIndex = 50,
		}, children),
	})
end

return SkillCommandHud
