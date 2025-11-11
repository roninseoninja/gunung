--[[
═══════════════════════════════════════════════════════════════════════════════
    MOVEMENT RECORDER - EXECUTOR VERSION
    
    For use with script executors (Synapse, KRNL, etc.)
    Just execute this script and press RIGHT SHIFT to open GUI
═══════════════════════════════════════════════════════════════════════════════
--]]

-- Check if already loaded
if _G.MovementRecorderLoaded then
    warn("Movement Recorder already loaded! Restarting...")
    if _G.MovementRecorderGui then
        _G.MovementRecorderGui:Destroy()
    end
end

_G.MovementRecorderLoaded = true

print("╔══════════════════════════════════════╗")
print("║  MOVEMENT RECORDER - EXECUTOR v1.0   ║")
print("╚══════════════════════════════════════╝")

-- Get services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- Get player
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

print("✓ Player:", player.Name)
print("✓ Character loaded")

--[[═══════════════════════════════════════════════════════════════════════════
    DATA STORAGE
═══════════════════════════════════════════════════════════════════════════════]]

local frames = {}
local isRecording = false
local isPlaying = false
local currentFrame = 1

local history = {}
local historyIndex = 0

local connections = {}

--[[═══════════════════════════════════════════════════════════════════════════
    RECORDING FUNCTIONS
═══════════════════════════════════════════════════════════════════════════════]]

local function startRecording()
    if isRecording then return end
    
    frames = {}
    isRecording = true
    
    print("► Recording started...")
    
    connections.record = RunService.Heartbeat:Connect(function()
        if not isRecording then return end
        
        local pos = hrp.Position
        local rot = hrp.CFrame - hrp.Position
        
        table.insert(frames, {
            Position = pos,
            CFrame = hrp.CFrame,
            Rotation = rot,
            Velocity = hrp.AssemblyLinearVelocity or hrp.Velocity,
            State = humanoid:GetState()
        })
    end)
end

local function stopRecording()
    if not isRecording then return end
    
    isRecording = false
    
    if connections.record then
        connections.record:Disconnect()
        connections.record = nil
    end
    
    print("■ Recording stopped - Frames:", #frames)
end

--[[═══════════════════════════════════════════════════════════════════════════
    PLAYBACK FUNCTIONS
═══════════════════════════════════════════════════════════════════════════════]]

local function startPlayback()
    if #frames == 0 then
        warn("No recording to play!")
        return
    end
    
    if isPlaying then return end
    
    isPlaying = true
    currentFrame = 1
    
    print("▶ Playing recording...")
    
    -- Teleport to start
    hrp.CFrame = frames[1].CFrame
    
    connections.play = RunService.Heartbeat:Connect(function()
        if not isPlaying then return end
        
        if currentFrame > #frames then
            stopPlayback()
            return
        end
        
        local frame = frames[currentFrame]
        
        -- Natural movement using MoveTo
        if currentFrame < #frames then
            local nextFrame = frames[currentFrame + 1]
            
            -- Calculate movement
            local direction = (nextFrame.Position - hrp.Position).Unit
            local distance = (nextFrame.Position - hrp.Position).Magnitude
            
            if distance > 0.5 then
                -- Use Humanoid:MoveTo for natural walking
                humanoid:MoveTo(nextFrame.Position)
                
                -- Also apply direct velocity for smoothness
                if hrp.AssemblyLinearVelocity then
                    hrp.AssemblyLinearVelocity = direction * math.min(distance * 10, 50)
                else
                    hrp.Velocity = direction * math.min(distance * 10, 50)
                end
            end
            
            -- Handle rotation
            hrp.CFrame = CFrame.new(hrp.Position) * nextFrame.Rotation
            
            -- Handle jumping
            if frame.State == Enum.HumanoidStateType.Jumping then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
        
        currentFrame = currentFrame + 1
    end)
end

local function stopPlayback()
    if not isPlaying then return end
    
    isPlaying = false
    
    if connections.play then
        connections.play:Disconnect()
        connections.play = nil
    end
    
    -- Stop movement
    if hrp.AssemblyLinearVelocity then
        hrp.AssemblyLinearVelocity = Vector3.zero
    else
        hrp.Velocity = Vector3.zero
    end
    
    print("■ Playback stopped")
end

--[[═══════════════════════════════════════════════════════════════════════════
    FRAME EDITING
═══════════════════════════════════════════════════════════════════════════════]]

local function jumpToFrame(frameNum)
    if frameNum < 1 or frameNum > #frames then return end
    
    local frame = frames[frameNum]
    
    -- Anchor to prevent falling
    local wasAnchored = hrp.Anchored
    hrp.Anchored = true
    
    hrp.CFrame = frame.CFrame
    
    task.wait(0.1)
    hrp.Anchored = wasAnchored
    
    currentFrame = frameNum
    print("→ Jumped to frame:", frameNum)
end

local function deleteFrame(frameNum)
    if frameNum < 1 or frameNum > #frames or #frames <= 1 then return end
    
    table.remove(frames, frameNum)
    print("✗ Frame deleted:", frameNum)
end

local function exportRecording()
    local data = {}
    for i, frame in ipairs(frames) do
        table.insert(data, {
            p = {frame.Position.X, frame.Position.Y, frame.Position.Z},
            r = {frame.CFrame:ToEulerAnglesXYZ()}
        })
    end
    
    local json = HttpService:JSONEncode(data)
    print("═══ EXPORT START ═══")
    print(json)
    print("═══ EXPORT END ═══")
    
    if setclipboard then
        setclipboard(json)
        print("✓ Copied to clipboard!")
    end
    
    return json
end

--[[═══════════════════════════════════════════════════════════════════════════
    GUI CREATION
═══════════════════════════════════════════════════════════════════════════════]]

local function createGUI()
    -- Clean up old GUI
    if _G.MovementRecorderGui then
        _G.MovementRecorderGui:Destroy()
    end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "MovementRecorder"
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.ResetOnSpawn = false
    _G.MovementRecorderGui = gui
    
    -- Main frame
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 350, 0, 450)
    main.Position = UDim2.new(0.5, -175, 0.5, -225)
    main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    main.BorderSizePixel = 2
    main.BorderColor3 = Color3.fromRGB(0, 255, 255)
    main.Active = true
    main.Draggable = true
    main.Visible = false
    main.Parent = gui
    
    -- Corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = main
    
    -- Title bar
    local title = Instance.new("Frame")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    title.BorderSizePixel = 0
    title.Parent = main
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = title
    
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -60, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "MOVEMENT RECORDER"
    titleText.TextColor3 = Color3.fromRGB(0, 255, 255)
    titleText.TextSize = 18
    titleText.Font = Enum.Font.GothamBold
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = title
    
    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 40, 0, 30)
    closeBtn.Position = UDim2.new(1, -45, 0, 5)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.white
    closeBtn.TextSize = 20
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = title
    
    local closeBtnCorner = Instance.new("UICorner")
    closeBtnCorner.CornerRadius = UDim.new(0, 6)
    closeBtnCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        main.Visible = false
    end)
    
    -- Info panel
    local info = Instance.new("TextLabel")
    info.Name = "Info"
    info.Size = UDim2.new(1, -20, 0, 60)
    info.Position = UDim2.new(0, 10, 0, 50)
    info.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    info.BorderSizePixel = 0
    info.Text = "Frames: 0 | Current: 0\nStatus: Idle"
    info.TextColor3 = Color3.white
    info.TextSize = 14
    info.Font = Enum.Font.Gotham
    info.Parent = main
    
    local infoCorner = Instance.new("UICorner")
    infoCorner.CornerRadius = UDim.new(0, 8)
    infoCorner.Parent = info
    
    -- Button creator
    local function createButton(name, text, pos, color, callback)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(0, 160, 0, 40)
        btn.Position = pos
        btn.BackgroundColor3 = color
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.TextColor3 = Color3.white
        btn.TextSize = 16
        btn.Font = Enum.Font.GothamBold
        btn.Parent = main
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(callback)
        
        return btn
    end
    
    -- Record button
    local recordBtn = createButton(
        "Record",
        "⏺ RECORD",
        UDim2.new(0, 10, 0, 120),
        Color3.fromRGB(60, 60, 60),
        function()
            if not isRecording then
                startRecording()
                recordBtn.Text = "⏹ STOP REC"
                recordBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            else
                stopRecording()
                recordBtn.Text = "⏺ RECORD"
                recordBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end
        end
    )
    
    -- Play button
    local playBtn = createButton(
        "Play",
        "▶ PLAY",
        UDim2.new(0, 180, 0, 120),
        Color3.fromRGB(60, 60, 60),
        function()
            if not isPlaying then
                startPlayback()
                playBtn.Text = "⏹ STOP"
                playBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            else
                stopPlayback()
                playBtn.Text = "▶ PLAY"
                playBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            end
        end
    )
    
    -- Clear button
    createButton(
        "Clear",
        "🗑 CLEAR",
        UDim2.new(0, 10, 0, 170),
        Color3.fromRGB(60, 60, 60),
        function()
            frames = {}
            currentFrame = 1
            print("✓ All frames cleared")
        end
    )
    
    -- Export button
    createButton(
        "Export",
        "📋 EXPORT",
        UDim2.new(0, 180, 0, 170),
        Color3.fromRGB(60, 60, 60),
        exportRecording
    )
    
    -- Timeline label
    local timelineLabel = Instance.new("TextLabel")
    timelineLabel.Size = UDim2.new(1, -20, 0, 30)
    timelineLabel.Position = UDim2.new(0, 10, 0, 220)
    timelineLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    timelineLabel.BorderSizePixel = 0
    timelineLabel.Text = "TIMELINE (Click to jump, Right-click to delete)"
    timelineLabel.TextColor3 = Color3.white
    timelineLabel.TextSize = 12
    timelineLabel.Font = Enum.Font.GothamBold
    timelineLabel.Parent = main
    
    local timelineLabelCorner = Instance.new("UICorner")
    timelineLabelCorner.CornerRadius = UDim.new(0, 6)
    timelineLabelCorner.Parent = timelineLabel
    
    -- Timeline
    local timeline = Instance.new("ScrollingFrame")
    timeline.Name = "Timeline"
    timeline.Size = UDim2.new(1, -20, 0, 170)
    timeline.Position = UDim2.new(0, 10, 0, 260)
    timeline.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    timeline.BorderSizePixel = 0
    timeline.ScrollBarThickness = 6
    timeline.Parent = main
    
    local timelineCorner = Instance.new("UICorner")
    timelineCorner.CornerRadius = UDim.new(0, 8)
    timelineCorner.Parent = timeline
    
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 2)
    layout.Parent = timeline
    
    -- Update function
    local function updateGUI()
        local status = "Idle"
        if isRecording then
            status = "Recording..."
        elseif isPlaying then
            status = "Playing..."
        end
        
        info.Text = string.format("Frames: %d | Current: %d\nStatus: %s", #frames, currentFrame, status)
        
        -- Update timeline
        for _, child in ipairs(timeline:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        for i, frame in ipairs(frames) do
            local frameBtn = Instance.new("TextButton")
            frameBtn.Name = "Frame" .. i
            frameBtn.Size = UDim2.new(1, -6, 0, 25)
            frameBtn.BackgroundColor3 = (i == currentFrame) and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(50, 50, 50)
            frameBtn.BorderSizePixel = 0
            frameBtn.Text = string.format("#%d: %.1f, %.1f, %.1f", i, frame.Position.X, frame.Position.Y, frame.Position.Z)
            frameBtn.TextColor3 = Color3.white
            frameBtn.TextSize = 12
            frameBtn.Font = Enum.Font.Gotham
            frameBtn.TextXAlignment = Enum.TextXAlignment.Left
            frameBtn.Parent = timeline
            
            local frameBtnCorner = Instance.new("UICorner")
            frameBtnCorner.CornerRadius = UDim.new(0, 4)
            frameBtnCorner.Parent = frameBtn
            
            frameBtn.MouseButton1Click:Connect(function()
                jumpToFrame(i)
            end)
            
            frameBtn.MouseButton2Click:Connect(function()
                deleteFrame(i)
            end)
        end
        
        timeline.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
    end
    
    -- Update loop
    connections.guiUpdate = RunService.Heartbeat:Connect(function()
        if main.Visible then
            updateGUI()
        end
    end)
    
    -- Parent to CoreGui (works in executors)
    local success = pcall(function()
        gui.Parent = game:GetService("CoreGui")
    end)
    
    if not success then
        gui.Parent = player:WaitForChild("PlayerGui")
    end
    
    print("✓ GUI created")
    
    return main
end

--[[═══════════════════════════════════════════════════════════════════════════
    KEYBINDS
═══════════════════════════════════════════════════════════════════════════════]]

local mainFrame = createGUI()

connections.input = UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    -- RIGHT SHIFT - Toggle GUI
    if input.KeyCode == Enum.KeyCode.RightShift then
        mainFrame.Visible = not mainFrame.Visible
        print(mainFrame.Visible and "✓ GUI opened" or "✓ GUI closed")
    end
    
    -- SPACE - Play/Stop
    if input.KeyCode == Enum.KeyCode.Space and mainFrame.Visible then
        if not isPlaying then
            startPlayback()
        else
            stopPlayback()
        end
    end
end)

-- Character respawn handling
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    hrp = character:WaitForChild("HumanoidRootPart")
    
    if isRecording then
        stopRecording()
    end
    if isPlaying then
        stopPlayback()
    end
    
    print("✓ Character respawned")
end)

print("╔══════════════════════════════════════╗")
print("║      READY! Press RIGHT SHIFT        ║")
print("╚══════════════════════════════════════╝")

end)

if not success then
    warn("╔══════════════════════════════════════╗")
    warn("║  MOVEMENT RECORDER FAILED TO LOAD!   ║")
    warn("╚══════════════════════════════════════╝")
    warn("Error:", err)
end
