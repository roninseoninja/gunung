-- Walk Recorder V3 - TRUE WALKING (No Teleporting!)
-- Place this in StarterPlayer > StarterPlayerScripts or StarterGui

print("=== Walk Recorder V3 - Natural Walking ===")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

wait(0.5)

-- Recording Variables
local recordings = {}
local currentRecording = {}
local isRecording = false
local isPlaying = false
local playbackSpeed = 1
local recordingName = "Recording_1"
local recordConnection = nil
local playConnection = nil

-- Create GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WalkRecorderV3"
screenGui.ResetOnSpawn = false

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 350, 0, 400)
mainFrame.Position = UDim2.new(0.5, -175, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
mainFrame.BorderSizePixel = 3
mainFrame.BorderColor3 = Color3.fromRGB(0, 255, 127)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 40)
title.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
title.Text = "Walk Recorder V3 - Natural Walking"
title.TextColor3 = Color3.fromRGB(0, 255, 127)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = mainFrame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 35, 0, 35)
closeBtn.Position = UDim2.new(1, -37, 0, 2)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = mainFrame

closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = not mainFrame.Visible
end)

local function createButton(name, text, position, size)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    button.BorderSizePixel = 1
    button.BorderColor3 = Color3.fromRGB(100, 100, 120)
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.TextSize = 14
    button.Parent = mainFrame
    
    button.MouseEnter:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    end)
    button.MouseLeave:Connect(function()
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    end)
    
    return button
end

local recordBtn = createButton("RecordBtn", "⏺ START RECORDING", UDim2.new(0, 10, 0, 50), UDim2.new(0, 330, 0, 40))
local stopBtn = createButton("StopBtn", "⏹ STOP", UDim2.new(0, 10, 0, 100), UDim2.new(0, 160, 0, 40))
local playBtn = createButton("PlayBtn", "▶ PLAY", UDim2.new(0, 180, 0, 100), UDim2.new(0, 160, 0, 40))

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 100)
statusLabel.Position = UDim2.new(0, 10, 0, 150)
statusLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
statusLabel.BorderSizePixel = 1
statusLabel.BorderColor3 = Color3.fromRGB(100, 100, 120)
statusLabel.Text = "Status: Ready\nWaypoints: 0\nMethod: Natural Humanoid Walking"
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 14
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(0, 150, 0, 20)
speedLabel.Position = UDim2.new(0, 10, 0, 260)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Playback Speed: 1.0x"
speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 14
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = mainFrame

local speedSlider = Instance.new("Frame")
speedSlider.Size = UDim2.new(0, 330, 0, 25)
speedSlider.Position = UDim2.new(0, 10, 0, 285)
speedSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
speedSlider.BorderSizePixel = 1
speedSlider.BorderColor3 = Color3.fromRGB(100, 100, 120)
speedSlider.Parent = mainFrame

local speedButton = Instance.new("TextButton")
speedButton.Size = UDim2.new(0, 20, 1, 0)
speedButton.Position = UDim2.new(0.5, -10, 0, 0)
speedButton.BackgroundColor3 = Color3.fromRGB(0, 255, 127)
speedButton.Text = ""
speedButton.Parent = speedSlider

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 80)
infoLabel.Position = UDim2.new(0, 10, 0, 320)
infoLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
infoLabel.BorderSizePixel = 1
infoLabel.BorderColor3 = Color3.fromRGB(100, 100, 120)
infoLabel.Text = "✓ Character walks naturally\n✓ Feet animate properly\n✓ No teleporting!\nPress RIGHT SHIFT to toggle GUI"
infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 12
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Parent = mainFrame

-- Recording and Playback Functions
local function updateStatus()
    local waypointCount = #currentRecording
    local status = "Ready"
    
    if isRecording then
        status = "🔴 RECORDING - Waypoints: " .. waypointCount
    elseif isPlaying then
        status = "▶ PLAYING - Walking to waypoints..."
    end
    
    statusLabel.Text = string.format("%s\nWaypoints: %d\nMethod: Natural Humanoid Walking", status, waypointCount)
end

local function startRecording()
    if isRecording or isPlaying then return end
    
    print("Starting recording...")
    isRecording = true
    currentRecording = {}
    recordBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    recordBtn.Text = "⏺ RECORDING..."
    
    local recordInterval = 0.2 -- Record waypoint every 0.2 seconds
    local timeSinceLastRecord = 0
    
    recordConnection = RunService.Heartbeat:Connect(function(deltaTime)
        timeSinceLastRecord = timeSinceLastRecord + deltaTime
        
        if timeSinceLastRecord >= recordInterval then
            local waypoint = {
                Position = hrp.Position,
                LookVector = hrp.CFrame.LookVector,
                IsJumping = humanoid:GetState() == Enum.HumanoidStateType.Jumping or 
                           humanoid:GetState() == Enum.HumanoidStateType.Freefall,
                Timestamp = tick()
            }
            table.insert(currentRecording, waypoint)
            timeSinceLastRecord = 0
            updateStatus()
        end
    end)
end

local function stopRecording()
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    if playConnection then
        playConnection:Disconnect()
        playConnection = nil
    end
    
    isRecording = false
    isPlaying = false
    
    recordBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    recordBtn.Text = "⏺ START RECORDING"
    playBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    playBtn.Text = "▶ PLAY"
    
    updateStatus()
    print("Recording stopped. Waypoints:", #currentRecording)
end

local function playRecording()
    if isRecording or isPlaying or #currentRecording == 0 then 
        print("Cannot play: recording empty or already playing")
        return 
    end
    
    print("Starting playback with", #currentRecording, "waypoints")
    isPlaying = true
    playBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    playBtn.Text = "▶ PLAYING..."
    
    local currentWaypoint = 1
    local moveTimeout = 0
    local maxMoveTimeout = 5 -- 5 seconds max per waypoint
    
    playConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if currentWaypoint > #currentRecording then
            print("Playback complete!")
            stopRecording()
            return
        end
        
        local waypoint = currentRecording[currentWaypoint]
        local distanceToWaypoint = (waypoint.Position - hrp.Position).Magnitude
        
        -- Move to the waypoint - THIS MAKES THE CHARACTER WALK NATURALLY!
        humanoid:MoveTo(waypoint.Position)
        
        -- Update status
        updateStatus()
        
        -- Handle jumping
        if waypoint.IsJumping then
            local state = humanoid:GetState()
            if state ~= Enum.HumanoidStateType.Jumping and 
               state ~= Enum.HumanoidStateType.Freefall then
                humanoid.Jump = true
            end
        end
        
        -- Check if we reached the waypoint
        moveTimeout = moveTimeout + deltaTime
        if distanceToWaypoint < 3 or moveTimeout > maxMoveTimeout then
            -- Move to next waypoint
            currentWaypoint = currentWaypoint + 1
            moveTimeout = 0
            print("Reached waypoint", currentWaypoint - 1, "- Moving to next...")
        end
    end)
end

-- Speed Slider
local dragging = false
speedButton.MouseButton1Down:Connect(function()
    dragging = true
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local relativePos = math.clamp((input.Position.X - speedSlider.AbsolutePosition.X) / speedSlider.AbsoluteSize.X, 0, 1)
        speedButton.Position = UDim2.new(relativePos, -10, 0, 0)
        playbackSpeed = 0.5 + (relativePos * 2) -- 0.5x to 2.5x speed
        speedLabel.Text = string.format("Playback Speed: %.1fx", playbackSpeed)
        
        -- Adjust humanoid WalkSpeed during playback
        if isPlaying then
            humanoid.WalkSpeed = 16 * playbackSpeed
        end
    end
end)

-- Button Connections
recordBtn.MouseButton1Click:Connect(startRecording)
stopBtn.MouseButton1Click:Connect(stopRecording)
playBtn.MouseButton1Click:Connect(playRecording)

-- Initialize
updateStatus()
screenGui.Parent = playerGui

-- Toggle GUI
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.RightShift then
        mainFrame.Visible = not mainFrame.Visible
        print("GUI toggled:", mainFrame.Visible)
    end
end)

print("=== Walk Recorder V3 Loaded! ===")
print("✓ Uses natural Humanoid:MoveTo() for real walking")
print("✓ No teleporting - character walks to each waypoint")
print("✓ Feet animate properly!")
print("Press RIGHT SHIFT to show/hide GUI")
