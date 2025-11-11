local RunService = game:GetService("RunService")

local Recorder = {}
Recorder.__index = Recorder

function Recorder.new(humanoidRootPart)
	local self = setmetatable({
		hrp = humanoidRootPart,
		frames = {},        -- { {cf=CFrame, dt=number}, ... }
		_running = false,
		_paused = false,
		_lastCF = nil,
		_lastTick = nil,
		moveThreshold = 0.1,
		angleThreshold = 0.01,
		minFrameGap = 0.03, -- 30+ fps ceiling
		_sinceLast = 0,
	}, Recorder)
	return self
end

local function yawFrom(cf)
	local _, ry = cf:ToOrientation()
	return ry
end

function Recorder:_significant(newCF)
	if not self._lastCF then return true end
	local dist = (self._lastCF.Position - newCF.Position).Magnitude
	if dist > self.moveThreshold then return true end
	local dyaw = math.abs(yawFrom(newCF) - yawFrom(self._lastCF))
	return dyaw > self.angleThreshold
end

function Recorder:Start()
	if self._running then return end
	self._running, self._paused = true, false
	self._lastCF, self._sinceLast = nil, 0
	self._lastTick = os.clock()
end

function Recorder:Pause() self._paused = true end
function Recorder:Resume() self._paused = false end

function Recorder:Stop()
	self._running, self._paused = false, false
end

function Recorder:Step(dt)
	if not (self._running and not self._paused) then return end
	if not self.hrp or not self.hrp.Parent then return end
	self._sinceLast += dt
	local cf = self.hrp.CFrame
	if self:_significant(cf) and self._sinceLast >= self.minFrameGap then
		table.insert(self.frames, {cf = cf, dt = self._sinceLast})
		self._lastCF = cf
		self._sinceLast = 0
	end
end

function Recorder:Rollback(toIndex) -- cut tail frames
	if not toIndex or toIndex < 1 then return end
	for i = #self.frames, toIndex + 1, -1 do
		self.frames[i] = nil
	end
end

return Recorder
