local RunService = game:GetService("RunService")

local PlayerMod = {}
PlayerMod.__index = PlayerMod

function PlayerMod.new(humanoidRootPart)
	return setmetatable({
		hrp = humanoidRootPart,
		frames = nil,    -- { {cf, dt}, ... }
		playing = false,
		speed = 1,
		loop = false,
		index = 1,
		_conn = nil,
	}, PlayerMod)
end

function PlayerMod:Load(frames)
	self.frames = frames
	self.index = 1
end

function PlayerMod:Start()
	if not self.frames or #self.frames < 2 or self.playing then return end
	self.playing = true
	local acc = 0
	local prev = self.frames[self.index].cf

	self._conn = RunService.Heartbeat:Connect(function(dt)
		if not self.playing or not self.hrp or not self.hrp.Parent then return end
		local cur = self.frames[self.index]
		local nxt = self.frames[self.index + 1]
		if not nxt then
			if self.loop then
				self.index = 1
				prev = self.frames[1].cf
				return
			else
				self:Stop()
				return
			end
		end
		local duration = math.max(1e-3, cur.dt) / math.max(0.01, self.speed)
		acc += dt
		local alpha = math.clamp(acc / duration, 0, 1)
		self.hrp.CFrame = prev:Lerp(nxt.cf, alpha)
		if alpha >= 1 then
			acc = 0
			self.index += 1
			prev = nxt.cf
		end
	end)
end

function PlayerMod:Pause()
	self.playing = false
	if self._conn then self._conn:Disconnect() self._conn = nil end
end

function PlayerMod:Stop()
	self.index = 1
	self:Pause()
end

return PlayerMod
