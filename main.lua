--[[
	MOVEMENT RECORDER SYSTEM
	A complete client-side movement tracking and replay system for Roblox
	Place in: StarterPlayer > StarterPlayerScripts
	
	Features:
	- Continuous movement recording with state detection
	- Editable log GUI with individual entry management
	- Smooth replay system with speed controls
	- Save/Load system with JSON export
	- Modern, minimalist UI design
	
	Controls:
	- R: Toggle recording on/off
	- UI buttons for all other functions
]]

-- ========================================
-- SERVICES & VARIABLES
-- ========================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local camera = workspace.CurrentCamera

-- Recording state
local isRecording = false
local recordingStartTime = 0
local currentRecording = {}
local recordingConnection = nil
local stateConnection = nil
local lastAction = "Idle"

-- Replay state
local isReplaying = false
local replayConnection = nil
local replayPaused = false
local replayIndex = 1
local replaySpeed = 1

-- Saved recordings
local savedRecordings = {}

-- UI Elements (will be created later)
local mainGui = nil
local recordingButton = nil
local statusLabel = nil
local entryCountLabel = nil
local recordingTimeLabel = nil
local scrollingFrame = nil
local replayControlsFrame = nil
local savedRecordingsFrame = nil

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

-- Convert timestamp to readable time format
local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	local ms = math.floor((seconds % 1) * 100)
	return string.format("%02d:%02d.%02d", minutes, secs, ms)
end

-- Round number to specified decimal places
local function round(num, decimals)
	local mult = 10^(decimals or 0)
	return math.floor(num * mult + 0.5) / mult
end

-- Format Vector3 for display
local function formatVector3(vec)
	return string.format("%.1f, %.1f, %.1f", vec.X, vec.Y, vec.Z)
end

-- Get current humanoid state as string
local function getHumanoidAction(state)
	local stateMap = {
		[Enum.HumanoidStateType.Freefall] = "Falling",
		[Enum.HumanoidStateType.Flying] = "Flying",
		[Enum.HumanoidStateType.Jumping] = "Jumping",
		[Enum.HumanoidStateType.Climbing] = "Climbing",
		[Enum.HumanoidStateType.Swimming] = "Swimming",
		[Enum.HumanoidStateType.Running] = "Running",
		[Enum.HumanoidStateType.RunningNoPhysics] = "Running",
		[Enum.HumanoidStateType.Landed] = "Landed",
		[Enum.HumanoidStateType.Seated] = "Seated",
		[Enum.HumanoidStateType.Dead] = "Dead",
	}
	return stateMap[state] or "Idle"
end

-- ========================================
-- RECORDING FUNCTIONS
-- ========================================

-- Start recording player movements
local function startRecording()
	if isRecording then return end
	
	isRecording = true
	recordingStartTime = tick()
	currentRecording = {}
	lastAction = "Idle"
	
	-- Update UI
	recordingButton.Text = "⏹ Stop Recording"
	recordingButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	statusLabel.Text = "🔴 RECORDING"
	statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	
	-- Record movement data every frame
	recordingConnection = RunService.Heartbeat:Connect(function()
		if not isRecording then return end
		
		local currentTime = tick() - recordingStartTime
		local position = humanoidRootPart.Position
		local rotation = humanoidRootPart.CFrame
		
		-- Determine action based on velocity and state
		local action = lastAction
		if humanoid.MoveVector.Magnitude > 0 then
			action = humanoid.MoveSpeed > 16 and "Running" or "Walking"
		elseif humanoid.MoveVector.Magnitude == 0 and lastAction ~= "Jumping" and lastAction ~= "Falling" then
			action = "Idle"
		end
		
		-- Add entry to recording
		table.insert(currentRecording, {
			timestamp = currentTime,
			position = {position.X, position.Y, position.Z},
			action = action,
			rotation = {rotation:GetComponents()}, -- Store full CFrame
			cameraRotation = {camera.CFrame:GetComponents()}
		})
	end)
	
	-- Track state changes (jumping, climbing, etc.)
	stateConnection = humanoid.StateChanged:Connect(function(oldState, newState)
		lastAction = getHumanoidAction(newState)
	end)
	
	print("[Recorder] Recording started")
end

-- Stop recording
local function stopRecording()
	if not isRecording then return end
	
	isRecording = false
	
	if recordingConnection then
		recordingConnection:Disconnect()
		recordingConnection = nil
	end
	
	if stateConnection then
		stateConnection:Disconnect()
		stateConnection = nil
	end
	
	-- Update UI
	recordingButton.Text = "⏺ Start Recording"
	recordingButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	statusLabel.Text = "⚪ STOPPED"
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	
	-- Update entry count
	entryCountLabel.Text = "Entries: " .. #currentRecording
	
	-- Refresh the log display
	refreshLogDisplay()
	
	print("[Recorder] Recording stopped - " .. #currentRecording .. " entries")
end

-- Toggle recording on/off
local function toggleRecording()
	if isRecording then
		stopRecording()
	else
		startRecording()
	end
end

-- ========================================
-- GUI CREATION
-- ========================================

-- Create the main UI
local function createUI()
	-- Main ScreenGui
	mainGui = Instance.new("ScreenGui")
	mainGui.Name = "MovementRecorderGUI"
	mainGui.ResetOnSpawn = false
	mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mainGui.Parent = player.PlayerGui
	
	-- Main Frame (collapsible panel)
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 400, 0, 600)
	mainFrame.Position = UDim2.new(1, -420, 0, 20)
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = mainGui
	
	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 12)
	mainCorner.Parent = mainFrame
	
	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = Color3.fromRGB(60, 60, 70)
	mainStroke.Thickness = 2
	mainStroke.Parent = mainFrame
	
	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	header.BorderSizePixel = 0
	header.Parent = mainFrame
	
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = header
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 1, 0)
	titleLabel.Position = UDim2.new(0, 10, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🎬 Movement Recorder"
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = header
	
	-- Status Label
	statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(0, 120, 0, 30)
	statusLabel.Position = UDim2.new(1, -130, 0, 10)
	statusLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
	statusLabel.Text = "⚪ STOPPED"
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 12
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	statusLabel.Parent = header
	
	local statusCorner = Instance.new("UICorner")
	statusCorner.CornerRadius = UDim.new(0, 8)
	statusCorner.Parent = statusLabel
	
	-- Recording Controls Section
	local controlsFrame = Instance.new("Frame")
	controlsFrame.Name = "ControlsFrame"
	controlsFrame.Size = UDim2.new(1, -20, 0, 100)
	controlsFrame.Position = UDim2.new(0, 10, 0, 60)
	controlsFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	controlsFrame.BorderSizePixel = 0
	controlsFrame.Parent = mainFrame
	
	local controlsCorner = Instance.new("UICorner")
	controlsCorner.CornerRadius = UDim.new(0, 10)
	controlsCorner.Parent = controlsFrame
	
	-- Recording Button
	recordingButton = Instance.new("TextButton")
	recordingButton.Name = "RecordButton"
	recordingButton.Size = UDim2.new(1, -20, 0, 40)
	recordingButton.Position = UDim2.new(0, 10, 0, 10)
	recordingButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	recordingButton.Text = "⏺ Start Recording"
	recordingButton.Font = Enum.Font.GothamBold
	recordingButton.TextSize = 14
	recordingButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	recordingButton.Parent = controlsFrame
	
	local recButtonCorner = Instance.new("UICorner")
	recButtonCorner.CornerRadius = UDim.new(0, 8)
	recButtonCorner.Parent = recordingButton
	
	-- Info Labels
	entryCountLabel = Instance.new("TextLabel")
	entryCountLabel.Size = UDim2.new(0.5, -15, 0, 30)
	entryCountLabel.Position = UDim2.new(0, 10, 0, 60)
	entryCountLabel.BackgroundTransparency = 1
	entryCountLabel.Text = "Entries: 0"
	entryCountLabel.Font = Enum.Font.Gotham
	entryCountLabel.TextSize = 12
	entryCountLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	entryCountLabel.TextXAlignment = Enum.TextXAlignment.Left
	entryCountLabel.Parent = controlsFrame
	
	recordingTimeLabel = Instance.new("TextLabel")
	recordingTimeLabel.Size = UDim2.new(0.5, -15, 0, 30)
	recordingTimeLabel.Position = UDim2.new(0.5, 5, 0, 60)
	recordingTimeLabel.BackgroundTransparency = 1
	recordingTimeLabel.Text = "Time: 00:00.00"
	recordingTimeLabel.Font = Enum.Font.Gotham
	recordingTimeLabel.TextSize = 12
	recordingTimeLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	recordingTimeLabel.TextXAlignment = Enum.TextXAlignment.Right
	recordingTimeLabel.Parent = controlsFrame
	
	-- Log Section Header
	local logHeader = Instance.new("TextLabel")
	logHeader.Size = UDim2.new(1, -20, 0, 30)
	logHeader.Position = UDim2.new(0, 10, 0, 170)
	logHeader.BackgroundTransparency = 1
	logHeader.Text = "📋 Recording Log"
	logHeader.Font = Enum.Font.GothamBold
	logHeader.TextSize = 14
	logHeader.TextColor3 = Color3.fromRGB(255, 255, 255)
	logHeader.TextXAlignment = Enum.TextXAlignment.Left
	logHeader.Parent = mainFrame
	
	-- Clear All Button
	local clearAllButton = Instance.new("TextButton")
	clearAllButton.Size = UDim2.new(0, 80, 0, 25)
	clearAllButton.Position = UDim2.new(1, -100, 0, 172)
	clearAllButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	clearAllButton.Text = "Clear All"
	clearAllButton.Font = Enum.Font.Gotham
	clearAllButton.TextSize = 11
	clearAllButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	clearAllButton.Parent = mainFrame
	
	local clearCorner = Instance.new("UICorner")
	clearCorner.CornerRadius = UDim.new(0, 6)
	clearCorner.Parent = clearAllButton
	
	-- ScrollingFrame for log entries
	scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Name = "LogScrollFrame"
	scrollingFrame.Size = UDim2.new(1, -20, 0, 200)
	scrollingFrame.Position = UDim2.new(0, 10, 0, 205)
	scrollingFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.ScrollBarThickness = 6
	scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 90)
	scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollingFrame.Parent = mainFrame
	
	local scrollCorner = Instance.new("UICorner")
	scrollCorner.CornerRadius = UDim.new(0, 8)
	scrollCorner.Parent = scrollingFrame
	
	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
	scrollLayout.Padding = UDim.new(0, 5)
	scrollLayout.Parent = scrollingFrame
	
	-- Replay Controls Section
	replayControlsFrame = Instance.new("Frame")
	replayControlsFrame.Name = "ReplayFrame"
	replayControlsFrame.Size = UDim2.new(1, -20, 0, 140)
	replayControlsFrame.Position = UDim2.new(0, 10, 0, 415)
	replayControlsFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	replayControlsFrame.BorderSizePixel = 0
	replayControlsFrame.Parent = mainFrame
	
	local replayCorner = Instance.new("UICorner")
	replayCorner.CornerRadius = UDim.new(0, 10)
	replayCorner.Parent = replayControlsFrame
	
	local replayTitle = Instance.new("TextLabel")
	replayTitle.Size = UDim2.new(1, -20, 0, 25)
	replayTitle.Position = UDim2.new(0, 10, 0, 5)
	replayTitle.BackgroundTransparency = 1
	replayTitle.Text = "▶️ Replay Controls"
	replayTitle.Font = Enum.Font.GothamBold
	replayTitle.TextSize = 13
	replayTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	replayTitle.TextXAlignment = Enum.TextXAlignment.Left
	replayTitle.Parent = replayControlsFrame
	
	-- Play Button
	local playButton = Instance.new("TextButton")
	playButton.Name = "PlayButton"
	playButton.Size = UDim2.new(0.32, -5, 0, 35)
	playButton.Position = UDim2.new(0, 10, 0, 35)
	playButton.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
	playButton.Text = "▶ Play"
	playButton.Font = Enum.Font.GothamBold
	playButton.TextSize = 13
	playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	playButton.Parent = replayControlsFrame
	
	local playCorner = Instance.new("UICorner")
	playCorner.CornerRadius = UDim.new(0, 7)
	playCorner.Parent = playButton
	
	-- Pause Button
	local pauseButton = Instance.new("TextButton")
	pauseButton.Name = "PauseButton"
	pauseButton.Size = UDim2.new(0.32, -5, 0, 35)
	pauseButton.Position = UDim2.new(0.34, 0, 0, 35)
	pauseButton.BackgroundColor3 = Color3.fromRGB(220, 150, 50)
	pauseButton.Text = "⏸ Pause"
	pauseButton.Font = Enum.Font.GothamBold
	pauseButton.TextSize = 13
	pauseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	pauseButton.Parent = replayControlsFrame
	
	local pauseCorner = Instance.new("UICorner")
	pauseCorner.CornerRadius = UDim.new(0, 7)
	pauseCorner.Parent = pauseButton
	
	-- Stop Button
	local stopButton = Instance.new("TextButton")
	stopButton.Name = "StopButton"
	stopButton.Size = UDim2.new(0.32, -5, 0, 35)
	stopButton.Position = UDim2.new(0.68, 0, 0, 35)
	stopButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	stopButton.Text = "⏹ Stop"
	stopButton.Font = Enum.Font.GothamBold
	stopButton.TextSize = 13
	stopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	stopButton.Parent = replayControlsFrame
	
	local stopCorner = Instance.new("UICorner")
	stopCorner.CornerRadius = UDim.new(0, 7)
	stopCorner.Parent = stopButton
	
	-- Speed Label
	local speedLabel = Instance.new("TextLabel")
	speedLabel.Name = "SpeedLabel"
	speedLabel.Size = UDim2.new(1, -20, 0, 20)
	speedLabel.Position = UDim2.new(0, 10, 0, 80)
	speedLabel.BackgroundTransparency = 1
	speedLabel.Text = "Speed: 1.00x"
	speedLabel.Font = Enum.Font.Gotham
	speedLabel.TextSize = 11
	speedLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel.Parent = replayControlsFrame
	
	-- Speed Slider
	local speedSlider = Instance.new("Frame")
	speedSlider.Name = "SpeedSlider"
	speedSlider.Size = UDim2.new(1, -20, 0, 20)
	speedSlider.Position = UDim2.new(0, 10, 0, 105)
	speedSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
	speedSlider.BorderSizePixel = 0
	speedSlider.Parent = replayControlsFrame
	
	local sliderCorner = Instance.new("UICorner")
	sliderCorner.CornerRadius = UDim.new(0, 10)
	sliderCorner.Parent = speedSlider
	
	local speedFill = Instance.new("Frame")
	speedFill.Name = "Fill"
	speedFill.Size = UDim2.new(0.36, 0, 1, 0) -- 0.36 = (1.0 - 0.25) / (3.0 - 0.25)
	speedFill.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
	speedFill.BorderSizePixel = 0
	speedFill.Parent = speedSlider
	
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 10)
	fillCorner.Parent = speedFill
	
	-- Save/Load Section (bottom)
	savedRecordingsFrame = Instance.new("ScrollingFrame")
	savedRecordingsFrame.Name = "SavedRecordingsFrame"
	savedRecordingsFrame.Size = UDim2.new(1, -20, 0, 0)
	savedRecordingsFrame.Position = UDim2.new(0, 10, 1, -10)
	savedRecordingsFrame.AnchorPoint = Vector2.new(0, 1)
	savedRecordingsFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	savedRecordingsFrame.BorderSizePixel = 0
	savedRecordingsFrame.ScrollBarThickness = 4
	savedRecordingsFrame.Visible = false
	savedRecordingsFrame.Parent = mainFrame
	
	-- Save/Load Button (toggle)
	local saveLoadToggle = Instance.new("TextButton")
	saveLoadToggle.Size = UDim2.new(0, 120, 0, 30)
	saveLoadToggle.Position = UDim2.new(0, 10, 1, -40)
	saveLoadToggle.AnchorPoint = Vector2.new(0, 1)
	saveLoadToggle.BackgroundColor3 = Color3.fromRGB(100, 70, 180)
	saveLoadToggle.Text = "💾 Save/Load"
	saveLoadToggle.Font = Enum.Font.GothamBold
	saveLoadToggle.TextSize = 12
	saveLoadToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	saveLoadToggle.Parent = mainFrame
	
	local saveCorner = Instance.new("UICorner")
	saveCorner.CornerRadius = UDim.new(0, 8)
	saveCorner.Parent = saveLoadToggle
	
	-- Export Button
	local exportButton = Instance.new("TextButton")
	exportButton.Size = UDim2.new(0, 120, 0, 30)
	exportButton.Position = UDim2.new(0, 140, 1, -40)
	exportButton.AnchorPoint = Vector2.new(0, 1)
	exportButton.BackgroundColor3 = Color3.fromRGB(70, 140, 180)
	exportButton.Text = "📤 Export JSON"
	exportButton.Font = Enum.Font.GothamBold
	exportButton.TextSize = 12
	exportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	exportButton.Parent = mainFrame
	
	local exportCorner = Instance.new("UICorner")
	exportCorner.CornerRadius = UDim.new(0, 8)
	exportCorner.Parent = exportButton
	
	-- Import Button
	local importButton = Instance.new("TextButton")
	importButton.Size = UDim2.new(0, 120, 0, 30)
	importButton.Position = UDim2.new(0, 270, 1, -40)
	importButton.AnchorPoint = Vector2.new(0, 1)
	importButton.BackgroundColor3 = Color3.fromRGB(180, 140, 70)
	importButton.Text = "📥 Import JSON"
	importButton.Font = Enum.Font.GothamBold
	importButton.TextSize = 12
	importButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	importButton.Parent = mainFrame
	
	local importCorner = Instance.new("UICorner")
	importCorner.CornerRadius = UDim.new(0, 8)
	importCorner.Parent = importButton
	
	-- ========================================
	-- BUTTON CONNECTIONS
	-- ========================================
	
	-- Recording button
	recordingButton.MouseButton1Click:Connect(toggleRecording)
	
	-- Clear all button
	clearAllButton.MouseButton1Click:Connect(function()
		currentRecording = {}
		refreshLogDisplay()
		entryCountLabel.Text = "Entries: 0"
		print("[Recorder] All entries cleared")
	end)
	
	-- Play button
	playButton.MouseButton1Click:Connect(function()
		if #currentRecording == 0 then
			warn("[Recorder] No recording to replay")
			return
		end
		startReplay()
	end)
	
	-- Pause button
	pauseButton.MouseButton1Click:Connect(function()
		if isReplaying then
			replayPaused = not replayPaused
			pauseButton.Text = replayPaused and "▶ Resume" or "⏸ Pause"
		end
	end)
	
	-- Stop button
	stopButton.MouseButton1Click:Connect(function()
		stopReplay()
	end)
	
	-- Speed slider interaction
	local draggingSlider = false
	
	speedSlider.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingSlider = true
			updateSpeedSlider(input.Position.X)
		end
	end)
	
	speedSlider.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingSlider = false
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateSpeedSlider(input.Position.X)
		end
	end)
	
	-- Speed slider update function
	function updateSpeedSlider(mouseX)
		local sliderPos = speedSlider.AbsolutePosition.X
		local sliderSize = speedSlider.AbsoluteSize.X
		local relativeX = math.clamp((mouseX - sliderPos) / sliderSize, 0, 1)
		
		-- Map to speed range 0.25x to 3x
		replaySpeed = 0.25 + (relativeX * 2.75)
		speedFill.Size = UDim2.new(relativeX, 0, 1, 0)
		speedLabel.Text = string.format("Speed: %.2fx", replaySpeed)
	end
	
	-- Export button
	exportButton.MouseButton1Click:Connect(function()
		exportRecording()
	end)
	
	-- Import button
	importButton.MouseButton1Click:Connect(function()
		importRecording()
	end)
	
	-- Save/Load toggle
	saveLoadToggle.MouseButton1Click:Connect(function()
		savedRecordingsFrame.Visible = not savedRecordingsFrame.Visible
		if savedRecordingsFrame.Visible then
			savedRecordingsFrame:TweenSize(UDim2.new(1, -20, 0, 150), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
		else
			savedRecordingsFrame:TweenSize(UDim2.new(1, -20, 0, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
		end
	end)
	
	print("[Recorder] UI Created Successfully")
end

-- ========================================
-- LOG DISPLAY FUNCTIONS
-- ========================================

-- Refresh the log display
function refreshLogDisplay()
	-- Clear existing entries
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Display last 50 entries (performance optimization)
	local displayCount = math.min(#currentRecording, 50)
	local startIndex = math.max(1, #currentRecording - displayCount + 1)
	
	for i = startIndex, #currentRecording do
		local entry = currentRecording[i]
		createLogEntry(entry, i)
	end
	
	-- Update canvas size
	local layout = scrollingFrame:FindFirstChildOfClass("UIListLayout")
	if layout then
		scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end
	
	-- Scroll to bottom
	scrollingFrame.CanvasPosition = Vector2.new(0, scrollingFrame.CanvasSize.Y.Offset)
end

-- Create a single log entry UI element
function createLogEntry(entry, index)
	local entryFrame = Instance.new("Frame")
	entryFrame.Name = "Entry_" .. index
	entryFrame.Size = UDim2.new(1, -10, 0, 60)
	entryFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	entryFrame.BorderSizePixel = 0
	entryFrame.LayoutOrder = index
	entryFrame.Parent = scrollingFrame
	
	local entryCorner = Instance.new("UICorner")
	entryCorner.CornerRadius = UDim.new(0, 6)
	entryCorner.Parent = entryFrame
	
	-- Time label
	local timeLabel = Instance.new("TextLabel")
	timeLabel.Size = UDim2.new(0, 70, 0, 15)
	timeLabel.Position = UDim2.new(0, 8, 0, 5)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Text = formatTime(entry.timestamp)
	timeLabel.Font = Enum.Font.GothamMedium
	timeLabel.TextSize = 11
	timeLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
	timeLabel.TextXAlignment = Enum.TextXAlignment.Left
	timeLabel.Parent = entryFrame
	
	-- Action label
	local actionLabel = Instance.new("TextLabel")
	actionLabel.Size = UDim2.new(0, 70, 0, 15)
	actionLabel.Position = UDim2.new(1, -78, 0, 5)
	actionLabel.BackgroundColor3 = Color3.fromRGB(60, 100, 180)
	actionLabel.Text = entry.action
	actionLabel.Font = Enum.Font.GothamBold
	actionLabel.TextSize = 10
	actionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	actionLabel.Parent = entryFrame
	
	local actionCorner = Instance.new("UICorner")
	actionCorner.CornerRadius = UDim.new(0, 4)
	actionCorner.Parent = actionLabel
	
	-- Position label
	local posLabel = Instance.new("TextLabel")
	posLabel.Size = UDim2.new(1, -16, 0, 15)
	posLabel.Position = UDim2.new(0, 8, 0, 25)
	posLabel.BackgroundTransparency = 1
	posLabel.Text = "Pos: " .. formatVector3(Vector3.new(entry.position[1], entry.position[2], entry.position[3]))
	posLabel.Font = Enum.Font.Gotham
	posLabel.TextSize = 10
	posLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	posLabel.TextXAlignment = Enum.TextXAlignment.Left
	posLabel.TextTruncate = Enum.TextTruncate.AtEnd
	posLabel.Parent = entryFrame
	
	-- Delete button
	local deleteButton = Instance.new("TextButton")
	deleteButton.Size = UDim2.new(0, 60, 0, 20)
	deleteButton.Position = UDim2.new(0, 8, 1, -25)
	deleteButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	deleteButton.Text = "Delete"
	deleteButton.Font = Enum.Font.Gotham
	deleteButton.TextSize = 9
	deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	deleteButton.Parent = entryFrame
	
	local delCorner = Instance.new("UICorner")
	delCorner.CornerRadius = UDim.new(0, 4)
	delCorner.Parent = deleteButton
	
	deleteButton.MouseButton1Click:Connect(function()
		table.remove(currentRecording, index)
		refreshLogDisplay()
		entryCountLabel.Text = "Entries: " .. #currentRecording
	end)
	
	-- Edit button
	local editButton = Instance.new("TextButton")
	editButton.Size = UDim2.new(0, 60, 0, 20)
	editButton.Position = UDim2.new(0, 75, 1, -25)
	editButton.BackgroundColor3 = Color3.fromRGB(80, 120, 180)
	editButton.Text = "Edit"
	editButton.Font = Enum.Font.Gotham
	editButton.TextSize = 9
	editButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	editButton.Parent = entryFrame
	
	local editCorner = Instance.new("UICorner")
	editCorner.CornerRadius = UDim.new(0, 4)
	editCorner.Parent = editButton
	
	editButton.MouseButton1Click:Connect(function()
		-- Simple edit: prompt for new action type
		local newAction = promptForAction()
		if newAction then
			entry.action = newAction
			refreshLogDisplay()
		end
	end)
end

-- Simple action selector (cycles through actions)
function promptForAction()
	local actions = {"Idle", "Walking", "Running", "Jumping", "Climbing", "Swimming", "Falling"}
	-- In a full implementation, you'd create a popup UI
	-- For simplicity, we'll just cycle through
	print("[Recorder] Edit feature: Create a custom input UI for full functionality")
	return actions[math.random(1, #actions)]
end

-- ========================================
-- REPLAY FUNCTIONS
-- ========================================

-- Start replaying the recording
function startReplay()
	if isReplaying then return end
	if #currentRecording == 0 then
		warn("[Recorder] No recording to replay")
		return
	end
	
	isReplaying = true
	replayPaused = false
	replayIndex = 1
	
	print("[Recorder] Starting replay with " .. #currentRecording .. " entries")
	
	-- Optional: Make character semi-transparent during replay
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = part.Transparency + 0.3
		end
	end
	
	-- Disable character control during replay
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	
	local startTime = tick()
	
	replayConnection = RunService.Heartbeat:Connect(function()
		if not isReplaying or replayPaused then return end
		
		local elapsed = (tick() - startTime) * replaySpeed
		
		-- Find the appropriate entry for current time
		while replayIndex <= #currentRecording do
			local entry = currentRecording[replayIndex]
			
			if entry.timestamp > elapsed then
				break
			end
			
			-- Move character to this position
			local targetPos = Vector3.new(entry.position[1], entry.position[2], entry.position[3])
			
			-- Smooth interpolation to next position
			if replayIndex < #currentRecording then
				local nextEntry = currentRecording[replayIndex + 1]
				local nextPos = Vector3.new(nextEntry.position[1], nextEntry.position[2], nextEntry.position[3])
				local timeDiff = nextEntry.timestamp - entry.timestamp
				
				if timeDiff > 0 then
					local alpha = (elapsed - entry.timestamp) / timeDiff
					alpha = math.clamp(alpha, 0, 1)
					targetPos = targetPos:Lerp(nextPos, alpha)
				end
			end
			
			-- Apply position with smooth movement
			local success, err = pcall(function()
				humanoidRootPart.CFrame = CFrame.new(targetPos) * CFrame.Angles(0, math.rad(entry.rotation[6] or 0), 0)
			end)
			
			if not success then
				warn("[Recorder] Replay error:", err)
			end
			
			replayIndex = replayIndex + 1
		end
		
		-- Check if replay finished
		if replayIndex > #currentRecording then
			stopReplay()
		end
	end)
end

-- Stop replay
function stopReplay()
	if not isReplaying then return end
	
	isReplaying = false
	replayPaused = false
	
	if replayConnection then
		replayConnection:Disconnect()
		replayConnection = nil
	end
	
	-- Restore character visibility
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency > 0 then
			part.Transparency = math.max(0, part.Transparency - 0.3)
		end
	end
	
	-- Re-enable character control
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50
	
	print("[Recorder] Replay stopped")
end

-- ========================================
-- SAVE/LOAD FUNCTIONS
-- ========================================

-- Export recording as JSON
function exportRecording()
	if #currentRecording == 0 then
		warn("[Recorder] No recording to export")
		return
	end
	
	local success, jsonString = pcall(function()
		return HttpService:JSONEncode({
			version = "1.0",
			recordingName = "Recording_" .. os.date("%Y%m%d_%H%M%S"),
			entryCount = #currentRecording,
			data = currentRecording
		})
	end)
	
	if success then
		-- Try to copy to clipboard (may not work in all contexts)
		local clipboardSuccess = pcall(function()
			if setclipboard then
				setclipboard(jsonString)
				print("[Recorder] Recording exported and copied to clipboard!")
			else
				print("[Recorder] Recording exported (clipboard not available):")
				print(jsonString)
			end
		end)
		
		if not clipboardSuccess then
			print("[Recorder] Export successful. JSON output:")
			print(jsonString)
		end
	else
		warn("[Recorder] Failed to export recording:", jsonString)
	end
end

-- Import recording from JSON
function importRecording()
	-- In a full implementation, you'd create an input textbox
	-- For now, we'll just log instructions
	print("[Recorder] Import feature: Paste JSON in console or create input UI")
	warn("[Recorder] To implement: Create a TextBox for JSON input in the UI")
	
	-- Example of how to parse:
	-- local success, data = pcall(function()
	--     return HttpService:JSONDecode(jsonString)
	-- end)
	-- if success and data.data then
	--     currentRecording = data.data
	--     refreshLogDisplay()
	-- end
end

-- Save current recording to saved list
function saveRecordingToList(name)
	if #currentRecording == 0 then
		warn("[Recorder] No recording to save")
		return
	end
	
	local recordingCopy = {}
	for i, entry in ipairs(currentRecording) do
		recordingCopy[i] = {
			timestamp = entry.timestamp,
			position = {entry.position[1], entry.position[2], entry.position[3]},
			action = entry.action,
			rotation = entry.rotation,
			cameraRotation = entry.cameraRotation
		}
	end
	
	table.insert(savedRecordings, {
		name = name or ("Recording_" .. #savedRecordings + 1),
		data = recordingCopy,
		timestamp = os.time()
	})
	
	print("[Recorder] Recording saved:", name)
end

-- ========================================
-- UPDATE FUNCTIONS
-- ========================================

-- Update recording time display
RunService.Heartbeat:Connect(function()
	if isRecording then
		local elapsed = tick() - recordingStartTime
		recordingTimeLabel.Text = "Time: " .. formatTime(elapsed)
		
		-- Update log periodically (every 30 entries)
		if #currentRecording % 30 == 0 then
			task.spawn(refreshLogDisplay)
		end
	end
end)

-- ========================================
-- INPUT HANDLING
-- ========================================

-- Handle keybinds
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- R key to toggle recording
	if input.KeyCode == Enum.KeyCode.R then
		toggleRecording()
	end
end)

-- Handle character respawn
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	
	-- Stop any active recording or replay
	if isRecording then
		stopRecording()
	end
	if isReplaying then
		stopReplay()
	end
	
	-- Reconnect state tracking
	if stateConnection then
		stateConnection:Disconnect()
	end
	stateConnection = humanoid.StateChanged:Connect(function(oldState, newState)
		if isRecording then
			lastAction = getHumanoidAction(newState)
		end
	end)
	
	print("[Recorder] Character respawned - system ready")
end)

-- ========================================
-- INITIALIZATION
-- ========================================

-- Create UI on startup
createUI()

-- Initial state setup
print("[Recorder] Movement Recorder System Initialized")
print("[Recorder] Press R to start/stop recording")
print("[Recorder] Use UI for replay and save/load functions")

-- Success indicator
wait(1)
if mainGui and mainGui.Parent then
	print("✓ [Recorder] System fully operational!")
end
