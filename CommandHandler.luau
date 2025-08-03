local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(game.ServerScriptService.Config)
local NotificationEvent = ReplicatedStorage:WaitForChild("SendNotification")

-- Debug utility
local function debugPrint(...)
	if Config.EnableDebugMessages then
		print("[DEBUG]", ...)
	end
end

-- Notification utility
local function notifyPlayer(player, title, text, duration)
	NotificationEvent:FireClient(player, {
		Title = title or "Notice",
		Text = text or "",
		Duration = duration or Config.NotificationDuration or 4,
	})
end

-- Get Wallet and Bank references
local function getStats(player)
	local stats = player:FindFirstChild(Config.LeaderstatsFolderName)
	if not stats then return nil, nil end
	local wallet = stats:FindFirstChild(Config.WalletStatName)
	local bank = stats:FindFirstChild(Config.BankStatName)
	return wallet, bank
end

-- Work Pay System
if Config.EnableWorkPay then
	task.spawn(function()
		while true do
			task.wait(Config.PayIntervalSeconds)
			for _, player in pairs(Players:GetPlayers()) do
				local wallet = getStats(player)
				if wallet then
					local playedTime = math.floor(player:GetJoinTime() / Config.PayIntervalSeconds)
					local bonus = Config.BasePay + (playedTime * Config.PayIncreasePerInterval)
					wallet.Value = math.min(wallet.Value + bonus, Config.MaxWallet)
					notifyPlayer(player, "Work Pay", "You earned £" .. bonus .. " for playing.")
					debugPrint(player.Name .. " earned £" .. bonus)
				end
			end
		end
	end)
end

-- Interest System
if Config.EnableInterest then
	task.spawn(function()
		while true do
			task.wait(Config.InterestInterval)
			for _, player in pairs(Players:GetPlayers()) do
				local _, bank = getStats(player)
				if bank then
					local interest = math.floor(bank.Value * Config.InterestRate)
					interest = math.min(interest, Config.MaxInterestPerPayout)
					bank.Value = math.min(bank.Value + interest, Config.MaxBank)
					notifyPlayer(player, "Bank Interest", "You earned £" .. interest .. " in interest.")
					debugPrint(player.Name .. " received £" .. interest .. " interest")
				end
			end
		end
	end)
end

-- Lottery System
if Config.EnableLottery then
	_G.LotteryEntries = {}
	task.spawn(function()
		while true do
			task.wait(Config.LotteryInterval)
			local entries = _G.LotteryEntries or {}
			if #entries >= Config.LotteryMinPlayers then
				local winner = entries[math.random(1, #entries)]
				local prize = Config.LotteryTicketPrice * #entries
				local wallet = getStats(winner)
				if wallet then
					wallet.Value = math.min(wallet.Value + prize, Config.MaxWallet)
					notifyPlayer(winner, "You Won the Lottery!", "You won £" .. prize .. "!")
					debugPrint(winner.Name .. " won the lottery with £" .. prize)
				end
			else
				debugPrint("Not enough participants for lottery.")
			end
			_G.LotteryEntries = {}
		end
	end)
end

-- Tax logic helpers
local function applyTax(amount, taxRate)
	return math.floor(amount * (1 - taxRate))
end

-- Admin check
local function isAdmin(player)
	for _, id in ipairs(Config.Admins) do
		if player.UserId == id then
			return true
		end
	end
	return false
end

-- Command handler
local function handleCommand(player, msg)
	local args = string.split(msg, " ")
	local cmdRaw = args[1]
	if not cmdRaw or string.sub(cmdRaw, 1, #Config.CommandPrefix) ~= Config.CommandPrefix then return end

	local cmd = string.lower(string.sub(cmdRaw, #Config.CommandPrefix + 1))
	debugPrint("Command:", cmd)

	if cmd == "givecash" and isAdmin(player) then
		local targetName = args[2]
		local amount = tonumber(args[3])
		if targetName and amount and amount > 0 then
			local target = Players:FindFirstChild(targetName)
			if target then
				local wallet = getStats(target)
				if wallet then
					wallet.Value = math.min(wallet.Value + amount, Config.MaxWallet)
					notifyPlayer(player, "Cash Given", "You gave £" .. amount .. " to " .. target.Name)
					notifyPlayer(target, "Cash Received", player.Name .. " gave you £" .. amount)
				end
			end
		end

	elseif cmd == "setbank" and isAdmin(player) then
		local targetName = args[2]
		local amount = tonumber(args[3])
		if targetName and amount and amount >= 0 then
			local target = Players:FindFirstChild(targetName)
			if target then
				local _, bank = getStats(target)
				if bank then
					bank.Value = math.min(amount, Config.MaxBank)
					notifyPlayer(player, "Bank Set", "Set " .. target.Name .. "'s bank to £" .. amount)
					notifyPlayer(target, "Bank Updated", "Your bank was set to £" .. amount)
				end
			end
		end

	elseif cmd == "deposit" then
		local amount = tonumber(args[2])
		if amount and amount > 0 then
			local wallet, bank = getStats(player)
			if wallet and bank and wallet.Value >= amount then
				local taxedAmount = Config.EnableTax and applyTax(amount, Config.TaxDeposit) or amount
				wallet.Value -= amount
				bank.Value = math.min(bank.Value + taxedAmount, Config.MaxBank)
				notifyPlayer(player, "Deposit Complete", "You deposited £" .. taxedAmount)
			else
				notifyPlayer(player, "Deposit Failed", "Not enough funds.")
			end
		end

	elseif cmd == "withdraw" then
		local amount = tonumber(args[2])
		if amount and amount > 0 then
			local wallet, bank = getStats(player)
			if wallet and bank and bank.Value >= amount then
				local taxedAmount = Config.EnableTax and applyTax(amount, Config.TaxWithdraw) or amount
				bank.Value -= amount
				wallet.Value = math.min(wallet.Value + taxedAmount, Config.MaxWallet)
				notifyPlayer(player, "Withdraw Complete", "You withdrew £" .. taxedAmount)
			else
				notifyPlayer(player, "Withdraw Failed", "Not enough in bank.")
			end
		end

	elseif cmd == "enterlottery" and Config.EnableLottery then
		local wallet = getStats(player)
		if not wallet then return end
		if not _G.LotteryEntries then _G.LotteryEntries = {} end
		for _, entry in ipairs(_G.LotteryEntries) do
			if entry == player then
				notifyPlayer(player, "Lottery", "You already entered this draw.")
				return
			end
		end
		if wallet.Value >= Config.LotteryTicketPrice then
			wallet.Value -= Config.LotteryTicketPrice
			table.insert(_G.LotteryEntries, player)
			notifyPlayer(player, "Lottery", "You entered for £" .. Config.LotteryTicketPrice .. "!")
			debugPrint(player.Name .. " entered the lottery")
		else
			notifyPlayer(player, "Lottery", "Not enough money to enter.")
		end
	end
end

-- Chat hook
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		pcall(function()
			handleCommand(player, msg)
		end)
	end)
end)
