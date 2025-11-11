--[[
Walk Recorder v4 (fixed)
Perbaikan utama:
- Re-bind character/humanoid/root saat CharacterAdded
- Playback berjalan di coroutine supaya UI tidak nge-freeze
- Flag playing untuk mencegah interaksi berlebih saat playback
- Hide / Show / Close UI diperbaiki
- Status lebih informatif untuk debugging
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- references yang akan di-rebind ketika character muncul/respawn
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart")

local recording = false
local paused = false
local playing = false
local waypoints = {}
local recordings = {}
local recordName = ""
local connection
local recordInterval = 0.12
local movementThreshold = 0.05
local elapsedTime = 0

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "WalkRecorderUI"
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 340, 0, 380)
frame.Position = UDim2.new(0, 30, 0, 30)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
title.Text = "Walk Recorder v4"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = frame

-- Drag
local dragging, dragStart, startPos = false, nil, nil
title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

local nameBox = Instance.new("TextBox")
nameBox.Size = UDim2.new(1, -20, 0, 30)
nameBox.Position = UDim2.new(0, 10, 0, 40)
nameBox.PlaceholderText = "Masukkan nama record (cth: autowalk_1)"
nameBox.Text = ""
nameBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
nameBox.TextColor3 = Color3.new(1, 1, 1)
nameBox.Font = Enum.Font.Gotham
nameBox.TextSize = 12
nameBox.ClearTextOnFocus = false
nameBox.Parent = frame
Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 6)

local recordBtn = Instance.new("TextButton")
recordBtn.Size = UDim2.new(1, -20, 0, 35)
recordBtn.Position = UDim2.new(0, 10, 0, 80)
recordBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
recordBtn.Text = "Start Recording"
recordBtn.TextColor3 = Color3.new(1, 1, 1)
recordBtn.Font = Enum.Font.Gotham
recordBtn.TextSize = 13
recordBtn.Parent = frame
Instance.new("UICorner", recordBtn).CornerRadius = UDim.new(0, 6)

local pauseBtn = Instance.new("TextButton")
pauseBtn.Size = UDim2.new(1, -20, 0, 30)
pauseBtn.Position = UDim2.new(0, 10, 0, 120)
pauseBtn.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
pauseBtn.Text = "Pause"
pauseBtn.Visible = false
pauseBtn.TextColor3 = Color3.new(0, 0, 0)
pauseBtn.Font = Enum.Font.Gotham
pauseBtn.TextSize = 12
pauseBtn.Parent = frame
Instance.new("UICorner", pauseBtn).CornerRadius = UDim.new(0, 6)

local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0, 70, 0, 25)
hideBtn.Position = UDim2.new(1, -80, 0, 6)
hideBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
hideBtn.Text = "Hide"
hideBtn.TextColor3 = Color3.new(1,1,1)
hideBtn.Font = Enum.Font.Gotham
hideBtn.TextSize = 12
hideBtn.Parent = frame
Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 25, 0, 25)
closeBtn.Position = UDim2.new(1, -40, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1,1,1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = frame
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

local showBtn = Instance.new("TextButton")
showBtn.Size = UDim2.new(0, 60, 0, 30)
showBtn.Position = UDim2.new(0, 10, 0, 30)
showBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
showBtn.Text = "Show"
showBtn.TextColor3 = Color3.new(1,1,1)
showBtn.Font = Enum.Font.Gotham
showBtn.TextSize = 12
showBtn.Parent = gui
showBtn.Visible = false
Instance.new("UICorner", showBtn).CornerRadius = UDim.new(0, 6)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 25)
status.Position = UDim2.new(0, 10, 0, 160)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.Text = "Status: Idle"
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.Parent = frame

local listLabel = Instance.new("TextLabel")
listLabel.Size = UDim2.new(1, -20, 0, 20)
listLabel.Position = UDim2.new(0, 10, 0, 190)
listLabel.BackgroundTransparency = 1
listLabel.Text = "Daftar Record:"
listLabel.TextColor3 = Color3.new(1, 1, 1)
listLabel.Font = Enum.Font.GothamBold
listLabel.TextSize = 12
listLabel.Parent = frame

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 0, 170)
scroll.Position = UDim2.new(0, 10, 0, 215)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarThickness = 6
scroll.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
scroll.BorderSizePixel = 0
scroll.Parent = frame
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)

local layout = Instance.new("UIListLayout", scroll)
layout.Padding = UDim.new(0, 5)
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- helper: update canvas size when layout changes
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end)

-- rebind refs on respawn
local function bindCharacter(newChar)
	character = newChar
	humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid")
	root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart")
end

player.CharacterAdded:Connect(function(char)
	-- delay sedikit untuk child tersedia
	bindCharacter(char)
	-- disconnect existing recording connection to avoid using old humanoid
	if connection then
		connection:Disconnect()
		connection = nil
	end
	status.Text = "Status: Character respawned, refs diupdate"
end)

local function refreshList()
	-- hapus tombol lama
	for _, child in pairs(scroll:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	for name, _ in pairs(recordings) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -10, 0, 30)
		btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		btn.Text = "▶ " .. name
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 12
		btn.Parent = scroll
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

		btn.MouseButton1Click:Connect(function()
			-- jalankan playback di coroutine supaya tidak nge-freeze
			if playing then
				status.Text = "Already playing..."
				return
			end
			playing = true
			-- nonaktifkan tombol recording saat play
			recordBtn.Active = false
			pauseBtn.Active = false
			status.Text = "Playing " .. name .. "..."
			local path = recordings[name]
			if not path or #path == 0 then
				status.Text = "Record tidak ditemukan atau kosong!"
				playing = false
				recordBtn.Active = true
				pauseBtn.Active = true
				return
			end
			-- run in coroutine
			spawn(function()
				-- safe: jika character berganti, keluar
				if not character or not character.Parent then
					status.Text = "Karakter tidak ada, stop play"
					playing = false
					recordBtn.Active = true
					pauseBtn.Active = true
					return
				end

				local arrivalRadius = 1.5
				for i = 1, #path - 1 do
					if not character or not character.Parent then break end
					local entry = path[i]
					local nextEntry = path[i+1]
					local targetPos = nextEntry.pos
					local segmentDuration = math.max(0.05, nextEntry.t - entry.t)

					-- trigger jump if flag terpasang
					if nextEntry.jump then
						pcall(function() humanoid.Jump = true end)
					end

					-- compute path
					local ok, computedPath = pcall(function()
						local p = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, AgentMaxSlope = 45})
						p:ComputeAsync(root.Position, targetPos)
						return p
					end)

					if ok and computedPath and computedPath.Status == Enum.PathStatus.Success then
						local waypointsPF = computedPath:GetWaypoints()
						for _, wp in ipairs(waypointsPF) do
							if not character or not character.Parent then break end
							if wp.Action == Enum.PathWaypointAction.Jump then
								pcall(function() humanoid.Jump = true end)
							end
							humanoid:MoveTo(wp.Position)
							local elapsed = 0
							local maxTime = 3.0
							while elapsed < maxTime do
								local dt = RunService.Heartbeat:Wait()
								elapsed = elapsed + dt
								if (root.Position - wp.Position).Magnitude <= math.max(1.2, arrivalRadius) then break end
								if not character or not character.Parent then break end
							end
						end
					else
						-- fallback: direct MoveTo
						humanoid:MoveTo(targetPos)
						local elapsed = 0
						local maxTime = math.max(1.0, segmentDuration * 2 + 0.8)
						while elapsed < maxTime do
							local dt = RunService.Heartbeat:Wait()
							elapsed = elapsed + dt
							if (root.Position - targetPos).Magnitude <= arrivalRadius then break end
							if not character or not character.Parent then break end
						end
					end
				end

				-- pastikan ke titik terakhir
				local last = path[#path]
				if last then
					if (root.Position - last.pos).Magnitude <= 5 then
						pcall(function() root.CFrame = CFrame.new(last.pos) end)
					else
						humanoid:MoveTo(last.pos)
						local elapsed = 0
						local maxTime = 3.0
						while elapsed < maxTime do
							local dt = RunService.Heartbeat:Wait()
							elapsed = elapsed + dt
							if (root.Position - last.pos).Magnitude <= 1.5 then break end
							if not character or not character.Parent then break end
						end
					end
				end

				status.Text = "Selesai play " .. name
				playing = false
				recordBtn.Active = true
				pauseBtn.Active = true
			end)
		end)
	end
end

local function startRecording()
	recordName = nameBox.Text
	if recordName == "" then
		status.Text = "Masukkan nama record dulu!"
		return
	end
	if recordings[recordName] then
		status.Text = "Nama sudah dipakai!"
		return
	end

	recording = true
	paused = false
	waypoints = {}
	status.Text = "Recording " .. recordName .. "..."
	recordBtn.Text = "Stop Recording"
	recordBtn.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
	pauseBtn.Visible = true
	pauseBtn.Text = "Pause"

	elapsedTime = 0
	local lastSample = 0

	-- disconnect existing connection jika ada
	if connection then connection:Disconnect() connection = nil end

	connection = RunService.Heartbeat:Connect(function(dt)
		-- jika humanoid berubah (respawn) skip sampai bindCharacter terupdate
		if not humanoid or not root then return end
		if not recording or paused then return end

		elapsedTime = elapsedTime + dt
		local state = humanoid:GetState()
		local isJumping = (state == Enum.HumanoidStateType.Jumping) or (state == Enum.HumanoidStateType.Freefall)

		if humanoid.MoveDirection.Magnitude > movementThreshold or isJumping or (elapsedTime - lastSample >= recordInterval) then
			if elapsedTime - lastSample >= 0.02 then
				table.insert(waypoints, {pos = root.Position, t = elapsedTime, jump = isJumping})
				lastSample = elapsedTime
			end
		end
	end)
end

local function stopRecording()
	recording = false
	paused = false
	if connection then connection:Disconnect() connection = nil end
	pauseBtn.Visible = false

	if #waypoints > 0 then
		recordings[recordName] = table.clone(waypoints)
		status.Text = "Record " .. recordName .. " tersimpan (" .. #waypoints .. " titik)"
		refreshList()
	else
		status.Text = "Tidak ada data yang direkam"
	end
	recordBtn.Text = "Start Recording"
	recordBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
end

-- UI callbacks
recordBtn.MouseButton1Click:Connect(function()
	if playing then
		status.Text = "Sedang play, tunggu selesai dulu."
		return
	end
	if not recording then startRecording() else stopRecording() end
end)

pauseBtn.MouseButton1Click:Connect(function()
	if not recording then return end
	paused = not paused
	if paused then
		pauseBtn.Text = "Resume"
		status.Text = "Recording paused"
	else
		pauseBtn.Text = "Pause"
		status.Text = "Recording " .. recordName .. "..."
	end
end)

hideBtn.MouseButton1Click:Connect(function()
	frame.Visible = false
	showBtn.Visible = true
end)

showBtn.MouseButton1Click:Connect(function()
	frame.Visible = true
	showBtn.Visible = false
end)

closeBtn.MouseButton1Click:Connect(function()
	if connection then connection:Disconnect() connection = nil end
	gui:Destroy()
end)

-- safety: disconnect connection on character removing
player.CharacterRemoving:Connect(function()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end)

-- init
refreshList()
status.Text = "Ready"ition - last.pos).Magnitude <= 5 then
					-- sedikit teleport agar posisi sinkron tanpa terasa
					pcall(function() root.CFrame = CFrame.new(last.pos) end)
				else
					-- jika jauh, biarkan Humanoid MoveTo untuk mencapai
					humanoid:MoveTo(last.pos)
					local elapsed = 0
					local maxTime = 3.0
					while elapsed < maxTime do
						local dt = RunService.Heartbeat:Wait()
						elapsed = elapsed + dt
						if (root.Position - last.pos).Magnitude <= 1.5 then break end
						if not character or not character.Parent then break end
					end
				end
			end

			status.Text = "Selesai play " .. name
		end)
	end

	scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end

-- Recording
local function startRecording()
	recordName = nameBox.Text
	if recordName == "" then
		status.Text = "Masukkan nama record dulu!"
		return
	end
	if recordings[recordName] then
		status.Text = "Nama sudah dipakai!"
		return
	end

	recording = true
	paused = false
	waypoints = {}
	status.Text = "Recording " .. recordName .. "..."
	recordBtn.Text = "Stop Recording"
	recordBtn.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
	pauseBtn.Visible = true
	pauseBtn.Text = "Pause"

	elapsedTime = 0
	local lastSample = 0

	connection = RunService.Heartbeat:Connect(function(dt)
		if not recording or paused then return end
		elapsedTime = elapsedTime + dt
		local state = humanoid:GetState()
		local isJumping = (state == Enum.HumanoidStateType.Jumping) or (state == Enum.HumanoidStateType.Freefall)

		-- Rekam jika bergerak, jump, atau interval waktu tercapai
		if humanoid.MoveDirection.Magnitude > movementThreshold or isJumping or (elapsedTime - lastSample >= recordInterval) then
			if elapsedTime - lastSample >= 0.02 then
				table.insert(waypoints, {pos = root.Position, t = elapsedTime, jump = isJumping})
				lastSample = elapsedTime
			end
		end
	end)
end

local function stopRecording()
	recording = false
	paused = false
	if connection then connection:Disconnect() connection = nil end
	pauseBtn.Visible = false

	if #waypoints > 0 then
		recordings[recordName] = table.clone(waypoints)
		status.Text = "Record " .. recordName .. " tersimpan (" .. #waypoints .. " titik)"
		refreshList()
	else
		status.Text = "Tidak ada data yang direkam"
	end
	recordBtn.Text = "Start Recording"
	recordBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
end

-- UI actions
recordBtn.MouseButton1Click:Connect(function()
	if not recording then startRecording() else stopRecording() end
end)

pauseBtn.MouseButton1Click:Connect(function()
	if not recording then return end
	paused = not paused
	if paused then
		pauseBtn.Text = "Resume"
		status.Text = "Recording paused"
	else
		pauseBtn.Text = "Pause"
		status.Text = "Recording " .. recordName .. "..."
	end
end)

hideBtn.MouseButton1Click:Connect(function()
	frame.Visible = false
	showBtn.Visible = true
end)

showBtn.MouseButton1Click:Connect(function()
	frame.Visible = true
	showBtn.Visible = false
end)

closeBtn.MouseButton1Click:Connect(function()
	-- hentikan koneksi lalu hancurkan gui
	if connection then connection:Disconnect() connection = nil end
	gui:Destroy()
end)

player.CharacterRemoving:Connect(function()
	if connection then connection:Disconnect() end
end)

-- init
refreshList()al = 0.12
local movementThreshold = 0.05
local recordStartTime = 0
local elapsedTime = 0

-- === 🧱 UI ===
local gui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
gui.Name = "WalkRecorderUI"

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 340, 0, 360)
frame.Position = UDim2.new(0, 30, 0, 30)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.BorderSizePixel = 0
frame.Parent = gui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

-- Title bar
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
title.Text = "Walk Recorder v3 (improved)"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = frame

-- Drag function
local dragging, dragStart, startPos = false, nil, nil
title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

-- Input nama record
local nameBox = Instance.new("TextBox")
nameBox.Size = UDim2.new(1, -20, 0, 30)
nameBox.Position = UDim2.new(0, 10, 0, 40)
nameBox.PlaceholderText = "Masukkan nama record (cth: autowalk_1)"
nameBox.Text = ""
nameBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
nameBox.TextColor3 = Color3.new(1, 1, 1)
nameBox.Font = Enum.Font.Gotham
nameBox.TextSize = 12
nameBox.ClearTextOnFocus = false
nameBox.Parent = frame
Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 6)

-- Tombol record / stop
local recordBtn = Instance.new("TextButton")
recordBtn.Size = UDim2.new(1, -20, 0, 35)
recordBtn.Position = UDim2.new(0, 10, 0, 80)
recordBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
recordBtn.Text = "Start Recording"
recordBtn.TextColor3 = Color3.new(1, 1, 1)
recordBtn.Font = Enum.Font.Gotham
recordBtn.TextSize = 13
recordBtn.Parent = frame
Instance.new("UICorner", recordBtn).CornerRadius = UDim.new(0, 6)

-- Tombol pause/resume (hanya saat recording)
local pauseBtn = Instance.new("TextButton")
pauseBtn.Size = UDim2.new(1, -20, 0, 30)
pauseBtn.Position = UDim2.new(0, 10, 0, 120)
pauseBtn.BackgroundColor3 = Color3.fromRGB(255, 193, 7)
pauseBtn.Text = "Pause"
pauseBtn.Visible = false
pauseBtn.TextColor3 = Color3.new(0, 0, 0)
pauseBtn.Font = Enum.Font.Gotham
pauseBtn.TextSize = 12
pauseBtn.Parent = frame
Instance.new("UICorner", pauseBtn).CornerRadius = UDim.new(0, 6)

-- Status
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 25)
status.Position = UDim2.new(0, 10, 0, 160)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.new(1, 1, 1)
status.Text = "Status: Idle"
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.Parent = frame

-- Label daftar record
local listLabel = Instance.new("TextLabel")
listLabel.Size = UDim2.new(1, -20, 0, 20)
listLabel.Position = UDim2.new(0, 10, 0, 190)
listLabel.BackgroundTransparency = 1
listLabel.Text = "Daftar Record:"
listLabel.TextColor3 = Color3.new(1, 1, 1)
listLabel.Font = Enum.Font.GothamBold
listLabel.TextSize = 12
listLabel.Parent = frame

-- Scroll daftar record
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 0, 150)
scroll.Position = UDim2.new(0, 10, 0, 215)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarThickness = 6
scroll.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
scroll.BorderSizePixel = 0
scroll.Parent = frame
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 6)

local layout = Instance.new("UIListLayout", scroll)
layout.Padding = UDim.new(0, 5)
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- === 🧠 Functions ===

local function refreshList()
	for _, child in pairs(scroll:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for name, _ in pairs(recordings) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -10, 0, 30)
		btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		btn.Text = "▶ " .. name
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 12
		btn.Parent = scroll
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

		btn.MouseButton1Click:Connect(function()
			status.Text = "Playing " .. name .. "..."
			local path = recordings[name]
			if not path then
				status.Text = "Record tidak ditemukan!"
				return
			end

			-- Playback: gunakan tween per segmen berdasarkan timestamp
			-- Teleport ke posisi awal (agar playback dimulai dari titik pertama)
			if #path == 0 then
				status.Text = "Record kosong!"
				return
			end

			-- Pastikan karakter ada
			if not character or not character.Parent then
				status.Text = "Karakter tidak ada!"
				return
			end

			-- Set posisi awal tanpa tween (agar sinkron)
			root.CFrame = CFrame.new(path[1].pos)

			-- Loop segmen
			for i = 1, #path do
				if not character or not character.Parent then break end
				local entry = path[i]
				local nextEntry = path[i+1]
				local duration = recordInterval
				if nextEntry then
					duration = math.max(0.03, nextEntry.t - entry.t) -- gunakan delta waktu rekaman
				end

				-- Jika titik menandai jump, trigger jump
				if entry.jump then
					-- trigger jump; jika grounded maka ini akan membuat humanoid melompat
					humanoid.Jump = true
				end

				-- Tween ke posisi target (CFrame menggunakan posisi target dengan rotasi saat ini)
				local targetCFrame = CFrame.new(entry.pos, entry.pos + (root.CFrame.LookVector))
				local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
				tween:Play()

				-- tunggu durasi dengan Heartbeat supaya tetap responsive
				local elapsed = 0
				while elapsed < duration do
					local dt = RunService.Heartbeat:Wait()
					elapsed = elapsed + dt
					-- jika karakter terhapus, stop
					if not character or not character.Parent then break end
				end
			end

			status.Text = "Selesai play " .. name
		end)
	end

	-- sesuaikan CanvasSize
	scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
end

local function startRecording()
	recordName = nameBox.Text
	if recordName == "" then
		status.Text = "Masukkan nama record dulu!"
		return
	end

	if recordings[recordName] then
		status.Text = "Nama sudah dipakai!"
		return
	end

	recording = true
	paused = false
	waypoints = {}
	status.Text = "Recording " .. recordName .. "..."
	recordBtn.Text = "Stop Recording"
	recordBtn.BackgroundColor3 = Color3.fromRGB(244, 67, 54)
	pauseBtn.Visible = true
	pauseBtn.Text = "Pause"

	recordStartTime = tick()
	elapsedTime = 0
	local lastSample = 0

	-- koneksi Heartbeat untuk sampling posisi + state
	connection = RunService.Heartbeat:Connect(function(dt)
		if not recording or paused then return end

		elapsedTime = elapsedTime + dt

		-- Ambil state jump (Jumping / Freefall) agar lompatan terekam
		local state = humanoid:GetState()
		local isJumping = (state == Enum.HumanoidStateType.Jumping) or (state == Enum.HumanoidStateType.Freefall)

		-- Rekam jika player bergerak/bergeser atau jika sedang jumping (biar lompatan terekam)
		if humanoid.MoveDirection.Magnitude > movementThreshold or isJumping or (elapsedTime - lastSample >= recordInterval) then
			-- pastikan titik tidak terlalu rapat waktu
			if elapsedTime - lastSample >= 0.02 then
				table.insert(waypoints, {pos = root.Position, t = elapsedTime, jump = isJumping})
				lastSample = elapsedTime
			end
		end
	end)
end

local function stopRecording()
	recording = false
	paused = false
	if connection then connection:Disconnect() connection = nil end
	pauseBtn.Visible = false

	if #waypoints > 0 then
		recordings[recordName] = table.clone(waypoints)
		status.Text = "Record " .. recordName .. " tersimpan (" .. #waypoints .. " titik)"
		refreshList()
	else
		status.Text = "Tidak ada data yang direkam"
	end
	recordBtn.Text = "Start Recording"
	recordBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
end

recordBtn.MouseButton1Click:Connect(function()
	if not recording then
		startRecording()
	else
		stopRecording()
	end
end)

pauseBtn.MouseButton1Click:Connect(function()
	if not recording then return end
	paused = not paused
	if paused then
		pauseBtn.Text = "Resume"
		status.Text = "Recording paused"
	else
		pauseBtn.Text = "Pause"
		status.Text = "Recording " .. recordName .. "..."
	end
end)

player.CharacterRemoving:Connect(function()
	if connection then connection:Disconnect() end
end)

-- Inisialisasi list jika ada data default (kosong sekarang)
refreshList()
