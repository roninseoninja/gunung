-- Movement Recorder Pro - EXACT PATH VERSION
-- Place this in StarterPlayer > StarterPlayerScripts or StarterGui
-- This version follows the EXACT recorded path, not pathfinding waypoints

print("=== Movement Recorder Pro - EXACT PATH (FIXED) ===")

-- ============================
-- SERVICES
-- ============================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

-- ============================
-- PLAYER SETUP
-- ============================
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local character = nil
local humanoid = nil
local hrp = nil

local function setupCharacter()
    character = player.Character or player.CharacterAdded:Wait()
    humanoid = character:WaitForChild("Humanoid")
    hrp = character:WaitForChild("HumanoidRootPart")
    print("Character setup complete")
end

setupCharacter()

player.CharacterAdded:Connect(function(newCharacter)
    print("Character respawned, updating references...")
    wait(0.5)
    setupCharacter()
end)

-- ============================
-- CONFIGURATION
-- ============================
local CONFIG = {
    RECORD_FPS = 30,
    PLAYBACK_DEFAULT_SPEED = 1.0,
    MAX_UNDO_STACK = 50,
    MOBILE_BUTTON_SIZE = 60,
    PC_BUTTON_SIZE = 40,
    FLOATING_ICON_SIZE = 50,
    -- EXACT PATH OPTIONS
    USE_EXACT_PATH = true, -- Follow exact recorded path
    SMOOTH_INTERPOLATION = true, -- Smooth between frames
}

-- ============================
-- STATE MANAGEMENT
-- ============================
local State = {
    frames = {},
    isRecording = false,
    isPaused = false,
    isPlaying = false,
    currentFrame = 0,
    playbackSpeed = CONFIG.PLAYBACK_DEFAULT_SPEED,
    loopEnabled = false,
    selectedFrame = nil,
    undoStack = {},
    redoStack = {},
    isMinimized = false,
    isMobile = false,
    recordConnection = nil,
    playConnection = nil,
    savedRecordings = {},
    currentRecordingName = "Recording_1"
}

-- ============================
-- UTILITY FUNCTIONS
-- ============================

local function detectMobile()
    local success, result = pcall(function()
        local hasTouch = UserInputService.TouchEnabled
        local hasKeyboard = UserInputService.KeyboardEnabled
        local hasMouse = UserInputService.MouseEnabled
        return hasTouch and (not hasKeyboard or not hasMouse)
    end)
    return success and result or false
end

local function deepCopy(original)
    if type(original) ~= "table" then
        return original
    end
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
    State.redoStack = {}
end

-- ============================
-- CHARACTER STABILITY FUNCTIONS
-- ============================

local function anchorCharacter()
    if hrp and hrp.Parent then
        pcall(function()
            hrp.Anchored = true
        end)
    end
end

local function unanchorCharacter()
    if hrp and hrp.Parent then
        pcall(function()
            hrp.Anchored = false
        end)
    end
end

local function teleportToFrame(frame)
    if not frame or not hrp or not hrp.Parent then return end
    
    pcall(function()
        anchorCharacter()
        hrp.CFrame = frame.cframe
        wait(0.05)
        unanchorCharacter()
    end)
end

-- ============================
-- RECORDING FUNCTIONS
-- ============================

local function captureFrame()
    if not humanoid or not humanoid.Parent or not hrp or not hrp.Parent then
        return nil
    end
    
    local success, result = pcall(function()
        local currentState = humanoid:GetState()
        
        return {
            index = #State.frames + 1,
            timestamp = tick(),
            position = hrp.Position,
            cframe = hrp.CFrame,
            lookVector = hrp.CFrame.LookVector,
            velocity = hrp.AssemblyVelocity, -- Capture velocity for exact replay
            state = currentState,
            isJumping = currentState == Enum.HumanoidStateType.Jumping or 
                       currentState == Enum.HumanoidStateType.Freefall,
            isClimbing = currentState == Enum.HumanoidStateType.Climbing
        }
    end)
    
    return success and result or nil
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
            if frame then
                table.insert(State.frames, frame)
            end
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
-- EXACT PATH PLAYBACK FUNCTIONS
-- ============================

local function setWalkingAnimation(isWalking, speed)
    -- Trigger walking animation by setting WalkSpeed
    if not humanoid or not humanoid.Parent then return end
    
    pcall(function()
        if isWalking then
            humanoid.WalkSpeed = 16 * speed
        else
            humanoid.WalkSpeed = 0
        end
    end)
end

local function interpolateFrames(frame1, frame2, alpha)
    if not frame1 or not frame2 then return frame1 end
    
    local success, result = pcall(function()
        return {
            position = frame1.position:Lerp(frame2.position, alpha),
            cframe = frame1.cframe:Lerp(frame2.cframe, alpha),
            lookVector = frame1.lookVector:Lerp(frame2.lookVector, alpha),
            velocity = frame1.velocity:Lerp(frame2.velocity, alpha),
            isJumping = alpha > 0.5 and frame2.isJumping or frame1.isJumping,
            isClimbing = alpha > 0.5 and frame2.isClimbing or frame1.isClimbing
        }
    end)
    
    return success and result or frame1
end

local function playRecordingExactPath()
    if State.isRecording or State.isPlaying or #State.frames == 0 then 
        print("Cannot play: no frames or already playing")
        return 
    end
    
    if not humanoid or not humanoid.Parent then
        warn("Cannot play: humanoid not found")
        return
    end
    
    print("Playback started (EXACT PATH) with", #State.frames, "frames")
    State.isPlaying = true
    State.currentFrame = 1
    
    -- Temporarily unanchor to allow movement but control via CFrame
    unanchorCharacter()
    
    State.playConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not State.isPlaying or State.isPaused then return end
        if not humanoid or not humanoid.Parent or not hrp or not hrp.Parent then
            stopPlayback()
            return
        end
        
        pcall(function()
            -- Progress through frames based on playback speed
            local adjustedDelta = deltaTime * State.playbackSpeed
            State.currentFrame = State.currentFrame + (adjustedDelta * CONFIG.RECORD_FPS)
            
            local frameIndex = math.floor(State.currentFrame)
            
            -- Loop or stop at end
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
                local targetCFrame = frame.cframe
                local targetVelocity = frame.velocity
                
                -- Smooth interpolation between frames
                if CONFIG.SMOOTH_INTERPOLATION and nextFrame then
                    local alpha = State.currentFrame - frameIndex
                    local interpolated = interpolateFrames(frame, nextFrame, alpha)
                    if interpolated then
                        targetCFrame = interpolated.cframe
                        targetVelocity = interpolated.velocity
                    end
                end
                
                -- EXACT PATH: Set CFrame directly to follow recorded path precisely
                hrp.CFrame = targetCFrame
                
                -- Apply velocity for physics (optional, for more realism)
                if hrp.AssemblyVelocity then
                    hrp.AssemblyVelocity = targetVelocity * State.playbackSpeed
                end
                
                -- Trigger walking animation
                local speed = targetVelocity.Magnitude
                if speed > 0.5 then
                    setWalkingAnimation(true, State.playbackSpeed)
                    -- Make humanoid think it's moving for animation
                    humanoid:Move(targetCFrame.LookVector, true)
                else
                    setWalkingAnimation(false, 1)
                end
                
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
            end
        end)
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
    
    -- Reset walk speed
    pcall(function()
        if humanoid and humanoid.Parent then
            humanoid.WalkSpeed = 16
        end
    end)
    
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
    if not newFrame then return end
    
    newFrame.index = atIndex
    table.insert(State.frames, atIndex, newFrame)
    
    for i = atIndex + 1, #State.frames do
        State.frames[i].index = i
    end
    
    print("Frame inserted at index", atIndex)
end

local function deleteFrame(frameIndex)
    if frameIndex < 1 or frameIndex > #State.frames then return end
    
    saveToUndoStack()
    table.remove(State.frames, frameIndex)
    
    for i = frameIndex, #State.frames do
        State.frames[i].index = i
    end
    
    print("Frame deleted at index", frameIndex)
end

local function modifyFrame(frameIndex, newData)
    if frameIndex < 1 or frameIndex > #State.frames then return end
    if not hrp or not hrp.Parent then return end
    
    saveToUndoStack()
    
    local frame = State.frames[frameIndex]
    
    pcall(function()
        if newData.position then
            frame.position = newData.position
            frame.cframe = CFrame.new(newData.position) * CFrame.Angles(0, math.atan2(frame.lookVector.X, frame.lookVector.Z), 0)
        end
        
        if newData.rotation then
            frame.cframe = CFrame.new(frame.position) * newData.rotation
            frame.lookVector = frame.cframe.LookVector
        end
        
        -- Update velocity if standing still
        if hrp.AssemblyVelocity then
            frame.velocity = hrp.AssemblyVelocity
        end
    end)
    
    print("Frame modified at index", frameIndex)
end

local function undo()
    if #State.undoStack == 0 then 
        print("Nothing to undo")
        return 
    end
    
    table.insert(State.redoStack, deepCopy(State.frames))
    State.frames = table.remove(State.undoStack)
    
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
    
    table.insert(State.undoStack, deepCopy(State.frames))
    State.frames = table.remove(State.redoStack)
    
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
            fps = CONFIG.RECORD_FPS,
            exactPath = CONFIG.USE_EXACT_PATH
        }
    }
    
    for i, frame in ipairs(State.frames) do
        local success = pcall(function()
            table.insert(data.frames, {
                index = frame.index,
                timestamp = frame.timestamp,
                position = {frame.position.X, frame.position.Y, frame.position.Z},
                cframe = {frame.cframe:GetComponents()},
                lookVector = {frame.lookVector.X, frame.lookVector.Y, frame.lookVector.Z},
                velocity = {frame.velocity.X, frame.velocity.Y, frame.velocity.Z},
                state = tostring(frame.state),
                isJumping = frame.isJumping,
                isClimbing = frame.isClimbing
            })
        end)
        if not success then
            warn("Failed to serialize frame", i)
        end
    end
    
    local success, jsonData = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    
    return success and jsonData or nil
end

local function deserializeRecording(jsonData)
    local success, data = pcall(function()
        return HttpService:JSONDecode(jsonData)
    end)
    
    if not success or not data then
        warn("Failed to deserialize recording")
        return false
    end
    
    State.frames = {}
    
    for i, frameData in ipairs(data.frames) do
        pcall(function()
            local stateString = frameData.state:match("HumanoidStateType%.(.+)") or "Running"
            local frame = {
                index = frameData.index,
                timestamp = frameData.timestamp,
                position = Vector3.new(frameData.position[1], frameData.position[2], frameData.position[3]),
                cframe = CFrame.new(unpack(frameData.cframe)),
                lookVector = Vector3.new(frameData.lookVector[1], frameData.lookVector[2], frameData.lookVector[3]),
                velocity = Vector3.new(frameData.velocity[1], frameData.velocity[2], frameData.velocity[3]),
                state = Enum.HumanoidStateType[stateString],
                isJumping = frameData.isJumping,
                isClimbing = frameData.isClimbing
            }
            table.insert(State.frames, frame)
        end)
    end
    
    State.currentRecordingName = data.name
    print("Recording loaded:", data.name, "with", #State.frames, "frames")
    return true
end

local function saveRecording()
    local jsonData = serializeRecording()
    if jsonData then
        State.savedRecordings[State.currentRecordingName] = jsonData
        print("Recording saved:", State.currentRecordingName)
    else
        warn("Failed to save recording")
    end
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

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0.8, 0, 0.85, 0)
mainFrame.Position = UDim2.new(0.1, 0, 0.075, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(0, 200, 255)
mainFrame.Active = true
mainFrame.Draggable = not State.isMobile
mainFrame.Parent = screenGui

local floatingIcon = Instance.new("TextButton")
floatingIcon.Name = "FloatingIcon"
floatingIcon.Size = UDim2.new(0, CONFIG.FLOATING_ICON_SIZE, 0, CONFIG.FLOATING_ICON_SIZE)
floatingIcon.Position = UDim2.new(0.95, -CONFIG.FLOATING_ICON_SIZE, 0.5, -CONFIG.FLOATING_ICON_SIZE/2)
floatingIcon.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
floatingIcon.BorderSizePixel = 0
floatingIcon.Text = "📹"
floatingIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
floatingIcon.Font = Enum.Font.GothamBold
floatingIcon.TextSize = 24
floatingIcon.Visible = false
floatingIcon.Active = true
floatingIcon.Draggable = true
floatingIcon.Parent = screenGui

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(0.5, 0)
iconCorner.Parent = floatingIcon

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
titleLabel.Text = "Movement Recorder Pro - EXACT PATH"
titleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = State.isMobile and 16 or 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

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

local contentFrame = Instance.new("Frame")
contentFrame.Name = "ContentFrame"
contentFrame.Size = UDim2.new(1, -20, 1, -70)
contentFrame.Position = UDim2.new(0, 10, 0, 60)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

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
statusLabel.Text = "Status: Ready\nFrames: 0\nCurrent Frame: 0\nMode: EXACT PATH (CFrame-based)"
statusLabel.TextColor3 = Color3.fromRGB(0, 255, 200)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = State.isMobile and 12 or 14
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextWrapped = true
statusLabel.Parent = statusBox

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
speedButton.Size = UDim2.new(0, State.isMobile and 30 or 20, 1, 0)
speedButton.Position = UDim2.new(0.5, -(State.isMobile and 15 or 10), 0, 0)
speedButton.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
speedButton.Text = ""
speedButton.Parent = speedSlider

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
infoLabel.Text = "✓ EXACT PATH - Follows recorded route precisely!\n✓ Frame-by-frame editing\n✓ Walking animations maintained\n" .. (State.isMobile and "Tap floating icon to expand" or "Press RIGHT SHIFT to toggle")
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
    pcall(function()
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
        
        statusLabel.Text = string.format("Status: %s\n%s\nMode: EXACT PATH (CFrame-based)", status, frameText)
    end)
end

local function updateSpeedLabel()
    pcall(function()
        speedLabel.Text = string.format("Playback Speed: %.1fx", State.playbackSpeed)
    end)
end

local function updateTimelinePosition()
    pcall(function()
        if #State.frames > 0 and timelineButton and timelineButton.Parent then
            local progress = math.clamp(State.currentFrame / #State.frames, 0, 1)
            timelineButton.Position = UDim2.new(progress, -(timelineButton.AbsoluteSize.X / 2), 0, 0)
        end
    end)
end

local function updateLoopButton()
    pcall(function()
        if State.loopEnabled then
            loopBtn.Text = "🔁 LOOP: ON"
            loopBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 100)
        else
            loopBtn.Text = "🔁 LOOP: OFF"
            loopBtn.BackgroundColor3 = Color3.fromRGB(100, 150, 100)
        end
    end)
end

-- ============================
-- MINIMIZE/EXPAND FUNCTIONS
-- ============================

local function minimizeGUI()
    State.isMinimized = true
    
    pcall(function()
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        local tween = TweenService:Create(mainFrame, tweenInfo, {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0)
        })
        tween:Play()
        
        tween.Completed:Connect(function()
            mainFrame.Visible = false
            floatingIcon.Visible = true
            
            floatingIcon.Size = UDim2.new(0, 0, 0, 0)
            local iconTween = TweenService:Create(floatingIcon, 
                TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 
                {Size = UDim2.new(0, CONFIG.FLOATING_ICON_SIZE, 0, CONFIG.FLOATING_ICON_SIZE)})
            iconTween:Play()
        end)
    end)
end

local function expandGUI()
    State.isMinimized = false
    
    pcall(function()
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        local tween = TweenService:Create(floatingIcon, tweenInfo, {
            Size = UDim2.new(0, 0, 0, 0)
        })
        tween:Play()
        
        tween.Completed:Connect(function()
            floatingIcon.Visible = false
            mainFrame.Visible = true
            
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
    end)
end

-- ============================
-- BUTTON CONNECTIONS
-- ============================

recordBtn.MouseButton1Click:Connect(function()
    pcall(function()
        startRecording()
        updateStatus()
    end)
end)

stopBtn.MouseButton1Click:Connect(function()
    pcall(function()
        stopRecording()
        stopPlayback()
        updateStatus()
    end)
end)

playBtn.MouseButton1Click:Connect(function()
    pcall(function()
        playRecordingExactPath()
        updateStatus()
    end)
end)

pauseBtn.MouseButton1Click:Connect(function()
    pcall(function()
        pausePlayback()
        updateStatus()
    end)
end)

loopBtn.MouseButton1Click:Connect(function()
    pcall(function()
        State.loopEnabled = not State.loopEnabled
        updateLoopButton()
    end)
end)

insertBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if State.selectedFrame and State.selectedFrame > 0 then
            insertFrame(State.selectedFrame)
        else
            insertFrame(#State.frames + 1)
        end
        updateStatus()
    end)
end)

deleteBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if State.selectedFrame and State.selectedFrame > 0 then
            deleteFrame(State.selectedFrame)
            State.selectedFrame = nil
            updateStatus()
        end
    end)
end)

modifyBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if State.selectedFrame and State.selectedFrame > 0 and hrp and hrp.Parent then
            modifyFrame(State.selectedFrame, {position = hrp.Position})
            updateStatus()
        end
    end)
end)

undoBtn.MouseButton1Click:Connect(function()
    pcall(function()
        undo()
        updateStatus()
    end)
end)

redoBtn.MouseButton1Click:Connect(function()
    pcall(function()
        redo()
        updateStatus()
    end)
end)

saveBtn.MouseButton1Click:Connect(function()
    pcall(saveRecording)
end)

loadBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if State.savedRecordings[State.currentRecordingName] then
            loadRecording(State.currentRecordingName)
            updateStatus()
        end
    end)
end)

minimizeBtn.MouseButton1Click:Connect(minimizeGUI)

closeBtn.MouseButton1Click:Connect(function()
    pcall(function()
        mainFrame.Visible = false
    end)
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
        pcall(function()
            local relativePos = math.clamp((input.Position.X - speedSlider.AbsolutePosition.X) / speedSlider.AbsoluteSize.X, 0, 1)
            speedButton.Position = UDim2.new(relativePos, -(speedButton.AbsoluteSize.X / 2), 0, 0)
            State.playbackSpeed = 0.25 + (relativePos * 2.75)
            updateSpeedLabel()
        end)
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
        pcall(function()
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
        end)
    end
end)

-- ============================
-- MAIN UPDATE LOOP
-- ============================

RunService.Heartbeat:Connect(function()
    pcall(function()
        updateStatus()
        updateTimelinePosition()
    end)
end)

-- Keyboard Controls (PC only)
if not State.isMobile then
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        pcall(function()
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
                playRecordingExactPath()
            elseif input.KeyCode == Enum.KeyCode.Space and State.isPlaying then
                pausePlayback()
            elseif input.KeyCode == Enum.KeyCode.Z and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                undo()
            elseif input.KeyCode == Enum.KeyCode.Y and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                redo()
            end
        end)
    end)
end

-- Initialize
updateStatus()
updateSpeedLabel()
updateLoopButton()

print("=== Movement Recorder Pro Loaded (EXACT PATH MODE) ===")
print("✓ Error handling enabled")
print("✓ Character respawn support")
print("✓ EXACT PATH - Uses CFrame positioning (no pathfinding!)")
print("✓ Walking animations maintained")
print("✓ Frame-by-frame recording at " .. CONFIG.RECORD_FPS .. " FPS")
print("✓ Smooth interpolation between frames")
print(State.isMobile and "Tap the floating icon to expand GUI" or "Press RIGHT SHIFT to toggle GUI")
print("====================================")
