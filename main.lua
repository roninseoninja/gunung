--[[
	MOVEMENT RECORDER SYSTEM v3.0 - NATURAL WALKING
	Combines advanced GUI with TRUE natural walking (no teleporting!)
	Place in: StarterPlayer > StarterPlayerScripts
	
	Key Features:
	- Natural walking using Humanoid:MoveTo() - NO TELEPORTING!
	- Draggable GUI with minimize/maximize
	- Waypoint-based recording system
	- Smooth replay with adjustable speed
	- Modern, polished UI
	
	Controls:
	- R: Toggle recording on/off
	- RIGHT SHIFT: Toggle GUI visibility
	- Drag header to move GUI
	- Click minimize button to collapse to icon
]]

print("=== Movement Recorder v3.0 - Natural Walking Edition ===")

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
local isPlaying = false
local recordingStartTime = 0
local currentRecording = {}
local recordConnection = nil
local playConnection = nil
local recordInterval = 0.2 -- Record waypoint every 0.2 seconds
local timeSinceLastRecord = 0

-- Playback state
local playbackSpeed = 1
local currentWaypoint = 1
local moveTimeout = 0
local maxMoveTimeout = 5
local originalWalkSpeed = 16

-- Saved recordings
local savedRecordings = {}

-- UI Elements
local mainGui = nil
local mainFrame = nil
local minimizedIcon = nil
local recordingButton = nil
local statusLabel = nil
local waypointCountLabel = nil
local recordingTimeLabel = nil
local scrollingFrame = nil
local playButton = nil
local stopButton = nil
local pauseButton = nil
local speedLabel = nil
local isMinimized = false

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

-- Format time as MM:SS.ms
local function formatTime(seconds)
	local minutes = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	local ms = math.floor((seconds % 1) * 100)
	return string.format("%02d:%02d.%02d", minutes, secs, ms)
end

-- Format Vector3 for display
local function formatVector3(vec)
	return string.format("%.1f, %.1f, %.1f", vec.X, vec.Y, vec.Z)
end

-- ========================================
-- GUI DRAG FUNCTIONS
-- ========================================

local function makeDraggable(frame, dragHandle)
	local dragging = false
	local dragInput = nil
	local dragStart = nil
	local startPos = nil
	
	local function update(input)
		local delta = input.Position - dragStart
		local newPosition = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
		frame.Position = newPosition
	end
	
	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	
	dragHandle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			update(input)
		end
	end)
end

local function minimizeGUI()
	if not mainFrame or not minimizedIcon then return end
	
	isMinimized = true
	
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	local tween = TweenService:Create(mainFrame, tweenInfo, {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(mainFrame.Position.X.Scale, mainFrame.Position.X.Offset + 200, mainFrame.Position.Y.Scale, mainFrame.Position.Y.Offset)
	})
	tween:Play()
	
	tween.Completed:Connect(function()
		mainFrame.Visible = false
	end)
	
	minimizedIcon.Visible = true
	minimizedIcon.Size = UDim2.new(0, 0, 0, 0)
	
	local iconTween = TweenService:Create(minimizedIcon, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 60, 0, 60)
	})
	iconTween:Play()
end

local function maximizeGUI()
	if not mainFrame or not minimizedIcon then return end
	
	isMinimized = false
	
	local iconTween = TweenService:Create(minimizedIcon, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0)
	})
	iconTween:Play()
	
	iconTween.Completed:Connect(function()
		minimizedIcon.Visible = false
	end)
	
	mainFrame.Visible = true
	mainFrame.Size = UDim2.new(0, 0, 0, 0)
	
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local tween = TweenService:Create(mainFrame, tweenInfo, {
		Size = UDim2.new(0, 400, 0, 550)
	})
	tween:Play()
end

-- ========================================
-- RECORDING FUNCTIONS (NATURAL WALKING)
-- ========================================

local function startRecording()
	if isRecording or isPlaying then return end
	
	if not humanoidRootPart or not humanoid then
		warn("[Recorder] Character not ready!")
		return
	end
	
	isRecording = true
	recordingStartTime = tick()
	currentRecording = {}
	timeSinceLastRecord = 0
	
	-- Update UI
	if recordingButton then
		recordingButton.Text = "⏹ STOP RECORDING"
		recordingButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	end
	if statusLabel then
		statusLabel.Text = "🔴 RECORDING"
		statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	end
	
	-- Show recording indicator on minimized icon
	if minimizedIcon then
		local indicator = minimizedIcon:FindFirstChild("RecordingIndicator")
		if indicator then
			indicator.Visible = true
			-- Pulse animation
			task.spawn(function()
				while isRecording do
					TweenService:Create(indicator, TweenInfo.new(0.5), {BackgroundColor3 = Color3.fromRGB(255, 150, 150)}):Play()
					wait(0.5)
					TweenService:Create(indicator, TweenInfo.new(0.5), {BackgroundColor3 = Color3.fromRGB(255, 50, 50)}):Play()
					wait(0.5)
				end
			end)
		end
	end
	
	print("[Recorder] Recording started - Using natural waypoint system")
	
	-- Record waypoints at intervals
	recordConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if not isRecording then return end
		
		if not humanoidRootPart or not humanoidRootPart.Parent then
			warn("[Recorder] Character missing, stopping recording")
			stopRecording()
			return
		end
		
		timeSinceLastRecord = timeSinceLastRecord + deltaTime
		
		-- Record waypoint at interval
		if timeSinceLastRecord >= recordInterval then
			local waypoint = {
				Position = humanoidRootPart.Position,
				LookVector = humanoidRootPart.CFrame.LookVector,
				IsJumping = humanoid:GetState() == Enum.HumanoidStateType.Jumping or 
				           humanoid:GetState() == Enum.HumanoidStateType.Freefall,
				Timestamp = tick() - recordingStartTime
			}
			
			table.insert(currentRecording, waypoint)
			timeSinceLastRecord = 0
			
			-- Debug output every 10 waypoints
			if #currentRecording % 10 == 0 then
				print("[Recorder] Recorded " .. #currentRecording .. " waypoints")
			end
		end
	end)
end

local function stopRecording()
	if not isRecording then return end
	
	isRecording = false
	
	if recordConnection then
		recordConnection:Disconnect()
		recordConnection = nil
	end
	
	-- Update UI
	if recordingButton then
		recordingButton.Text = "⏺ START RECORDING"
		recordingButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	end
	if statusLabel then
		statusLabel.Text = "⚪ STOPPED"
		statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
	
	-- Hide recording indicator
	if minimizedIcon then
		local indicator = minimizedIcon:FindFirstChild("RecordingIndicator")
		if indicator then
			indicator.Visible = false
		end
	end
	
	-- Update waypoint count
	if waypointCountLabel then
		waypointCountLabel.Text = "Waypoints: " .. #currentRecording
	end
	
	-- Refresh display
	task.spawn(refreshLogDisplay)
	
	print("[Recorder] Recording stopped - " .. #currentRecording .. " waypoints captured")
	print("[Recorder] Method: Natural walking with Humanoid:MoveTo()")
end

local function toggleRecording()
	if isRecording then
		stopRecording()
	else
		startRecording()
	end
end

-- ========================================
-- REPLAY FUNCTIONS (NATURAL WALKING)
-- ========================================

local function startPlayback()
	if isRecording or isPlaying or #currentRecording == 0 then
		warn("[Recorder] Cannot play: recording empty or already playing")
		return
	end
	
	print("[Recorder] Starting natural walking playback with " .. #currentRecording .. " waypoints")
	isPlaying = true
	currentWaypoint = 1
	moveTimeout = 0
	originalWalkSpeed = humanoid.WalkSpeed
	
	-- Update UI
	if playButton then
		playButton.Text = "▶ PLAYING..."
		playButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	end
	if statusLabel then
		statusLabel.Text = "▶ PLAYING"
		statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	end
	
	-- Apply playback speed to walk speed
	humanoid.WalkSpeed = originalWalkSpeed * playbackSpeed
	
	playConnection = RunService.Heartbeat:Connect(function(deltaTime)
		if currentWaypoint > #currentRecording then
			print("[Recorder] Playback complete!")
			stopPlayback()
			return
		end
		
		local waypoint = currentRecording[currentWaypoint]
		local distanceToWaypoint = (waypoint.Position - humanoidRootPart.Position).Magnitude
		
		-- THIS IS THE KEY: Use MoveTo for natural walking!
		humanoid:MoveTo(waypoint.Position)
		
		-- Handle jumping
		if waypoint.IsJumping then
			local state = humanoid:GetState()
			if state ~= Enum.HumanoidStateType.Jumping and 
			   state ~= Enum.HumanoidStateType.Freefall then
				humanoid.Jump = true
			end
		end
		
		-- Check if reached waypoint
		moveTimeout = moveTimeout + deltaTime
		if distanceToWaypoint < 3 or moveTimeout > maxMoveTimeout then
			currentWaypoint = currentWaypoint + 1
			moveTimeout = 0
			
			-- Update progress
			if waypointCountLabel then
				waypointCountLabel.Text = string.format("Waypoints: %d / %d", currentWaypoint, #currentRecording)
			end
		end
	end)
end

local function stopPlayback()
	if not isPlaying then return end
	
	isPlaying = false
	
	if playConnection then
		playConnection:Disconnect()
		playConnection = nil
	end
	
	-- Restore original walk speed
	humanoid.WalkSpeed = originalWalkSpeed
	
	-- Update UI
	if playButton then
		playButton.Text = "▶ PLAY"
		playButton.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
	end
	if statusLabel then
		statusLabel.Text = "⚪ STOPPED"
		statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
	if waypointCountLabel then
		waypointCountLabel.Text = "Waypoints: " .. #currentRecording
	end
	
	print("[Recorder] Playback stopped")
end

-- ========================================
-- LOG DISPLAY FUNCTIONS
-- ========================================

function refreshLogDisplay()
	if not scrollingFrame then return end
	
	-- Clear existing entries
	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	
	-- Display last 30 waypoints
	local displayCount = math.min(#currentRecording, 30)
	local startIndex = math.max(1, #currentRecording - displayCount + 1)
	
	for i = startIndex, #currentRecording do
		local waypoint = currentRecording[i]
		createWaypointEntry(waypoint, i)
	end
	
	-- Update canvas size
	local layout = scrollingFrame:FindFirstChildOfClass("UIListLayout")
	if layout then
		scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end
	
	scrollingFrame.CanvasPosition = Vector2.new(0, scrollingFrame.CanvasSize.Y.Offset)
end

function createWaypointEntry(waypoint, index)
	local entryFrame = Instance.new("Frame")
	entryFrame.Name = "Waypoint_" .. index
	entryFrame.Size = UDim2.new(1, -10, 0, 55)
	entryFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	entryFrame.BorderSizePixel = 0
	entryFrame.LayoutOrder = index
	entryFrame.Parent = scrollingFrame
	
	local entryCorner = Instance.new("UICorner")
	entryCorner.CornerRadius = UDim.new(0, 6)
	entryCorner.Parent = entryFrame
	
	-- Waypoint number
	local numberLabel = Instance.new("TextLabel")
	numberLabel.Size = UDim2.new(0, 50, 0, 15)
	numberLabel.Position = UDim2.new(0, 8, 0, 5)
	numberLabel.BackgroundTransparency = 1
	numberLabel.Text = "#" .. index
	numberLabel.Font = Enum.Font.GothamBold
	numberLabel.TextSize = 11
	numberLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
	numberLabel.TextXAlignment = Enum.TextXAlignment.Left
	numberLabel.Parent = entryFrame
	
	-- Time label
	local timeLabel = Instance.new("TextLabel")
	timeLabel.Size = UDim2.new(0, 70, 0, 15)
	timeLabel.Position = UDim2.new(0, 60, 0, 5)
	timeLabel.BackgroundTransparency = 1
	timeLabel.Text = formatTime(waypoint.Timestamp)
	timeLabel.Font = Enum.Font.Gotham
	timeLabel.TextSize = 10
	timeLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	timeLabel.TextXAlignment = Enum.TextXAlignment.Left
	timeLabel.Parent = entryFrame
	
	-- Jump indicator
	if waypoint.IsJumping then
		local jumpLabel = Instance.new("TextLabel")
		jumpLabel.Size = UDim2.new(0, 50, 0, 15)
		jumpLabel.Position = UDim2.new(1, -58, 0, 5)
		jumpLabel.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
		jumpLabel.Text = "JUMP"
		jumpLabel.Font = Enum.Font.GothamBold
		jumpLabel.TextSize = 9
		jumpLabel.TextColor3 = Color3.fromRGB(50, 50, 50)
		jumpLabel.Parent = entryFrame
		
		local jumpCorner = Instance.new("UICorner")
		jumpCorner.CornerRadius = UDim.new(0, 4)
		jumpCorner.Parent = jumpLabel
	end
	
	-- Position label
	local posLabel = Instance.new("TextLabel")
	posLabel.Size = UDim2.new(1, -16, 0, 15)
	posLabel.Position = UDim2.new(0, 8, 0, 25)
	posLabel.BackgroundTransparency = 1
	posLabel.Text = "Pos: " .. formatVector3(waypoint.Position)
	posLabel.Font = Enum.Font.Gotham
	posLabel.TextSize = 10
	posLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	posLabel.TextXAlignment = Enum.TextXAlignment.Left
	posLabel.Parent = entryFrame
	
	-- Delete button
	local deleteButton = Instance.new("TextButton")
	deleteButton.Size = UDim2.new(0, 50, 0, 18)
	deleteButton.Position = UDim2.new(0, 8, 1, -23)
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
		if waypointCountLabel then
			waypointCountLabel.Text = "Waypoints: " .. #currentRecording
		end
	end)
end

-- ========================================
-- GUI CREATION
-- ========================================

local function createUI()
	mainGui = Instance.new("ScreenGui")
	mainGui.Name = "MovementRecorderGUI"
	mainGui.ResetOnSpawn = false
	mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mainGui.Parent = player.PlayerGui
	
	-- Main Frame
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 400, 0, 550)
	mainFrame.Position = UDim2.new(0.5, -200, 0.5, -275)
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = mainGui
	
	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 12)
	mainCorner.Parent = mainFrame
	
	local mainStroke = Instance.new("UIStroke")
	mainStroke.Color = Color3.fromRGB(0, 255, 127)
	mainStroke.Thickness = 2
	mainStroke.Parent = mainFrame
	
	-- Header (Draggable)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	header.BorderSizePixel = 0
	header.Parent = mainFrame
	
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = header
	
	makeDraggable(mainFrame, header)
	
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -100, 1, 0)
	titleLabel.Position = UDim2.new(0, 10, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🚶 Natural Walk Recorder"
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 18
	titleLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = header
	
	-- Minimize Button
	local minimizeButton = Instance.new("TextButton")
	minimizeButton.Size = UDim2.new(0, 35, 0, 35)
	minimizeButton.Position = UDim2.new(1, -45, 0, 7.5)
	minimizeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
	minimizeButton.Text = "−"
	minimizeButton.Font = Enum.Font.GothamBold
	minimizeButton.TextSize = 24
	minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	minimizeButton.Parent = header
	
	local minCorner = Instance.new("UICorner")
	minCorner.CornerRadius = UDim.new(0, 8)
	minCorner.Parent = minimizeButton
	
	minimizeButton.MouseButton1Click:Connect(minimizeGUI)
	
	minimizeButton.MouseEnter:Connect(function()
		minimizeButton.BackgroundColor3 = Color3.fromRGB(100, 100, 110)
	end)
	minimizeButton.MouseLeave:Connect(function()
		minimizeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
	end)
	
	-- Minimized Floating Icon
	minimizedIcon = Instance.new("ImageButton")
	minimizedIcon.Name = "MinimizedIcon"
	minimizedIcon.Size = UDim2.new(0, 60, 0, 60)
	minimizedIcon.Position = UDim2.new(1, -80, 0, 20)
	minimizedIcon.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	minimizedIcon.BorderSizePixel = 0
	minimizedIcon.Visible = false
	minimizedIcon.Parent = mainGui
	
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 30)
	iconCorner.Parent = minimizedIcon
	
	local iconStroke = Instance.new("UIStroke")
	iconStroke.Color = Color3.fromRGB(0, 255, 127)
	iconStroke.Thickness = 3
	iconStroke.Parent = minimizedIcon
	
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(1, 0, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = "🚶"
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextSize = 30
	iconLabel.Parent = minimizedIcon
	
	makeDraggable(minimizedIcon, minimizedIcon)
	minimizedIcon.MouseButton1Click:Connect(maximizeGUI)
	
	-- Recording indicator on icon
	local recordingIndicator = Instance.new("Frame")
	recordingIndicator.Name = "RecordingIndicator"
	recordingIndicator.Size = UDim2.new(0, 16, 0, 16)
	recordingIndicator.Position = UDim2.new(1, -4, 0, -4)
	recordingIndicator.AnchorPoint = Vector2.new(1, 0)
	recordingIndicator.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	recordingIndicator.BorderSizePixel = 0
	recordingIndicator.Visible = false
	recordingIndicator.Parent = minimizedIcon
	
	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(1, 0)
	indicatorCorner.Parent = recordingIndicator
	
	-- Status Label
	statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(0, 120, 0, 30)
	statusLabel.Position = UDim2.new(1, -130, 0, 10)
	statusLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
	statusLabel.Text = "⚪ READY"
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 12
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	statusLabel.Parent = header
	
	local statusCorner = Instance.new("UICorner")
	statusCorner.CornerRadius = UDim.new(0, 8)
	statusCorner.Parent = statusLabel
	
	-- Info Box
	local infoBox = Instance.new("Frame")
	infoBox.Size = UDim2.new(1, -20, 0, 70)
	infoBox.Position = UDim2.new(0, 10, 0, 60)
	infoBox.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	infoBox.BorderSizePixel = 0
	infoBox.Parent = mainFrame
	
	local infoCorner = Instance.new("UICorner")
	infoCorner.CornerRadius = UDim.new(0, 10)
	infoCorner.Parent = infoBox
	
	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -20, 1, -20)
	infoLabel.Position = UDim2.new(0, 10, 0, 10)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = "✓ Natural walking - NO teleporting!\n✓ Character walks to waypoints\n✓ Feet animate properly"
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextSize = 12
	infoLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	infoLabel.TextYAlignment = Enum.TextYAlignment.Top
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.Parent = infoBox
	
	-- Recording Button
	recordingButton = Instance.new("TextButton")
	recordingButton.Size = UDim2.new(1, -20, 0, 40)
	recordingButton.Position = UDim2.new(0, 10, 0, 140)
	recordingButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	recordingButton.Text = "⏺ START RECORDING"
	recordingButton.Font = Enum.Font.GothamBold
	recordingButton.TextSize = 14
	recordingButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	recordingButton.Parent = mainFrame
	
	local recCorner = Instance.new("UICorner")
	recCorner.CornerRadius = UDim.new(0, 8)
	recCorner.Parent = recordingButton
	
	recordingButton.MouseButton1Click:Connect(toggleRecording)
	
	-- Info Labels
	waypointCountLabel = Instance.new("TextLabel")
	waypointCountLabel.Size = UDim2.new(0.5, -15, 0, 25)
	waypointCountLabel.Position = UDim2.new(0, 10, 0, 190)
	waypointCountLabel.BackgroundTransparency = 1
	waypointCountLabel.Text = "Waypoints: 0"
	waypointCountLabel.Font = Enum.Font.Gotham
	waypointCountLabel.TextSize = 12
	waypointCountLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	waypointCountLabel.TextXAlignment = Enum.TextXAlignment.Left
	waypointCountLabel.Parent = mainFrame
	
	recordingTimeLabel = Instance.new("TextLabel")
	recordingTimeLabel.Size = UDim2.new(0.5, -15, 0, 25)
	recordingTimeLabel.Position = UDim2.new(0.5, 5, 0, 190)
	recordingTimeLabel.BackgroundTransparency = 1
	recordingTimeLabel.Text = "Time: 00:00.00"
	recordingTimeLabel.Font = Enum.Font.Gotham
	recordingTimeLabel.TextSize = 12
	recordingTimeLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	recordingTimeLabel.TextXAlignment = Enum.TextXAlignment.Right
	recordingTimeLabel.Parent = mainFrame
	
	-- Log Section
	local logHeader = Instance.new("TextLabel")
	logHeader.Size = UDim2.new(1, -100, 0, 30)
	logHeader.Position = UDim2.new(0, 10, 0, 220)
	logHeader.BackgroundTransparency = 1
	logHeader.Text = "📋 Waypoint Log"
	logHeader.Font = Enum.Font.GothamBold
	logHeader.TextSize = 14
	logHeader.TextColor3 = Color3.fromRGB(0, 255, 127)
	logHeader.TextXAlignment = Enum.TextXAlignment.Left
	logHeader.Parent = mainFrame
	
	local clearButton = Instance.new("TextButton")
	clearButton.Size = UDim2.new(0, 80, 0, 25)
	clearButton.Position = UDim2.new(1, -100, 0, 222)
	clearButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	clearButton.Text = "Clear All"
	clearButton.Font = Enum.Font.Gotham
	clearButton.TextSize = 11
	clearButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	clearButton.Parent = mainFrame
	
	local clearCorner = Instance.new("UICorner")
	clearCorner.CornerRadius = UDim.new(0, 6)
	clearCorner.Parent = clearButton
	
	clearButton.MouseButton1Click:Connect(function()
		currentRecording = {}
		refreshLogDisplay()
		waypointCountLabel.Text = "Waypoints: 0"
	end)
	
	-- ScrollingFrame
	scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Size = UDim2.new(1, -20, 0, 150)
	scrollingFrame.Position = UDim2.new(0, 10, 0, 255)
	scrollingFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.ScrollBarThickness = 6
	scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 127)
	scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollingFrame.Parent = mainFrame
	
	local scrollCorner = Instance.new("UICorner")
	scrollCorner.CornerRadius = UDim.new(0, 8)
	scrollCorner.Parent = scrollingFrame
	
	local scrollLayout = Instance.new("UIListLayout")
	scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
	scrollLayout.Padding = UDim.new(0, 5)
	scrollLayout.Parent = scrollingFrame
	
	-- Replay Controls
	local replayFrame = Instance.new("Frame")
	replayFrame.Size = UDim2.new(1, -20, 0, 110)
	replayFrame.Position = UDim2.new(0, 10, 0, 415)
	replayFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	replayFrame.BorderSizePixel = 0
	replayFrame.Parent = mainFrame
	
	local replayCorner = Instance.new("UICorner")
	replayCorner.CornerRadius = UDim.new(0, 10)
	replayCorner.Parent = replayFrame
	
	local replayTitle = Instance.new("TextLabel")
	replayTitle.Size = UDim2.new(1, -20, 0, 25)
	replayTitle.Position = UDim2.new(0, 10, 0, 5)
	replayTitle.BackgroundTransparency = 1
	replayTitle.Text = "▶️ Playback Controls"
	replayTitle.Font = Enum.Font.GothamBold
	replayTitle.TextSize = 13
	replayTitle.TextColor3 = Color3.fromRGB(0, 255, 127)
	replayTitle.TextXAlignment = Enum.TextXAlignment.Left
	replayTitle.Parent = replayFrame
	
	-- Play Button
	playButton = Instance.new("TextButton")
	playButton.Size = UDim2.new(0.48, -5, 0, 35)
	playButton.Position = UDim2.new(0, 10, 0, 35)
	playButton.BackgroundColor3 = Color3.fromRGB(50, 120, 220)
	playButton.Text = "▶ PLAY"
	playButton.Font = Enum.Font.GothamBold
	playButton.TextSize = 13
	playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	playButton.Parent = replayFrame
	
	local playCorner = Instance.new("UICorner")
	playCorner.CornerRadius = UDim.new(0, 7)
	playCorner.Parent = playButton
	
	playButton.MouseButton1Click:Connect(startPlayback)
	
	-- Stop Button
	stopButton = Instance.new("TextButton")
	stopButton.Size = UDim2.new(0.48, -5, 0, 35)
	stopButton.Position = UDim2.new(0.52, 0, 0, 35)
	stopButton.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
	stopButton.Text = "⏹ STOP"
	stopButton.Font = Enum.Font.GothamBold
	stopButton.TextSize = 13
	stopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	stopButton.Parent = replayFrame
	
	local stopCorner = Instance.new("UICorner")
	stopCorner.CornerRadius = UDim.new(0, 7)
	stopCorner.Parent = stopButton
	
	stopButton.MouseButton1Click:Connect(stopPlayback)
	
	-- Speed Label
	speedLabel = Instance.new("TextLabel")
	speedLabel.Size = UDim2.new(1, -20, 0, 15)
	speedLabel.Position = UDim2.new(0, 10, 0, 75)
	speedLabel.BackgroundTransparency = 1
	speedLabel.Text = "Speed: 1.0x"
	speedLabel.Font = Enum.Font.Gotham
	speedLabel.TextSize = 11
	speedLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel.Parent = replayFrame
	
	-- Speed Slider
	local speedSlider = Instance.new("Frame")
	speedSlider.Size = UDim2.new(1, -20, 0, 20)
	speedSlider.Position = UDim2.new(0, 10, 1, -25)
	speedSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
	speedSlider.BorderSizePixel = 0
	speedSlider.Parent = replayFrame
	
	local sliderCorner = Instance.new("UICorner")
	sliderCorner.CornerRadius = UDim.new(0, 10)
	sliderCorner.Parent = speedSlider
	
	local speedFill = Instance.new("Frame")
	speedFill.Name = "Fill"
	speedFill.Size = UDim2.new(0.33, 0, 1, 0)
	speedFill.BackgroundColor3 = Color3.fromRGB(0, 255, 127)
	speedFill.BorderSizePixel = 0
	speedFill.Parent = speedSlider
	
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 10)
	fillCorner.Parent = speedFill
	
	-- Speed slider interaction
	local draggingSlider = false
	
	speedSlider.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingSlider = true
		end
	end)
	
	speedSlider.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			draggingSlider = false
		end
	end)
	
	local function updateSpeedSlider(mouseX)
		local sliderPos = speedSlider.AbsolutePosition.X
		local sliderSize = speedSlider.AbsoluteSize.X
		local relativeX = math.clamp((mouseX - sliderPos) / sliderSize, 0, 1)
		
		playbackSpeed = 0.5 + (relativeX * 2)
		speedFill.Size = UDim2.new(relativeX, 0, 1, 0)
		speedLabel.Text = string.format("Speed: %.1fx", playbackSpeed)
		
		if isPlaying then
			humanoid.WalkSpeed = originalWalkSpeed * playbackSpeed
		end
	end
	
	UserInputService.InputChanged:Connect(function(input)
		if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateSpeedSlider(input.Position.X)
		end
	end)
	
	speedSlider.MouseButton1Down:Connect(function()
		updateSpeedSlider(UserInputService:GetMouseLocation().X)
	end)
	
	print("[Recorder] UI Created Successfully")
end

-- ========================================
-- UPDATE FUNCTIONS
-- ========================================

RunService.Heartbeat:Connect(function()
	if isRecording and recordingTimeLabel then
		local elapsed = tick() - recordingStartTime
		recordingTimeLabel.Text = "Time: " .. formatTime(elapsed)
	end
end)

-- ========================================
-- INPUT HANDLING
-- ========================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- R key to toggle recording
	if input.KeyCode == Enum.KeyCode.R then
		toggleRecording()
	end
	
	-- RIGHT SHIFT to toggle GUI visibility
	if input.KeyCode == Enum.KeyCode.RightShift then
		if mainGui then
			if isMinimized then
				if minimizedIcon then
					minimizedIcon.Visible = not minimizedIcon.Visible
				end
			else
				if mainFrame then
					mainFrame.Visible = not mainFrame.Visible
				end
			end
		end
	end
end)

-- Handle character respawn
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = character:WaitForChild("Humanoid")
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	
	if isRecording then
		stopRecording()
	end
	if isPlaying then
		stopPlayback()
	end
	
	originalWalkSpeed = humanoid.WalkSpeed
	
	print("[Recorder] Character respawned - system ready")
end)

-- ========================================
-- INITIALIZATION
-- ========================================

createUI()

print("=== Movement Recorder v3.0 Fully Loaded! ===")
print("✓ Natural walking with Humanoid:MoveTo()")
print("✓ No teleporting - real walking animations!")
print("✓ Draggable GUI with minimize/maximize")
print("✓ Press R to start/stop recording")
print("✓ Press RIGHT SHIFT to toggle GUI visibility")
print("✓ System ready!")
