local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local ItemMeta = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("ItemMeta"))
local AngledBand = require(script.Parent.Parent:WaitForChild("components"):WaitForChild("AngledBand"))
local CategoryButton = require(script.Parent.Parent:WaitForChild("components"):WaitForChild("CategoryButton"))
local DamageDirectionLayer = require(script.Parent.Parent:WaitForChild("components"):WaitForChild("DamageDirectionLayer"))
local HitIndicatorLayer = require(script.Parent.Parent:WaitForChild("components"):WaitForChild("HitIndicatorLayer"))
local ItemRow = require(script.Parent.Parent:WaitForChild("components"):WaitForChild("ItemRow"))
local SkillOrb = require(script.Parent.Parent:WaitForChild("components"):WaitForChild("SkillOrb"))
local SlotRow = require(script.Parent.Parent:WaitForChild("components"):WaitForChild("SlotRow"))
local WeaponMeshPreview = require(script.Parent.Parent:WaitForChild("components"):WaitForChild("WeaponMeshPreview"))
local e = React.createElement
local PLAYER_NAME = ItemMeta.PlayerName
local ARCANA = ItemMeta.Arcana
local SKILL_META = ItemMeta.SkillMeta
local CATEGORY_CONFIG = ItemMeta.CategoryConfig

local function splitList(value: string?, fallback: { string }): { string }
	if not value or value == "" then return table.clone(fallback) end
	local result = {}
	for item in string.gmatch(value, "([^,]+)") do table.insert(result, item) end
	if #result == 0 then return table.clone(fallback) end
	return result
end

local function InventoryView(props)
	local category = props.Category
	local setCategory = props.SetCategory
	local selectedSlot = props.SelectedSlot
	local setSelectedSlot = props.SetSelectedSlot
	local selectedItem = props.SelectedItem
	local setSelectedItem = props.SetSelectedItem
	local listData = props.ListData
	local equippedSkills = props.EquippedSkills
	local equippedWeapon = props.EquippedWeapon
	local equippedSkin = props.EquippedSkin
	local hitIndicators = props.HitIndicators
	local damageTakenIndicators = props.DamageTakenIndicators
	local setVisible = props.SetVisible

	local categoryConfig = CATEGORY_CONFIG[category]
	local inventoryItems = splitList(listData[category], categoryConfig.fallback)
	local selectedName = if selectedItem ~= "" then selectedItem else inventoryItems[1]
	local selectedMeta = categoryConfig.meta[selectedName] or {}
	local weaponHitDamage = selectedMeta.hitDamage or 25
	local weaponHitCooldown = selectedMeta.hitCooldown or 0.5
	local leftPanelPosition = if category == "Weapon" then UDim2.fromScale(0.01, 0.22) else UDim2.fromScale(0.03, 0.62)
	local leftPanelSize = if category == "Weapon" then UDim2.fromScale(0.55, 0.66) else UDim2.fromScale(0.48, 0.23)
	local equipRemote = ReplicatedStorage:FindFirstChild("EquipInventoryItemEvent")

	local function confirmSelection()
		if not selectedName or not equipRemote or not equipRemote:IsA("RemoteEvent") then
			return
		end

		equipRemote:FireServer(category, selectedName, selectedSlot)
	end

	local orbChildren = {}
	for index, slotName in ipairs({ "Q", "E", "R", "F" }) do
		local itemName = equippedSkills[slotName]
		orbChildren[slotName] = e(SkillOrb, {
			LayoutOrder = index,
			Meta = SKILL_META[itemName],
			Selected = category == "Skill" and selectedSlot == slotName,
			OnActivated = function()
				setCategory("Skill")
				setSelectedSlot(slotName)
				setSelectedItem(itemName)
			end,
		})
	end
	orbChildren.Layout = e("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
	})

	local slotChildren = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for order, slotName in ipairs({ "Q", "E", "R", "F" }) do
		slotChildren[slotName] = e(SlotRow, {
			LayoutOrder = order,
			Slot = slotName,
			Value = equippedSkills[slotName],
			Selected = selectedSlot == slotName,
			OnActivated = function()
				setSelectedSlot(slotName)
			end,
		})
	end

	local leftPanelChildren = slotChildren
	if category == "Weapon" then
		leftPanelChildren = {
			GlowA = e("Frame", {
				BackgroundColor3 = selectedMeta.color or Color3.fromRGB(0, 230, 255),
				BackgroundTransparency = 0.35,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.26, 0.03),
				Rotation = -22,
				Size = UDim2.fromScale(0.36, 0.88),
				ZIndex = 15,
			}),
			GlowB = e("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 28, 255),
				BackgroundTransparency = 0.58,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.05, 0.34),
				Rotation = -13,
				Size = UDim2.fromScale(0.86, 0.18),
				ZIndex = 14,
			}),
			Category = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.06, 0.37),
				Rotation = -8,
				Size = UDim2.fromScale(0.24, 0.08),
				Text = "WEAPON",
				TextColor3 = Color3.fromRGB(0, 230, 255),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 19,
			}),
			WeaponPreview = e(WeaponMeshPreview, {
				BaseRotation = selectedMeta.previewRotation or CFrame.Angles(math.rad(-8), math.rad(-36), math.rad(54)),
				Position = UDim2.fromScale(0.15, -0.09),
				Rotation = -5,
				Size = UDim2.fromScale(0.82, 0.82),
				WeaponName = selectedName,
				ZIndex = 17,
			}),
			DescBack = e("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 45),
				BackgroundTransparency = 0.12,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.04, 0.64),
				Rotation = -3,
				Size = UDim2.fromScale(0.6, 0.26),
				ZIndex = 21,
			}),
			NameSlash = e("Frame", {
				BackgroundColor3 = selectedMeta.color or Color3.fromRGB(0, 230, 255),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.07, 0.61),
				Rotation = -12,
				Size = UDim2.fromScale(0.28, 0.055),
				ZIndex = 22,
			}),
			Name = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.08, 0.58),
				Rotation = -4,
				Size = UDim2.fromScale(0.48, 0.09),
				Text = selectedName or "NONE",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 23,
			}),
			Description = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.08, 0.69),
				Size = UDim2.fromScale(0.5, 0.1),
				Text = selectedMeta.description or "Select a weapon.",
				TextColor3 = Color3.fromRGB(235, 235, 245),
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 22,
			}),
			HitDamageLabel = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.08, 0.81),
				Size = UDim2.fromScale(0.18, 0.055),
				Text = "HIT DMG",
				TextColor3 = Color3.fromRGB(255, 90, 35),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 22,
			}),
			HitDamageValue = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.27, 0.81),
				Size = UDim2.fromScale(0.09, 0.055),
				Text = tostring(weaponHitDamage),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 22,
			}),
			HitCooldownLabel = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.39, 0.81),
				Size = UDim2.fromScale(0.14, 0.055),
				Text = "HIT CD",
				TextColor3 = Color3.fromRGB(255, 90, 35),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 22,
			}),
			HitCooldownValue = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.5, 0.81),
				Size = UDim2.fromScale(0.09, 0.055),
				Text = string.format("%.1fs", weaponHitCooldown),
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 22,
			}),
		}
	elseif category ~= "Skill" then
		leftPanelChildren = {
			PreviewBack = e("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 42),
				BackgroundTransparency = 0.12,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.02, 0.02),
				Rotation = -3,
				Size = UDim2.fromScale(0.92, 0.9),
				ZIndex = 14,
			}),
			Accent = e("Frame", {
				BackgroundColor3 = selectedMeta.color or Color3.fromRGB(0, 220, 255),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.08, 0.2),
				Rotation = -14,
				Size = UDim2.fromScale(0.34, 0.18),
				ZIndex = 15,
			}),
			Category = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.06, 0.06),
				Rotation = -8,
				Size = UDim2.fromScale(0.42, 0.18),
				Text = category:upper(),
				TextColor3 = Color3.fromRGB(0, 230, 255),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 16,
			}),
			Name = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.1, if category == "Weapon" then 0.06 else 0.32),
				Size = UDim2.fromScale(0.78, if category == "Weapon" then 0.16 else 0.24),
				Text = selectedName or "NONE",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 20,
			}),
			Description = if category ~= "Weapon" then e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.1, 0.58),
				Size = UDim2.fromScale(0.78, 0.24),
				Text = selectedMeta.description or "Select an item.",
				TextColor3 = Color3.fromRGB(220, 220, 230),
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 16,
			}) else nil,
		}
	end

	local itemChildren = {
		Layout = e("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		}),
	}
	for index, itemName in ipairs(inventoryItems) do
		itemChildren[itemName] = e(ItemRow, {
			LayoutOrder = index,
			Meta = categoryConfig.meta[itemName],
			Name = itemName,
			Selected = itemName == selectedName,
			OnActivated = function()
				setSelectedItem(itemName)
			end,
		})
	end

	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 9, 105),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, {
		BlueA = e(AngledBand, {
			Color = Color3.fromRGB(0, 24, 255),
			Position = UDim2.fromScale(-0.05, 0.06),
			Rotation = -10,
			Size = UDim2.fromScale(1.25, 0.22),
			ZIndex = 2,
		}),
		BlueB = e(AngledBand, {
			Color = Color3.fromRGB(0, 18, 190),
			Position = UDim2.fromScale(0.08, 0.62),
			Rotation = -18,
			Size = UDim2.fromScale(1.2, 0.22),
			ZIndex = 2,
		}),
		TopWhite = e(AngledBand, {
			Color = Color3.fromRGB(255, 255, 255),
			Position = UDim2.fromScale(-0.02, -0.1),
			Rotation = -10,
			Size = UDim2.fromScale(1.25, 0.27),
			ZIndex = 4,
		}),
		RedSlash = e(AngledBand, {
			Color = Color3.fromRGB(255, 0, 55),
			Position = UDim2.fromScale(-0.05, 0.13),
			Rotation = -10,
			Size = UDim2.fromScale(1.25, 0.012),
			ZIndex = 5,
		}),
		GhostText = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromScale(0.12, 0.24),
			Rotation = -8,
			Size = UDim2.fromScale(0.6, 0.28),
			Text = category:upper(),
			TextColor3 = Color3.fromRGB(0, 0, 55),
			TextScaled = true,
			TextTransparency = 0.25,
			ZIndex = 3,
		}),
		Header = e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.03, 0.03),
			Size = UDim2.fromScale(0.52, 0.16),
			ZIndex = 20,
		}, {
			Tabs = e("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0.34),
				ZIndex = 20,
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 14),
				}),
				Skill = e(CategoryButton, {
					LayoutOrder = 1,
					Text = "1 Skill",
					Selected = category == "Skill",
					OnActivated = function()
						setCategory("Skill")
						setSelectedItem("")
					end,
				}),
				Weapon = e(CategoryButton, {
					LayoutOrder = 2,
					Text = "2 Weapon",
					Selected = category == "Weapon",
					OnActivated = function()
						setCategory("Weapon")
						setSelectedItem("")
					end,
				}),
				Skin = e(CategoryButton, {
					LayoutOrder = 3,
					Text = "3 Skin",
					Selected = category == "Skin",
					OnActivated = function()
						setCategory("Skin")
						setSelectedItem("")
					end,
				}),
			}),
			Arcana = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.14, 0.36),
				Size = UDim2.fromScale(0.28, 0.52),
				Text = ARCANA,
				TextColor3 = Color3.fromRGB(210, 210, 210),
				TextScaled = true,
				TextTransparency = 0.2,
				Rotation = -6,
				ZIndex = 20,
			}),
			PlayerName = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.32, 0.42),
				Size = UDim2.fromScale(0.26, 0.36),
				Text = PLAYER_NAME,
				TextColor3 = Color3.fromRGB(0, 0, 0),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 21,
			}),
			Level = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.14, 0.73),
				Size = UDim2.fromScale(0.28, 0.28),
				Text = "LV 68",
				TextColor3 = Color3.fromRGB(230, 255, 0),
				TextScaled = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 21,
			}),
		}),
		SkillOrbs = if category == "Skill" then e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.09, 0.25),
			Size = UDim2.fromScale(0.46, 0.09),
			ZIndex = 14,
		}, orbChildren) else nil,
		SlotPanel = e("Frame", {
			BackgroundTransparency = 1,
			Position = leftPanelPosition,
			Size = leftPanelSize,
			ZIndex = 14,
		}, leftPanelChildren),
		-- NextSkill = e("Frame", {
		-- 	BackgroundColor3 = Color3.fromRGB(0, 28, 255),
		-- 	BorderSizePixel = 0,
		-- 	Position = UDim2.fromScale(0.02, 0.88),
		-- 	Size = UDim2.fromScale(0.49, 0.08),
		-- 	ZIndex = 13,
		-- }, {
		-- 	Label = e("TextLabel", {
		-- 		BackgroundTransparency = 1,
		-- 		Font = Enum.Font.GothamBlack,
		-- 		Position = UDim2.fromScale(0.02, 0.06),
		-- 		Size = UDim2.fromScale(0.28, 0.8),
		-- 		Text = "NEXT SKILL",
		-- 		TextColor3 = Color3.fromRGB(0, 220, 255),
		-- 		TextScaled = true,
		-- 		TextXAlignment = Enum.TextXAlignment.Left,
		-- 		ZIndex = 15,
		-- 	}),
		-- 	Name = e("TextLabel", {
		-- 		BackgroundTransparency = 1,
		-- 		Font = Enum.Font.GothamBlack,
		-- 		Position = UDim2.fromScale(0.32, 0.08),
		-- 		Size = UDim2.fromScale(0.55, 0.78),
		-- 		Text = selectedName or "NONE",
		-- 		TextColor3 = Color3.fromRGB(255, 255, 0),
		-- 		TextScaled = true,
		-- 		TextXAlignment = Enum.TextXAlignment.Left,
		-- 		ZIndex = 15,
		-- 	}),
		-- 	Unknown = e("TextLabel", {
		-- 		BackgroundTransparency = 1,
		-- 		Font = Enum.Font.GothamBlack,
		-- 		Position = UDim2.fromScale(0.86, 0.16),
		-- 		Size = UDim2.fromScale(0.13, 0.72),
		-- 		Text = "???",
		-- 		TextColor3 = Color3.fromRGB(0, 230, 255),
		-- 		TextScaled = true,
		-- 		ZIndex = 15,
		-- 	}),
		-- }),
		RightTitle = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromScale(0.64, 0.21),
			Rotation = -5,
			Size = UDim2.fromScale(0.3, 0.12),
			Text = categoryConfig.title .. "!",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 20,
		}),
		TitleBang = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromScale(0.87, 0.18),
			Rotation = 10,
			Size = UDim2.fromScale(0.06, 0.18),
			Text = "!",
			TextColor3 = Color3.fromRGB(145, 255, 255),
			TextScaled = true,
			ZIndex = 20,
		}),
		ItemList = e("ScrollingFrame", {
			Active = true,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, #inventoryItems * 66),
			Position = UDim2.fromScale(0.56, 0.42),
			ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
			ScrollBarThickness = 8,
			Size = UDim2.fromScale(0.39, 0.31),
			ZIndex = 18,
		}, itemChildren),
		Info = if category ~= "Weapon" then e("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.63, 0.75),
			Size = UDim2.fromScale(0.31, 0.12),
			ZIndex = 20,
		}, {
			Tag = e("TextLabel", {
				BackgroundColor3 = Color3.fromRGB(18, 26, 80),
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0, 0.04),
				Size = UDim2.fromScale(0.14, 0.25),
				Text = "Info",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				ZIndex = 21,
			}),
			Description = e("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.16, 0),
				Size = UDim2.fromScale(0.84, 1),
				Text = selectedMeta.description or "Select an item to see details.",
				TextColor3 = Color3.fromRGB(230, 230, 230),
				TextScaled = true,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				ZIndex = 21,
			}),
		}) else nil,
		EquippedReadout = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromScale(0.62, 0.88),
			Size = UDim2.fromScale(0.34, 0.05),
			Text = "Weapon " .. tostring(equippedWeapon) .. "   Skin " .. tostring(equippedSkin),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 20,
		}),
		Confirm = e("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromScale(0.73, 0.94),
			Size = UDim2.fromScale(0.13, 0.045),
			Text = "Confirm",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			ZIndex = 25,
			[React.Event.Activated] = confirmSelection,
		}),
		Back = e("TextButton", {
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromScale(0.86, 0.94),
			Size = UDim2.fromScale(0.1, 0.045),
			Text = "Back",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			ZIndex = 25,
			[React.Event.Activated] = function()
				setVisible(false)
			end,
		}),
		SlotHint = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromScale(0.74, 0.33),
			Size = UDim2.fromScale(0.2, 0.05),
			Text = if category == "Skill" then "TARGET SLOT " .. selectedSlot else "EQUIP DIRECT",
			TextColor3 = Color3.fromRGB(255, 255, 0),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 20,
		}),
		HitIndicators = e(HitIndicatorLayer, {
			Indicators = hitIndicators,
		}),
		DamageDirections = e(DamageDirectionLayer, {
			Indicators = damageTakenIndicators,
		}),
	})
end

return InventoryView
