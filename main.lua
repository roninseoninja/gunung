--[[
═══════════════════════════════════════════════════════════════════════════════
    ROBLOX MOVEMENT RECORDER SYSTEM
    A comprehensive frame-by-frame movement recording and editing system
    
    Features:
    - Frame-by-frame movement recording
    - Full timeline editing capabilities
    - Natural playback using Humanoid:MoveTo()
    - Undo/Redo with character stability
    - Save/Load recordings
    
    Usage: Place this LocalScript in StarterPlayer > StarterPlayerScripts
═══════════════════════════════════════════════════════════════════════════════
--]]

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- Player and Character
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- Constants
local RECORD_FPS = 30 -- Configurable frame rate
local FRAME_TIME = 1 / RECORD_FPS
local MAX_UNDO_HISTORY = 50

--[[═══════════════════════════════════════════════════════════════════════════
    DATA STRUCTURES
═══════════════════════════════════════════════════════════════════════════════]]

-- Frame data structure
local function createFrame(position, rotation, state, timestamp, velocity)
    return {
        Position = position,
        Rotation = rotation,
        State = state, -- Humanoid state
        Timestamp = timestamp,
        Velocity = velocity or Vector3.new(0, 0, 0),
        JumpPower = humanoid.JumpPower,
        WalkSpeed = humanoid.WalkSpeed
    }
end

-- Recording storage
local Recording = {
    Frames = {},
    Name = "Untitled Recording",
    Duration = 0,
    FPS = RECORD_FPS,
    CurrentFrame = 1
}

-- Undo/Redo system
local EditHistory = {
    UndoStack = {},
    RedoStack = {},
    MaxHistory = MAX_UNDO_HISTORY
}

-- Recording state
local RecordingState = {
    IsRecording = false,
    IsPlaying = false,
    IsPaused = false,
    PlaybackSpeed = 1.0,
    Loop = false,
    LastRecordTime = 0,
    PlaybackStartTime = 0,
    PlaybackConnection = nil,
    SelectedFrame = nil
}

--[[═══════════════════════════════════════════════════════════════════════════
    UNDO/REDO SYSTEM
═══════════════════════════════════════════════════════════════════════════════]]

-- Save current state for undo
local function saveStateForUndo(action, data)
    -- Create a deep copy of current frames
    local stateCopy = {
        Action = action,
        Frames = {},
        Data = data,
        Timestamp = tick()
    }
    
    for i, frame in ipairs(Recording.Frames) do
        stateCopy.Frames[i] = {
            Position = frame.Position,
            Rotation = frame.Rotation,
            State = frame.State,
            Timestamp = frame.Timestamp,
            Velocity = frame.Velocity,
            JumpPower = frame.JumpPower,
            WalkSpeed = frame.WalkSpeed
        }
    end
    
    table.insert(EditHistory.UndoStack, stateCopy)
    
    -- Limit undo stack size
    if #EditHistory.UndoStack > EditHistory.MaxHistory then
        table.remove(EditHistory.UndoStack, 1)
    end
    
    -- Clear redo stack when new action is performed
    EditHistory.RedoStack = {}
end

-- Undo last action with character stability
local function performUndo()
    if #EditHistory.UndoStack == 0 then
        print("Nothing to undo")
        return false
    end
    
    -- CRITICAL: Anchor character to prevent falling during undo
    local wasAnchored = rootPart.Anchored
    rootPart.Anchored = true
    
    -- Save current state to redo stack
    local currentState = {
        Action = "Redo Point",
        Frames = {},
        Timestamp = tick()
    }
    
    for i, frame in ipairs(Recording.Frames) do
        currentState.Frames[i] = {
            Position = frame.Position,
            Rotation = frame.Rotation,
            State = frame.State,
            Timestamp = frame.Timestamp,
            Velocity = frame.Velocity,
            JumpPower = frame.JumpPower,
            WalkSpeed = frame.WalkSpeed
        }
    end
    
    table.insert(EditHistory.RedoStack, currentState)
    
    -- Restore previous state
    local previousState = table.remove(EditHistory.UndoStack)
    Recording.Frames = {}
    
    for i, frame in ipairs(previousState.Frames) do
        Recording.Frames[i] = {
            Position = frame.Position,
            Rotation = frame.Rotation,
            State = frame.State,
            Timestamp = frame.Timestamp,
            Velocity = frame.Velocity,
            JumpPower = frame.JumpPower,
            WalkSpeed = frame.WalkSpeed
        }
    end
    
    -- Restore character to position if there are frames
    if #Recording.Frames > 0 and RecordingState.SelectedFrame then
        local frameIndex = math.clamp(RecordingState.SelectedFrame, 1, #Recording.Frames)
        local frame = Recording.Frames[frameIndex]
        rootPart.CFrame = CFrame.new(frame.Position) * CFrame.Angles(frame.Rotation.X, frame.Rotation.Y, frame.Rotation.Z)
    end
    
    -- Wait a moment for physics to settle, then unanchor
    task.wait(0.1)
    rootPart.Anchored = wasAnchored
    
    print("Undone: " .. previousState.Action)
    return true
end

-- Redo last undone action with character stability
local function performRedo()
    if #EditHistory.RedoStack == 0 then
        print("Nothing to redo")
        return false
    end
    
    -- CRITICAL: Anchor character to prevent falling during redo
    local wasAnchored = rootPart.Anchored
    rootPart.Anchored = true
    
    -- Save current state to undo stack
    local currentState = {
        Action = "Undo Point",
        Frames = {},
        Timestamp = tick()
    }
    
    for i, frame in ipairs(Recording.Frames) do
        currentState.Frames[i] = {
            Position = frame.Position,
            Rotation = frame.Rotation,
            State = frame.State,
            Timestamp = frame.Timestamp,
            Velocity = frame.Velocity,
            JumpPower = frame.JumpPower,
            WalkSpeed = frame.WalkSpeed
        }
    end
    
    table.insert(EditHistory.UndoStack, currentState)
    
    -- Restore redo state
    local redoState = table.remove(EditHistory.RedoStack)
    Recording.Frames = {}
    
    for i, frame in ipairs(redoState.Frames) do
        Recording.Frames[i] = {
            Position = frame.Position,
            Rotation = frame.Rotation,
            State = frame.State,
            Timestamp = frame.Timestamp,
            Velocity = frame.Velocity,
            JumpPower = frame.JumpPower,
            WalkSpeed = frame.WalkSpeed
        }
    end
    
    -- Restore character to position if there are frames
    if #Recording.Frames > 0 and RecordingState.SelectedFrame then
        local frameIndex = math.clamp(RecordingState.SelectedFrame, 1, #Recording.Frames)
        local frame = Recording.Frames[frameIndex]
        rootPart.CFrame = CFrame.new(frame.Position) * CFrame.Angles(frame.Rotation.X, frame.Rotation.Y, frame.Rotation.Z)
    end
    
    -- Wait a moment for physics to settle, then unanchor
    task.wait(0.1)
    rootPart.Anchored = wasAnchored
    
    print("Redone: " .. redoState.Action)
    return true
end

--[[═══════════════════════════════════════════════════════════════════════════
    RECORDING SYSTEM
═══════════════════════════════════════════════════════════════════════════════]]

-- Start recording
local function startRecording()
    if RecordingState.IsRecording then
        print("Already recording!")
        return
    end
    
    -- Reset recording data
    Recording.Frames = {}
    Recording.CurrentFrame = 1
    Recording.Duration = 0
    
    -- Clear undo/redo history
    EditHistory.UndoStack = {}
    EditHistory.RedoStack = {}
    
    RecordingState.IsRecording = true
    RecordingState.LastRecordTime = tick()
    
    print("Recording started...")
    
    -- Record loop
    RecordingState.RecordConnection = RunService.Heartbeat:Connect(function()
        local currentTime = tick()
        
        if currentTime - RecordingState.LastRecordTime >= FRAME_TIME then
            -- Capture current frame
            local position = rootPart.Position
            local rotation = Vector3.new(rootPart.CFrame:ToEulerAnglesXYZ())
            local state = humanoid:GetState()
            local velocity = rootPart.Velocity
            
            local frame = createFrame(
                position,
                rotation,
                state,
                currentTime - RecordingState.LastRecordTime,
                velocity
            )
            
            table.insert(Recording.Frames, frame)
            Recording.Duration = Recording.Duration + FRAME_TIME
            RecordingState.LastRecordTime = currentTime
        end
    end)
end

-- Stop recording
local function stopRecording()
    if not RecordingState.IsRecording then
        print("Not recording!")
        return
    end
    
    RecordingState.IsRecording = false
    
    if RecordingState.RecordConnection then
        RecordingState.RecordConnection:Disconnect()
        RecordingState.RecordConnection = nil
    end
    
    print("Recording stopped. Captured " .. #Recording.Frames .. " frames")
end

--[[═══════════════════════════════════════════════════════════════════════════
    PLAYBACK SYSTEM (Using Humanoid:MoveTo for natural movement)
═══════════════════════════════════════════════════════════════════════════════]]

-- Interpolate between frames for smooth movement
local function interpolateFrames(frame1, frame2, alpha)
    return {
        Position = frame1.Position:Lerp(frame2.Position, alpha),
        Rotation = Vector3.new(
            frame1.Rotation.X + (frame2.Rotation.X - frame1.Rotation.X) * alpha,
            frame1.Rotation.Y + (frame2.Rotation.Y - frame1.Rotation.Y) * alpha,
            frame1.Rotation.Z + (frame2.Rotation.Z - frame1.Rotation.Z) * alpha
        ),
        State = frame1.State
    }
end

-- Play recording using Humanoid:MoveTo() for natural movement
local function playRecording()
    if #Recording.Frames == 0 then
        print("No recording to play!")
        return
    end
    
    if RecordingState.IsPlaying then
        print("Already playing!")
        return
    end
    
    RecordingState.IsPlaying = true
    RecordingState.IsPaused = false
    RecordingState.PlaybackStartTime = tick()
    Recording.CurrentFrame = 1
    
    print("Playing recording...")
    
    local currentFrameIndex = 1
    local moveToConnection = nil
    
    RecordingState.PlaybackConnection = RunService.Heartbeat:Connect(function()
        if RecordingState.IsPaused then
            return
        end
        
        if currentFrameIndex > #Recording.Frames then
            if RecordingState.Loop then
                currentFrameIndex = 1
                RecordingState.PlaybackStartTime = tick()
            else
                stopPlayback()
                return
            end
        end
        
        local frame = Recording.Frames[currentFrameIndex]
        Recording.CurrentFrame = currentFrameIndex
        
        -- CRITICAL: Use Humanoid:MoveTo() for natural movement
        if currentFrameIndex < #Recording.Frames then
            local nextFrame = Recording.Frames[currentFrameIndex + 1]
            
            -- Calculate distance to next position
            local distance = (nextFrame.Position - rootPart.Position).Magnitude
            
            -- Only MoveTo if distance is significant
            if distance > 0.5 then
                humanoid:MoveTo(nextFrame.Position)
            end
            
            -- Handle jumping
            if nextFrame.State == Enum.HumanoidStateType.Jumping or 
               nextFrame.State == Enum.HumanoidStateType.Freefall then
                humanoid.Jump = true
            end
            
            -- Apply rotation smoothly
            local targetCFrame = CFrame.new(rootPart.Position) * 
                                CFrame.Angles(nextFrame.Rotation.X, nextFrame.Rotation.Y, nextFrame.Rotation.Z)
            rootPart.CFrame = rootPart.CFrame:Lerp(targetCFrame, 0.3)
        end
        
        -- Advance frame based on playback speed
        local frameAdvance = RecordingState.PlaybackSpeed * (1 / RECORD_FPS) / FRAME_TIME
        currentFrameIndex = currentFrameIndex + frameAdvance
        currentFrameIndex = math.floor(currentFrameIndex)
    end)
end

-- Stop playback
local function stopPlayback()
    RecordingState.IsPlaying = false
    RecordingState.IsPaused = false
    
    if RecordingState.PlaybackConnection then
        RecordingState.PlaybackConnection:Disconnect()
        RecordingState.PlaybackConnection = nil
    end
    
    print("Playback stopped")
end

-- Pause playback
local function pausePlayback()
    if not RecordingState.IsPlaying then
        print("Not playing!")
        return
    end
    
    RecordingState.IsPaused = not RecordingState.IsPaused
    print(RecordingState.IsPaused and "Playback paused" or "Playback resumed")
end

-- Jump to specific frame
local function jumpToFrame(frameNumber)
    if frameNumber < 1 or frameNumber > #Recording.Frames then
        print("Invalid frame number!")
        return
    end
    
    Recording.CurrentFrame = frameNumber
    local frame = Recording.Frames[frameNumber]
    
    -- CRITICAL: Anchor before teleporting to frame
    local wasAnchored = rootPart.Anchored
    rootPart.Anchored = true
    
    -- Set position and rotation
    rootPart.CFrame = CFrame.new(frame.Position) * CFrame.Angles(frame.Rotation.X, frame.Rotation.Y, frame.Rotation.Z)
    
    -- Wait and unanchor
    task.wait(0.1)
    rootPart.Anchored = wasAnchored
    
    RecordingState.SelectedFrame = frameNumber
    print("Jumped to frame " .. frameNumber)
end

--[[═══════════════════════════════════════════════════════════════════════════
    FRAME EDITING SYSTEM
═══════════════════════════════════════════════════════════════════════════════]]

-- Modify a specific frame
local function modifyFrame(frameIndex, newPosition, newRotation, newState)
    if frameIndex < 1 or frameIndex > #Recording.Frames then
        print("Invalid frame index!")
        return false
    end
    
    -- Save state for undo
    saveStateForUndo("Modify Frame " .. frameIndex, {
        FrameIndex = frameIndex,
        OldFrame = Recording.Frames[frameIndex]
    })
    
    local frame = Recording.Frames[frameIndex]
    
    if newPosition then
        frame.Position = newPosition
    end
    
    if newRotation then
        frame.Rotation = newRotation
    end
    
    if newState then
        frame.State = newState
    end
    
    print("Frame " .. frameIndex .. " modified")
    return true
end

-- Insert new frame
local function insertFrame(afterIndex, position, rotation, state)
    if afterIndex < 0 or afterIndex > #Recording.Frames then
        print("Invalid insert position!")
        return false
    end
    
    -- Save state for undo
    saveStateForUndo("Insert Frame", {
        InsertIndex = afterIndex + 1
    })
    
    local newFrame = createFrame(
        position or rootPart.Position,
        rotation or Vector3.new(rootPart.CFrame:ToEulerAnglesXYZ()),
        state or humanoid:GetState(),
        FRAME_TIME,
        Vector3.new(0, 0, 0)
    )
    
    table.insert(Recording.Frames, afterIndex + 1, newFrame)
    print("Frame inserted at position " .. (afterIndex + 1))
    return true
end

-- Delete frame
local function deleteFrame(frameIndex)
    if frameIndex < 1 or frameIndex > #Recording.Frames then
        print("Invalid frame index!")
        return false
    end
    
    if #Recording.Frames <= 1 then
        print("Cannot delete the only frame!")
        return false
    end
    
    -- Save state for undo
    saveStateForUndo("Delete Frame " .. frameIndex, {
        FrameIndex = frameIndex,
        DeletedFrame = Recording.Frames[frameIndex]
    })
    
    table.remove(Recording.Frames, frameIndex)
    print("Frame " .. frameIndex .. " deleted")
    return true
end

-- Adjust frame timing
local function adjustFrameTiming(frameIndex, newTimestamp)
    if frameIndex < 1 or frameIndex > #Recording.Frames then
        print("Invalid frame index!")
        return false
    end
    
    -- Save state for undo
    saveStateForUndo("Adjust Timing " .. frameIndex, {
        FrameIndex = frameIndex,
        OldTimestamp = Recording.Frames[frameIndex].Timestamp
    })
    
    Recording.Frames[frameIndex].Timestamp = newTimestamp
    print("Frame " .. frameIndex .. " timing adjusted")
    return true
end

--[[═══════════════════════════════════════════════════════════════════════════
    SAVE/LOAD SYSTEM
═══════════════════════════════════════════════════════════════════════════════]]

-- Export recording as JSON string
local function exportRecording()
    local exportData = {
        Name = Recording.Name,
        FPS = Recording.FPS,
        Duration = Recording.Duration,
        FrameCount = #Recording.Frames,
        Frames = {}
    }
    
    for i, frame in ipairs(Recording.Frames) do
        table.insert(exportData.Frames, {
            Position = {frame.Position.X, frame.Position.Y, frame.Position.Z},
            Rotation = {frame.Rotation.X, frame.Rotation.Y, frame.Rotation.Z},
            State = tostring(frame.State),
            Timestamp = frame.Timestamp,
            Velocity = {frame.Velocity.X, frame.Velocity.Y, frame.Velocity.Z},
            JumpPower = frame.JumpPower,
            WalkSpeed = frame.WalkSpeed
        })
    end
    
    local json = HttpService:JSONEncode(exportData)
    print("Recording exported to clipboard (JSON)")
    print("Frame count: " .. #Recording.Frames)
    
    return json
end

-- Import recording from JSON string
local function importRecording(jsonString)
    local success, importData = pcall(function()
        return HttpService:JSONDecode(jsonString)
    end)
    
    if not success then
        print("Failed to import recording: Invalid JSON")
        return false
    end
    
    -- Save current state for undo
    saveStateForUndo("Import Recording", {})
    
    Recording.Name = importData.Name or "Imported Recording"
    Recording.FPS = importData.FPS or RECORD_FPS
    Recording.Duration = importData.Duration or 0
    Recording.Frames = {}
    
    for i, frameData in ipairs(importData.Frames) do
        local frame = {
            Position = Vector3.new(frameData.Position[1], frameData.Position[2], frameData.Position[3]),
            Rotation = Vector3.new(frameData.Rotation[1], frameData.Rotation[2], frameData.Rotation[3]),
            State = Enum.HumanoidStateType[frameData.State:gsub("Enum.HumanoidStateType.", "")] or Enum.HumanoidStateType.Running,
            Timestamp = frameData.Timestamp,
            Velocity = Vector3.new(frameData.Velocity[1], frameData.Velocity[2], frameData.Velocity[3]),
            JumpPower = frameData.JumpPower or 50,
            WalkSpeed = frameData.WalkSpeed or 16
        }
        table.insert(Recording.Frames, frame)
    end
    
    print("Recording imported: " .. Recording.Name)
    print("Frame count: " .. #Recording.Frames)
    return true
end

--[[═══════════════════════════════════════════════════════════════════════════
    GUI SYSTEM
═══════════════════════════════════════════════════════════════════════════════]]

-- Create main GUI
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "MovementRecorderGUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 600, 0, 400)
    mainFrame.Position = UDim2.new(0.5, -300, 0.5, -200)
    mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- Add corner
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    title.BorderSizePixel = 0
    title.Text = "Movement Recorder"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    -- Title corner
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = title
    
    -- Control buttons frame
    local controlsFrame = Instance.new("Frame")
    controlsFrame.Name = "ControlsFrame"
    controlsFrame.Size = UDim2.new(1, -20, 0, 60)
    controlsFrame.Position = UDim2.new(0, 10, 0, 50)
    controlsFrame.BackgroundTransparency = 1
    controlsFrame.Parent = mainFrame
    
    -- Button creation helper
    local function createButton(name, text, position, callback)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Size = UDim2.new(0, 90, 0, 50)
        button.Position = position
        button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        button.BorderSizePixel = 0
        button.Text = text
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 14
        button.Font = Enum.Font.Gotham
        button.Parent = controlsFrame
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 6)
        buttonCorner.Parent = button
        
        button.MouseButton1Click:Connect(callback)
        
        -- Hover effect
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end)
        
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end)
        
        return button
    end
    
    -- Control buttons
    local recordBtn = createButton("RecordBtn", "Record", UDim2.new(0, 0, 0, 0), function()
        if not RecordingState.IsRecording then
            startRecording()
            recordBtn.Text = "Stop Rec"
            recordBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        else
            stopRecording()
            recordBtn.Text = "Record"
            recordBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
    end)
    
    local playBtn = createButton("PlayBtn", "Play", UDim2.new(0, 100, 0, 0), function()
        if not RecordingState.IsPlaying then
            playRecording()
            playBtn.Text = "Stop"
            playBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
        else
            stopPlayback()
            playBtn.Text = "Play"
            playBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
    end)
    
    createButton("PauseBtn", "Pause", UDim2.new(0, 200, 0, 0), pausePlayback)
    
    createButton("UndoBtn", "Undo", UDim2.new(0, 300, 0, 0), performUndo)
    
    createButton("RedoBtn", "Redo", UDim2.new(0, 400, 0, 0), performRedo)
    
    createButton("ExportBtn", "Export", UDim2.new(0, 500, 0, 0), function()
        local json = exportRecording()
        -- Copy to clipboard (in real implementation, you'd use clipboard API)
        print("JSON:", json)
    end)
    
    -- Info frame
    local infoFrame = Instance.new("Frame")
    infoFrame.Name = "InfoFrame"
    infoFrame.Size = UDim2.new(1, -20, 0, 80)
    infoFrame.Position = UDim2.new(0, 10, 0, 120)
    infoFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    infoFrame.BorderSizePixel = 0
    infoFrame.Parent = mainFrame
    
    local infoCorner = Instance.new("UICorner")
    infoCorner.CornerRadius = UDim.new(0, 6)
    infoCorner.Parent = infoFrame
    
    -- Info labels
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -10, 0, 20)
    statusLabel.Position = UDim2.new(0, 5, 0, 5)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: Idle"
    statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusLabel.TextSize = 14
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = infoFrame
    
    local framesLabel = Instance.new("TextLabel")
    framesLabel.Name = "FramesLabel"
    framesLabel.Size = UDim2.new(1, -10, 0, 20)
    framesLabel.Position = UDim2.new(0, 5, 0, 25)
    framesLabel.BackgroundTransparency = 1
    framesLabel.Text = "Frames: 0"
    framesLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    framesLabel.TextSize = 14
    framesLabel.Font = Enum.Font.Gotham
    framesLabel.TextXAlignment = Enum.TextXAlignment.Left
    framesLabel.Parent = infoFrame
    
    local currentFrameLabel = Instance.new("TextLabel")
    currentFrameLabel.Name = "CurrentFrameLabel"
    currentFrameLabel.Size = UDim2.new(1, -10, 0, 20)
    currentFrameLabel.Position = UDim2.new(0, 5, 0, 45)
    currentFrameLabel.BackgroundTransparency = 1
    currentFrameLabel.Text = "Current Frame: 0"
    currentFrameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    currentFrameLabel.TextSize = 14
    currentFrameLabel.Font = Enum.Font.Gotham
    currentFrameLabel.TextXAlignment = Enum.TextXAlignment.Left
    currentFrameLabel.Parent = infoFrame
    
    -- Timeline frame
    local timelineFrame = Instance.new("Frame")
    timelineFrame.Name = "TimelineFrame"
    timelineFrame.Size = UDim2.new(1, -20, 0, 150)
    timelineFrame.Position = UDim2.new(0, 10, 0, 210)
    timelineFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    timelineFrame.BorderSizePixel = 0
    timelineFrame.Parent = mainFrame
    
    local timelineCorner = Instance.new("UICorner")
    timelineCorner.CornerRadius = UDim.new(0, 6)
    timelineCorner.Parent = timelineFrame
    
    -- Timeline title
    local timelineTitle = Instance.new("TextLabel")
    timelineTitle.Name = "TimelineTitle"
    timelineTitle.Size = UDim2.new(1, 0, 0, 30)
    timelineTitle.BackgroundTransparency = 1
    timelineTitle.Text = "Timeline"
    timelineTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    timelineTitle.TextSize = 16
    timelineTitle.Font = Enum.Font.GothamBold
    timelineTitle.Parent = timelineFrame
    
    -- Timeline scroll frame
    local timelineScroll = Instance.new("ScrollingFrame")
    timelineScroll.Name = "TimelineScroll"
    timelineScroll.Size = UDim2.new(1, -10, 1, -40)
    timelineScroll.Position = UDim2.new(0, 5, 0, 35)
    timelineScroll.BackgroundTransparency = 1
    timelineScroll.BorderSizePixel = 0
    timelineScroll.ScrollBarThickness = 6
    timelineScroll.Parent = timelineFrame
    
    -- Timeline list layout
    local listLayout = Instance.new("UIListLayout")
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 2)
    listLayout.Parent = timelineScroll
    
    -- Update GUI function
    local function updateGUI()
        -- Update status
        if RecordingState.IsRecording then
            statusLabel.Text = "Status: Recording"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        elseif RecordingState.IsPlaying then
            statusLabel.Text = RecordingState.IsPaused and "Status: Paused" or "Status: Playing"
            statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        else
            statusLabel.Text = "Status: Idle"
            statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
        
        -- Update frames count
        framesLabel.Text = "Frames: " .. #Recording.Frames
        
        -- Update current frame
        currentFrameLabel.Text = "Current Frame: " .. Recording.CurrentFrame .. " / " .. #Recording.Frames
        
        -- Update timeline
        timelineScroll:ClearAllChildren()
        
        local listLayout = Instance.new("UIListLayout")
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Padding = UDim.new(0, 2)
        listLayout.Parent = timelineScroll
        
        for i, frame in ipairs(Recording.Frames) do
            local frameButton = Instance.new("TextButton")
            frameButton.Name = "Frame" .. i
            frameButton.Size = UDim2.new(1, -6, 0, 25)
            frameButton.BackgroundColor3 = i == Recording.CurrentFrame and Color3.fromRGB(80, 120, 180) or Color3.fromRGB(70, 70, 70)
            frameButton.BorderSizePixel = 0
            frameButton.Text = string.format("Frame %d - Pos: %.1f, %.1f, %.1f", i, frame.Position.X, frame.Position.Y, frame.Position.Z)
            frameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            frameButton.TextSize = 12
            frameButton.Font = Enum.Font.Gotham
            frameButton.TextXAlignment = Enum.TextXAlignment.Left
            frameButton.Parent = timelineScroll
            
            local frameCorner = Instance.new("UICorner")
            frameCorner.CornerRadius = UDim.new(0, 4)
            frameCorner.Parent = frameButton
            
            frameButton.MouseButton1Click:Connect(function()
                jumpToFrame(i)
                updateGUI()
            end)
        end
        
        timelineScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
    end
    
    -- Toggle GUI visibility
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(0, 50, 0, 50)
    toggleButton.Position = UDim2.new(1, -60, 0, 10)
    toggleButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    toggleButton.BorderSizePixel = 0
    toggleButton.Text = "📹"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextSize = 24
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.Parent = screenGui
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = toggleButton
    
    toggleButton.MouseButton1Click:Connect(function()
        mainFrame.Visible = not mainFrame.Visible
    end)
    
    -- Update GUI loop
    RunService.Heartbeat:Connect(function()
        if mainFrame.Visible then
            updateGUI()
        end
    end)
    
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    print("Movement Recorder GUI loaded!")
end

--[[═══════════════════════════════════════════════════════════════════════════
    KEYBOARD SHORTCUTS
═══════════════════════════════════════════════════════════════════════════════]]

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    -- Ctrl+Z: Undo
    if input.KeyCode == Enum.KeyCode.Z and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        performUndo()
    end
    
    -- Ctrl+Y: Redo
    if input.KeyCode == Enum.KeyCode.Y and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        performRedo()
    end
    
    -- Space: Play/Pause
    if input.KeyCode == Enum.KeyCode.Space and not UserInputService:GetFocusedTextBox() then
        if RecordingState.IsPlaying then
            pausePlayback()
        else
            playRecording()
        end
    end
    
    -- R: Record
    if input.KeyCode == Enum.KeyCode.R and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        if not RecordingState.IsRecording then
            startRecording()
        else
            stopRecording()
        end
    end
end)

--[[═══════════════════════════════════════════════════════════════════════════
    INITIALIZATION
═══════════════════════════════════════════════════════════════════════════════]]

-- Handle character respawn
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Stop any ongoing recording or playback
    if RecordingState.IsRecording then
        stopRecording()
    end
    
    if RecordingState.IsPlaying then
        stopPlayback()
    end
end)

-- Initialize GUI
createGUI()

print("═══════════════════════════════════════════════════════════════")
print("Movement Recorder System Loaded!")
print("═══════════════════════════════════════════════════════════════")
print("Controls:")
print("- Click the 📹 button to toggle the GUI")
print("- Ctrl+R: Start/Stop Recording")
print("- Space: Play/Pause")
print("- Ctrl+Z: Undo")
print("- Ctrl+Y: Redo")
print("═══════════════════════════════════════════════════════════════")
