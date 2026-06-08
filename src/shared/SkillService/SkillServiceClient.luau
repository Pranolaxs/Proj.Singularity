local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Networker = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networker"))

local SkillServiceClient = {}
export type SkillServiceClient = typeof(SkillServiceClient) & {}

local initialized = false
local activeSkills = {}
local attributeConnections = {}
local character: Model? = nil
local clientSkillsFolder = script.Parent:WaitForChild("ClientSkills")
local networker
local cooldownAccumulator = 0

local KEY_SLOTS = {
	[Enum.KeyCode.Q] = "Q",
	[Enum.KeyCode.E] = "E",
	[Enum.KeyCode.R] = "R",
	[Enum.KeyCode.F] = "F",
}

local function disconnectAttributeConnections()
	for _, connection in ipairs(attributeConnections) do
		connection:Disconnect()
	end
	table.clear(attributeConnections)
end

local function setSkillHudState(player: Player, keyCode: Enum.KeyCode, skillModule)
	local slot = KEY_SLOTS[keyCode]
	if not slot then
		return
	end

	if not skillModule then
		player:SetAttribute("SkillHud_" .. slot .. "_Name", "")
		player:SetAttribute("SkillHud_" .. slot .. "_Icon", "")
		player:SetAttribute("SkillCooldown_" .. slot .. "_Total", 0)
		player:SetAttribute("SkillCooldown_" .. slot .. "_Remaining", 0)
		return
	end

	player:SetAttribute("SkillHud_" .. slot .. "_Name", skillModule.SkillName or "")
	player:SetAttribute("SkillHud_" .. slot .. "_Icon", skillModule.SkillIcon or "")
	player:SetAttribute("SkillCooldown_" .. slot .. "_Total", skillModule.CurrentCooldown or skillModule.BaseCooldown or 0)
	player:SetAttribute("SkillCooldown_" .. slot .. "_Remaining", 0)
end

local function loadSkill(player: Player, skillName: string?, keyCode: Enum.KeyCode)
	local currentCharacter = character
	if not currentCharacter then
		return
	end

	if activeSkills[keyCode] and type(activeSkills[keyCode].Unequip) == "function" then
		activeSkills[keyCode].Unequip(player, currentCharacter)
	end

	if not skillName or skillName == "" then
		activeSkills[keyCode] = nil
		setSkillHudState(player, keyCode, nil)
		return
	end

	local skillObj = clientSkillsFolder:FindFirstChild(skillName)
	if not skillObj or not skillObj:IsA("ModuleScript") then
		activeSkills[keyCode] = nil
		setSkillHudState(player, keyCode, nil)
		warn("Missing client skill module: " .. tostring(skillName))
		return
	end

	local skillModule = require(skillObj)
	activeSkills[keyCode] = skillModule
	setSkillHudState(player, keyCode, skillModule)

	if type(skillModule.Equip) == "function" then
		skillModule.Equip(player, currentCharacter)
	end
end

local function setupCharacter(newCharacter: Model)
	local player = Players.LocalPlayer
	character = newCharacter
	table.clear(activeSkills)
	disconnectAttributeConnections()

	loadSkill(player, player:GetAttribute("EquippedSkill_Q") or "Hook", Enum.KeyCode.Q)
	loadSkill(player, player:GetAttribute("EquippedSkill_E") or "Dash", Enum.KeyCode.E)
	loadSkill(player, player:GetAttribute("EquippedSkill_R") or "Push", Enum.KeyCode.R)
	loadSkill(player, player:GetAttribute("EquippedSkill_F") or "Repel", Enum.KeyCode.F)

	table.insert(attributeConnections, player:GetAttributeChangedSignal("EquippedSkill_Q"):Connect(function()
		loadSkill(player, player:GetAttribute("EquippedSkill_Q"), Enum.KeyCode.Q)
	end))
	table.insert(attributeConnections, player:GetAttributeChangedSignal("EquippedSkill_E"):Connect(function()
		loadSkill(player, player:GetAttribute("EquippedSkill_E"), Enum.KeyCode.E)
	end))
	table.insert(attributeConnections, player:GetAttributeChangedSignal("EquippedSkill_R"):Connect(function()
		loadSkill(player, player:GetAttribute("EquippedSkill_R"), Enum.KeyCode.R)
	end))
	table.insert(attributeConnections, player:GetAttributeChangedSignal("EquippedSkill_F"):Connect(function()
		loadSkill(player, player:GetAttribute("EquippedSkill_F"), Enum.KeyCode.F)
	end))
end

function SkillServiceClient.build()
	return SkillServiceClient
end

function SkillServiceClient.init()
	if initialized then
		return SkillServiceClient
	end
	initialized = true
	networker = Networker.client.new("SkillService", SkillServiceClient)

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		setupCharacter(player.Character)
	end

	RunService.RenderStepped:Connect(function(dt)
		cooldownAccumulator += dt
		if cooldownAccumulator < 0.05 then
			return
		end
		cooldownAccumulator = 0

		for keyCode, skillModule in pairs(activeSkills) do
			local slot = KEY_SLOTS[keyCode]
			if slot then
				local total = skillModule.CurrentCooldown or skillModule.BaseCooldown or 0
				local remaining = math.max(0, total - (tick() - (skillModule.LastUsed or 0)))
				player:SetAttribute("SkillCooldown_" .. slot .. "_Total", total)
				player:SetAttribute("SkillCooldown_" .. slot .. "_Remaining", remaining)
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		local currentCharacter = character
		local targetSkill = activeSkills[input.KeyCode]
		if currentCharacter and targetSkill and type(targetSkill.Execute) == "function" then
			targetSkill.Execute(player, currentCharacter, networker)
		end
	end)

	return SkillServiceClient
end

function SkillServiceClient.useSkill(skillName: string, payload)
	if networker then
		networker:fire("UseSkill", skillName, payload)
	end
end

return SkillServiceClient :: SkillServiceClient
