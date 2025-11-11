--[[
═══════════════════════════════════════════════════════════════════════════════
    ROBLOX MOVEMENT RECORDER v2.0 - SIMPLIFIED & ROBUST
    
    Place in: StarterPlayer > StarterPlayerScripts (as LocalScript)
    
    Press F1 to open GUI
═══════════════════════════════════════════════════════════════════════════════
--]]

print("=== Movement Recorder Loading ===")

-- Wait for everything to load
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local hrp = character:WaitForChild("HumanoidRootPart")

print("Player loaded:", player.Name)

-- Simple state
local isRecording = false
local isPlaying = false
local frames = {}
local currentFrame = 1
local recordConnection = nil
local playConnection = nil

-- Undo system
local history = {}
local historyIndex = 0

--[[═══════════════════════════════════════════════════════════════════════════
    CORE FUNCTIONS
═══════════════════════════════════════════════════════════════════════════════]]

-- Save state for undo
local function saveHistory()
    historyIndex = historyIndex + 1
    history[historyIndex] = {}
    for i, frame in ipairs(frames) do
        history[historyIndex][i] = {
            pos = frame.pos,
            rot = frame.rot,
            state = frame.state
        }
    end
    -- Clear redo history
    for i = historyIndex + 1, #history do
        history[i] = nil
    end
end

-- Undo
local function undo()
    if historyIndex > 1 then
        historyIndex = historyIndex - 1
        frames = {}
        for i, frame in ipairs(history[historyIndex]) do
            frames[i] = {
                pos = frame.pos,
                rot = frame.rot,
                state = frame.state
            }
        end
        print("Undo - Frame count:", #frames)
        return true
    end
    print("Nothing to undo")
    return false
end

-- Redo
local function redo()
    if historyIndex < #history then
        historyIndex = historyIndex + 1
        frames = {}
        for i, frame in ipairs(history[historyIndex]) do
            frames[i] = {
                pos = frame.pos,
                rot = frame.rot,
                state = frame.state
            }
        end
        print("Redo - Frame count:", #frames)
        return true
    end
    print("Nothing to redo")
    return false
end

-- Start recording
local function startRecord()
    if isRecording then return end
    
    frames = {}
    currentFrame = 1
    isRecording = true
    
    saveHistory()
    
    print("Recording started...")
    
    recordConnection = RunService.Heartbeat:Connect(function(dt)
        -- Record every frame
        local cf = hrp.CFrame
        local state = humanoid:GetState()
        
        table.insert(frames, {
            pos = cf.Position,
            rot = Vector3.new(cf:ToEulerAnglesXYZ()),
            state = state,
            vel = hrp.AssemblyLinearVelocity
        })
    end)
end

-- Stop recording
local function stopRecord()
    if not isRecording then return end
    
    isRecording = false
    
    if recordConnection then
        recordConnection:Disconnect()
        recordConnection = nil
    end
    
    print("Recording stopped - Frames:", #frames)
end

-- Play recording with natural movement
local function startPlay()
    if #frames == 0 then
        print("No recording to play!")
        return
    end
    
    if isPlaying then return end
    
    isPlaying = true
    currentFrame = 1
    
    print("Playing recording...")
    
    -- Teleport to first frame
    hrp.CFrame = CFrame.new(frames[1].pos) * CFrame.Angles(frames[1].rot.X, frames[1].rot.Y, frames[1].rot.Z)
    
    playConnection = RunService.Heartbeat:Connect(function(dt)
        if currentFrame > #frames then
            stopPlay()
            return
        end
        
        local frame = frames[currentFrame]
        local nextFrame = frames[math.min(currentFrame + 1, #frames)]
        
        -- Use BodyVelocity for smooth movement
        local distance = (nextFrame.pos - hrp.Position).Magnitude
        
        if distance > 0.1 then
            -- Move towards next position
            local direction = (nextFrame.pos - hrp.Position).Unit
            local speed = math.min(distance / dt, 50) -- Cap speed
            
            -- Apply velocity
            hrp.AssemblyLinearVelocity = direction * speed
            
            -- Apply rotation
            local targetCF = CFrame.new(hrp.Position) * CFrame.Angles(nextFrame.rot.X, nextFrame.rot.Y, nextFrame.rot.Z)
            hrp.CFrame = hrp.CFrame:Lerp(targetCF, 0.5)
        end
        
        -- Handle jumping
        if frame.state == Enum.HumanoidStateType.Jumping or frame.state == Enum.HumanoidStateType.Freefall then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
        
        currentFrame = currentFrame + 1
    end)
end

-- Stop playing
local function stopPlay()
    if not isPlaying then return end
    
    isPlaying = false
    
    if playConnection then
        playConnection:Disconnect()
        playConnection = nil
    end
    
    -- Stop movement
    hrp.AssemblyLinearVelocity = Vector3.zero
    
    print("Playback stopped")
end

-- Jump to frame
local function jumpToFrame(frameNum)
    if frameNum < 1 or frameNum > #frames then return end
    
    local frame = frames[frameNum]
    
    -- Anchor to prevent falling
    hrp.Anchored = true
    hrp.CFrame = CFrame.new(frame.pos) * CFrame.Angles(frame.rot.X, frame.rot.Y, frame.rot.Z)
    task.wait(0.05)
    hrp.Anchored = false
    
    currentFrame = frameNum
    print("Jumped to frame:", frameNum)
end

-- Delete frame
local function deleteFrame(frameNum)
    if frameNum < 1 or frameNum > #frames then return end
    if #frames <= 1 then 
        print("Cannot delete last frame")
        return 
    end
    
    saveHistory()
    table.remove(frames, frameNum)
    print("Frame deleted:", frameNum)
end

-- Export
local function exportFrames()
    local data = {frames = {}}
    for i, frame in ipairs(frames) do
        table.insert(data.frames, {
            pos = {frame.pos.X, frame.pos.Y, frame.pos.Z},
            rot = {frame.rot.X, frame.rot.Y, frame.rot.Z}
        })
    end
    local json = HttpService:JSONEncode(data)
    print("=== EXPORT DATA ===")
    print(json)
    print("=== END EXPORT ===")
    return json
end

--[[═══════════════════════════════════════════════════════════════════════════
    GUI
═══════════════════════════════════════════════════════════════════════════════]]

local gui = Instance.new("ScreenGui")
gui.Name = "MovementRecorder"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main frame
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 400, 0, 500)
main.Position = UDim2.new(0.5, -200, 0.5, -250)
main.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
main.BorderSizePixel = 2
main.BorderColor3 = Color3.fromRGB(255, 255, 255)
main.Visible = false
main.Parent = gui

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
title.BorderSizePixel = 0
title.Text = "MOVEMENT RECORDER"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextSize = 18
title.Font = Enum.Font.SourceSansBold
title.Parent = main

-- Info label
local info = Instance.new("TextLabel")
info.Size = UDim2.new(1, -20, 0, 60)
info.Position = UDim2.new(0, 10, 0, 50)
info.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
info.BorderSizePixel = 1
info.BorderColor3 = Color3.fromRGB(255, 255, 255)
info.Text = "Frames: 0\nCurrent: 0\nStatus: Idle"
info.TextColor3 = Color3.fromRGB(255, 255, 255)
info.TextSize = 16
info.Font = Enum.Font.SourceSans
info.TextYAlignment = Enum.TextYAlignment.Top
info.Parent = main

-- Button creator
local function createButton(name, text, pos, callback)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 180, 0, 40)
    btn.Position = pos
    btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    btn.BorderSizePixel = 1
    btn.BorderColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 16
    btn.Font = Enum.Font.SourceSansBold
    btn.Parent = main
    
    btn.MouseButton1Click:Connect(callback)
    
    return btn
end

-- Buttons
local recordBtn = createButton("Record", "START RECORD", UDim2.new(0, 10, 0, 120), function()
    if not isRecording then
        startRecord()
        recordBtn.Text = "STOP RECORD"
        recordBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    else
        stopRecord()
        recordBtn.Text = "START RECORD"
        recordBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
end)

local playBtn = createButton("Play", "PLAY", UDim2.new(0, 210, 0, 120), function()
    if not isPlaying then
        startPlay()
        playBtn.Text = "STOP PLAY"
        playBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    else
        stopPlay()
        playBtn.Text = "PLAY"
        playBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
end)

createButton("Undo", "UNDO (Ctrl+Z)", UDim2.new(0, 10, 0, 170), undo)
createButton("Redo", "REDO (Ctrl+Y)", UDim2.new(0, 210, 0, 170), redo)
createButton("Export", "EXPORT", UDim2.new(0, 10, 0, 220), exportFrames)
createButton("Clear", "CLEAR ALL", UDim2.new(0, 210, 0, 220), function()
    saveHistory()
    frames = {}
    currentFrame = 1
    print("All frames cleared")
end)

-- Timeline
local timelineLabel = Instance.new("TextLabel")
timelineLabel.Size = UDim2.new(1, -20, 0, 30)
timelineLabel.Position = UDim2.new(0, 10, 0, 270)
timelineLabel.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
timelineLabel.BorderSizePixel = 1
timelineLabel.BorderColor3 = Color3.fromRGB(255, 255, 255)
timelineLabel.Text = "TIMELINE"
timelineLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
timelineLabel.TextSize = 16
timelineLabel.Font = Enum.Font.SourceSansBold
timelineLabel.Parent = main

local timeline = Instance.new("ScrollingFrame")
timeline.Size = UDim2.new(1, -20, 0, 180)
timeline.Position = UDim2.new(0, 10, 0, 310)
timeline.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
timeline.BorderSizePixel = 1
timeline.BorderColor3 = Color3.fromRGB(255, 255, 255)
timeline.ScrollBarThickness = 8
timeline.Parent = main

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 2)
layout.Parent = timeline

-- Update timeline
local function updateTimeline()
    -- Clear
    for _, child in ipairs(timeline:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    
    -- Add frames
    for i, frame in ipairs(frames) do
        local frameBtn = Instance.new("TextButton")
        frameBtn.Name = "Frame" .. i
        frameBtn.Size = UDim2.new(1, -8, 0, 25)
        frameBtn.BackgroundColor3 = (i == currentFrame) and Color3.fromRGB(100, 150, 255) or Color3.fromRGB(60, 60, 60)
        frameBtn.BorderSizePixel = 0
        frameBtn.Text = string.format("%d: %.1f, %.1f, %.1f", i, frame.pos.X, frame.pos.Y, frame.pos.Z)
        frameBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        frameBtn.TextSize = 14
        frameBtn.Font = Enum.Font.SourceSans
        frameBtn.TextXAlignment = Enum.TextXAlignment.Left
        frameBtn.Parent = timeline
        
        frameBtn.MouseButton1Click:Connect(function()
            jumpToFrame(i)
        end)
        
        -- Right click to delete
        frameBtn.MouseButton2Click:Connect(function()
            deleteFrame(i)
        end)
    end
    
    timeline.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
end

-- Update GUI
local function updateGUI()
    local status = "Idle"
    if isRecording then
        status = "Recording"
    elseif isPlaying then
        status = "Playing"
    end
    
    info.Text = string.format("Frames: %d\nCurrent: %d\nStatus: %s", #frames, currentFrame, status)
    updateTimeline()
end

-- Update loop
RunService.Heartbeat:Connect(function()
    if main.Visible then
        updateGUI()
    end
end)

-- Toggle GUI with F1
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode.F1 then
        main.Visible = not main.Visible
        print("GUI toggled:", main.Visible)
    end
    
    -- Ctrl+Z - Undo
    if input.KeyCode == Enum.KeyCode.Z and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        undo()
    end
    
    -- Ctrl+Y - Redo
    if input.KeyCode == Enum.KeyCode.Y and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        redo()
    end
    
    -- Space - Play/Stop
    if input.KeyCode == Enum.KeyCode.Space and main.Visible then
        if not isPlaying then
            startPlay()
        else
            stopPlay()
        end
    end
end)

-- Parent to PlayerGui
gui.Parent = player:WaitForChild("PlayerGui")

print("=== Movement Recorder Ready! ===")
print("Press F1 to open GUI")
print("================================")
