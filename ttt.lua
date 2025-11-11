-- Movement Recorder Pro - Complete Frame-by-Frame Movement Recording & Editing System
-- Place this in StarterPlayer > StarterPlayerScripts or StarterGui
-- Features: Frame editing, Undo/Redo, Mobile support, Natural walking replay, Minimize to floating icon

print("=== Movement Recorder Pro - Initializing ===")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

wait(0.5)

-- ============================
-- CONFIGURATION
-- ============================
local CONFIG = {
    RECORD_FPS = 30, -- Frames per second for recording
    PLAYBACK_DEFAULT_SPEED = 1.0,
    MAX_UNDO_STACK = 50,
    WAYPOINT_THRESHOLD = 2.5, -- Distance to consider waypoint reached
    MOBILE_BUTTON_SIZE = 60, -- Larger buttons for mobile
    PC_BUTTON_SIZE = 40,
    FLOATING_ICON_SIZE = 50
}

-- ============================
-- STATE MANAGEMENT
-- ============================
local State = {
    -- Recording
    frames = {}, -- Array of frame data
    isRecording = false,
    isPaused = false,
    isPlaying = false,
    
    -- Playback
    currentFrame = 0,
    playbackSpeed = CONFIG.PLAYBACK_DEFAULT_SPEED,
    loopEnabled = false,
    
    -- Editing
    selectedFrame = nil,
    undoStack = {},
    redoStack = {},
    
    -- UI
    isMinimized = false,
    isMobile = false,
    
    -- Connections
    recordConnection = nil,
    playConnection = nil,
    
    -- Recordings management
    savedRecordings = {},
    currentRecordingName = "Recording_1"
}

-- ============================
-- FRAME DATA STRUCTURE
-- ============================
--[[
Frame = {
    index = number,
    timestamp = number,
    position = Vector3,
    cframe = CFrame,
    lookVector = Vector3,
    state = HumanoidStateType,
    isJumping = boolean,
    isClimbing = boolean
}
]]

-- ============================
-- UTILITY FUNCTIONS
-- ============================

local function detectMobile()
    local hasTouch = UserInputService.TouchEnabled
    local hasKeyboard = UserInputService.KeyboardEnabled
    local hasMouse = UserInputService.MouseEnabled
    
    -- Consider mobile if touch is enabled and either no keyboard or no mouse
    return hasTouch and (not hasKeyboard or not hasMouse)
end

local function deepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = deepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function saveToUndoStack()
    table.insert(State.undoStack, deepCopy(State.frames))
    if #State.undoStack > CONFIG.MAX_UNDO_STACK then
        table.remove(State.undoStack, 1)
    end
    State.redoStack = {} -- Clear redo stack on new action
end

-- ============================
-- CHARACTER STABILITY FUNCTIONS
-- ============================

local function anchorCharacter()
    -- Anchor character to prevent falling during edits
    if hrp then
        hrp.Anchored = true
    end
end

local function unanchorCharacter()
    -- Unanchor character after edits
    if hrp then
        hrp.Anchored = false
    end
end

local function teleportToFrame(frame)
    -- Safely teleport character to frame position
    if not frame or not hrp then return end
    
    anchorCharacter()
    hrp.CFrame = frame.cframe
    wait(0.05) -- Small delay for physics to settle
    unanchorCharacter()
end

-- ============================
-- RECORDING FUNCTIONS
-- ============================

local function captureFrame()
    local currentState = humanoid:GetState()
    
    local frame = {
        index = #State.frames + 1,
        timestamp = tick(),
        position = hrp.Position,
        cframe = hrp.CFrame,
        lookVector = hrp.CFrame.LookVector,
        state = currentState,
        isJumping = currentState == Enum.HumanoidStateType.Jumping or 
                   currentState == Enum.HumanoidStateType.Freefall,
        isClimbing = currentState == Enum.HumanoidStateType.Climbing
    }
    
    return frame
end

local function startRecording()
    if State.isRecording or State.isPlaying then return end
    
    print("Recording started...")
    State.isRecording = true
    State.frames = {}
    saveToUndoStack()
    
    local frameInterval = 1 / CONFIG.RECORD_FPS
    local timeSinceLastFrame = 0
    
    State.recordConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not State.isRecording then return end
        
        timeSinceLastFrame = timeSinceLastFrame + deltaTime
        
        if timeSinceLastFrame >= frameInterval then
            local frame = captureFrame()
            table.insert(State.frames, frame)
            timeSinceLastFrame = 0
        end
    end)
end

local function stopRecording()
    if State.recordConnection then
        State.recordConnection:Disconnect()
        State.recordConnection = nil
    end
    
    State.isRecording = false
    print("Recording stopped. Total frames:", #State.frames)
end

-- ============================
-- PLAYBACK FUNCTIONS
-- ============================

local function interpolateFrames(frame1, frame2, alpha)
    -- Smooth interpolation between two frames
    return {
        position = frame1.position:Lerp(frame2.position, alpha),
        cframe = frame1.cframe:Lerp(frame2.cframe, alpha),
        lookVector = frame1.lookVector:Lerp(frame2.lookVector, alpha),
        isJumping = frame2.isJumping,
        isClimbing = frame2.isClimbing
    }
end

local function playRecording()
    if State.isRecording or State.isPlaying or #State.frames == 0 then 
        print("Cannot play: no frames or already playing")
        return 
    end
    
    print("Playback started with", #State.frames, "frames")
    State.isPlaying = true
    State.currentFrame = 1
    
    local moveTimeout = 0
    local maxMoveTimeout = 3
    
    State.playConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not State.isPlaying or State.isPaused then return end
        
        local adjustedDelta = deltaTime * State.playbackSpeed
        State.currentFrame = State.currentFrame + (adjustedDelta * CONFIG.RECORD_FPS)
        
        local frameIndex = math.floor(State.currentFrame)
        
        if frameIndex >= #State.frames then
            if State.loopEnabled then
                State.currentFrame = 1
                frameIndex = 1
            else
                stopPlayback()
                return
            end
        end
        
        local frame = State.frames[frameIndex]
        local nextFrame = State.frames[frameIndex + 1]
        
        if frame then
            -- Use Humanoid:MoveTo() for natural walking - NO TELEPORTING!
            local targetPosition = frame.position
            
            if nextFrame then
                local alpha = State.currentFrame - frameIndex
                local interpolated = interpolateFrames(frame, nextFrame, alpha)
                targetPosition = interpolated.position
            end
            
            -- Move naturally using Humanoid
            humanoid:MoveTo(targetPosition)
            
            -- Handle jumping
            if frame.isJumping then
                local currentState = humanoid:GetState()
                if currentState ~= Enum.HumanoidStateType.Jumping and 
                   currentState ~= Enum.HumanoidStateType.Freefall then
                    humanoid.Jump = true
                end
            end
            
            -- Handle climbing
            if frame.isClimbing then
                humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
            end
            
            -- Check if stuck
            local distanceToTarget = (targetPosition - hrp.Position).Magnitude
            if distanceToTarget < CONFIG.WAYPOINT_THRESHOLD then
                moveTimeout = 0
            else
                moveTimeout = moveTimeout + deltaTime
                if moveTimeout > maxMoveTimeout then
                    -- Skip to next frame if stuck
                    State.currentFrame = frameIndex + 1
                    moveTimeout = 0
                end
            end
        end
    end)
end

local function stopPlayback()
    if State.playConnection then
        State.playConnection:Disconnect()
        State.playConnection = nil
    end
    
    State.isPlaying = false
    State.isPaused = false
    State.currentFrame = 0
    print("Playback stopped")
end

local function pausePlayback()
    State.isPaused = not State.isPaused
end

local function scrubToFrame(frameIndex)
    if frameIndex < 1 or frameIndex > #State.frames then return end
    
    State.currentFrame = frameIndex
    local frame = State.frames[frameIndex]
    
    if frame then
        teleportToFrame(frame)
    end
end

-- ============================
-- EDITING FUNCTIONS
-- ============================

local function insertFrame(atIndex)
    if #State.frames == 0 then return end
    
    saveToUndoStack()
    
    local newFrame = captureFrame()
    newFrame.index = atIndex
    
    table.insert(State.frames, atIndex, newFrame)
    
    -- Reindex frames
    for i = atIndex + 1, #State.frames do
        State.frames[i].index = i
    end
    
    print("Frame inserted at index", atIndex)
end

local function deleteFrame(frameIndex)
    if frameIndex < 1 or frameIndex > #State.frames then return end
    
    saveToUndoStack()
    
    table.remove(State.frames, frameIndex)
    
    -- Reindex frames
    for i = frameIndex, #State.frames do
        State.frames[i].index = i
    end
    
    print("Frame deleted at index", frameIndex)
end

local function modifyFrame(frameIndex, newData)
    if frameIndex < 1 or frameIndex > #State.frames then return end
    
    saveToUndoStack()
    
    local frame = State.frames[frameIndex]
    
    if newData.position then
        frame.position = newData.position
        frame.cframe = CFrame.new(newData.position) * CFrame.Angles(0, math.atan2(frame.lookVector.X, frame.lookVector.Z), 0)
    end
    
    if newData.rotation then
        frame.cframe = CFrame.new(frame.position) * newData.rotation
        frame.lookVector = frame.cframe.LookVector
    end
    
    print("Frame modified at index", frameIndex)
end

local function undo()
    if #State.undoStack == 0 then 
        print("Nothing to undo")
        return 
    end
    
    -- Save current state to redo stack
    table.insert(State.redoStack, deepCopy(State.frames))
    
    -- Restore previous state
    State.frames = table.remove(State.undoStack)
    
    -- Keep character stable during undo
    if State.selectedFrame and State.frames[State.selectedFrame] then
        teleportToFrame(State.frames[State.selectedFrame])
    end
    
    print("Undo performed")
end

local function redo()
    if #State.redoStack == 0 then 
        print("Nothing to redo")
        return 
    end
    
    -- Save current state to undo stack
    table.insert(State.undoStack, deepCopy(State.frames))
    
    -- Restore redo state
    State.frames = table.remove(State.redoStack)
    
    -- Keep character stable during redo
    if State.selectedFrame and State.frames[State.selectedFrame] then
        teleportToFrame(State.frames[State.selectedFrame])
    end
    
    print("Redo performed")
end

-- ============================
-- SAVE/LOAD FUNCTIONS
-- ============================

local function serializeRecording()
    local data = {
        name = State.currentRecordingName,
        frames = {},
        metadata = {
            frameCount = #State.frames,
            recordedAt = os.time(),
            fps = CONFIG.RECORD_FPS
        }
    }
    
    for i, frame in ipairs(State.frames) do
        table.insert(data.frames, {
            index = frame.index,
            timestamp = frame.timestamp,
            position = {frame.position.X, frame.position.Y, frame.position.Z},
            cframe = {frame.cframe:GetComponents()},
            lookVector = {frame.lookVector.X, frame.lookVector.Y, frame.lookVector.Z},
            state = tostring(frame.state),
            isJumping = frame.isJumping,
            isClimbing = frame.isClimbing
        })
    end
    
    return HttpService:JSONEncode(data)
end

local function deserializeRecording(jsonData)
    local success, data = pcall(function()
        return HttpService:JSONDecode(jsonData)
    end)
    
    if not success then
        warn("Failed to deserialize recording")
        return false
    end
    
    State.frames = {}
    
    for i, frameData in ipairs(data.frames) do
        local frame = {
            index = frameData.index,
            timestamp = frameData.timestamp,
            position = Vector3.new(frameData.position[1], frameData.position[2], frameData.position[3]),
            cframe = CFrame.new(unpack(frameData.cframe)),
            lookVector = Vector3.new(frameData.lookVector[1], frameData.lookVector[2], frameData.lookVector[3]),
            state = Enum.HumanoidStateType[frameData.state:match("HumanoidStateType%.(.+)")],
            isJumping = frameData.isJumping,
            isClimbing = frameData.isClimbing
        }
        table.insert(State.frames, frame)
    end
    
    State.currentRecordingName = data.name
    print("Recording loaded:", data.name, "with", #State.frames, "frames")
    return true
end

local function saveRecording()
    local jsonData = serializeRecording()
    State.savedRecordings[State.currentRecordingName] = jsonData
    print("Recording saved:", State.currentRecordingName)
    
    -- In a real game, you'd save to DataStore here:
    -- pcall(function()
    --     DataStoreService:GetDataStore("Recordings"):SetAsync(player.UserId, State.savedRecordings)
    -- end)
end

local function loadRecording(name)
    if not State.savedRecordings[name] then
        warn("Recording not found:", name)
        return false
    end
    
    return deserializeRecording(State.savedRecordings[name])
end

-- ============================
-- GUI CREATION
-- ============================

State.isMobile = detectMobile()
local buttonSize = State.isMobile and CONFIG.MOBILE_BUTTON_SIZE or CONFIG.PC_BUTTON_SIZE

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MovementRecorderPro"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main Frame (Full GUI)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0.8, 0, 0.85, 0)
mainFrame.Position = UDim2.new(0.1, 0, 0.075, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(0, 200, 255)
mainFrame.Active = true
mainFrame.Draggable = not State.isMobile -- Only draggable on PC
mainFrame.Parent = screenGui

-- Floating Icon (Minimized state)
local floatingIcon = Instance.new("ImageButton")
floatingIcon.Name = "FloatingIcon"
floatingIcon.Size = UDim2.new(0, CONFIG.FLOATING_ICON_SIZE, 0, CONFIG.FLOATING_ICON_SIZE)
floatingIcon.Position = UDim2.new(0.95, -CONFIG.FLOATING_ICON_SIZE, 0.5, -CONFIG.FLOATING_ICON_SIZE/2)
floatingIcon.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
floatingIcon.BorderSizePixel = 0
floatingIcon.Text = ""
floatingIcon.Visible = false
floatingIcon.Active = true
floatingIcon.Draggable = true
floatingIcon.Parent = screenGui

-- Add rounded corners to floating icon
local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(0.5, 0)
iconCorner.Parent = floatingIcon

-- Icon label
local iconLabel = Instance.new("TextLabel")
iconLabel.Size = UDim2.new(1, 0, 1, 0)
iconLabel.BackgroundTransparency = 1
iconLabel.Text = "📹"
iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
iconLabel.Font = Enum.Font.GothamBold
iconLabel.TextSize = 24
iconLabel.Parent = floatingIcon

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -100, 1, 0)
titleLabel.Position = UDim2.new(0, 10, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Movement Recorder Pro"
titleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = State.isMobile and 18 or 20
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Minimize Button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "MinimizeBtn"
minimizeBtn.Size = UDim2.new(0, 40, 0, 40)
minimizeBtn.Position = UDim2.new(1, -90, 0, 5)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
minimizeBtn.Text = "−"
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = 24
minimizeBtn.Parent = titleBar

local minimizeCorner = Instance.new("UICorner")
minimizeCorner.CornerRadius = UDim.new(0.2, 0)
minimizeCorner.Parent = minimizeBtn

-- Close Button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -45, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 24
closeBtn.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0.2, 0)
closeCorner.Parent = closeBtn

-- Content Frame
local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, -20, 1, -70)
contentFrame.Position = UDim2.new(0, 10, 0, 60)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- Button creation helper
local function createButton(name, text, position, size, color)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = size
    button.Position = position
    button.BackgroundColor3 = color or Color3.fromRGB(50, 50, 70)
    button.BorderSizePixel = 0
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamBold
    button.TextSize = State.isMobile and 14 or 16
    button.TextScaled = State.isMobile
    button.Parent = contentFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.1, 0)
    corner.Parent = button
    
    return button
end

-- Recording Controls Section
local recordBtn = createButton("RecordBtn", "⏺ RECORD", 
    UDim2.new(0, 0, 0, 0), 
    UDim2.new(0.32, -5, 0, buttonSize), 
    Color3.fromRGB(200, 50, 50))

local stopBtn = createButton("StopBtn", "⏹ STOP", 
    UDim2.new(0.34, 0, 0, 0), 
    UDim2.new(0.32, -5, 0, buttonSize), 
    Color3.fromRGB(150, 150, 150))

local playBtn = createButton("PlayBtn", "▶ PLAY", 
    UDim2.new(0.68, 0, 0, 0), 
    UDim2.new(0.32, 0, 0, buttonSize), 
    Color3.fromRGB(50, 200, 50))

local pauseBtn = createButton("PauseBtn", "⏸ PAUSE", 
    UDim2.new(0, 0, 0, buttonSize + 10), 
    UDim2.new(0.49, -5, 0, buttonSize * 0.8), 
    Color3.fromRGB(100, 100, 200))

local loopBtn = createButton("LoopBtn", "🔁 LOOP: OFF", 
    UDim2.new(0.51, 0, 0, buttonSize + 10), 
    UDim2.new(0.49, 0, 0, buttonSize * 0.8), 
    Color3.fromRGB(100, 150, 100))

-- Status Display
local statusBox = Instance.new("Frame")
statusBox.Name = "StatusBox"
statusBox.Size = UDim2.new(1, 0, 0, 80)
statusBox.Position = UDim2.new(0, 0, 0, buttonSize * 1.9 + 20)
statusBox.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
statusBox.BorderSizePixel = 1
statusBox.BorderColor3 = Color3.fromRGB(100, 100, 120)
statusBox.Parent = contentFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 1, -10)
statusLabel.Position = UDim2.new(0, 10, 0, 5)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: Ready\nFrames: 0\nCurrent Frame: 0\nMode: Natural Humanoid Walking"
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = State.isMobile and 12 or 14
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextWrapped = true
statusLabel.Parent = statusBox

-- Speed Control
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, 0, 0, 20)
speedLabel.Position = UDim2.new(0, 0, 0, buttonSize * 1.9 + 110)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Playback Speed: 1.0x"
speedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = State.isMobile and 12 or 14
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = contentFrame

local speedSlider = Instance.new("Frame")
speedSlider.Size = UDim2.new(1, 0, 0, State.isMobile and 40 or 30)
speedSlider.Position = UDim2.new(0, 0, 0, buttonSize * 1.9 + 135)
speedSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
speedSlider.BorderSizePixel = 1
speedSlider.BorderColor3 = Color3.fromRGB(100, 100, 120)
speedSlider.Parent = contentFrame

local speedButton = Instance.new("TextButton")
speedButton.Size = UDim2.new(0, State.isMobile and 30 : 20, 1, 0)
speedButton.Position = UDim2.new(0.5, -(State.isMobile and 15 or 10), 0, 0)
speedButton.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
speedButton.Text = ""
speedButton.Parent = speedSlider

-- Timeline Scrubber
local timelineLabel = Instance.new("TextLabel")
timelineLabel.Size = UDim2.new(1, 0, 0, 20)
timelineLabel.Position = UDim2.new(0, 0, 0, buttonSize * 1.9 + 180)
timelineLabel.BackgroundTransparency = 1
timelineLabel.Text = "Timeline Scrubber"
timelineLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timelineLabel.Font = Enum.Font.Gotham
timelineLabel.TextSize = State.isMobile and 12 or 14
timelineLabel.TextXAlignment = Enum.TextXAlignment.Left
timelineLabel.Parent = contentFrame

local timelineBar = Instance.new("Frame")
timelineBar.Size = UDim2.new(1, 0, 0, State.isMobile and 40 or 30)
timelineBar.Position = UDim2.new(0, 0, 0, buttonSize * 1.9 + 205)
timelineBar.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
timelineBar.BorderSizePixel = 1
timelineBar.BorderColor3 = Color3.fromRGB(100, 100, 120)
timelineBar.Parent = contentFrame

local timelineButton = Instance.new("TextButton")
timelineButton.Size = UDim2.new(0, State.isMobile and 30 or 20, 1, 0)
timelineButton.Position = UDim2.new(0, 0, 0, 0)
timelineButton.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
timelineButton.Text = ""
timelineButton.Parent = timelineBar

-- Editing Controls
local editLabel = Instance.new("TextLabel")
editLabel.Size = UDim2.new(1, 0, 0, 25)
editLabel.Position = UDim2.new(0, 0, 0, buttonSize * 1.9 + 250)
editLabel.BackgroundTransparency = 1
editLabel.Text = "Frame Editing"
editLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
editLabel.Font = Enum.Font.GothamBold
editLabel.TextSize = State.isMobile and 14 or 16
editLabel.TextXAlignment = Enum.TextXAlignment.Left
editLabel.Parent = contentFrame

local insertBtn = createButton("InsertBtn", "➕ INSERT", 
    UDim2.new(0, 0, 0, buttonSize * 1.9 + 280), 
    UDim2.new(0.32, -5, 0, buttonSize * 0.8), 
    Color3.fromRGB(50, 150, 200))

local deleteBtn = createButton("DeleteBtn", "🗑 DELETE", 
    UDim2.new(0.34, 0, 0, buttonSize * 1.9 + 280), 
    UDim2.new(0.32, -5, 0, buttonSize * 0.8), 
    Color3.fromRGB(200, 50, 100))

local modifyBtn = createButton("ModifyBtn", "✏ MODIFY", 
    UDim2.new(0.68, 0, 0, buttonSize * 1.9 + 280), 
    UDim2.new(0.32, 0, 0, buttonSize * 0.8), 
    Color3.fromRGB(150, 100, 200))

local undoBtn = createButton("UndoBtn", "↶ UNDO", 
    UDim2.new(0, 0, 0, buttonSize * 1.9 + 280 + buttonSize * 0.9), 
    UDim2.new(0.49, -5, 0, buttonSize * 0.8), 
    Color3.fromRGB(100, 100, 150))

local redoBtn = createButton("RedoBtn", "↷ REDO", 
    UDim2.new(0.51, 0, 0, buttonSize * 1.9 + 280 + buttonSize * 0.9), 
    UDim2.new(0.49, 0, 0, buttonSize * 0.8), 
    Color3.fromRGB(100, 100, 150))

-- Save/Load Controls
local saveLoadLabel = Instance.new("TextLabel")
saveLoadLabel.Size = UDim2.new(1, 0, 0, 25)
saveLoadLabel.Position = UDim2.new(0, 0, 0, buttonSize * 1.9 + 280 + buttonSize * 1.8)
saveLoadLabel.BackgroundTransparency = 1
saveLoadLabel.Text = "Save / Load"
saveLoadLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
saveLoadLabel.Font = Enum.Font.GothamBold
saveLoadLabel.TextSize = State.isMobile and 14 or 16
saveLoadLabel.TextXAlignment = Enum.TextXAlignment.Left
saveLoadLabel.Parent = contentFrame

local saveBtn = createButton("SaveBtn", "💾 SAVE", 
    UDim2.new(0, 0, 0, buttonSize * 1.9 + 310 + buttonSize * 1.8), 
    UDim2.new(0.49, -5, 0, buttonSize * 0.8), 
    Color3.fromRGB(50, 200, 100))

local loadBtn = createButton("LoadBtn", "📂 LOAD", 
    UDim2.new(0.51, 0, 0, buttonSize * 1.9 + 310 + buttonSize * 1.8), 
    UDim2.new(0.49, 0, 0, buttonSize * 0.8), 
    Color3.fromRGB(100, 150, 200))

-- Info Box
local infoBox = Instance.new("Frame")
infoBox.Size = UDim2.new(1, 0, 0, 70)
infoBox.Position = UDim2.new(0, 0, 1, -75)
infoBox.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
infoBox.BorderSizePixel = 1
infoBox.BorderColor3 = Color3.fromRGB(100, 100, 120)
infoBox.Parent = contentFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 1, -10)
infoLabel.Position = UDim2.new(0, 10, 0, 5)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "✓ Natural walking (no teleport!)\n✓ Frame-by-frame editing\n✓ Undo/Redo with stability\n" .. (State.isMobile and "Tap floating icon to expand" or "Press RIGHT SHIFT to toggle")
infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = State.isMobile and 10 or 12
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextWrapped = true
infoLabel.Parent = infoBox

screenGui.Parent = playerGui

-- ============================
-- UI UPDATE FUNCTIONS
-- ============================

local function updateStatus()
    local status = "Ready"
    
    if State.isRecording then
        status = "🔴 RECORDING"
    elseif State.isPlaying then
        if State.isPaused then
            status = "⏸ PAUSED"
        else
            status = "▶ PLAYING"
        end
    end
    
    local frameText = string.format("Frames: %d\nCurrent Frame: %d/%d", 
        #State.frames, 
        math.floor(State.currentFrame), 
        #State.frames)
    
    statusLabel.Text = string.format("Status: %s\n%s\nMode: Natural Humanoid Walking", status, frameText)
end

local function updateSpeedLabel()
    speedLabel.Text = string.format("Playback Speed: %.1fx", State.playbackSpeed)
end

local function updateTimelinePosition()
    if #State.frames > 0 then
        local progress = math.clamp(State.currentFrame / #State.frames, 0, 1)
        timelineButton.Position = UDim2.new(progress, -(timelineButton.AbsoluteSize.X / 2), 0, 0)
    end
end

local function updateLoopButton()
    if State.loopEnabled then
        loopBtn.Text = "🔁 LOOP: ON"
        loopBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
    else
        loopBtn.Text = "🔁 LOOP: OFF"
        loopBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 100)
    end
end

-- ============================
-- MINIMIZE/EXPAND FUNCTIONS
-- ============================

local function minimizeGUI()
    State.isMinimized = true
    
    -- Animate main frame out
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    local tween = TweenService:Create(mainFrame, tweenInfo, {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0)
    })
    tween:Play()
    
    tween.Completed:Connect(function()
        mainFrame.Visible = false
        floatingIcon.Visible = true
        
        -- Animate floating icon in
        floatingIcon.Size = UDim2.new(0, 0, 0, 0)
        local iconTween = TweenService:Create(floatingIcon, 
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 
            {Size = UDim2.new(0, CONFIG.FLOATING_ICON_SIZE, 0, CONFIG.FLOATING_ICON_SIZE)})
        iconTween:Play()
    end)
end

local function expandGUI()
    State.isMinimized = false
    
    -- Animate floating icon out
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
    local tween = TweenService:Create(floatingIcon, tweenInfo, {
        Size = UDim2.new(0, 0, 0, 0)
    })
    tween:Play()
    
    tween.Completed:Connect(function()
        floatingIcon.Visible = false
        mainFrame.Visible = true
        
        -- Animate main frame in
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        
        local mainTween = TweenService:Create(mainFrame, 
            TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 
            {
                Size = UDim2.new(0.8, 0, 0.85, 0),
                Position = UDim2.new(0.1, 0, 0.075, 0)
            })
        mainTween:Play()
    end)
end

-- ============================
-- BUTTON CONNECTIONS
-- ============================

recordBtn.MouseButton1Click:Connect(function()
    startRecording()
    updateStatus()
end)

stopBtn.MouseButton1Click:Connect(function()
    stopRecording()
    stopPlayback()
    updateStatus()
end)

playBtn.MouseButton1Click:Connect(function()
    playRecording()
    updateStatus()
end)

pauseBtn.MouseButton1Click:Connect(function()
    pausePlayback()
    updateStatus()
end)

loopBtn.MouseButton1Click:Connect(function()
    State.loopEnabled = not State.loopEnabled
    updateLoopButton()
end)

insertBtn.MouseButton1Click:Connect(function()
    if State.selectedFrame and State.selectedFrame > 0 then
        insertFrame(State.selectedFrame)
        updateStatus()
    else
        insertFrame(#State.frames + 1)
        updateStatus()
    end
end)

deleteBtn.MouseButton1Click:Connect(function()
    if State.selectedFrame and State.selectedFrame > 0 then
        deleteFrame(State.selectedFrame)
        State.selectedFrame = nil
        updateStatus()
    end
end)

modifyBtn.MouseButton1Click:Connect(function()
    if State.selectedFrame and State.selectedFrame > 0 then
        -- Modify selected frame to current position
        modifyFrame(State.selectedFrame, {position = hrp.Position})
        updateStatus()
    end
end)

undoBtn.MouseButton1Click:Connect(function()
    undo()
    updateStatus()
end)

redoBtn.MouseButton1Click:Connect(function()
    redo()
    updateStatus()
end)

saveBtn.MouseButton1Click:Connect(function()
    saveRecording()
end)

loadBtn.MouseButton1Click:Connect(function()
    -- For demo purposes, load the most recent recording
    if State.savedRecordings[State.currentRecordingName] then
        loadRecording(State.currentRecordingName)
        updateStatus()
    end
end)

minimizeBtn.MouseButton1Click:Connect(minimizeGUI)
closeBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
end)

floatingIcon.MouseButton1Click:Connect(expandGUI)

-- Speed Slider
local speedDragging = false

speedButton.MouseButton1Down:Connect(function()
    speedDragging = true
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        speedDragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if speedDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
                          input.UserInputType == Enum.UserInputType.Touch) then
        local relativePos = math.clamp((input.Position.X - speedSlider.AbsolutePosition.X) / speedSlider.AbsoluteSize.X, 0, 1)
        speedButton.Position = UDim2.new(relativePos, -(speedButton.AbsoluteSize.X / 2), 0, 0)
        State.playbackSpeed = 0.25 + (relativePos * 2.75) -- 0.25x to 3.0x speed
        updateSpeedLabel()
        
        -- Adjust humanoid WalkSpeed during playback
        if State.isPlaying then
            humanoid.WalkSpeed = 16 * State.playbackSpeed
        end
    end
end)

-- Timeline Scrubber
local timelineDragging = false

timelineButton.MouseButton1Down:Connect(function()
    timelineDragging = true
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        timelineDragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if timelineDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
                             input.UserInputType == Enum.UserInputType.Touch) then
        local relativePos = math.clamp((input.Position.X - timelineBar.AbsolutePosition.X) / timelineBar.AbsoluteSize.X, 0, 1)
        
        if #State.frames > 0 then
            local targetFrame = math.floor(relativePos * #State.frames) + 1
            State.selectedFrame = targetFrame
            
            if not State.isPlaying then
                scrubToFrame(targetFrame)
            end
            
            updateTimelinePosition()
            updateStatus()
        end
    end
end)

-- ============================
-- MAIN UPDATE LOOP
-- ============================

RunService.Heartbeat:Connect(function()
    updateStatus()
    updateTimelinePosition()
end)

-- Keyboard Controls (PC only)
if not State.isMobile then
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.RightShift then
            if State.isMinimized then
                expandGUI()
            else
                mainFrame.Visible = not mainFrame.Visible
            end
        elseif input.KeyCode == Enum.KeyCode.R and not State.isRecording then
            startRecording()
        elseif input.KeyCode == Enum.KeyCode.S and State.isRecording then
            stopRecording()
        elseif input.KeyCode == Enum.KeyCode.P and not State.isPlaying then
            playRecording()
        elseif input.KeyCode == Enum.KeyCode.Space and State.isPlaying then
            pausePlayback()
        elseif input.KeyCode == Enum.KeyCode.Z and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            undo()
        elseif input.KeyCode == Enum.KeyCode.Y and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            redo()
        end
    end)
end

-- Initialize
updateStatus()
updateSpeedLabel()
updateLoopButton()

print("=== Movement Recorder Pro Loaded! ===")
print("✓ Frame-by-frame recording at " .. CONFIG.RECORD_FPS .. " FPS")
print("✓ Natural Humanoid:MoveTo() walking - NO TELEPORTING!")
print("✓ Undo/Redo with character stability")
print("✓ Full frame editing capabilities")
print("✓ Mobile-responsive GUI with minimize feature")
print(State.isMobile and "Tap the floating icon to expand GUI" or "Press RIGHT SHIFT to toggle GUI")
print("====================================")
