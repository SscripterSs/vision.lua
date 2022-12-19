shared.deliveryCooldown = shared.deliveryCooldown or 0
local gs = function(service)
	return game:GetService(service)
end

repeat task.wait() until game:IsLoaded()

local player = gs('Players').LocalPlayer
local mainGui = gs('Players').LocalPlayer.PlayerGui:WaitForChild('MainGUI', 10)
local modules = player:WaitForChild("PlayerScripts"):WaitForChild("Modules")

if not mainGui then
	player:Kick('Failed to load shit lol, make sure u execute on main menu maybe???????')
end

local Network, NetworkBypass
local ds = gs('ReplicatedStorage').Modules:WaitForChild("DataService", 5)

if not ds then
    player:Kick('Failed to find DataService, this usually means bloxburg has updated, please wait for an announcement in our discord server.')
    return
end

for _, v in next, getgc(true) do
	if type(v) == 'table' then
		if rawget(v, 'Shared') and rawget(v, 'net') then
			Network = v
		end
	elseif type(v) == 'function' then
		if getfenv(v).script == ds then
			local const = getconstants(v)
			if table.find(const, 'RemoteFunction') and table.find(const, 'RemoteEvent') then
				NetworkBypass = v
			end
		end
	end
	if Network and NetworkBypass then break end
end

local net = {}
function net:Fire(remoteName, args)
	local remote = NetworkBypass(remoteName)
	if remote then
		remote:FireServer(args)
	end
end

function net:Invoke(remoteName, args)
	local args = args or {}
	local remote = NetworkBypass(remoteName, true)
	if remote then
		return remote:InvokeServer(args)
	end
end

local bar = mainGui.Bar
local settingsMenu = bar.SettingsMenu
local setidentity = setidentity or syn and syn.set_thread_identity or function() end
if false and mainGui.MainMenu.Visible == false then
	if setidentity then
	    local hotbar = require(modules.HotbarUI)
    	setidentity(2)
    	hotbar.Modules.LoadingHandler:ShowLoading("OpenMenu");
    	if net:Invoke("ShowMenu") then
    		hotbar.Modules.MenuUI:ShowMenu();
    	else
    		player:Kick("Please execute on the main menu of bloxburg.")
    		return
    	end;
    	hotbar.Modules.LoadingHandler:HideLoading("OpenMenu");
    	setidentity(7)
    else
      player:Kick("Please execute on the main menu of bloxburg.")
      return
	end
end

local stats = gs('ReplicatedStorage'):WaitForChild('Stats'):WaitForChild(tostring(player))
local age = stats.Appearance.Age.Value

if age ~= 'Adult' and age ~= 'Teen' then
	player:Kick(('\nYour bloxburg age must be adult or teen to use Vision\n\nYour current age is: %s.\n\nYou can change your age via a dresser or wardrobe\n\nRejoining in 3 seconds.'):format(age))
	task.wait(3)
	gs('TeleportService'):Teleport(game.PlaceId, player)
	return
end

-- ## Prevent Errors & Anti AFK ## --
for k, v in next, getconnections(player.Idled) do
	v:Disable()
end

gs("CoreGui").RobloxPromptGui.promptOverlay.ChildAdded:Connect(function(child)
  if child.Name == 'ErrorPrompt' and child:FindFirstChild('MessageArea') and child.MessageArea:FindFirstChild("ErrorFrame") then
    gs("TeleportService"):Teleport(game.PlaceId)
  end
end)

local vu = gs("VirtualUser")
player.Idled:connect(function()
	vu:Button2Down(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
	wait(1)
	vu:Button2Up(Vector2.new(0,0),workspace.CurrentCamera.CFrame)
end)

wait()

local httpReq = (request or syn.request)
local url = shared.webhook
local savedHookMessage
local httpService = game:GetService('HttpService')
local sendWebhooks = true

local deserialize = function(json)
  return httpService:JSONDecode(json)
end

local serialize = function(tbl) 
  return httpService:JSONEncode(tbl) 
end
--  FIELD 1 --
-- Earnings, Estimated, Pizzas Delivered, Duration
-- FIELD 2 --
-- Total Cash, Job Level, Promotion Stats, Status
local baseHook = {
  content = nil,
  embeds = {
    {
      description = "ROBLOX Username: ||" .. player.Name .. " (@".. player.DisplayName .. ")||",
      color = 10047487,
      fields = {
        {
          name = "**vision Bloxburg Autofarm**‎‎‎‎‎‎‎ ‎ ‎ ‎ ‎",
          value = "‎\n`💵` **Shift Earnings**\n ```\n%s\n```\n`💸` **Estimated Earnings/Hour**\n ```\n%s\n```\n`🍕` **Pizzas Delivered**\n ```\n%s\n```\n`🕒` **Shift Duration**\n ```\n%s\n```",
          inline = true
        },
        {
          name = "‎                                                      ‎ ‎",
          value = "‎\n`💰` **Total Cash**\n```%s```\n`👷‍♂️` **Job Level**\n ```\n%s\n```\n`📊` **Promotion Stats**\n ```\n%s```\n`✈` **Status**\n```\n%s```",
          inline = true
        }
      }
    }
  },
  username = "vision - "..player.Name, player.DisplayName,
  avatar_url = "https://cdn.discordapp.com/attachments/1050921966808342610/1054186551854247967/Vision_-_icon.png",
  attachments = {}
}

function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == 'table' then
			v = deepCopy(v)
		end
		copy[k] = v
	end
	return copy
end

local sendHook = function(shiftData)
	if url == nil or not sendWebhooks then
		return
	end

  local requestData = deepCopy(baseHook)
  requestData.embeds[1].fields[1].value = requestData.embeds[1].fields[1].value:format(shiftData.earnings, shiftData.estimated, shiftData.delivered, shiftData.duration)
  requestData.embeds[1].fields[2].value = requestData.embeds[1].fields[2].value:format(shiftData.total, shiftData.promoLevel, shiftData.promoStats, shiftData.status)

	if not savedHookMessage then
		savedHookMessage = httpReq({ Url = url .. '?wait=true', Method = 'POST', Headers = {
			['Content-Type'] = 'application/json'
		}, Body = serialize(requestData) })
		if savedHookMessage.StatusMessage ~= 'OK' then
			sendWebhooks = false
		end
	else
		httpReq({ Url = url .. '/messages/' .. deserialize(savedHookMessage.Body).id, Method = 'PATCH', Headers = {
			['Content-Type'] = 'application/json'
		}, Body = serialize(requestData) })
	end
end

-- ## GUI ## --
local Visio = Instance.new('ScreenGui')
local Main = Instance.new('Frame')
local MainListLayout = Instance.new('UIListLayout')
local Title = Instance.new('TextLabel')
local TitleGradient = Instance.new('UIGradient')
local Card = Instance.new('Frame')
local CardTitle = Instance.new('TextLabel')
local CardLine = Instance.new('Frame')
local CardLineGradient = Instance.new('UIGradient')
local CardCorner = Instance.new('UICorner')
local CardContent = Instance.new('Frame')
local CardContentListLayout = Instance.new('UIListLayout')
local ShiftEarnings = Instance.new('TextLabel')
local PizzasDelivered = Instance.new('TextLabel')
local ShiftDuration = Instance.new('TextLabel')
local EstimatedEarnings = Instance.new('TextLabel')
local Card_2 = Instance.new('Frame')
local TextLabel = Instance.new('TextLabel')
local CardLine_2 = Instance.new('Frame')
local CardLineGradient_2 = Instance.new('UIGradient')
local CardCorner_2 = Instance.new('UICorner')
local CardContent_2 = Instance.new('Frame')
local CardContentListLayout_2 = Instance.new('UIListLayout')
local TotalCash = Instance.new('TextLabel')
local PromotionProgress = Instance.new('TextLabel')
local PromotionLevel = Instance.new('TextLabel')

--Properties:

Visio.Name = 'vision'
Visio.Parent = gs('CoreGui')

Main.Name = 'Main'
Main.Parent = Visio
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
Main.BorderSizePixel = 0
Main.Position = UDim2.new(0.5, 0, 0.5, 0)
Main.Size = UDim2.new(0, 5000000, 0, 5000000)

MainListLayout.Name = 'MainListLayout'
MainListLayout.Parent = Main
MainListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
MainListLayout.SortOrder = Enum.SortOrder.LayoutOrder
MainListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
MainListLayout.Padding = UDim.new(0, 16)

Title.Name = 'Title'
Title.Parent = Main
Title.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundTransparency = 1.000
Title.Size = UDim2.new(0, 200, 0, 50)
Title.Font = Enum.Font.GothamBlack
Title.Text = 'vision Bloxburg Autofarm'
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 32.000
Title.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)

TitleGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(113, 103, 255)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(222, 30, 255))}
TitleGradient.Name = 'TitleGradient'
TitleGradient.Parent = Title

Card.Name = 'Card'
Card.Parent = Main
Card.BackgroundColor3 = Color3.fromRGB(21, 21, 21)
Card.BorderSizePixel = 0
Card.Position = UDim2.new(0.363550514, 0, 0.388383836, 0)
Card.Size = UDim2.new(0, 578, 0, 142)

CardTitle.Name = 'CardTitle'
CardTitle.Parent = Card
CardTitle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CardTitle.BackgroundTransparency = 1.000
CardTitle.BorderSizePixel = 0
CardTitle.Position = UDim2.new(0.0160000008, 0, 0.0599999987, 0)
CardTitle.Size = UDim2.new(0, 194, 0, 16)
CardTitle.Font = Enum.Font.GothamBold
CardTitle.Text = 'Shift Stats'
CardTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
CardTitle.TextSize = 18.000
CardTitle.TextXAlignment = Enum.TextXAlignment.Left
CardTitle.TextYAlignment = Enum.TextYAlignment.Top

CardLine.Name = 'CardLine'
CardLine.Parent = Card
CardLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CardLine.BorderSizePixel = 0
CardLine.Position = UDim2.new(0, 0, 0, 28)
CardLine.Size = UDim2.new(0, 578, 0, 4)

CardLineGradient.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(113, 103, 255)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(222, 30, 255))}
CardLineGradient.Name = 'CardLineGradient'
CardLineGradient.Parent = CardLine

CardCorner.Name = 'CardCorner'
CardCorner.Parent = Card

CardContent.Name = 'CardContent'
CardContent.Parent = Card
CardContent.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CardContent.BackgroundTransparency = 1.000
CardContent.Position = UDim2.new(0, 0, 0.225352108, 0)
CardContent.Size = UDim2.new(0, 578, 0, 109)

CardContentListLayout.Name = 'CardContentListLayout'
CardContentListLayout.Parent = CardContent
CardContentListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
CardContentListLayout.SortOrder = Enum.SortOrder.LayoutOrder
CardContentListLayout.VerticalAlignment = Enum.VerticalAlignment.Center

ShiftEarnings.Name = 'ShiftEarnings'
ShiftEarnings.Parent = CardContent
ShiftEarnings.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ShiftEarnings.BackgroundTransparency = 1.000
ShiftEarnings.BorderSizePixel = 0
ShiftEarnings.Position = UDim2.new(0.0159999747, 0, 0, 0)
ShiftEarnings.Size = UDim2.new(0.969000041, 0, 0, 24)
ShiftEarnings.Font = Enum.Font.GothamMedium
ShiftEarnings.Text = 'Shift Earnings: Loading'
ShiftEarnings.TextColor3 = Color3.fromRGB(255, 255, 255)
ShiftEarnings.TextSize = 18.000
ShiftEarnings.TextXAlignment = Enum.TextXAlignment.Left

PizzasDelivered.Name = 'PizzasDelivered'
PizzasDelivered.Parent = CardContent
PizzasDelivered.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
PizzasDelivered.BackgroundTransparency = 1.000
PizzasDelivered.BorderSizePixel = 0
PizzasDelivered.Position = UDim2.new(0.0159999747, 0, 0, 0)
PizzasDelivered.Size = UDim2.new(0.969000041, 0, 0, 24)
PizzasDelivered.Font = Enum.Font.GothamMedium
PizzasDelivered.Text = 'Pizzas Delivered: Loading'
PizzasDelivered.TextColor3 = Color3.fromRGB(255, 255, 255)
PizzasDelivered.TextSize = 18.000
PizzasDelivered.TextXAlignment = Enum.TextXAlignment.Left

ShiftDuration.Name = 'ShiftDuration'
ShiftDuration.Parent = CardContent
ShiftDuration.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ShiftDuration.BackgroundTransparency = 1.000
ShiftDuration.BorderSizePixel = 0
ShiftDuration.Position = UDim2.new(0.0159999747, 0, 0, 0)
ShiftDuration.Size = UDim2.new(0.969000041, 0, 0, 24)
ShiftDuration.Font = Enum.Font.GothamMedium
ShiftDuration.Text = 'Shift Duration: Loading'
ShiftDuration.TextColor3 = Color3.fromRGB(255, 255, 255)
ShiftDuration.TextSize = 18.000
ShiftDuration.TextXAlignment = Enum.TextXAlignment.Left

EstimatedEarnings.Name = 'EstimatedEarnings'
EstimatedEarnings.Parent = CardContent
EstimatedEarnings.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
EstimatedEarnings.BackgroundTransparency = 1.000
EstimatedEarnings.BorderSizePixel = 0
EstimatedEarnings.Position = UDim2.new(0.0159999747, 0, 0, 0)
EstimatedEarnings.Size = UDim2.new(0.969000041, 0, 0, 24)
EstimatedEarnings.Font = Enum.Font.GothamMedium
EstimatedEarnings.Text = 'Estimated Earnings: Loading'
EstimatedEarnings.TextColor3 = Color3.fromRGB(255, 255, 255)
EstimatedEarnings.TextSize = 18.000
EstimatedEarnings.TextXAlignment = Enum.TextXAlignment.Left

Card_2.Name = 'Card'
Card_2.Parent = Main
Card_2.BackgroundColor3 = Color3.fromRGB(21, 21, 21)
Card_2.BorderSizePixel = 0
Card_2.Position = UDim2.new(0.363550514, 0, 0.50858587, 0)
Card_2.Size = UDim2.new(0, 578, 0, 120)

TextLabel.Parent = Card_2
TextLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TextLabel.BackgroundTransparency = 1.000
TextLabel.BorderSizePixel = 0
TextLabel.Position = UDim2.new(0.0160000008, 0, 0.0599999987, 0)
TextLabel.Size = UDim2.new(0, 194, 0, 16)
TextLabel.Font = Enum.Font.GothamBold
TextLabel.Text = 'Overall'
TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TextLabel.TextSize = 18.000
TextLabel.TextXAlignment = Enum.TextXAlignment.Left
TextLabel.TextYAlignment = Enum.TextYAlignment.Top

CardLine_2.Name = 'CardLine'
CardLine_2.Parent = Card_2
CardLine_2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CardLine_2.BorderSizePixel = 0
CardLine_2.Position = UDim2.new(0, 0, 0, 28)
CardLine_2.Size = UDim2.new(0, 578, 0, 4)

CardLineGradient_2.Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(113, 103, 255)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(222, 30, 255))}
CardLineGradient_2.Name = 'CardLineGradient'
CardLineGradient_2.Parent = CardLine_2

CardCorner_2.Name = 'CardCorner'
CardCorner_2.Parent = Card_2

CardContent_2.Name = 'CardContent'
CardContent_2.Parent = Card_2
CardContent_2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CardContent_2.BackgroundTransparency = 1.000
CardContent_2.Position = UDim2.new(0, 0, 0.266666681, 0)
CardContent_2.Size = UDim2.new(0, 578, 0, 88)

CardContentListLayout_2.Name = 'CardContentListLayout'
CardContentListLayout_2.Parent = CardContent_2
CardContentListLayout_2.HorizontalAlignment = Enum.HorizontalAlignment.Center
CardContentListLayout_2.SortOrder = Enum.SortOrder.LayoutOrder
CardContentListLayout_2.VerticalAlignment = Enum.VerticalAlignment.Center

TotalCash.Name = 'TotalCash'
TotalCash.Parent = CardContent_2
TotalCash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TotalCash.BackgroundTransparency = 1.000
TotalCash.BorderSizePixel = 0
TotalCash.Position = UDim2.new(0.0159999747, 0, 0, 0)
TotalCash.Size = UDim2.new(0.969000041, 0, 0, 24)
TotalCash.Font = Enum.Font.GothamMedium
TotalCash.Text = 'Total Cash: Loading'
TotalCash.TextColor3 = Color3.fromRGB(255, 255, 255)
TotalCash.TextSize = 18.000
TotalCash.TextXAlignment = Enum.TextXAlignment.Left

PromotionProgress.Name = 'PromotionProgress'
PromotionProgress.Parent = CardContent_2
PromotionProgress.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
PromotionProgress.BackgroundTransparency = 1.000
PromotionProgress.BorderSizePixel = 0
PromotionProgress.Position = UDim2.new(0.0159999747, 0, 0, 0)
PromotionProgress.Size = UDim2.new(0.969000041, 0, 0, 24)
PromotionProgress.Font = Enum.Font.GothamMedium
PromotionProgress.Text = 'Promotion Progress: Loading'
PromotionProgress.TextColor3 = Color3.fromRGB(255, 255, 255)
PromotionProgress.TextSize = 18.000
PromotionProgress.TextXAlignment = Enum.TextXAlignment.Left

PromotionLevel.Name = 'PromotionLevel'
PromotionLevel.Parent = CardContent_2
PromotionLevel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
PromotionLevel.BackgroundTransparency = 1.000
PromotionLevel.BorderSizePixel = 0
PromotionLevel.Position = UDim2.new(0.0159999747, 0, 0, 0)
PromotionLevel.Size = UDim2.new(0.969000041, 0, 0, 24)
PromotionLevel.Font = Enum.Font.GothamMedium
PromotionLevel.Text = 'Promotion Level: Loading'
PromotionLevel.TextColor3 = Color3.fromRGB(255, 255, 255)
PromotionLevel.TextSize = 18.000
PromotionLevel.TextXAlignment = Enum.TextXAlignment.Left

local mainChanged = 0
Main.Changed:Connect(function(changed)
	mainChanged = mainChanged + 1
	if mainChanged > 2 then
    while true do end
	end
end)

local visioChanged = 0
Visio.Changed:Connect(function(changed)
	visioChanged = visioChanged + 1
	if visioChanged > 2 then
    while true do end
	end
end)

local formatNumber = (function (n)
	n = tostring(n)
	local pattern = n:reverse():gsub('%d%d%d', '%1,'):reverse():gsub('^,', '')
	return pattern
end)

local textStrings = {
	['level'] = 'Promotion Level: ',
	['progress'] = 'Deliveries Until Promotion: ',
	['totalCash'] = 'Total Cash: $',
	['estimatedEarnings'] = 'Estimated Earnings: $',
	['duration'] = 'Shift Duration: ',
	['delivered'] = 'Pizzas Delivered: ',
	['shiftEarnings'] = 'Shift Earnings: $'
}

local setters = {
	['level'] = function(text)
		PromotionLevel.Text = textStrings.level .. text
	end,
	['progress'] = function(text)
		PromotionProgress.Text = textStrings.progress .. text
	end,
	['totalCash'] = function(text)
		TotalCash.Text = textStrings.totalCash .. text
	end,
	['estimatedEarnings'] = function(text)
		EstimatedEarnings.Text = textStrings.estimatedEarnings .. text
	end,
	['duration'] = function(text)
		ShiftDuration.Text = textStrings.duration .. text
	end,
	['delivered'] = function(text)
		PizzasDelivered.Text = textStrings.delivered .. text
	end,
	['shiftEarnings'] = function(text)
		ShiftEarnings.Text = textStrings.shiftEarnings .. text
	end,
}

local deliveryStatus = Instance.new('StringValue')
deliveryStatus.Parent = gs('CoreGui')

local firstPizzaAmt, currentLevel, estimatedEarnings, lastShiftEarnings, shiftDuration
local lastPizzaDeliveredTick = tick()
local setNewEstimate = false
local totalDelivered = 0
local workFrame = player.PlayerGui.MainGUI.Bar.CharMenu.WorkFrame.WorkFrame
local promoFrame = workFrame.PromotionBar

local shiftEarnings
local totalCash 
local promoProgress 
local level
local formattedShiftEarnings
local formattedTotalCash
local formattedEstimatedEarnings
local formattedTotalDelivered

deliveryStatus.Changed:Connect(function(status)
  pcall(function()
		sendHook({
      earnings = (formattedShiftEarnings and '$' .. formattedShiftEarnings or deliveryStatus.Value),
      delivered = (formattedTotalDelivered and formattedTotalDelivered or deliveryStatus.Value),
      duration = (shiftDuration and shiftDuration or deliveryStatus.Value),
      estimated = (formattedEstimatedEarnings and '$' .. formattedEstimatedEarnings or deliveryStatus.Value),
      total = (formattedTotalCash and'$' .. formattedTotalCash or deliveryStatus.Value),
      promoStats = (level == nil and deliveryStatus.Value) or (level == 50 and 'Max Promotion' or promoProgress),
      promoLevel = (level == nil and deliveryStatus.Value) or tostring(level == 50 and 'Max Promotion' or level),
      status = deliveryStatus.Value
    })
	end)
end)

stats.Job.ShiftEarnings.Changed:Connect(function(changed)
	-- ## Variables ## --
	lastPizzaDeliveredTick = tick()
	totalDelivered = totalDelivered + 1

	-- ## Estimate ## --
	if totalDelivered == 1 or setNewEstimate == true then
		if setNewEstimate == true then
			setNewEstimate = false
			firstPizzaAmt = math.floor(shiftEarnings - lastShiftEarnings)
		else
			firstPizzaAmt = changed
		end
		currentLevel = level
    local deliveryTime = (shared.deliveryCooldown > 5 and shared.deliveryCooldown or 5)
		estimatedEarnings = math.floor(firstPizzaAmt * ((60 / deliveryTime) * 60))
		setters.estimatedEarnings(formatNumber(estimatedEarnings))
	end

	if currentLevel ~= level then
		setNewEstimate = true
		lastShiftEarnings = shiftEarnings
	end

	-- ## Formatted Numbers ## --
	shiftEarnings = math.floor(stats.Job.ShiftEarnings.Value)
	totalCash = math.floor(stats.Money.Value + shiftEarnings)
	promoProgress = promoFrame.Value.Text
	level = tonumber(string.split(promoFrame.Level.Text, ' ')[2])
	formattedShiftEarnings = formatNumber(shiftEarnings)
	formattedTotalCash = formatNumber(totalCash)
	formattedEstimatedEarnings = formatNumber(estimatedEarnings)
	formattedTotalDelivered = formatNumber(totalDelivered)

	-- ## Setters # --
	setters.delivered(formattedTotalDelivered)
	setters.shiftEarnings(formattedShiftEarnings)
	setters.totalCash(formattedTotalCash)
	setters.progress(promoProgress)
	setters.level(tostring(level == 50 and 'Max Promotion' or level))

	deliveryStatus.Value = "Successful Delivery!"
end)

workFrame.TimeLabel.TextLabel:GetPropertyChangedSignal('Text'):Connect(function()
	shiftDuration = workFrame.TimeLabel.TextLabel.Text
	setters.duration(shiftDuration)
end)

local jobModule = require(modules:WaitForChild('JobHandler'))

if not bbfbHooksLoaded then
  local old = require(modules._Utilities.GUIHandler).AlertBox
	require(modules._Utilities.GUIHandler).AlertBox = function(...)
    if ({...})[2] == 'E_LeftWorkplace' then
      return
    end
    return old(...)
  end

  jobModule.StopWorking = function(...)
    return
  end
end

gs('RunService'):Set3dRenderingEnabled(false)
workspace.Camera.CameraType = 'Custom'

local visio = {}

function visio:Teleport(cframe, bypass)
	if bypass then
		local clonedHum = player.Character.Humanoid:Clone()
		player.Character.Humanoid:Destroy()
		task.wait(0.5)
		clonedHum.Parent = player.Character
	end
	player.Character:SetPrimaryPartCFrame(cframe)
end

function visio:Work()
	if not jobModule:IsWorking() then
		task.spawn(function()
		    net:Invoke('ToWork', { Name = "PizzaPlanetDelivery" });
	    end)
	    task.wait(2)
		--net:Invoke('UsePizzaMoped');
	end
	net:Invoke('UsePizzaMoped');
end

function visio:CompleteOrder()
  if totalDelivered >= 1 then deliveryStatus.Value = "Getting Pizza" end
  local customer
  local getPizza = function()
    repeat task.wait() until gs('Workspace').Environment.Locations:FindFirstChild('PizzaPlanet')
    local Boxes = workspace.Environment.Locations.PizzaPlanet.Conveyor.MovingBoxes
    repeat task.wait() until #Boxes:GetChildren() > 0
    Boxes = Boxes:GetChildren()
    local Box = Boxes[#Boxes]
    repeat
      visio:Teleport(CFrame.new(Box.Position + Vector3.new(0, 7, 0)))
      task.wait(1)
      customer = net:Invoke('TakePizzaBox', { Box = Box })
    until customer or task.wait(1)
  end
  
  repeat getPizza() until customer
  task.wait(1)
  if totalDelivered >= 1 then deliveryStatus.Value = "Delivering Pizza" end

	visio:Teleport(customer:WaitForChild('HumanoidRootPart').CFrame, true)
	task.wait(.5)
	repeat
		net:Fire('DeliverPizza', { Customer = customer })
		task.wait()
	until not player.Character:FindFirstChild('Pizza Box')
end

-- // Init farm
visio:Work()
visio:CompleteOrder()
player.CharacterAdded:Connect(function()
  if shared.deliveryCooldown > 1 then
    deliveryStatus.Value = "Awaiting Cooldown"
  end
  task.wait(0.1 + shared.deliveryCooldown)
  visio:Work()
  visio:CompleteOrder()
end)

-- // Prevent farm from getting stuck
task.spawn(function()
  while task.wait(1) do
    if (tick() - lastPizzaDeliveredTick) > (10 + shared.deliveryCooldown) then
      lastPizzaDeliveredTick = tick() + 6
      if player.Character and player.Character:FindFirstChild('Head') then
        player.Character.Head:Destroy()
      end
    end
  end
end)
