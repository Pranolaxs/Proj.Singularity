local RoundServiceUtils = {}

function RoundServiceUtils.getValue(parent: Instance, className: string, name: string, defaultValue)
	local value = parent:FindFirstChild(name)
	if not value then
		value = Instance.new(className)
		value.Name = name
		value.Parent = parent
	end

	value.Value = defaultValue
	return value
end

return RoundServiceUtils
