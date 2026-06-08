local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RoundServiceUtils = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RoundService"):WaitForChild("RoundServiceUtils"))

local RoundServiceServer = {}
export type RoundServiceServer = typeof(RoundServiceServer) & {}

local WIN_SCORE = 100
local SCORE_MAP_DROP = 2
local SCORE_BLACKHOLE = 5
local TIME_LOBBY = 20
local TIME_PLAYING = 180
local TIME_ENDING = 5
local initialized = false

local gameState
local gameTime
local topPlayerName
local topScoreValue

local function teleportAlivePlayers(folderName: string)
	local folder = Workspace:FindFirstChild(folderName)
	if not folder then
		warn("Missing spawn folder: " .. folderName)
		return
	end

	local spawns = folder:GetChildren()
	if #spawns == 0 then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if character and humanoid and character:FindFirstChild("HumanoidRootPart") and humanoid.Health > 0 then
			character:PivotTo(spawns[math.random(1, #spawns)].CFrame + Vector3.new(0, 3, 0))
		end
	end
end

local function handleRespawn(character: Model)
	local folderName = gameState.Value == "PLAYING" and "MapSpawns" or "LobbySpawns"
	local folder = Workspace:FindFirstChild(folderName)
	if not folder then
		return
	end

	local spawns = folder:GetChildren()
	local root = character:WaitForChild("HumanoidRootPart", 5)
	if root and #spawns > 0 then
		task.wait(0.1)
		character:PivotTo(spawns[math.random(1, #spawns)].CFrame + Vector3.new(0, 3, 0))
	end
end

local function bindPlayer(player: Player)
	player:SetAttribute("Points", 0)

	player.CharacterAdded:Connect(function(character)
		handleRespawn(character)

		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			local attackerName = character:GetAttribute("LastAttacker")
			local deathCause = character:GetAttribute("DeathCause") or "Void"
			local attacker = Players:FindFirstChild(attackerName or "")

			if attacker and attacker ~= player and gameState.Value == "PLAYING" then
				local pointsToGive = deathCause == "BlackHole" and SCORE_BLACKHOLE or SCORE_MAP_DROP
				local newScore = (attacker:GetAttribute("Points") or 0) + pointsToGive
				attacker:SetAttribute("Points", newScore)

				if newScore > topScoreValue.Value then
					topScoreValue.Value = newScore
					topPlayerName.Value = attacker.Name
				end
			end

			task.wait(2)
			player:LoadCharacter()
		end)
	end)
end

function RoundServiceServer.build()
	gameState = RoundServiceUtils.getValue(ReplicatedStorage, "StringValue", "GameState", "LOBBY")
	gameTime = RoundServiceUtils.getValue(ReplicatedStorage, "IntValue", "GameTime", 0)
	topPlayerName = RoundServiceUtils.getValue(ReplicatedStorage, "StringValue", "TopPlayerName", "None")
	topScoreValue = RoundServiceUtils.getValue(ReplicatedStorage, "IntValue", "TopScoreValue", 0)
	return RoundServiceServer
end

function RoundServiceServer.init()
	if initialized then
		return RoundServiceServer
	end
	initialized = true
	RoundServiceServer.build()

	Players.PlayerAdded:Connect(bindPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		bindPlayer(player)
	end

	task.spawn(function()
		while true do
			gameState.Value = "LOBBY"
			topPlayerName.Value = "None"
			topScoreValue.Value = 0

			for _, player in ipairs(Players:GetPlayers()) do
				player:SetAttribute("Points", 0)
			end

			teleportAlivePlayers("LobbySpawns")
			for i = TIME_LOBBY, 0, -1 do
				gameTime.Value = i
				task.wait(1)
			end

			gameState.Value = "PLAYING"
			teleportAlivePlayers("MapSpawns")

			local roundWinner = nil
			for i = TIME_PLAYING, 0, -1 do
				gameTime.Value = i
				for _, player in ipairs(Players:GetPlayers()) do
					if (player:GetAttribute("Points") or 0) >= WIN_SCORE then
						roundWinner = player
						break
					end
				end
				if roundWinner then
					break
				end
				task.wait(1)
			end

			if roundWinner then
				gameState.Value = roundWinner.Name .. " WINS!"
			else
				gameState.Value = "BLACK HOLE ERUPTION!"
				for _, player in ipairs(Players:GetPlayers()) do
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.Health = 0
					end
				end
			end

			task.wait(TIME_ENDING)
		end
	end)

	return RoundServiceServer
end

return RoundServiceServer :: RoundServiceServer
