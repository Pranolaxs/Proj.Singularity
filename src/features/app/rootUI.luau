local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))

local e = React.createElement

local PLAYER_NAME = "Alice"
local ARCANA = "Death"
local HIT_RANDOM = Random.new()
local HIT_SOUND_ID = "rbxasset://sounds/swordslash.wav"

local SKILL_META = {
	Hook = {
		cost = 3,
		color = Color3.fromRGB(160, 0, 255),
		icon = "rbxassetid://71833534900512",
		description = "Launches your weapon forward and pulls 1 foe to your current position.",
	},
	Dash = {
		cost = 4,
		color = Color3.fromRGB(0, 220, 255),
		icon = "rbxassetid://111690592544646",
		description = "Bursts in the chosen direction. Reduces downtime after clean movement.",
	},
	Push = {
		cost = 6,
		color = Color3.fromRGB(255, 70, 60),
		icon = "rbxassetid://93847486089506",
		description = "After a short windup, pushes enemies in front of you.",
	},
	Repel = {
		cost = 8,
		color = Color3.fromRGB(255, 220, 35),
		icon = "rbxassetid://103963230014073",
		description = "Breaks pull and knockback pressure around you.",
	},
	Ghost = {
		cost = 10,
		color = Color3.fromRGB(90, 255, 150),
		icon = "rbxassetid://112885944680569",
		description = "Phases briefly, lowering collision pressure and visibility.",
	},
}

local WEAPON_META = {
	KnockbackStick = {
		cost = 0,
		color = Color3.fromRGB(255, 190, 40),
		description = "Reliable starter weapon with a quick swing and steady knockback pressure.",
		hitDamage = 25,
		hitCooldown = 0.5,
	},
	Scythe = {
		cost = 0,
		color = Color3.fromRGB(180, 240, 255),
		description = "Wide sweeping weapon with heavier timing and strong reach control.",
		hitDamage = 25,
		hitCooldown = 0.5,
	},
}

local SKIN_META = {
	Default = {
		cost = 0,
		color = Color3.fromRGB(80, 180, 255),
		description = "Default hook skin.",
	},
	NeonRuin = {
		cost = 0,
		color = Color3.fromRGB(255, 40, 190),
		description = "High contrast neon hook skin.",
	},
}

local CATEGORY_CONFIG = {
	Skill = {
		title = "SELECT SKILL",
		listAttribute = "SkillInventoryData",
		fallback = { "Hook", "Dash", "Push", "Repel", "Ghost" },
		meta = SKILL_META,
	},
	Weapon = {
		title = "SELECT WEAPON",
		listAttribute = "WeaponInventoryData",
		fallback = { "KnockbackStick", "Scythe" },
		meta = WEAPON_META,
	},
	Skin = {
		title = "SELECT SKIN",
		listAttribute = "InventoryData",
		fallback = { "Default", "NeonRuin" },
		meta = SKIN_META,
	},
}

local SLOT_ATTRIBUTES = {
	Q = "EquippedSkill_Q",
	E = "EquippedSkill_E",
	R = "EquippedSkill_R",
	F = "EquippedSkill_F",
}

local HUD_SLOTS = {
	{
		slot = "Q",
		position = UDim2.fromOffset(10, 64),
		rotation = -8,
	},
	{
		slot = "E",
		position = UDim2.fromOffset(88, 18),
		rotation = -4,
	},
	{
		slot = "R",
		position = UDim2.fromOffset(104, 104),
		rotation = 4,
	},
	{
		slot = "F",
		position = UDim2.fromOffset(182, 60),
		rotation = 8,
	},
}

local STAMINA_SEGMENTS = 20

local function splitList(value: string?, fallback: { string }): { string }
	if not value or value == "" then
		return table.clone(fallback)
	end

	local result = {}
	for item in string.gmatch(value, "([^,]+)") do
		table.insert(result, item)
	end

	if #result == 0 then
		return table.clone(fallback)
	end

	return result
end

local function makeChildren(children: { any }): { [string]: any }
	local result = {}
	for index, child in ipairs(children) do
		result[tostring(index)] = child
	end
	return result
end

local function playLocalHitSound(volume: number, playbackSpeed: number)
	local sound = Instance.new("Sound")
	sound.Name = "HitFeedbackSound"
	sound.SoundId = HIT_SOUND_ID
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed
	sound.Parent = SoundService
	SoundService:PlayLocalSound(sound)
	Debris:AddItem(sound, 1.2)
end

local function safeClamp(value: number, minimum: number, maximum: number): number
	if maximum < minimum then
		return (minimum + maximum) / 2
	end

	return math.clamp(value, minimum, maximum)
end

local function getHitScreenPlacement(targetPosition: Vector3?, stackIndex: number?)
	local camera = Workspace.CurrentCamera
	if not camera or not targetPosition then
		return Vector2.new(camera and camera.ViewportSize.X * 0.58 or 960, camera and camera.ViewportSize.Y * 0.42 or 360), 0.62
	end

	local viewportPoint = camera:WorldToViewportPoint(targetPosition)
	local viewportSize = camera.ViewportSize
	local distance = (camera.CFrame.Position - targetPosition).Magnitude
	local scale = math.clamp(1 - ((distance - 14) / 115) * 0.42, 0.56, 0.92)
	local x = viewportPoint.X + 92 * scale
	local y = viewportPoint.Y - (22 + (stackIndex or 0) * 42) * scale

	if viewportPoint.Z < 0 then
		x = viewportSize.X * 0.62
		y = viewportSize.Y * 0.42
	end

	x = safeClamp(x, 86, viewportSize.X - 86)
	y = safeClamp(y, 68, viewportSize.Y - 68)

	return Vector2.new(x, y), scale
end

local function getDamageDirectionPlacement(payload)
	local camera = Workspace.CurrentCamera
	if not camera then
		return UDim2.fromScale(0.5, 0.34), 0
	end

	local viewportSize = camera.ViewportSize
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local center = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
	local sourcePosition = payload.sourcePosition

	if typeof(sourcePosition) == "Vector3" and root and root:IsA("BasePart") then
		local rootViewport = camera:WorldToViewportPoint(root.Position)
		local sourceViewport = camera:WorldToViewportPoint(sourcePosition)
		if rootViewport.Z > 0 and sourceViewport.Z > 0 then
			center = Vector2.new(rootViewport.X, rootViewport.Y)
			local delta = Vector2.new(sourceViewport.X, sourceViewport.Y) - center
			if delta.Magnitude > 0.01 then
				local unit = delta.Unit
				local radius = math.min(viewportSize.X, viewportSize.Y) * 0.28
				local x = safeClamp(center.X + unit.X * radius, 64, viewportSize.X - 64)
				local y = safeClamp(center.Y + unit.Y * radius, 64, viewportSize.Y - 64)
				return UDim2.fromOffset(x, y), math.deg(math.atan2(unit.Y, unit.X))
			end
		end
	end

	local direction = payload.attackDirection
	if typeof(direction) ~= "Vector3" or direction.Magnitude <= 0.01 then
		direction = camera.CFrame.LookVector
	end
	local localDirection = camera.CFrame:VectorToObjectSpace(direction.Unit)
	local screenDirection = Vector2.new(localDirection.X, -localDirection.Z)
	if screenDirection.Magnitude <= 0.01 then
		screenDirection = Vector2.new(1, 0)
	else
		screenDirection = screenDirection.Unit
	end
	local radius = math.min(viewportSize.X, viewportSize.Y) * 0.28
	local x = safeClamp(center.X + screenDirection.X * radius, 64, viewportSize.X - 64)
	local y = safeClamp(center.Y + screenDirection.Y * radius, 64, viewportSize.Y - 64)

	return UDim2.fromOffset(x, y), math.deg(math.atan2(screenDirection.Y, screenDirection.X))
end

local function useAttribute(player: Player, attributeName: string, fallback)
	local value, setValue = React.useState(player:GetAttribute(attributeName) or fallback)

	React.useEffect(function()
		local function refresh()
			local nextValue = player:GetAttribute(attributeName)
			if nextValue == nil then
				nextValue = fallback
			end
			setValue(nextValue)
		end

		refresh()
		local connection = player:GetAttributeChangedSignal(attributeName):Connect(refresh)
		return function()
			connection:Disconnect()
		end
	end, { player, attributeName, fallback })

	return value
end

local function useToggle(defaultValue: boolean)
	local visible, setVisible = React.useState(defaultValue)

	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end

			if input.KeyCode == Enum.KeyCode.I or input.KeyCode == Enum.KeyCode.B then
				setVisible(function(current)
					return not current
				end)
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	return visible, setVisible
end

local function calculateViewportScale(): number
	local camera = Workspace.CurrentCamera
	local viewportSize = if camera then camera.ViewportSize else Vector2.new(1366, 768)
	local scale = math.min(viewportSize.X / 1366, viewportSize.Y / 768)
	return math.clamp(scale, 0.72, 1.12)
end

local function useViewportScale()
	local scale, setScale = React.useState(calculateViewportScale())

	React.useEffect(function()
		local lastScale = scale
		local connection = RunService.RenderStepped:Connect(function()
			local nextScale = calculateViewportScale()
			if math.abs(nextScale - lastScale) > 0.01 then
				lastScale = nextScale
				setScale(nextScale)
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	return scale
end

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function useGameplayProjection(player: Player, viewportScale: number)
	local projection, setProjection = React.useState({
		hudPosition = UDim2.fromScale(0.58, 0.64),
		staminaPosition = UDim2.fromScale(0.42, 0.52),
		scale = viewportScale,
	})

	React.useEffect(function()
		local lastX = -1
		local lastY = -1
		local lastScale = -1

		local connection = RunService.RenderStepped:Connect(function()
			local camera = Workspace.CurrentCamera
			if not camera then
				return
			end

			local viewportSize = camera.ViewportSize
			local root = getCharacterRoot(player)
			local hudX = viewportSize.X - 230 * viewportScale
			local hudY = viewportSize.Y - 185 * viewportScale
			local staminaX = 118 * viewportScale
			local staminaY = viewportSize.Y * 0.54
			local distanceScale = viewportScale

			if root then
				local lowerPoint = root.Position + Vector3.new(0, -1.75, 0)
				local centerPoint = root.Position + Vector3.new(0, 0.3, 0)
				local lowerViewport = camera:WorldToViewportPoint(lowerPoint)
				local centerViewport = camera:WorldToViewportPoint(centerPoint)
				local distance = (camera.CFrame.Position - root.Position).Magnitude

				distanceScale = math.clamp(1 - ((distance - 14) / 120) * 0.25, 0.78, 1.05) * viewportScale

				if lowerViewport.Z > 0 then
					hudX = lowerViewport.X + 118 * distanceScale
					hudY = lowerViewport.Y + 34 * distanceScale
					hudX = safeClamp(hudX, 160 * distanceScale, viewportSize.X - 155 * distanceScale)
					hudY = safeClamp(hudY, 170 * distanceScale, viewportSize.Y - 78 * distanceScale)
				end

				if centerViewport.Z > 0 then
					staminaX = centerViewport.X - 118 * distanceScale
					staminaY = centerViewport.Y + 4 * distanceScale
					staminaX = safeClamp(staminaX, 52 * distanceScale, viewportSize.X - 70 * distanceScale)
					staminaY = safeClamp(staminaY, 130 * distanceScale, viewportSize.Y - 126 * distanceScale)
				end
			end

			if math.abs(hudX - lastX) > 1 or math.abs(hudY - lastY) > 1 or math.abs(distanceScale - lastScale) > 0.01 then
				lastX = hudX
				lastY = hudY
				lastScale = distanceScale
				setProjection({
					hudPosition = UDim2.fromOffset(hudX, hudY),
					staminaPosition = UDim2.fromOffset(staminaX, staminaY),
					scale = distanceScale,
				})
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, { player, viewportScale })

	return projection
end

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

local function CostBadge(props)
	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = props.Position,
		Size = props.Size or UDim2.fromOffset(118, 34),
		ZIndex = props.ZIndex or 20,
	}, {
		Cost = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Arcade,
			Position = UDim2.fromScale(0.08, 0),
			Size = UDim2.fromScale(0.54, 1),
			Text = tostring(props.Cost or 0),
			TextColor3 = Color3.fromRGB(255, 255, 0),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = (props.ZIndex or 20) + 1,
		}),
		SP = e("TextLabel", {
			BackgroundColor3 = Color3.fromRGB(255, 240, 20),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromScale(0.66, 0.12),
			Rotation = -12,
			Size = UDim2.fromScale(0.32, 0.76),
			Text = "SP",
			TextColor3 = Color3.fromRGB(0, 0, 0),
			TextScaled = true,
			ZIndex = (props.ZIndex or 20) + 1,
		}),
	})
end

local function SlotRow(props)
	local filled = props.Value and props.Value ~= ""
	return e("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = if props.Selected then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(42, 48, 104),
		BackgroundTransparency = if props.Selected then 0 else 0.05,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, 50),
		Text = "",
		ZIndex = 15,
		[React.Event.Activated] = props.OnActivated,
	}, {
		Key = e("TextLabel", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(48, 34),
			Text = props.Slot,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			ZIndex = 16,
		}),
		Name = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(68, 2),
			Size = UDim2.new(1, -116, 1, -4),
			Text = filled and props.Value or "-----",
			TextColor3 = if props.Selected then Color3.fromRGB(0, 0, 0) else Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 16,
		}),
		Check = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.new(1, -48, 0, 0),
			Size = UDim2.fromOffset(42, 50),
			Text = if filled then ">" else "",
			TextColor3 = Color3.fromRGB(0, 220, 255),
			TextScaled = true,
			ZIndex = 16,
		}),
	})
end

local function ItemRow(props)
	local meta = props.Meta or {}
	return e("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = if props.Selected then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = if props.Selected then 0 else 0.55,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, -28, 0, 56),
		Text = "",
		ZIndex = 18,
		[React.Event.Activated] = props.OnActivated,
	}, {
		ColorSlash = e("Frame", {
			BackgroundColor3 = meta.color or Color3.fromRGB(0, 220, 255),
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(14, 12),
			Rotation = -12,
			Size = UDim2.fromOffset(84, 28),
			ZIndex = 19,
		}),
		Icon = e("ImageLabel", {
			BackgroundTransparency = 1,
			Image = meta.icon or "",
			Position = UDim2.fromOffset(18, 6),
			Size = UDim2.fromOffset(48, 48),
			ZIndex = 20,
		}),
		Name = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Position = UDim2.fromOffset(104, 0),
			Size = UDim2.new(1, -250, 1, 0),
			Text = props.Name,
			TextColor3 = if props.Selected then Color3.fromRGB(0, 0, 0) else Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 20,
		}),
		Cost = e(CostBadge, {
			Cost = meta.cost or 0,
			Position = UDim2.new(1, -138, 0.5, -17),
			Size = UDim2.fromOffset(112, 34),
			ZIndex = 21,
		}),
	})
end

local function CategoryButton(props)
	return e("TextButton", {
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromOffset(138, 48),
		Text = props.Text,
		TextColor3 = if props.Selected then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(0, 245, 255),
		TextScaled = true,
		Font = Enum.Font.GothamBlack,
		ZIndex = 20,
		[React.Event.Activated] = props.OnActivated,
	}, {
		Line = e("Frame", {
			BackgroundColor3 = if props.Selected then Color3.fromRGB(255, 0, 70) else Color3.fromRGB(0, 245, 255),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 1, -5),
			Size = UDim2.new(1, 0, 0, 5),
			ZIndex = 19,
		}),
	})
end

local function useHitIndicators()
	local indicators, setIndicators = React.useState({})

	React.useEffect(function()
		local remote = ReplicatedStorage:WaitForChild("HitIndicatorEvent", 10)
		if not remote or not remote:IsA("RemoteEvent") then
			return function() end
		end

		local connection = remote.OnClientEvent:Connect(function(payload)
			payload = if type(payload) == "table" then payload else {}
			playLocalHitSound(0.28, HIT_RANDOM:NextNumber(0.95, 1.08))

			local id = tostring(os.clock()) .. "-" .. tostring(HIT_RANDOM:NextInteger(1000, 9999))
			local targetName = payload.targetName or "Target"

			setIndicators(function(current)
				local nextIndicators = table.clone(current)
				local stackIndex = 0
				for _, item in ipairs(nextIndicators) do
					if item.targetName == targetName then
						stackIndex += 1
					end
				end

				local screenPosition, scale = getHitScreenPlacement(payload.targetPosition, stackIndex)
				local indicator = {
					id = id,
					targetName = targetName,
					text = payload.text or "HIT!",
					damage = payload.damage or 0,
					totalDamage = payload.totalDamage or 0,
					position = screenPosition,
					scale = scale,
					rotation = HIT_RANDOM:NextInteger(-5, 3),
				}

				table.insert(nextIndicators, indicator)
				if #nextIndicators > 5 then
					table.remove(nextIndicators, 1)
				end
				return nextIndicators
			end)

			task.delay(0.82, function()
				setIndicators(function(current)
					local nextIndicators = {}
					for _, item in ipairs(current) do
						if item.id ~= id then
							table.insert(nextIndicators, item)
						end
					end
					return nextIndicators
				end)
			end)
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	return indicators
end

local function useDamageTakenIndicators()
	local indicators, setIndicators = React.useState({})

	React.useEffect(function()
		local remote = ReplicatedStorage:WaitForChild("DamageTakenIndicatorEvent", 10)
		if not remote or not remote:IsA("RemoteEvent") then
			return function() end
		end

		local connection = remote.OnClientEvent:Connect(function(payload)
			payload = if type(payload) == "table" then payload else {}
			local position, rotation = getDamageDirectionPlacement(payload)
			playLocalHitSound(0.36, HIT_RANDOM:NextNumber(0.82, 0.96))

			local id = tostring(os.clock()) .. "-damage-" .. tostring(HIT_RANDOM:NextInteger(1000, 9999))
			local indicator = {
				id = id,
				position = position,
				rotation = rotation,
			}

			setIndicators(function(current)
				local nextIndicators = table.clone(current)
				table.insert(nextIndicators, indicator)
				if #nextIndicators > 3 then
					table.remove(nextIndicators, 1)
				end
				return nextIndicators
			end)

			task.delay(0.56, function()
				setIndicators(function(current)
					local nextIndicators = {}
					for _, item in ipairs(current) do
						if item.id ~= id then
							table.insert(nextIndicators, item)
						end
					end
					return nextIndicators
				end)
			end)
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	return indicators
end

local function HitIndicatorLayer(props)
	local children = {}

	for index, indicator in ipairs(props.Indicators or {}) do
		local baseZ = 900 + index * 10
		local accentColor = if indicator.text == "WEAK!" then Color3.fromRGB(170, 255, 255) else Color3.fromRGB(75, 255, 255)
		local shadowColor = if indicator.text == "WEAK!" then Color3.fromRGB(105, 80, 255) else Color3.fromRGB(255, 45, 175)
		local scale = indicator.scale or 0.64
		local size = Vector2.new(188 * scale, 74 * scale)
		local position = indicator.position or Vector2.new(0, 0)

		local particleChildren = {}
		for particleIndex = 1, 5 do
			local side = if particleIndex % 2 == 0 then 1 else -1
			particleChildren["Particle" .. particleIndex] = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = if particleIndex % 3 == 0 then Color3.fromRGB(255, 255, 255) else shadowColor,
				BorderSizePixel = 0,
				Position = UDim2.new(0.5, side * (22 + particleIndex * 7) * scale, 0.5, (-18 + particleIndex * 7) * scale),
				Rotation = -28 + particleIndex * 17,
				Size = UDim2.fromOffset((18 + particleIndex * 2) * scale, math.max(2, 4 * scale)),
				ZIndex = baseZ + 1,
			})
		end

		children[indicator.id] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(position.X, position.Y),
			Rotation = indicator.rotation,
			Size = UDim2.fromOffset(size.X, size.Y),
			ZIndex = baseZ,
		}, {
			Particles = e("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = baseZ,
			}, particleChildren),
			BackText = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.51, 0.54),
				Rotation = -8,
				Size = UDim2.fromScale(0.9, 0.78),
				Text = indicator.text,
				TextColor3 = Color3.fromRGB(0, 0, 80),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
				TextStrokeTransparency = 0,
				ZIndex = baseZ + 1,
			}),
			MainText = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.48, 0.48),
				Rotation = -8,
				Size = UDim2.fromScale(0.9, 0.78),
				Text = indicator.text,
				TextColor3 = accentColor,
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(255, 255, 255),
				TextStrokeTransparency = 0.1,
				ZIndex = baseZ + 2,
			}),
			Damage = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.15,
				BorderSizePixel = 0,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.74, 0.83),
				Rotation = -8,
				Size = UDim2.fromScale(0.5, 0.26),
				Text = "+" .. tostring(indicator.damage) .. "%  / " .. tostring(indicator.totalDamage) .. "%",
				TextColor3 = Color3.fromRGB(255, 255, 0),
				TextScaled = true,
				ZIndex = baseZ + 3,
			}),
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 900,
	}, children)
end

local function DamageDirectionLayer(props)
	local children = {}

	for index, indicator in ipairs(props.Indicators or {}) do
		local baseZ = 840 + index * 6
		children[indicator.id] = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = indicator.position,
			Rotation = indicator.rotation,
			Size = UDim2.fromOffset(96, 96),
			ZIndex = baseZ,
		}, {
			Glow = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
				Text = ")",
				TextColor3 = Color3.fromRGB(255, 0, 35),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(255, 255, 255),
				TextStrokeTransparency = 0.18,
				TextTransparency = 0.08,
				ZIndex = baseZ + 1,
			}),
			Core = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Position = UDim2.fromScale(0.45, 0.5),
				Size = UDim2.fromScale(0.72, 0.72),
				Text = ")",
				TextColor3 = Color3.fromRGB(255, 245, 245),
				TextScaled = true,
				TextStrokeColor3 = Color3.fromRGB(170, 0, 25),
				TextStrokeTransparency = 0.2,
				ZIndex = baseZ + 2,
			}),
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 840,
	}, children)
end

local function CooldownMask(props)
	local ratio = math.clamp(props.Ratio or 0, 0, 1)
	if ratio <= 0 then
		return nil
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.ZIndex,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		Shade = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromScale(1, ratio),
			ZIndex = props.ZIndex,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
	})
end

local function SkillCommandButton(props)
	local meta = SKILL_META[props.SkillName] or {}
	local cooldownTotal = props.CooldownTotal or 0
	local cooldownRemaining = props.CooldownRemaining or 0
	local cooldownRatio = if cooldownTotal > 0 then cooldownRemaining / cooldownTotal else 0
	local isCoolingDown = cooldownRemaining > 0.05
	local icon = props.Icon ~= "" and props.Icon or meta.icon or ""
	local color = meta.color or Color3.fromRGB(0, 210, 255)

	return e("Frame", {
		BackgroundTransparency = 1,
		Position = props.Position,
		Rotation = props.Rotation,
		Size = UDim2.fromOffset(84, 84),
		ZIndex = 62,
	}, {
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
				Color = Color3.fromRGB(255, 255, 255),
				Thickness = 3,
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
				ImageColor3 = if isCoolingDown then Color3.fromRGB(130, 130, 130) else Color3.fromRGB(255, 255, 255),
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

local function WeaponMeshPreview(props)
	local viewportRef = React.useRef(nil)
	local modelRef = React.useRef(nil)
	local centerOffsetRef = React.useRef(CFrame.identity)
	local draggingRef = React.useRef(false)
	local lastInputXRef = React.useRef(0)
	local yaw, setYaw = React.useState(0)

	React.useEffect(function()
		local viewport = viewportRef.current
		if not viewport then
			return function() end
		end

		viewport:ClearAllChildren()
		modelRef.current = nil

		local previewFolder = ReplicatedStorage:FindFirstChild("WeaponPreviewModels")
		local source = previewFolder and previewFolder:FindFirstChild(props.WeaponName)
		if not source then
			return function() end
		end

		local world = Instance.new("WorldModel")
		world.Parent = viewport

		local model = source:Clone()
		model.Parent = world
		model:PivotTo(CFrame.identity)

		local boundsCFrame, size = model:GetBoundingBox()
		centerOffsetRef.current = CFrame.new(-boundsCFrame.Position)
		model:PivotTo(
			(props.BaseRotation or CFrame.Angles(math.rad(-8), math.rad(-36), math.rad(54)))
				* CFrame.Angles(0, math.rad(yaw), 0)
				* centerOffsetRef.current
		)
		modelRef.current = model

		local _, centeredSize = model:GetBoundingBox()
		size = centeredSize
		local maxSize = math.max(size.X, size.Y, size.Z, 1)

		local camera = Instance.new("Camera")
		camera.FieldOfView = 32
		camera.CFrame = CFrame.lookAt(Vector3.new(0, maxSize * 0.03, maxSize * 2), Vector3.new(0, 0, 0))
		camera.Parent = viewport
		viewport.CurrentCamera = camera

		return function()
			if viewport then
				viewport:ClearAllChildren()
			end
			modelRef.current = nil
		end
	end, { props.WeaponName, props.BaseRotation })

	React.useEffect(function()
		local model = modelRef.current
		if model then
			model:PivotTo(
				(props.BaseRotation or CFrame.Angles(math.rad(-8), math.rad(-36), math.rad(54)))
					* CFrame.Angles(0, math.rad(yaw), 0)
					* centerOffsetRef.current
			)
		end
	end, { yaw, props.BaseRotation })

	React.useEffect(function()
		local changedConnection = UserInputService.InputChanged:Connect(function(input)
			if not draggingRef.current then
				return
			end

			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			local nextX = input.Position.X
			local delta = nextX - lastInputXRef.current
			lastInputXRef.current = nextX
			setYaw(function(current)
				return current + delta * 0.5
			end)
		end)

		local endedConnection = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				draggingRef.current = false
			end
		end)

		return function()
			changedConnection:Disconnect()
			endedConnection:Disconnect()
		end
	end, {})

	return e("ViewportFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(40, 180, 255),
		LightColor = Color3.fromRGB(180, 255, 255),
		LightDirection = Vector3.new(-0.4, -0.7, -0.3),
		Position = props.Position,
		Rotation = props.Rotation or -6,
		Size = props.Size,
		ZIndex = props.ZIndex or 16,
		ref = viewportRef,
		[React.Event.InputBegan] = function(_, input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end

			draggingRef.current = true
			lastInputXRef.current = input.Position.X
		end,
	}, {
		Stroke = if props.ShowStroke then e("UIStroke", {
			Color = Color3.fromRGB(110, 255, 255),
			Thickness = 4,
			Transparency = 0,
		}) else nil,
	})
end

local function RootUI()
	local player = Players.LocalPlayer
	local viewportScale = useViewportScale()
	local projection = useGameplayProjection(player, viewportScale)
	local visible, setVisible = useToggle(false)
	local hitIndicators = useHitIndicators()
	local damageTakenIndicators = useDamageTakenIndicators()
	local category, setCategory = React.useState("Skill")
	local selectedSlot, setSelectedSlot = React.useState("E")
	local selectedItem, setSelectedItem = React.useState("")

	local skillListData = useAttribute(player, "SkillInventoryData", "")
	local weaponListData = useAttribute(player, "WeaponInventoryData", "")
	local skinListData = useAttribute(player, "InventoryData", "")
	local equippedWeapon = useAttribute(player, "EquippedWeapon", "KnockbackStick")
	local equippedSkin = useAttribute(player, "EquippedHookSkin", "Default")
	local equippedQ = useAttribute(player, "EquippedSkill_Q", "Hook")
	local equippedE = useAttribute(player, "EquippedSkill_E", "Dash")
	local equippedR = useAttribute(player, "EquippedSkill_R", "Push")
	local equippedF = useAttribute(player, "EquippedSkill_F", "Repel")
	local staminaPercent = useAttribute(player, "StaminaPercent", 100)
	local isStaminaExhausted = useAttribute(player, "IsStaminaExhausted", false)
	local cooldownQ = useAttribute(player, "SkillCooldown_Q_Remaining", 0)
	local cooldownE = useAttribute(player, "SkillCooldown_E_Remaining", 0)
	local cooldownR = useAttribute(player, "SkillCooldown_R_Remaining", 0)
	local cooldownF = useAttribute(player, "SkillCooldown_F_Remaining", 0)
	local cooldownTotalQ = useAttribute(player, "SkillCooldown_Q_Total", 0)
	local cooldownTotalE = useAttribute(player, "SkillCooldown_E_Total", 0)
	local cooldownTotalR = useAttribute(player, "SkillCooldown_R_Total", 0)
	local cooldownTotalF = useAttribute(player, "SkillCooldown_F_Total", 0)
	local iconQ = useAttribute(player, "SkillHud_Q_Icon", "")
	local iconE = useAttribute(player, "SkillHud_E_Icon", "")
	local iconR = useAttribute(player, "SkillHud_R_Icon", "")
	local iconF = useAttribute(player, "SkillHud_F_Icon", "")

	local listData = {
		Skill = skillListData,
		Weapon = weaponListData,
		Skin = skinListData,
	}

	local equippedSkills = {
		Q = equippedQ,
		E = equippedE,
		R = equippedR,
		F = equippedF,
	}

	local gameplaySkills = {
		Q = {
			name = equippedQ,
			icon = iconQ,
			remaining = cooldownQ,
			total = cooldownTotalQ,
		},
		E = {
			name = equippedE,
			icon = iconE,
			remaining = cooldownE,
			total = cooldownTotalE,
		},
		R = {
			name = equippedR,
			icon = iconR,
			remaining = cooldownR,
			total = cooldownTotalR,
		},
		F = {
			name = equippedF,
			icon = iconF,
			remaining = cooldownF,
			total = cooldownTotalF,
		},
	}

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
				BaseRotation = if selectedName == "Scythe" then CFrame.Angles(math.rad(-6), math.rad(30), math.rad(-48)) else CFrame.Angles(math.rad(-8), math.rad(-36), math.rad(54)),
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

	if not visible then
		return e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Gameplay = e(GameplayHud, {
				Projection = projection,
				Skills = gameplaySkills,
				StaminaPercent = staminaPercent,
				IsStaminaExhausted = isStaminaExhausted,
			}),
			HitIndicators = e(HitIndicatorLayer, {
				Indicators = hitIndicators,
			}),
			DamageDirections = e(DamageDirectionLayer, {
				Indicators = damageTakenIndicators,
			}),
			Hint = e("TextLabel", {
				AnchorPoint = Vector2.new(1, 1),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.new(1, -24, 1, -18),
				Size = UDim2.fromOffset(250, 28),
				Text = "I / B Inventory",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				TextTransparency = 0.35,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 50,
			}),
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

return RootUI
