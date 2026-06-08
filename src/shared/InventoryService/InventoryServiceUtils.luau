local InventoryServiceUtils = {}

function InventoryServiceUtils.toList(value: string?, fallback: { string }): { string }
	if not value or value == "" then
		return table.clone(fallback)
	end

	return string.split(value, ",")
end

function InventoryServiceUtils.toString(values: { string }): string
	return table.concat(values, ",")
end

return InventoryServiceUtils
