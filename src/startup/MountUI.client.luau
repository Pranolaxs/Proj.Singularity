local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("React"))
local ReactRoblox = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("ReactRoblox"))

local RootUI = require(ReplicatedStorage:WaitForChild("Features"):WaitForChild("app"):WaitForChild("rootUI"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local oldContainer = playerGui:FindFirstChild("SingularityReactUI")
if oldContainer then
	oldContainer:Destroy()
end

local container = Instance.new("ScreenGui")
container.Name = "SingularityReactUI"
container.IgnoreGuiInset = true
container.ResetOnSpawn = false
container.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
container.DisplayOrder = 100
container.Parent = playerGui

local root = ReactRoblox.createRoot(container)
root:render(React.createElement(RootUI))
