-- Simple Maid for cleaning RBXScriptConnections & tasks
local Maid = {}
Maid.__index = Maid

function Maid.new()
	local self = setmetatable({_tasks = {}}, Maid)
	return self
end

function Maid:Give(taskObj)
	local id = #self._tasks + 1
	self._tasks[id] = taskObj
	return id
end

function Maid:DoCleaning()
	for i, t in ipairs(self._tasks) do
		if typeof(t) == "RBXScriptConnection" then
			if t.Connected then t:Disconnect() end
		elseif type(t) == "function" then
			pcall(t)
		elseif typeof(t) == "Instance" then
			if t.Destroy then t:Destroy() end
		end
		self._tasks[i] = nil
	end
end

return Maid
