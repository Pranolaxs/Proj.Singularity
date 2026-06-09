--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetworkLayer = {}

function NetworkLayer.getByteNet()
	local packages = ReplicatedStorage:FindFirstChild("Packages")
	local byteNetModule = packages and packages:FindFirstChild("ByteNet")
	if not byteNetModule then
		return nil
	end

	local ok, byteNet = pcall(require, byteNetModule)
	if not ok then
		warn("NetworkLayer: ByteNet exists but failed to load")
		return nil
	end

	return byteNet
end

function NetworkLayer.isByteNetAvailable(): boolean
	return NetworkLayer.getByteNet() ~= nil
end

return NetworkLayer
