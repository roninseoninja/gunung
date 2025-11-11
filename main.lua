--[[
═══════════════════════════════════════════════════════════════════════════════
    MOVEMENT RECORDER - CROSS-DEVICE VERSION
    
    ✓ Mobile (Touch)
    ✓ Tablet (Touch)
    ✓ Console (Controller)
    ✓ PC (Mouse)
    ✓ NO Keyboard Required
    
    Tap the 📹 icon to open!
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
print("║  MOVEMENT RECORDER - CROSS-DEVICE    ║")
print("║     Mobile | Tablet | Console | PC   ║")
print("╚══════════════════════════════════════╝")

-- Get services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

-- Detect device type
local function getDeviceType()
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        return "Mobile"
    elseif UserInputService.TouchEnabled and UserInputService.KeyboardEnabled then
        return "Tablet"
    elseif UserInputService.GamepadEnabled then
        return "Console"
    else
        return "PC"
    end
end

local deviceType = getDeviceType()
print("✓ Device detected:", deviceType)

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
    
    hrp.CFrame = frames[1].CFrame
    
    connections.play = RunService.Heartbeat:Connect(function()
        if not isPlaying then return end
        
        if currentFrame > #frames then
            stopPlayback()
            return
        end
        
        local frame = frames[currentFrame]
        
        if currentFrame < #frames then
            local nextFrame = frames[currentFrame + 1]
            
            local direction = (nextFrame.Position - hrp.Position).Unit
            local distance = (nextFrame.Position - hrp.Position).Magnitude
            
            if distance > 0.5 then
                humanoid:MoveTo(nextFrame.Position)
                
                if hrp.AssemblyLinearVelocity then
                    hrp.AssemblyLinearVelocity = direction * math.min(distance * 10, 50)
                else
                    hrp.Velocity = direction * math.min(distance * 10, 50)
                end
            end
            
            hrp.CFrame = CFrame.new(hrp.Position) * nextFrame.Rotation
            
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
    CROSS-DEVICE GUI WITH TOUCH SUPPORT
═══════════════════════════════════════════════════════════════════════════════]]

local function createGUI()
    if _G.MovementRecorderGui then
        _G.MovementRecorderGui:Destroy()
    end
    
    local gui = Instance.new("ScreenGui")
    gui.Name = "MovementRecorder"
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true -- Full screen on mobile
    _G.MovementRecorderGui = gui
    
    -- Scale based on device
    local buttonScale = (deviceType == "Mobile" or deviceType == "Tablet") and 1.2 or 1.0
    local fontSize = (deviceType == "Mobile" or deviceType == "Tablet") and 18 or 16
    
    --[[═══════════════════════════════════════════════════════════════════════
        FLOATING ICON (Always visible initially)
    ═══════════════════════════════════════════════════════════════════════════]]
    
    local floatingIcon = Instance.new("ImageButton")
    floatingIcon.Name = "FloatingIcon"
    floatingIcon.Size = UDim2.new(0, 70 * buttonScale, 0, 70 * buttonScale)
    floatingIcon.Position = UDim2.new(1, -80 * buttonScale, 0, 20)
    floatingIcon.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
    floatingIcon.BorderSizePixel = 0
    floatingIcon.Active = true
    floatingIcon.Draggable = true
    floatingIcon.Visible = true -- Always visible on start
    floatingIcon.Parent = gui
    
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(1, 0)
    iconCorner.Parent = floatingIcon
    
    -- Icon shadow
    local iconShadow = Instance.new("Frame")
    iconShadow.Name = "Shadow"
    iconShadow.Size = UDim2.new(1, 12, 1, 12)
    iconShadow.Position = UDim2.new(0, -6, 0, -6)
    iconShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    iconShadow.BackgroundTransparency = 0.6
    iconShadow.BorderSizePixel = 0
    iconShadow.ZIndex = -1
    iconShadow.Parent = floatingIcon
    
    local iconShadowCorner = Instance.new("UICorner")
    iconShadowCorner.CornerRadius = UDim.new(1, 0)
    iconShadowCorner.Parent = iconShadow
    
    -- Icon text
    local iconText = Instance.new("TextLabel")
    iconText.Size = UDim2.new(1, 0, 1, 0)
    iconText.BackgroundTransparency = 1
    iconText.Text = "📹"
    iconText.TextColor3 = Color3.fromRGB(20, 20, 20)
    iconText.TextSize = 36 * buttonScale
    iconText.Font = Enum.Font.GothamBold
    iconText.Parent = floatingIcon
    
    -- Icon pulse animation
    local iconPulse = TweenService:Create(
        floatingIcon,
        TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, true),
        {Size = UDim2.new(0, 75 * buttonScale, 0, 75 * buttonScale)}
    )
    iconPulse:Play()
    
    --[[═══════════════════════════════════════════════════════════════════════
        MAIN FRAME
    ═══════════════════════════════════════════════════════════════════════════]]
    
    local main = Instance.new("Frame")
    main.Name = "Main"
    
    -- Responsive sizing
    if deviceType == "Mobile" then
        main.Size = UDim2.new(0.95, 0, 0.85, 0)
        main.Position = UDim2.new(0.025, 0, 0.075, 0)
    elseif deviceType == "Tablet" then
        main.Size = UDim2.new(0.7, 0, 0.8, 0)
        main.Position = UDim2.new(0.15, 0, 0.1, 0)
    else
        main.Size = UDim2.new(0, 400, 0, 500)
        main.Position = UDim2.new(0.5, -200, 0.5, -250)
    end
    
    main.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    main.BorderSizePixel = 0
    main.Active = true
    main.Visible = false
    main.Parent = gui
    
    -- Main shadow
    local mainShadow = Instance.new("Frame")
    mainShadow.Name = "Shadow"
    mainShadow.Size = UDim2.new(1, 20, 1, 20)
    mainShadow.Position = UDim2.new(0, -10, 0, -10)
    mainShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    mainShadow.BackgroundTransparency = 0.6
    mainShadow.BorderSizePixel = 0
    mainShadow.ZIndex = -1
    mainShadow.Parent = main
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 15)
    shadowCorner.Parent = mainShadow
    
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 12)
    mainCorner.Parent = main
    
    -- Enable dragging on PC/Tablet only (not mobile - too small)
    if deviceType ~= "Mobile" then
        local dragging = false
        local dragInput, dragStart, startPos
        
        main.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = main.Position
                
                input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                    end
                end)
            end
        end)
        
        main.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement or
               input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if input == dragInput and dragging then
                local delta = input.Position - dragStart
                main.Position = UDim2.new(
                    startPos.X.Scale,
                    startPos.X.Offset + delta.X,
                    startPos.Y.Scale,
                    startPos.Y.Offset + delta.Y
                )
            end
        end)
    end
    
    --[[═══════════════════════════════════════════════════════════════════════
        TITLE BAR
    ═══════════════════════════════════════════════════════════════════════════]]
    
    local title = Instance.new("Frame")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 50 * buttonScale)
    title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    title.BorderSizePixel = 0
    title.Parent = main
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = title
    
    local titleCover = Instance.new("Frame")
    titleCover.Size = UDim2.new(1, 0, 0, 12)
    titleCover.Position = UDim2.new(0, 0, 1, -12)
    titleCover.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    titleCover.BorderSizePixel = 0
    titleCover.Parent = title
    
    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -120 * buttonScale, 1, 0)
    titleText.Position = UDim2.new(0, 15, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "📹 RECORDER"
    titleText.TextColor3 = Color3.fromRGB(0, 255, 255)
    titleText.TextSize = fontSize * 1.2
    titleText.Font = Enum.Font.GothamBold
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.TextScaled = deviceType == "Mobile"
    titleText.Parent = title
    
    -- Touch-friendly button creator
    local function createTitleButton(name, text, color, xOffset, callback)
        local btn = Instance.new("TextButton")
        btn.Name = name
        btn.Size = UDim2.new(0, 45 * buttonScale, 0, 40 * buttonScale)
        btn.Position = UDim2.new(1, xOffset * buttonScale, 0, 5 * buttonScale)
        btn.BackgroundColor3 = color
        btn.Text = text
        btn.TextColor3 = text == "─" and Color3.fromRGB(20, 20, 20) or Color3.white
        btn.TextSize = fontSize * 1.3
        btn.Font = Enum.Font.GothamBold
        btn.AutoButtonColor = false
        btn.Parent = title
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 8)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(callback)
        
        -- Touch feedback
        btn.MouseButton1Down:Connect(function()
            btn.Size = UDim2.new(0, 42 * buttonScale, 0, 37 * buttonScale)
        end)
        
        btn.MouseButton1Up:Connect(function()
            btn.Size = UDim2.new(0, 45 * buttonScale, 0, 40 * buttonScale)
        end)
        
        return btn
    end
    
    -- Minimize/Restore functions
    local function minimizeGUI()
        main.Visible = false
        floatingIcon.Visible = true
        print("✓ Minimized")
    end
    
    local function restoreGUI()
        floatingIcon.Visible = false
        main.Visible = true
        print("✓ Restored")
    end
    
    -- Title buttons
    createTitleButton("Minimize", "─", Color3.fromRGB(255, 200, 0), -95, minimizeGUI)
    createTitleButton("Close", "✕", Color3.fromRGB(200, 50, 50), -45, function()
        main.Visible = false
        floatingIcon.Visible = true
    end)
    
    -- Icon click to restore
    floatingIcon.MouseButton1Click:Connect(restoreGUI)
    
    --[[═══════════════════════════════════════════════════════════════════════
        INFO PANEL
    ═══════════════════════════════════════════════════════════════════════════]]
    
    local info = Instance.new("TextLabel")
    info.Name = "Info"
    info.Size = UDim2.new(0.95, 0, 0, 70 * buttonScale)
    info.Position = UDim2.new(0.025, 0, 0, 60 * buttonScale)
    info.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    info.BorderSizePixel = 0
    info.Text = "Frames: 0 | Current: 0\nStatus: Idle"
    info.TextColor3 = Color3.white
    info.TextSize = fontSize
    info.Font = Enum.Font.Gotham
    info.TextScaled = deviceType == "Mobile"
    info.Parent = main
    
    local infoCorner = Instance.new("UICorner")
    infoCorner.CornerRadius = UDim.new(0, 10)
    infoCorner.Parent = info
    
    --[[═══════════════════════════════════════════════════════════════════════
        CONTROL BUTTONS (Touch-friendly, large)
    ═══════════════════════════════════════════════════════════════════════════]]
    
    local function createButton(name, text, row, col, color, callback)
        local btn = Instance.new("TextButton")
        btn.Name = name
        
        -- Responsive button sizing
        if deviceType == "Mobile" then
            btn.Size = UDim2.new(0.46, 0, 0, 60)
            btn.Position = UDim2.new(0.025 + (col * 0.49), 0, 0, 140 + (row * 70))
        else
            btn.Size = UDim2.new(0.46, 0, 0, 50 * buttonScale)
            btn.Position = UDim2.new(0.025 + (col * 0.49), 0, 0, 140 * buttonScale + (row * 60 * buttonScale))
        end
        
        btn.BackgroundColor3 = color
        btn.BorderSizePixel = 0
        btn.Text = text
        btn.TextColor3 = Color3.white
        btn.TextSize = fontSize * 1.1
        btn.Font = Enum.Font.GothamBold
        btn.AutoButtonColor = false
        btn.TextScaled = deviceType == "Mobile"
        btn.Parent = main
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 10)
        btnCorner.Parent = btn
        
        -- Gradient
        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 200))
        })
        gradient.Rotation = 90
        gradient.Parent = btn
        
        btn.MouseButton1Click:Connect(callback)
        
        -- Touch feedback animation
        btn.MouseButton1Down:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {
                Size = btn.Size - UDim2.new(0, 5, 0, 5)
            }):Play()
        end)
        
        btn.MouseButton1Up:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1), {
                Size = btn.Size + UDim2.new(0, 5, 0, 5)
            }):Play()
        end)
        
        return btn
    end
    
    -- Control buttons
    local recordBtn = createButton("Record", "⏺ RECORD", 0, 0, Color3.fromRGB(60, 60, 60), function()
        if not isRecording then
            startRecording()
            recordBtn.Text = "⏹ STOP REC"
            recordBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        else
            stopRecording()
            recordBtn.Text = "⏺ RECORD"
            recordBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
    end)
    
    local playBtn = createButton("Play", "▶ PLAY", 0, 1, Color3.fromRGB(60, 60, 60), function()
        if not isPlaying then
            startPlayback()
            playBtn.Text = "⏹ STOP"
            playBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        else
            stopPlayback()
            playBtn.Text = "▶ PLAY"
            playBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
    end)
    
    createButton("Clear", "🗑 CLEAR", 1, 0, Color3.fromRGB(60, 60, 60), function()
        frames = {}
        currentFrame = 1
        print("✓ Cleared")
    end)
    
    createButton("Export", "📋 EXPORT", 1, 1, Color3.fromRGB(60, 60, 60), exportRecording)
    
    --[[═══════════════════════════════════════════════════════════════════════
        TIMELINE (Touch-scrollable)
    ═══════════════════════════════════════════════════════════════════════════]]
    
    local timelineY = deviceType == "Mobile" and 280 or 260 * buttonScale
    local timelineHeight = deviceType == "Mobile" and "55%" or 0.45
    
    local timelineLabel = Instance.new("TextLabel")
    timelineLabel.Size = UDim2.new(0.95, 0, 0, 30 * buttonScale)
    timelineLabel.Position = UDim2.new(0.025, 0, 0, timelineY)
    timelineLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    timelineLabel.BorderSizePixel = 0
    timelineLabel.Text = "⏱ TIMELINE (Tap: Jump | Hold: Delete)"
    timelineLabel.TextColor3 = Color3.fromRGB(0, 255, 255)
    timelineLabel.TextSize = fontSize * 0.9
    timelineLabel.Font = Enum.Font.GothamBold
    timelineLabel.TextScaled = deviceType == "Mobile"
    timelineLabel.Parent = main
    
    local timelineLabelCorner = Instance.new("UICorner")
    timelineLabelCorner.CornerRadius = UDim.new(0, 8)
    timelineLabelCorner.Parent = timelineLabel
    
    local timeline = Instance.new("ScrollingFrame")
    timeline.Name = "Timeline"
    
    if deviceType == "Mobile" then
        timeline.Size = UDim2.new(0.95, 0, timelineHeight, 0)
        timeline.Position = UDim2.new(0.025, 0, 0, timelineY + 40)
    else
        timeline.Size = UDim2.new(0.95, 0, 0, 180 * buttonScale)
        timeline.Position = UDim2.new(0.025, 0, 0, timelineY + 40 * buttonScale)
    end
    
    timeline.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    timeline.BorderSizePixel = 0
    timeline.ScrollBarThickness = 10 * buttonScale
    timeline.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 255)
    timeline.Parent = main
    
    local timelineCorner = Instance.new("UICorner")
    timelineCorner.CornerRadius = UDim.new(0, 10)
    timelineCorner.Parent = timeline
    
    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 3)
    layout.Parent = timeline
    
    --[[═══════════════════════════════════════════════════════════════════════
        UPDATE GUI
    ═══════════════════════════════════════════════════════════════════════════]]
    
    local function updateGUI()
        local status = "Idle"
        local statusColor = Color3.white
        
        if isRecording then
            status = "Recording..."
            statusColor = Color3.fromRGB(255, 100, 100)
        elseif isPlaying then
            status = "Playing..."
            statusColor = Color3.fromRGB(100, 255, 100)
        end
        
        info.Text = string.format("Frames: %d | Current: %d\nStatus: %s", #frames, currentFrame, status)
        info.TextColor3 = statusColor
        
        -- Update timeline
        for _, child in ipairs(timeline:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        for i, frame in ipairs(frames) do
            local frameBtn = Instance.new("TextButton")
            frameBtn.Name = "Frame" .. i
            frameBtn.Size = UDim2.new(1, -6, 0, 35 * buttonScale)
            frameBtn.BackgroundColor3 = (i == currentFrame) and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(50, 50, 50)
            frameBtn.BorderSizePixel = 0
            frameBtn.Text = string.format("#%d: %.1f, %.1f, %.1f", i, frame.Position.X, frame.Position.Y, frame.Position.Z)
            frameBtn.TextColor3 = Color3.white
            frameBtn.TextSize = fontSize * 0.85
            frameBtn.Font = Enum.Font.Gotham
            frameBtn.TextXAlignment = Enum.TextXAlignment.Left
            frameBtn.AutoButtonColor = false
            frameBtn.TextScaled = deviceType == "Mobile"
            frameBtn.Parent = timeline
            
            local frameBtnCorner = Instance.new("UICorner")
            frameBtnCorner.CornerRadius = UDim.new(0, 6)
            frameBtnCorner.Parent = frameBtn
            
            -- Tap to jump
            frameBtn.MouseButton1Click:Connect(function()
                jumpToFrame(i)
            end)
            
            -- Hold to delete (touch-friendly)
            local holdTimer = nil
            frameBtn.MouseButton1Down:Connect(function()
                holdTimer = task.delay(0.7, function()
                    deleteFrame(i)
                    frameBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                end)
            end)
            
            frameBtn.MouseButton1Up:Connect(function()
                if holdTimer then
                    task.cancel(holdTimer)
                end
            end)
        end
        
        timeline.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
    end
    
    -- Update loop
    connections.guiUpdate = RunService.Heartbeat:Connect(function()
        if main.Visible or floatingIcon.Visible then
            updateGUI()
        end
    end)
    
    -- Parent to CoreGui or PlayerGui
    local success = pcall(function()
        gui.Parent = game:GetService("CoreGui")
    end)
    
    if not success then
        gui.Parent = player:WaitForChild("PlayerGui")
    end
    
    print("✓ Cross-device GUI created")
    print("✓ Device type:", deviceType)
    print("✓ Touch-friendly:", deviceType == "Mobile" or deviceType == "Tablet")
    
    return main, floatingIcon
end

--[[═══════════════════════════════════════════════════════════════════════════
    INITIALIZATION
═══════════════════════════════════════════════════════════════════════════════]]

local mainFrame, floatingIcon = createGUI()

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
print("║       READY! Tap the 📹 icon        ║")
print("║     NO keyboard required!            ║")
print("╚══════════════════════════════════════╝")
print("Device:", deviceType)
