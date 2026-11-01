-- [[ Rscripts Risk Notice ]]
-- This script is not verified by rscripts.net. Deal with caution.
--
-- Stay safe:
--   • Never log in on unofficial Roblox sites or lookalike domains.
--   • Real Roblox links use roblox.com (check the .com ending).
--   • Treat fake Roblox login / "claim reward" pages as phishing.
-- [[ End Rscripts Risk Notice ]]
-- LocalScript: FE Verity Hat Controller (Updated Pitch Controls)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local VERITY_HAT_ID = "136919891265571"
local IS_CONTROLLING = false
local IS_MINIMIZED = false
local IS_SETTINGS_OPEN = false
local IS_BETA_FACE_CAM = false

-- Speed Configuration
local SLOW_SPEED = 0.15
local FAST_SPEED = 0.35

-- Input Delay Configuration
local INITIAL_HOLD_DELAY = 0.35
local HOLD_REPEAT_RATE = 0.03

-- Degree Modifiers
local BETA_YAW_OFFSET = 0 
local CUSTOM_ROT_OFFSET = CFrame.identity

local HeartbeatConnection = nil
local MovementConnection = nil
local ControlAnchor = nil
local HatHandle = nil

-- Cyber Glow Palette
local YELLOW_GLOW = Color3.fromRGB(255, 220, 0)
local DARK_MAIN_BG = Color3.fromRGB(12, 12, 15)
local PANEL_BG = Color3.fromRGB(20, 20, 25)
local BTN_BG = Color3.fromRGB(28, 28, 36)

local function getCurrentSpeed()
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
		return FAST_SPEED
	end
	return SLOW_SPEED
end

local function sendChatMessage(msg)
	pcall(function()
		if TextChatService and TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
			local textChannels = TextChatService:FindFirstChild("TextChannels")
			local generalChannel = textChannels and textChannels:FindFirstChild("RBXGeneral")
			if generalChannel then
				generalChannel:SendAsync(msg)
			else
				Players:Chat(msg)
			end
		else
			local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
			if chatEvents and chatEvents:FindFirstChild("SayMessageRequest") then
				chatEvents.SayMessageRequest:FireServer(msg, "All")
			else
				Players:Chat(msg)
			end
		end
	end)
end

local function getVerityHandle()
	local character = LocalPlayer.Character
	if not character then return nil end
	
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			if handle then
				local mesh = handle:FindFirstChildOfClass("SpecialMesh")
				if child.Name:lower():find("verity") or (mesh and mesh.MeshId:find(VERITY_HAT_ID)) then
					return handle
				end
			end
		end
	end
	
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") and child:FindFirstChild("Handle") then
			return child.Handle
		end
	end
	return nil
end

local function addYawOffset(degrees)
	if IS_BETA_FACE_CAM then
		BETA_YAW_OFFSET = BETA_YAW_OFFSET + degrees
	else
		CUSTOM_ROT_OFFSET = CUSTOM_ROT_OFFSET * CFrame.fromOrientation(0, math.rad(degrees), 0)
	end
end

local function addPitchOffset(degrees)
	CUSTOM_ROT_OFFSET = CUSTOM_ROT_OFFSET * CFrame.fromOrientation(math.rad(degrees), 0, 0)
end

-- ScreenGui Setup
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FEVerityGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true

if gethui then
	screenGui.Parent = gethui()
elseif syn and syn.protect_gui then
	syn.protect_gui(screenGui)
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
else
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

-- Main Frame
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 250, 0, 360)
frame.Position = UDim2.new(0.02, 0, 0.25, 0)
frame.BackgroundColor3 = DARK_MAIN_BG
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.ClipsDescendants = true
frame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent = frame

-- Title Header
local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.55, 0, 0, 32)
title.Position = UDim2.new(0.05, 0, 0, 0)
title.BackgroundTransparency = 1
title.Text = "FE Verity"
title.TextColor3 = YELLOW_GLOW
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

-- Settings Button (⚙)
local btnSettings = Instance.new("TextButton")
btnSettings.Size = UDim2.new(0, 26, 0, 24)
btnSettings.Position = UDim2.new(0.70, 0, 0.025, 0)
btnSettings.BackgroundColor3 = BTN_BG
btnSettings.Text = "⚙"
btnSettings.TextColor3 = YELLOW_GLOW
btnSettings.Font = Enum.Font.GothamBold
btnSettings.TextSize = 13
btnSettings.ZIndex = 25
btnSettings.Parent = frame

local setCorner = Instance.new("UICorner")
setCorner.CornerRadius = UDim.new(0, 6)
setCorner.Parent = btnSettings

-- Minimize Button (— / +)
local btnMinimize = Instance.new("TextButton")
btnMinimize.Size = UDim2.new(0, 26, 0, 24)
btnMinimize.Position = UDim2.new(0.83, 0, 0.025, 0)
btnMinimize.BackgroundColor3 = BTN_BG
btnMinimize.Text = "—"
btnMinimize.TextColor3 = YELLOW_GLOW
btnMinimize.Font = Enum.Font.GothamBold
btnMinimize.TextSize = 14
btnMinimize.ZIndex = 25
btnMinimize.Parent = frame

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 6)
minCorner.Parent = btnMinimize

-- Floating Settings Overlay Frame
local settingsFrame = Instance.new("Frame")
settingsFrame.Size = UDim2.new(0.9, 0, 0, 180)
settingsFrame.Position = UDim2.new(0.05, 0, 0.10, 0)
settingsFrame.BackgroundColor3 = PANEL_BG
settingsFrame.BorderSizePixel = 0
settingsFrame.Visible = false
settingsFrame.ZIndex = 15
settingsFrame.Parent = frame

local setFrameCorner = Instance.new("UICorner")
setFrameCorner.CornerRadius = UDim.new(0, 8)
setFrameCorner.Parent = settingsFrame

-- Settings Header Title
local setHeader = Instance.new("TextLabel")
setHeader.Size = UDim2.new(1, 0, 0, 24)
setHeader.Position = UDim2.new(0, 0, 0.02, 0)
setHeader.BackgroundTransparency = 1
setHeader.Text = "SETTINGS"
setHeader.TextColor3 = YELLOW_GLOW
setHeader.Font = Enum.Font.GothamBold
setHeader.TextSize = 12
setHeader.ZIndex = 16
setHeader.Parent = settingsFrame

-- Beta Toggle Button
local btnBetaToggle = Instance.new("TextButton")
btnBetaToggle.Size = UDim2.new(0.88, 0, 0, 32)
btnBetaToggle.Position = UDim2.new(0.06, 0, 0.18, 0)
btnBetaToggle.BackgroundColor3 = BTN_BG
btnBetaToggle.Text = "Beta Mode: OFF"
btnBetaToggle.TextColor3 = Color3.fromRGB(200, 200, 200)
btnBetaToggle.Font = Enum.Font.GothamBold
btnBetaToggle.TextSize = 11
btnBetaToggle.ZIndex = 16
btnBetaToggle.Parent = settingsFrame

local betaCorner = Instance.new("UICorner")
betaCorner.CornerRadius = UDim.new(0, 6)
betaCorner.Parent = btnBetaToggle

-- Settings 10-Degree Left / Right Yaw Adjusters
local function createYawAdjuster(labelText, posy, onLeft, onRight)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.5, 0, 0, 22)
	label.Position = UDim2.new(0.06, 0, posy, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = YELLOW_GLOW
	label.Font = Enum.Font.GothamSemibold
	label.TextSize = 10
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 16
	label.Parent = settingsFrame

	local btnLeft = Instance.new("TextButton")
	btnLeft.Size = UDim2.new(0, 32, 0, 22)
	btnLeft.Position = UDim2.new(0.56, 0, posy, 0)
	btnLeft.BackgroundColor3 = BTN_BG
	btnLeft.Text = "Left"
	btnLeft.TextColor3 = YELLOW_GLOW
	btnLeft.Font = Enum.Font.GothamBold
	btnLeft.TextSize = 10
	btnLeft.ZIndex = 16
	btnLeft.Parent = settingsFrame

	local decCorner = Instance.new("UICorner")
	decCorner.CornerRadius = UDim.new(0, 4)
	decCorner.Parent = btnLeft

	local btnRight = Instance.new("TextButton")
	btnRight.Size = UDim2.new(0, 32, 0, 22)
	btnRight.Position = UDim2.new(0.72, 0, posy, 0)
	btnRight.BackgroundColor3 = BTN_BG
	btnRight.Text = "Right"
	btnRight.TextColor3 = YELLOW_GLOW
	btnRight.Font = Enum.Font.GothamBold
	btnRight.TextSize = 10
	btnRight.ZIndex = 16
	btnRight.Parent = settingsFrame

	local incCorner = Instance.new("UICorner")
	incCorner.CornerRadius = UDim.new(0, 4)
	incCorner.Parent = btnRight

	btnLeft.Activated:Connect(onLeft)
	btnRight.Activated:Connect(onRight)
end

createYawAdjuster("Rotate Yaw (10°)", 0.50, function() addYawOffset(10) end, function() addYawOffset(-10) end)

-- Step 1: Net & Command Sequence Button
local btnGetHat = Instance.new("TextButton")
btnGetHat.Size = UDim2.new(0.9, 0, 0, 30)
btnGetHat.Position = UDim2.new(0.05, 0, 0.11, 0)
btnGetHat.BackgroundColor3 = BTN_BG
btnGetHat.Text = "1. Get Hat & Setup Net"
btnGetHat.TextColor3 = YELLOW_GLOW
btnGetHat.Font = Enum.Font.GothamSemibold
btnGetHat.TextSize = 12
btnGetHat.ZIndex = 1
btnGetHat.Parent = frame

local btnCorner1 = Instance.new("UICorner")
btnCorner1.CornerRadius = UDim.new(0, 6)
btnCorner1.Parent = btnGetHat

btnGetHat.Activated:Connect(function()
	btnGetHat.Text = "Sending -gh..."
	sendChatMessage("-gh " .. VERITY_HAT_ID)
	
	task.delay(1.3, function()
		btnGetHat.Text = "Sending -net..."
		sendChatMessage("-net")
		
		task.delay(1.3, function()
			btnGetHat.Text = "Sending -sh..."
			sendChatMessage("-sh")
			task.wait(0.5)
			btnGetHat.Text = "1. Get Hat & Setup Net"
		end)
	end)
end)

-- Step 2: Toggle Control Button
local btnControlHat = Instance.new("TextButton")
btnControlHat.Size = UDim2.new(0.9, 0, 0, 30)
btnControlHat.Position = UDim2.new(0.05, 0, 0.21, 0)
btnControlHat.BackgroundColor3 = YELLOW_GLOW
btnControlHat.Text = "2. Control / View Hat"
btnControlHat.TextColor3 = Color3.fromRGB(15, 15, 15)
btnControlHat.Font = Enum.Font.GothamBold
btnControlHat.TextSize = 12
btnControlHat.ZIndex = 1
btnControlHat.Parent = frame

local btnCorner2 = Instance.new("UICorner")
btnCorner2.CornerRadius = UDim.new(0, 6)
btnCorner2.Parent = btnControlHat

-- Main Rotation & Position Panel Frame
local rotPanel = Instance.new("Frame")
rotPanel.Size = UDim2.new(0.9, 0, 0, 240)
rotPanel.Position = UDim2.new(0.05, 0, 0.31, 0)
rotPanel.BackgroundColor3 = PANEL_BG
rotPanel.BorderSizePixel = 0
rotPanel.ZIndex = 1
rotPanel.Parent = frame

local rotCorner = Instance.new("UICorner")
rotCorner.CornerRadius = UDim.new(0, 8)
rotCorner.Parent = rotPanel

-- Holdable Button Builder
local function createHoldableButton(text, pos, size, action)
	local btn = Instance.new("TextButton")
	btn.Size = size
	btn.Position = pos
	btn.BackgroundColor3 = BTN_BG
	btn.Text = text
	btn.TextColor3 = YELLOW_GLOW
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 10
	btn.ZIndex = 2
	btn.Parent = rotPanel
	
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 5)
	c.Parent = btn

	local isPressing = false
	local holdThread = nil

	local function stopPressing()
		if not isPressing then return end
		isPressing = false
		btn.BackgroundColor3 = BTN_BG
		btn.TextColor3 = YELLOW_GLOW
		if holdThread then
			task.cancel(holdThread)
			holdThread = nil
		end
	end

	btn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if not IS_CONTROLLING then return end
			stopPressing()
			isPressing = true
			btn.BackgroundColor3 = YELLOW_GLOW
			btn.TextColor3 = Color3.fromRGB(15, 15, 15)
			
			action()
			
			holdThread = task.spawn(function()
				task.wait(INITIAL_HOLD_DELAY)
				while isPressing do
					action()
					task.wait(HOLD_REPEAT_RATE)
				end
			end)
		end
	end)

	btn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			stopPressing()
		end
	end)

	return btn
end

local function moveHatVertical(dirMultiplier)
	if ControlAnchor and ControlAnchor.Parent then
		local currentSpeed = getCurrentSpeed()
		ControlAnchor.CFrame = ControlAnchor.CFrame + Vector3.new(0, dirMultiplier * currentSpeed, 0)
	end
end

-- Outer Control Buttons (Pitch Inverted for Natural Pitch Up / Pitch Down)
createHoldableButton("Look Up", UDim2.new(0.04, 0, 0.05, 0), UDim2.new(0.44, 0, 0.16, 0), function() addPitchOffset(10) end)
createHoldableButton("Look Down", UDim2.new(0.52, 0, 0.05, 0), UDim2.new(0.44, 0, 0.16, 0), function() addPitchOffset(-10) end)

createHoldableButton("Yaw Left (+10°)", UDim2.new(0.04, 0, 0.25, 0), UDim2.new(0.44, 0, 0.16, 0), function() addYawOffset(10) end)
createHoldableButton("Yaw Right (-10°)", UDim2.new(0.52, 0, 0.25, 0), UDim2.new(0.44, 0, 0.16, 0), function() addYawOffset(-10) end)

createHoldableButton("Move Up (GUI)", UDim2.new(0.04, 0, 0.45, 0), UDim2.new(0.44, 0, 0.16, 0), function() moveHatVertical(1) end)
createHoldableButton("Move Down (GUI)", UDim2.new(0.52, 0, 0.45, 0), UDim2.new(0.44, 0, 0.16, 0), function() moveHatVertical(-1) end)

local btnResetRot = Instance.new("TextButton")
btnResetRot.Size = UDim2.new(0.92, 0, 0, 28)
btnResetRot.Position = UDim2.new(0.04, 0, 0.68, 0)
btnResetRot.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
btnResetRot.Text = "🔄 Reset Rotation"
btnResetRot.TextColor3 = Color3.fromRGB(255, 255, 255)
btnResetRot.Font = Enum.Font.GothamBold
btnResetRot.TextSize = 11
btnResetRot.ZIndex = 2
btnResetRot.Parent = rotPanel

local resetCorner = Instance.new("UICorner")
resetCorner.CornerRadius = UDim.new(0, 5)
resetCorner.Parent = btnResetRot

btnBetaToggle.Activated:Connect(function()
	IS_BETA_FACE_CAM = not IS_BETA_FACE_CAM
	if IS_BETA_FACE_CAM then
		btnBetaToggle.Text = "Beta Mode: ON (Shift Lock)"
		btnBetaToggle.BackgroundColor3 = YELLOW_GLOW
		btnBetaToggle.TextColor3 = Color3.fromRGB(15, 15, 15)
	else
		btnBetaToggle.Text = "Beta Mode: OFF"
		btnBetaToggle.BackgroundColor3 = BTN_BG
		btnBetaToggle.TextColor3 = Color3.fromRGB(200, 200, 200)
		
		if ControlAnchor and ControlAnchor.Parent then
			local currentPos = ControlAnchor.CFrame.Position
			ControlAnchor.CFrame = CFrame.new(currentPos)
		end
	end
end)

btnSettings.Activated:Connect(function()
	if IS_MINIMIZED then
		IS_MINIMIZED = false
		frame.Size = UDim2.new(0, 250, 0, 360)
		btnMinimize.Text = "—"
	end
	
	IS_SETTINGS_OPEN = not IS_SETTINGS_OPEN
	settingsFrame.Visible = IS_SETTINGS_OPEN
	btnSettings.BackgroundColor3 = IS_SETTINGS_OPEN and YELLOW_GLOW or BTN_BG
	btnSettings.TextColor3 = IS_SETTINGS_OPEN and Color3.fromRGB(15, 15, 15) or YELLOW_GLOW
end)

btnMinimize.Activated:Connect(function()
	IS_MINIMIZED = not IS_MINIMIZED
	if IS_MINIMIZED then
		frame.Size = UDim2.new(0, 250, 0, 32)
		btnMinimize.Text = "+"
		settingsFrame.Visible = false
	else
		frame.Size = UDim2.new(0, 250, 0, 360)
		btnMinimize.Text = "—"
		settingsFrame.Visible = IS_SETTINGS_OPEN
	end
end)

btnResetRot.Activated:Connect(function()
	BETA_YAW_OFFSET = 0
	CUSTOM_ROT_OFFSET = CFrame.identity
end)

local function stopHatControl()
	IS_CONTROLLING = false
	btnControlHat.Text = "2. Control / View Hat"
	btnControlHat.BackgroundColor3 = YELLOW_GLOW
	btnControlHat.TextColor3 = Color3.fromRGB(15, 15, 15)
	
	local char = LocalPlayer.Character
	if char then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then hrp.Anchored = false end
		
		local hum = char:FindFirstChild("Humanoid")
		if hum then Camera.CameraSubject = hum end
		
		if HatHandle and HatHandle.Parent then
			local targetPart = char:FindFirstChild("Head") or hrp
			if targetPart then
				HatHandle.CFrame = targetPart.CFrame
				local newWeld = Instance.new("WeldConstraint")
				newWeld.Name = "VerityReWeld"
				newWeld.Part0 = targetPart
				newWeld.Part1 = HatHandle
				newWeld.Parent = HatHandle
			end
		end
	end
	
	if HeartbeatConnection then
		HeartbeatConnection:Disconnect()
		HeartbeatConnection = nil
	end
	
	if MovementConnection then
		MovementConnection:Disconnect()
		MovementConnection = nil
	end
end

local function startHatControl()
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	
	HatHandle = getVerityHandle()
	if not HatHandle or not HatHandle.Parent then 
		btnControlHat.Text = "Hat Not Found!"
		task.wait(1)
		btnControlHat.Text = "2. Control / View Hat"
		return
	end
	
	IS_CONTROLLING = true
	btnControlHat.Text = "Cancel Control"
	btnControlHat.BackgroundColor3 = Color3.fromRGB(210, 45, 45)
	btnControlHat.TextColor3 = Color3.fromRGB(255, 255, 255)
	
	HatHandle.CanCollide = false
	
	local hrp = char.HumanoidRootPart
	hrp.Anchored = true
	
	for _, desc in ipairs(char:GetDescendants()) do
		if desc:IsA("Weld") or desc:IsA("WeldConstraint") or desc:IsA("Motor6D") then
			if desc.Part0 == HatHandle or desc.Part1 == HatHandle then
				desc:Destroy()
			end
		end
	end
	
	if not ControlAnchor or not ControlAnchor.Parent then
		ControlAnchor = Instance.new("Part")
		ControlAnchor.Name = "VerityAnchor"
		ControlAnchor.Size = Vector3.new(0.5, 0.5, 0.5)
		ControlAnchor.Transparency = 1
		ControlAnchor.CanCollide = false
		ControlAnchor.Anchored = true
		ControlAnchor.CFrame = hrp.CFrame * CFrame.new(0, 1, -4)
		ControlAnchor.Parent = workspace
	end
	
	Camera.CameraSubject = HatHandle
	
	if HeartbeatConnection then
		HeartbeatConnection:Disconnect()
		HeartbeatConnection = nil
	end

	HeartbeatConnection = RunService.Heartbeat:Connect(function()
		if HatHandle and HatHandle.Parent and ControlAnchor and ControlAnchor.Parent then
			HatHandle.CanCollide = false
			HatHandle.CFrame = ControlAnchor.CFrame * CUSTOM_ROT_OFFSET
			HatHandle.AssemblyLinearVelocity = Vector3.new(0, 25.05, 0)
			HatHandle.AssemblyAngularVelocity = Vector3.zero
		end
	end)

	if MovementConnection then
		MovementConnection:Disconnect()
		MovementConnection = nil
	end

	MovementConnection = RunService.RenderStepped:Connect(function()
		if not IS_CONTROLLING or not ControlAnchor or not ControlAnchor.Parent then return end
		if UserInputService:GetFocusedTextBox() ~= nil then return end
		
		-- Movement (WASD)
		local rawLook = Camera.CFrame.LookVector * Vector3.new(1, 0, 1)
		local rawRight = Camera.CFrame.RightVector * Vector3.new(1, 0, 1)
		
		local flatLook = rawLook.Magnitude > 0 and rawLook.Unit or Vector3.zero
		local flatRight = rawRight.Magnitude > 0 and rawRight.Unit or Vector3.zero
		
		local moveDir = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + flatLook end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - flatLook end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - flatRight end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + flatRight end
		
		if moveDir.Magnitude > 0 then
			local currentSpeed = getCurrentSpeed()
			ControlAnchor.CFrame = ControlAnchor.CFrame + (moveDir.Unit * currentSpeed)
		end
		
		-- Shift Lock Facing Alignment
		if IS_BETA_FACE_CAM then
			local pos = ControlAnchor.CFrame.Position
			local camLook = Camera.CFrame.LookVector
			local flatCamLook = (camLook * Vector3.new(1, 0, 1)).Unit
			
			local baseCFrame = CFrame.lookAt(pos, pos + flatCamLook)
			local betaOrient = baseCFrame * CFrame.Angles(0, math.rad(-90) + math.rad(BETA_YAW_OFFSET), 0)
			
			ControlAnchor.CFrame = betaOrient
		end
	end)
end

btnControlHat.Activated:Connect(function()
	if IS_CONTROLLING then
		stopHatControl()
	else
		startHatControl()
	end
end)

LocalPlayer.CharacterAdded:Connect(function()
	stopHatControl()
	if ControlAnchor then
		ControlAnchor:Destroy()
		ControlAnchor = nil
	end
end)
