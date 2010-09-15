local spatialhash = {}
spatialhash.__index = spatialhash
function Spatialhash(cell_size)
	local sh = {cell_size = cell_size or 100, cells = {}}
	return setmetatable(sh, spatialhash)
end

function spatialhash:cell(key)
	if not self.cells[key] then
		self.cells[key] = {}
		setmetatable(self.cells[key], {__mode = "kv"}) -- make weak table
	end
	return self.cells[key]
end

function spatialhash:cellCoords(v)
	local v = v / self.cell_size
	v.x, v.y = math.floor(v.x), math.floor(v.y)
	return v
end

function spatialhash:getKey(v)
	return tostring(self:cellCoords(v))
end

function spatialhash:getCell(v)
	return self.cells[tostring(self:cellCoords(v))]
end

function spatialhash:insert(obj, pos)
	self:cell(self:getKey(pos))[obj] = obj
end

function spatialhash:remove(obj)
	for _,cell in pairs(self.cells) do
		cell[obj] = nil
	end
end

function spatialhash:remove(obj, pos)
	self:cell(self:getKey(pos))[obj] = nil
end

function spatialhash:insertPolygon(obj, points)
	-- get bounding box
	local ul = self:cellCoords(points[1])
	local lr = ul:clone()
	for _,p in ipairs(points) do
		local pp = self:cellCoords(p)
		if ul.x > pp.x then ul.x = pp.x end
		if ul.y > pp.y then ul.y = pp.y end

		if lr.x < pp.x then lr.x = pp.x end
		if lr.y < pp.y then lr.y = pp.y end
	end

	-- insert polygon into bounding box. may
	-- actually insert too much
	for x = ul.x,lr.x do
		for y = ul.y,lr.y do
			self:cell(tostring(vector(x,y)))[obj] = obj
		end
	end
end

function spatialhash:getNeighbors(pos, rad)
	local set = {}
	local ul = self:cellCoords(pos - vector(rad,rad))
	local lr = self:cellCoords(pos + vector(rad,rad))
	for i = ul.x,lr.x do
		for k = ul.y,lr.y do
			local cell = self.cells[tostring(vector(i,k))]
			for i,_ in pairs(cell or {}) do set[i] = i end
		end
	end
	local items = {}
	for o,_ in pairs(set) do items[#items+1] = o end
	return items
end
