-- ===================================
-- Skrip GUI "Script Maker V1"
-- =s=================================

-- Layanan dan objek yang diperlukan
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- Variabel status
local isRecording = false
local connection = nil
local recordedCoordinates = {}

-- Membuat ScreenGui
local ScriptMakerGui = Instance.new("ScreenGui")
ScriptMakerGui.Name = "ScriptMakerV1"
ScriptMakerGui.Parent = PlayerGui

-- Membuat Frame utama
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 350)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -175)
MainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
MainFrame.BorderSizePixel = 2
MainFrame.BorderColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScriptMakerGui

-- Membuat Judul
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 30)
TitleLabel.Position = UDim2.new(0, 0, 0, 0)
TitleLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
TitleLabel.BorderSizePixel = 0
TitleLabel.TextColor3 = Color3.new(1, 1, 1)
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextSize = 18
TitleLabel.Text = "Script Maker V1"
TitleLabel.Parent = MainFrame

-- Membuat Tombol "Close"
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 60, 0, 30)
CloseButton.Position = UDim2.new(1, -60, 0, 0)
CloseButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
CloseButton.BorderSizePixel = 0
CloseButton.TextColor3 = Color3.new(1, 1, 1)
CloseButton.Font = Enum.Font.SourceSansBold
CloseButton.TextSize = 18
CloseButton.Text = "Close"
CloseButton.Parent = MainFrame

-- Membuat Tombol "Start"
local StartButton = Instance.new("TextButton")
StartButton.Size = UDim2.new(0, 80, 0, 40)
StartButton.Position = UDim2.new(0, 15, 0, 45)
StartButton.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
StartButton.BorderSizePixel = 0
StartButton.TextColor3 = Color3.new(1, 1, 1)
StartButton.Font = Enum.Font.SourceSansBold
StartButton.TextSize = 18
StartButton.Text = "Start"
StartButton.Parent = MainFrame

-- Membuat Tombol "Stop"
local StopButton = Instance.new("TextButton")
StopButton.Size = UDim2.new(0, 80, 0, 40)
StopButton.Position = UDim2.new(0, 105, 0, 45)
StopButton.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
StopButton.BorderSizePixel = 0
StopButton.TextColor3 = Color3.new(1, 1, 1)
StopButton.Font = Enum.Font.SourceSansBold
StopButton.TextSize = 18
StopButton.Text = "Stop"
StopButton.Parent = MainFrame

-- Membuat Tombol "Copy"
local CopyButton = Instance.new("TextButton")
CopyButton.Size = UDim2.new(0, 80, 0, 40)
CopyButton.Position = UDim2.new(0, 195, 0, 45)
CopyButton.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
CopyButton.BorderSizePixel = 0
CopyButton.TextColor3 = Color3.new(1, 1, 1)
CopyButton.Font = Enum.Font.SourceSansBold
CopyButton.TextSize = 18
CopyButton.Text = "Copy"
CopyButton.Parent = MainFrame

-- Membuat Tombol "Add Coor"
local AddCoorButton = Instance.new("TextButton")
AddCoorButton.Size = UDim2.new(0, 80, 0, 40)
AddCoorButton.Position = UDim2.new(0, 15, 0, 95)
AddCoorButton.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
AddCoorButton.BorderSizePixel = 0
AddCoorButton.TextColor3 = Color3.new(1, 1, 1)
AddCoorButton.Font = Enum.Font.SourceSansBold
AddCoorButton.TextSize = 18
AddCoorButton.Text = "Add Coor"
AddCoorButton.Parent = MainFrame

-- Membuat Tombol "Clear"
local ClearButton = Instance.new("TextButton")
ClearButton.Size = UDim2.new(0, 80, 0, 40)
ClearButton.Position = UDim2.new(0, 105, 0, 95)
ClearButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
ClearButton.BorderSizePixel = 0
ClearButton.TextColor3 = Color3.new(1, 1, 1)
ClearButton.Font = Enum.Font.SourceSansBold
ClearButton.TextSize = 18
ClearButton.Text = "Clear"
ClearButton.Parent = MainFrame

-- Membuat Textbox untuk logging
local LoggingTextBox = Instance.new("TextBox")
LoggingTextBox.Size = UDim2.new(1, -30, 1, -165)
LoggingTextBox.Position = UDim2.new(0, 15, 0, 150)
LoggingTextBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
LoggingTextBox.BorderSizePixel = 2
LoggingTextBox.BorderColor3 = Color3.fromRGB(20, 20, 20)
LoggingTextBox.TextColor3 = Color3.new(1, 1, 1)
LoggingTextBox.Font = Enum.Font.Code
LoggingTextBox.TextSize = 14
LoggingTextBox.Text = ""
LoggingTextBox.TextWrapped = true
LoggingTextBox.MultiLine = true
LoggingTextBox.Parent = MainFrame
LoggingTextBox.PlaceholderText = "Logging..."

-- ===================================
-- Fungsi-fungsi Skrip
-- ===================================

-- Fungsi untuk memulai perekaman
function StartRecording()
    if isRecording then return end
    isRecording = true
    print("Mulai merekam koordinat...")
    LoggingTextBox.PlaceholderText = "Merekam..."

    -- Hubungkan fungsi ke loop game (setiap frame)
    connection = RunService.Stepped:Connect(function()
        local char = Player.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pos = char.HumanoidRootPart.Position
            local formattedCoor = string.format("%.2f, %.2f, %.2f", pos.X, pos.Y, pos.Z)
            LoggingTextBox.Text = "Logging...\n" .. formattedCoor
        end
    end)
end

-- Fungsi untuk menghentikan perekaman
function StopRecording()
    if not isRecording then return end
    isRecording = false
    if connection then
        connection:Disconnect()
        connection = nil
    end
    print("Perekaman dihentikan.")
    LoggingTextBox.PlaceholderText = "Logging..."
end

-- Fungsi untuk menambahkan koordinat saat ini ke daftar
function AddCoordinate()
    local char = Player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local pos = char.HumanoidRootPart.Position
        local formattedCoor = string.format("%.2f, %.2f, %.2f", pos.X, pos.Y, pos.Z)
        
        table.insert(recordedCoordinates, formattedCoor)
        
        -- Perbarui tampilan di Logging
        LoggingTextBox.Text = "Logging...\n"
        for _, coor in ipairs(recordedCoordinates) do
            LoggingTextBox.Text = LoggingTextBox.Text .. coor .. "\n"
        end
        print("Koordinat ditambahkan: " .. formattedCoor)
    end
end

-- Fungsi untuk menghapus semua koordinat
function ClearCoordinates()
    recordedCoordinates = {}
    LoggingTextBox.Text = ""
    LoggingTextBox.PlaceholderText = "Logging..."
    print("Log dibersihkan.")
end

-- Fungsi untuk menyalin koordinat ke clipboard
function CopyCoordinates()
    local textToCopy = ""
    for _, coor in ipairs(recordedCoordinates) do
        textToCopy = textToCopy .. coor .. "\n"
    CopyButton.Text = "Copied!"
    task.delay(1, function() CopyButton.Text = "Copy" end)
    
    end

    -- Executor biasanya menyediakan fungsi `setclipboard` atau `writeclipboard`
    -- Coba beberapa nama fungsi yang umum
    local success = pcall(function()
        getfenv().setclipboard(textToCopy)
    end)

    if not success then
        success = pcall(function()
            getfenv().writeclipboard(textToCopy)
        end)
    end

    if success then
        print("Koordinat berhasil disalin ke clipboard.")
    else
        warn("Gagal menyalin ke clipboard. Fungsi clipboard mungkin tidak didukung oleh executor ini.")
        print("Salin manual dari konsol:")
        print(textToCopy)
    end
end

-- Fungsi untuk menutup GUI
function CloseGui()
    StopRecording()
    ScriptMakerGui:Destroy()
end

-- Menghubungkan tombol ke fungsinya
StartButton.MouseButton1Click:Connect(StartRecording)
StopButton.MouseButton1Click:Connect(StopRecording)
AddCoorButton.MouseButton1Click:Connect(AddCoordinate)
ClearButton.MouseButton1Click:Connect(ClearCoordinates)
CopyButton.MouseButton1Click:Connect(CopyCoordinates)
CloseButton.MouseButton1Click:Connect(CloseGui)

print("Skrip 'Script Maker V1' telah dijalankan. GUI muncul di layar Anda.")
