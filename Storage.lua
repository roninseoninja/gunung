local HttpService = game:GetService("HttpService")

-- Safe FS wrappers (support Syn/Script-Ware & Studio)
local hasFS = (isfolder and makefolder and isfile and writefile and readfile and delfile and listfiles) ~= nil

local Storage = {}
Storage.folder = "InfinityPlayRecord"

local function round3(x) return math.round(x * 1000) / 1000 end

local function encodeFrames(frames)
	-- frames: { {cf=CFrame, dt=number}, ... }
	local out = table.create(#frames)
	for i, f in ipairs(frames) do
		local px, py, pz = f.cf:GetPivot():Position():ToOrientation() -- nope: wrong API; use below
	end
end

-- pivot & toorientation need care; do manual:
local function cfToData(cf)
	local p = cf.Position
	local rx, ry, rz = cf:ToOrientation()
	return {pos = {round3(p.X), round3(p.Y), round3(p.Z)}, rot = {round3(rx), round3(ry), round3(rz)}}
end

local function dataToCF(d)
	local pos = Vector3.new(d.pos[1], d.pos[2], d.pos[3])
	return CFrame.new(pos) * CFrame.Angles(d.rot[1], d.rot[2], d.rot[3])
end

function Storage:EnsureFolder()
	if not hasFS then return false end
	if not isfolder(self.folder) then makefolder(self.folder) end
	return true
end

function Storage:SaveNew(name, frames)
	if not hasFS then return false, "No FS" end
	self:EnsureFolder()
	if not name:match("%.json$") then name = name .. ".json" end
	local payload = table.create(#frames)
	for i, f in ipairs(frames) do
		local row = cfToData(f.cf)
		row.dt = round3(f.dt)
		payload[i] = row
	end
	writefile(self.folder .. "/" .. name, HttpService:JSONEncode(payload))
	return true
end

function Storage:Append(name, frames)
	if not hasFS then return false, "No FS" end
	self:EnsureFolder()
	if not name:match("%.json$") then name = name .. ".json" end
	local path = self.folder .. "/" .. name
	local existing = {}
	if isfile(path) then
		local ok, data = pcall(function()
			return HttpService:JSONDecode(readfile(path))
		end)
		if ok and type(data) == "table" then existing = data end
	end
	for _, f in ipairs(frames) do
		local row = cfToData(f.cf)
		row.dt = round3(f.dt)
		table.insert(existing, row)
	end
	writefile(path, HttpService:JSONEncode(existing))
	return true
end

function Storage:Load(path)
	if not hasFS then return nil, "No FS" end
	if not path or not isfile(path) then return nil, "File not found" end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok or type(data) ~= "table" then return nil, "Decode error" end
	local frames = table.create(#data)
	for i, row in ipairs(data) do
		frames[i] = { cf = dataToCF(row), dt = tonumber(row.dt) or 0.033 }
	end
	return frames
end

return Storage
