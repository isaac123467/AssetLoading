local Players = game:GetService("Players")
local DataServer = require(script.Parent.Parent.DataServer)
local Config = require(game.ServerScriptService.Config)

local function setupLeaderstats(player, data)
	local stats = Instance.new("Folder")
	stats.Name = Config.LeaderstatsFolderName
	stats.Parent = player

	local wallet = Instance.new("IntValue")
	wallet.Name = Config.WalletStatName
	wallet.Value = data.Wallet
	wallet.Parent = stats

	local bank = Instance.new("IntValue")
	bank.Name = Config.BankStatName
	bank.Value = data.Bank
	bank.Parent = stats
end

Players.PlayerAdded:Connect(function(player)
	local data = DataServer:Load(player)
	setupLeaderstats(player, data)
end)

Players.PlayerRemoving:Connect(function(player)
	DataServer:Save(player)
end)

game:BindToClose(function()
	for _, player in pairs(Players:GetPlayers()) do 
		DataServer:Save(player)
	end
end)
