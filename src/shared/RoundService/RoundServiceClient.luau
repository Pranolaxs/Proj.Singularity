local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundServiceClient = {}
export type RoundServiceClient = typeof(RoundServiceClient) & {}

local initialized = false

function RoundServiceClient.build()
	return RoundServiceClient
end

function RoundServiceClient.init()
	if initialized then
		return RoundServiceClient
	end
	initialized = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = playerGui:FindFirstChild("GameManagerUI") or Instance.new("ScreenGui")
	screenGui.Name = "GameManagerUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	for _, child in ipairs(screenGui:GetChildren()) do
		child:Destroy()
	end

	local timeFrame = Instance.new("Frame")
	timeFrame.AnchorPoint = Vector2.new(0.5, 0)
	timeFrame.Position = UDim2.new(0.5, 0, 0, 20)
	timeFrame.Size = UDim2.new(0, 250, 0, 50)
	timeFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	timeFrame.BackgroundTransparency = 0.5
	timeFrame.Parent = screenGui
	Instance.new("UICorner", timeFrame).CornerRadius = UDim.new(0, 8)

	local timeLabel = Instance.new("TextLabel")
	timeLabel.Size = UDim2.new(1, 0, 1, 0)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Font = Enum.Font.FredokaOne
	timeLabel.TextScaled = true
	timeLabel.Parent = timeFrame

	local scoreFrame = Instance.new("Frame")
	scoreFrame.AnchorPoint = Vector2.new(1, 0)
	scoreFrame.Position = UDim2.new(1, -20, 0, 20)
	scoreFrame.Size = UDim2.new(0, 150, 0, 70)
	scoreFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	scoreFrame.BackgroundTransparency = 0.5
	scoreFrame.Parent = screenGui
	Instance.new("UICorner", scoreFrame).CornerRadius = UDim.new(0, 8)

	local topPlayerLabel = Instance.new("TextLabel")
	topPlayerLabel.Size = UDim2.new(1, -10, 0.5, 0)
	topPlayerLabel.Position = UDim2.new(0, 10, 0, 0)
	topPlayerLabel.BackgroundTransparency = 1
	topPlayerLabel.Font = Enum.Font.FredokaOne
	topPlayerLabel.TextSize = 16
	topPlayerLabel.TextXAlignment = Enum.TextXAlignment.Left
	topPlayerLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	topPlayerLabel.Parent = scoreFrame

	local myScoreLabel = Instance.new("TextLabel")
	myScoreLabel.Size = UDim2.new(1, -10, 0.5, 0)
	myScoreLabel.Position = UDim2.new(0, 10, 0.5, 0)
	myScoreLabel.BackgroundTransparency = 1
	myScoreLabel.Font = Enum.Font.FredokaOne
	myScoreLabel.TextSize = 16
	myScoreLabel.TextXAlignment = Enum.TextXAlignment.Left
	myScoreLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
	myScoreLabel.Parent = scoreFrame

	local gameState = ReplicatedStorage:WaitForChild("GameState")
	local gameTime = ReplicatedStorage:WaitForChild("GameTime")
	local topPlayer = ReplicatedStorage:WaitForChild("TopPlayerName")
	local topScore = ReplicatedStorage:WaitForChild("TopScoreValue")

	local function updateUI()
		local mins = math.floor(gameTime.Value / 60)
		local secs = gameTime.Value % 60

		if gameState.Value == "LOBBY" then
			timeLabel.Text = string.format("LOBBY - %02d:%02d", mins, secs)
			timeLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
		elseif gameState.Value == "PLAYING" then
			timeLabel.Text = string.format("PLAYING - %02d:%02d", mins, secs)
			timeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			timeLabel.Text = gameState.Value
			timeLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
		end

		topPlayerLabel.Text = "Top: " .. topPlayer.Value .. " : " .. tostring(topScore.Value)
		myScoreLabel.Text = "You : " .. tostring(player:GetAttribute("Points") or 0)
	end

	gameState.Changed:Connect(updateUI)
	gameTime.Changed:Connect(updateUI)
	topPlayer.Changed:Connect(updateUI)
	topScore.Changed:Connect(updateUI)
	player:GetAttributeChangedSignal("Points"):Connect(updateUI)
	updateUI()

	return RoundServiceClient
end

return RoundServiceClient :: RoundServiceClient
