local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local InventoryServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InventoryService"):WaitForChild("InventoryServiceUtils"))
local DamageUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DamageCalcService"):WaitForChild("DamageCalcServiceUtils"))
local WeaponRegistry = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("WeaponRegistry"))
local DataServiceServer = require(ServerScriptService:WaitForChild("Services"):WaitForChild("DataService"):WaitForChild("DataServiceServer"))
local WeaponFactory = require(script.Parent:WaitForChild("WeaponFactory"))

local InventoryServiceServer = {}
export type InventoryServiceServer = typeof(InventoryServiceServer) & {}

local DEFAULT_SKINS = { "Default", "NeonRuin" }
local DEFAULT_SKILLS = { "Dash", "Ghost", "Hook", "Push", "Repel", "Cloak", "LivingShadow" }
local DEFAULT_WEAPONS = WeaponRegistry.listIds()
local initialized = false

local function waitForAttribute(player: Player, attributeName: string, timeout: number)
	local value = player:GetAttribute(attributeName)
	if value ~= nil then
		return value
	end

	local started = os.clock()
	while os.clock() - started < timeout do
		player:GetAttributeChangedSignal(attributeName):Wait()
		value = player:GetAttribute(attributeName)
		if value ~= nil then
			return value
		end
	end

	return nil
end

local function getOrCreateRemote(name: string): RemoteEvent
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end

	return remote :: RemoteEvent
end

local function clearTools(player: Player, character: Model?)
	if character then
		for _, item in ipairs(character:GetChildren()) do
			if item:IsA("Tool") then
				item:Destroy()
			end
		end
	end

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if item:IsA("Tool") then
				item:Destroy()
			end
		end
	end
end

local function getWeaponConfig(tool: Tool)
	return WeaponRegistry.getOrDefault(tool.Name)
end

local function findWeaponVisual(tool: Tool, config): Instance?
	local visualName = config.VisualName or tool.Name

	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant.Name == visualName and (descendant:IsA("BasePart") or descendant:IsA("Model")) and descendant.Name ~= "Handle" then
			return descendant
		end
	end

	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("MeshPart") and descendant.Name ~= "Handle" then
			return descendant
		end
	end

	return tool:FindFirstChild("Handle")
end

local function preparePreviewClone(instance: Instance)
	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end
end

local function publishWeaponPreviewModels()
	local folder = ReplicatedStorage:FindFirstChild("WeaponPreviewModels")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WeaponPreviewModels"
		folder.Parent = ReplicatedStorage
	end

	folder:ClearAllChildren()

	local weaponFolder = ServerStorage:FindFirstChild("WeaponInventory")
	if not weaponFolder then
		return
	end

	for _, weaponName in ipairs(WeaponRegistry.listIds()) do
		local config = WeaponRegistry.get(weaponName)
		local weapon = if config then weaponFolder:FindFirstChild(config.ModelName) else nil
		if weapon and weapon:IsA("Tool") then
			local config = getWeaponConfig(weapon)
			local visual = findWeaponVisual(weapon, config)
			if visual then
				local model = Instance.new("Model")
				model.Name = weaponName

				local clone = visual:Clone()
				clone.Name = "PreviewVisual"
				clone.Parent = model
				preparePreviewClone(model)

				if clone:IsA("BasePart") then
					model.PrimaryPart = clone
				elseif clone:IsA("Model") then
					model.PrimaryPart = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
				end

				model.Parent = folder
			end
		end
	end
end

local function bindWeapon(player: Player, tool: Tool)
	if tool:GetAttribute("InventoryServiceBound") then
		return
	end
	tool:SetAttribute("InventoryServiceBound", true)

	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end

	local config = getWeaponConfig(tool)
	local debounce = {}
	local swingTrack: AnimationTrack? = nil
	local idleTrack: AnimationTrack? = nil
	local isSwinging = false
	local swingHitCharacters = {}

	tool.Equipped:Connect(function()
		local visualModel = tool:FindFirstChild(config.VisualName, true)
		if visualModel and visualModel:IsA("BasePart") then
			local weld = handle:FindFirstChild("WeaponWeld") or Instance.new("WeldConstraint")
			weld.Name = "WeaponWeld"
			weld.Part0 = handle
			weld.Part1 = visualModel
			weld.Parent = handle
			visualModel.Transparency = 0
		end

		local character = tool.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			return
		end

		local swingAnim = tool:FindFirstChild("SwingAnim")
		if swingAnim and swingAnim:IsA("Animation") then
			swingTrack = animator:LoadAnimation(swingAnim)
			swingTrack.Priority = Enum.AnimationPriority.Action
		end

		local idleAnim = tool:FindFirstChild("IdleAnim")
		if idleAnim and idleAnim:IsA("Animation") then
			idleTrack = animator:LoadAnimation(idleAnim)
			idleTrack.Looped = true
			idleTrack.Priority = Enum.AnimationPriority.Action
			task.delay(0.1, function()
				if tool.Parent == character and idleTrack then
					idleTrack:Play()
				end
			end)
		end
	end)

	tool.Unequipped:Connect(function()
		isSwinging = false
		if swingTrack then
			swingTrack:Stop()
			swingTrack = nil
		end
		if idleTrack then
			idleTrack:Stop()
			idleTrack = nil
		end
	end)

	tool.Activated:Connect(function()
		if isSwinging then
			return
		end

		isSwinging = true
		table.clear(swingHitCharacters)
		local character = tool.Parent
		if character then
			character:SetAttribute("LastCombatTick", tick())
		end
		if swingTrack then
			swingTrack:Play()
		end

		task.delay(config.HitCooldown, function()
			isSwinging = false
		end)
	end)

	handle.Touched:Connect(function(hit)
		if not isSwinging then
			return
		end

		local targetCharacter = hit:FindFirstAncestorOfClass("Model")
		local attackerCharacter = tool.Parent
		if not targetCharacter or targetCharacter == attackerCharacter then
			return
		end

		local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
		local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
		local attackerRoot = attackerCharacter and attackerCharacter:FindFirstChild("HumanoidRootPart")
		if not targetHumanoid or not targetRoot or not attackerRoot or targetHumanoid.Health <= 0 then
			return
		end

		if debounce[targetCharacter] then
			return
		end
		if swingHitCharacters[targetCharacter] then
			return
		end
		swingHitCharacters[targetCharacter] = true

		debounce[targetCharacter] = true
		task.delay(config.HitCooldown, function()
			debounce[targetCharacter] = nil
		end)

		DamageUtils.tagCombat(targetCharacter, player.Name)
		if attackerCharacter then
			attackerCharacter:SetAttribute("LastCombatTick", tick())
		end

		local currentDamage = targetCharacter:GetAttribute("DamagePercent") or 0
		local pushDirection = Vector3.new(
			targetRoot.Position.X - attackerRoot.Position.X,
			0,
			targetRoot.Position.Z - attackerRoot.Position.Z
		).Unit

		targetHumanoid.PlatformStand = true

		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Velocity = DamageUtils.knockback(pushDirection, currentDamage, config.BaseKnockback, config.DamageMultiplier, 20 + currentDamage * 0.1)
		bodyVelocity.MaxForce = Vector3.new(100000, 100000, 100000)
		bodyVelocity.Parent = targetRoot

		local bodyGyro = Instance.new("BodyGyro")
		bodyGyro.MaxTorque = Vector3.new(400000, 400000, 400000)
		bodyGyro.CFrame = targetRoot.CFrame
		bodyGyro.Parent = targetRoot

		game.Debris:AddItem(bodyVelocity, 0.2)
		game.Debris:AddItem(bodyGyro, 0.5)
		DamageUtils.addDamage(targetCharacter, config.DamagePerHit)
		targetCharacter:SetAttribute("KnockbackImmunity", tick() + 0.4)

		task.delay(1, function()
			if targetCharacter.Parent and targetHumanoid.Health > 0 then
				targetHumanoid.PlatformStand = false
			end
		end)
	end)
end

local function equipWeapon(player: Player, weaponName: string): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChild("Backpack")
	local newWeapon = WeaponFactory.createWeapon(weaponName)

	if not character or not humanoid or not backpack or not newWeapon then
		warn("InventoryService: missing weapon " .. tostring(weaponName))
		return false
	end

	clearTools(player, character)

	bindWeapon(player, newWeapon)
	newWeapon.Parent = backpack
	humanoid:EquipTool(newWeapon)
	return true
end

function InventoryServiceServer.build()
	getOrCreateRemote("EquipWeaponEvent")
	getOrCreateRemote("ChangeSkinEvent")
	getOrCreateRemote("EquipInventoryItemEvent")
	publishWeaponPreviewModels()
	return InventoryServiceServer
end

function InventoryServiceServer.init()
	if initialized then
		return InventoryServiceServer
	end
	initialized = true
	InventoryServiceServer.build()

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			if not character:WaitForChild("Humanoid", 5) then
				return
			end

			task.delay(0.5, function()
				if player.Parent then
					local equippedWeapon = waitForAttribute(player, "EquippedWeapon", 10) or "KnockbackStick"
					equipWeapon(player, equippedWeapon)
				end
			end)
		end)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			task.spawn(function()
				local equippedWeapon = waitForAttribute(player, "EquippedWeapon", 10) or "KnockbackStick"
				equipWeapon(player, equippedWeapon)
			end)
		end
	end

	ReplicatedStorage.EquipWeaponEvent.OnServerEvent:Connect(function(player, weaponName)
		if typeof(weaponName) == "string" then
			equipWeapon(player, weaponName)
		end
	end)

	ReplicatedStorage.ChangeSkinEvent.OnServerEvent:Connect(function(player, requestedName)
		if typeof(requestedName) ~= "string" then
			return
		end

		local gameState = ReplicatedStorage:FindFirstChild("GameState")
		if gameState and gameState.Value == "PLAYING" then
			warn(player.Name .. " tried to change inventory while playing")
			return
		end

		local ownedSkins = InventoryServiceUtils.toList(player:GetAttribute("InventoryData"), DEFAULT_SKINS)
		local ownedSkills = InventoryServiceUtils.toList(player:GetAttribute("SkillInventoryData"), DEFAULT_SKILLS)
		local ownedWeapons = InventoryServiceUtils.toList(player:GetAttribute("WeaponInventoryData"), DEFAULT_WEAPONS)

		if table.find(ownedSkins, requestedName) then
			DataServiceServer.setValue(player, "EquippedHookSkin", requestedName)
		elseif table.find(ownedSkills, requestedName) then
			DataServiceServer.setValue(player, "EquippedSkill_E", requestedName)
		elseif table.find(ownedWeapons, requestedName) then
			DataServiceServer.setValue(player, "EquippedWeapon", requestedName)
			equipWeapon(player, requestedName)
		else
			warn(player.Name .. " tried to equip an unowned item: " .. requestedName)
		end
	end)

	ReplicatedStorage.EquipInventoryItemEvent.OnServerEvent:Connect(function(player, category, itemName, slotName)
		if typeof(category) ~= "string" or typeof(itemName) ~= "string" then
			return
		end

		local gameState = ReplicatedStorage:FindFirstChild("GameState")
		if gameState and gameState.Value == "PLAYING" then
			warn(player.Name .. " tried to change inventory while playing")
			return
		end

		local ownedSkins = InventoryServiceUtils.toList(player:GetAttribute("InventoryData"), DEFAULT_SKINS)
		local ownedSkills = InventoryServiceUtils.toList(player:GetAttribute("SkillInventoryData"), DEFAULT_SKILLS)
		local ownedWeapons = InventoryServiceUtils.toList(player:GetAttribute("WeaponInventoryData"), DEFAULT_WEAPONS)

		if category == "Skin" and table.find(ownedSkins, itemName) then
			DataServiceServer.setValue(player, "EquippedHookSkin", itemName)
		elseif category == "Weapon" and table.find(ownedWeapons, itemName) then
			DataServiceServer.setValue(player, "EquippedWeapon", itemName)
			equipWeapon(player, itemName)
		elseif category == "Skill" and table.find(ownedSkills, itemName) then
			local validSlots = {
				Q = "EquippedSkill_Q",
				E = "EquippedSkill_E",
				R = "EquippedSkill_R",
				F = "EquippedSkill_F",
			}
			local attributeName = validSlots[slotName] or "EquippedSkill_E"
			DataServiceServer.setValue(player, attributeName, itemName)
		else
			warn(player.Name .. " tried to equip an unowned item: " .. itemName)
		end
	end)

	return InventoryServiceServer
end

return InventoryServiceServer :: InventoryServiceServer
