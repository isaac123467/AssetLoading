local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local StarterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")

local searchAreas = {
	game.ServerScriptService,
	game.StarterPlayer.StarterPlayerScripts
}

local function moveAsset(obj)
	if obj:IsA("LocalScript") then
		obj.Parent = StarterPlayerScripts
	elseif obj:IsA("RemoteEvent") then
		obj.Parent = ReplicatedStorage
	end
end

for _, container in ipairs(searchAreas) do
	for _, obj in ipairs(container:GetDescendants()) do
		moveAsset(obj)
	end
end
 
