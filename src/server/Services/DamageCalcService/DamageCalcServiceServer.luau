local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DamageCalcServiceServer = {}
export type DamageCalcServiceServer = typeof(DamageCalcServiceServer) & {}

local initialized = false

local function getOrCreateRemote(remoteName: string): RemoteEvent
	local remote = ReplicatedStorage:FindFirstChild(remoteName)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	if remote then
		remote:Destroy()
	end

	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = remoteName
	newRemote.Parent = ReplicatedStorage
	return newRemote
end

local function setupEntity(character: Model)
	if character:GetAttribute("DamagePercent") ~= nil then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 5)
	if not humanoid or not head then
		return
	end

	character:SetAttribute("DamagePercent", 0)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageUI"
	billboard.Adornee = head
	billboard.Size = UDim2.new(0, 100, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = character

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "0%"
	textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	textLabel.TextStrokeTransparency = 0
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.Parent = billboard

	local function refreshDamageUiVisibility()
		billboard.Enabled = character:GetAttribute("IsCloaked") ~= true
	end

	character:GetAttributeChangedSignal("DamagePercent"):Connect(function()
		local currentDamage = character:GetAttribute("DamagePercent") or 0
		textLabel.Text = tostring(currentDamage) .. "%"

		if currentDamage >= 100 then
			textLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
		elseif currentDamage >= 50 then
			textLabel.TextColor3 = Color3.fromRGB(255, 170, 0)
		else
			textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end)

	character:GetAttributeChangedSignal("IsCloaked"):Connect(refreshDamageUiVisibility)
	refreshDamageUiVisibility()
end

function DamageCalcServiceServer.build()
	getOrCreateRemote("HitIndicatorEvent")
	getOrCreateRemote("DamageTakenIndicatorEvent")
	return DamageCalcServiceServer
end

function DamageCalcServiceServer.init()
	if initialized then
		return DamageCalcServiceServer
	end
	initialized = true

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(setupEntity)
	end)

	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
			setupEntity(obj)
		end
	end

	workspace.DescendantAdded:Connect(function(obj)
		if obj:IsA("Model") then
			task.delay(0.1, function()
				if obj.Parent and obj:FindFirstChildOfClass("Humanoid") then
					setupEntity(obj)
				end
			end)
		end
	end)

	return DamageCalcServiceServer
end

return DamageCalcServiceServer :: DamageCalcServiceServer
