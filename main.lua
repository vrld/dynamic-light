require 'algorithms'
require 'class'
require 'camera'
require 'spatialhash'
require 'profiler'

local cam, player, hash

debug.showNormals = false
debug.showWireframe = false

local function unp(v, ...)
	if not v then return end
	return v.x, v.y, unp(...)
end
Polygon = Class{function(self, vertices)
	self.vertices = {}
	for i,v in ipairs(vertices) do
		self.vertices[i] = v:clone()
	end
	self.points = {unp(unpack(vertices))}

	local function edge(p1,p2)
		return {p1=p1,p2=p2, len = (p1-p2):len()/2, center=(p1+p2)/2, normal = (p2-p1):perpendicular():normalize_inplace()}
	end
	self.edges = {}
	for i = 1,#self.vertices do
		k = i == #self.vertices and 1 or i + 1
		self.edges[i] = edge(self.vertices[i], self.vertices[k])
	end

	self.indicies = {}
	for i,v in ipairs(self.vertices) do
		self.indicies[v] = i
	end
end}

function Polygon:draw()
	if not debug.showWireframe then
		love.graphics.setColor(200,120,30)
		love.graphics.polygon('fill', self.points)
	end
	if debug.showNormals then
		love.graphics.setColor(255,100,100)
		for _,e in ipairs(self.edges) do
			local k = e.center + e.normal * 20
			love.graphics.line(e.center.x,e.center.y,k.x,k.y)
		end
	end
	if debug.showWireframe or self.flagColission then
		love.graphics.setColor(100,255,100)
		love.graphics.polygon('line', self.points)
	end
end

function Polygon:contains(point)
	for _,e in ipairs(self.edges) do
		if e.normal * (point - e.p1) > 0 then return false end
	end
	return true
end

function Polygon:intersectsCircle(center, radius)
	if self:contains(center) then return true, vector(0,0) end
	local function segmentDistanceSqToPoint(e, p)
		local dsq_line = (p - e.center):projectOn(e.normal):len2() -- distance to line
		local lsq_line = (p - e.center):projectOn(e.normal:perpendicular()):len2() -- projection on line
		-- point over segment
		if lsq_line < e.len*e.len then return dsq_line end
		lsq_line = math.sqrt(lsq_line) - e.len -- excess
		-- point on line
		if dsq_line == 0 then return lsq_line*lsq_line end
		-- neither -> pythagoras
		return dsq_line + lsq_line*lsq_line
	end
	-- center outside of circle. check distance to each segment
	for _,e in ipairs(self.edges) do
		local dist = segmentDistanceSqToPoint(e, center)
		if e.normal * (center - e.p1) > 0 and dist <= radius*radius then
			return true, e.normal * (radius-math.sqrt(dist))
		end
	end
	return false
end

Light = Class{function(self, pos, range, intensity, color)
	self.pos = pos
	self.range = range and range / 256 or 1
	self.intensity = intensity or 1
	self.color = color or {255,255,255}
end}

function Light:castShadow(poly)
	local vertices = {}
	for _,e in ipairs(poly.edges) do
		local d = (e.p1 + e.p2)/2
		if (d - self.pos) * e.normal > 0 then
			vertices[#vertices+1] = e.p1
			vertices[#vertices+1] = e.p2

			vertices[#vertices+1] = e.p1 + 800 * (e.p1 - self.pos):normalized()
			vertices[#vertices+1] = e.p2 + 800 * (e.p2 - self.pos):normalized()
		end
	end

	vertices = ConvexHull(vertices)
	local poly = {}
	for i,v in ipairs(vertices) do
		poly[#poly+1] = v.x
		poly[#poly+1] = v.y
	end

	return poly
end

local light_img, light_mask
function Light:draw()
	love.graphics.setColor(self.color[1], self.color[2], self.color[3])
	love.graphics.draw(light_img, self.pos.x, self.pos.y, 0, self.range,self.range, 256,256)
end

function Light:drawMask(cam)
	cam:postdraw()
	love.graphics.setColor(0,0,0)
	local pos = cam:toCameraCoords(self.pos)
	love.graphics.draw(light_mask, pos.x, pos.y, 0, self.range,self.range,256,256)
	local ul = pos - vector(self.range,self.range)*256
	if ul.x > 0 then love.graphics.rectangle('fill', 0,0,ul.x,600) end
	if ul.y > 0 then love.graphics.rectangle('fill', 0,0,800,ul.y) end

	local lr = pos + vector(self.range,self.range)*256
	if lr.x < 800 then love.graphics.rectangle('fill', lr.x,0,800,600) end
	if lr.y < 600 then love.graphics.rectangle('fill', 0,lr.y,800,600) end

	if self.intensity < 1 then
		love.graphics.setColor(0,0,0,(1-self.intensity)*255)
		love.graphics.rectangle('fill', ul.x,ul.y,(lr-ul):unpack())
	end
	cam:postdraw()
end

Player = Class{name="Player", function(self, p)
	self.light = Light(p:clone(), 270, 1, {255,230,180})
	self.vel = vector(0,0)
	self.t = 0
	self.last = 0
end}

function Player:predraw(objects)
	self.light:draw()
	love.graphics.setColor(0,0,0)
	for _,o in ipairs(hash:getNeighbors(self.light.pos, self.light.range * 256)) do
		love.graphics.polygon('fill', self.light:castShadow(o))
	end
end

function Player:draw(cam)
	love.graphics.setColor(0,0,0)
	love.graphics.circle('line', self.light.pos.x, self.light.pos.y, 10)
	-- black out the rest
	if not debug.noDarkening then
		self.light:drawMask(cam)
	end
end

function Player:update(dt)
	self.t = self.t + dt
	local a = vector(0,0)
	if love.keyboard.isDown('left') then
		a.x = -1
	elseif love.keyboard.isDown('right') then
		a.x = 1
	end
	if love.keyboard.isDown('up') then
		a.y = -1
	elseif love.keyboard.isDown('down') then
		a.y = 1
	end

	-- flicker light
	self.last = math.min(1, math.max(0, 2*math.random()-1 + self.last * self.last))
	self.light.intensity = .98 + .04 * self.last
	self.light.range = self.light.intensity / 1.1

	-- Colission detection in fixed timesteps
	local function moveAndCollide(dt)
		self.vel = self.vel / 1.04 + a * 1200 * dt
		self.vel.y = self.vel.y + 1.2 * math.sin(math.pi * self.t)
		self.vel.x = self.vel.x + .8 * math.cos(math.pi * math.pi * self.t)

		local pos = self.light.pos + self.vel * dt

		local move = vector(0,0)
		for _,o in ipairs(hash:getNeighbors(pos, self.light.range * 256)) do
			local collide, separatingVector = o:intersectsCircle(pos, 12)
			if collide then
				move = move + separatingVector
			end
		end

		self.light.pos = pos + move
	end
	while dt > .01 do
		moveAndCollide(.01)
		dt = dt - .01
	end
	moveAndCollide(dt)
end


--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==
-- commencing holy trinity
--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==
-- functional magic
local function map(func, tbl) for k,v in pairs(tbl) do tbl[k] = func(v) end return tbl end
local function conc(tbl1,tbl2,...)
	if not tbl2 then return tbl1 end
	for i,v in ipairs(tbl2) do tbl1[#tbl1+1] = v end
	return conc(tbl1,...)
end

function love.load()
	local light_img_id = love.image.newImageData(512,512)
	light_img_id:mapPixel(function(x,y) x,y = x/256-1,y/256-1
		if x*x+y*y >= 1 then return 0,0,0,0 end
		local i = (1 - math.min(1, math.sqrt(x*x+y*y)) ^ .9) * 255
		return 255,255,255,i
	end)
	light_img = love.graphics.newImage(light_img_id)

	light_mask = love.image.newImageData(512,512)
	light_mask:mapPixel(function(x,y)
		local _,_,_,a = light_img_id:getPixel(x,y)
		return 0,0,0,255-a
	end)
	light_mask = love.graphics.newImage(light_mask)

	love.graphics.setBackgroundColor(0,0,0)
	objects = map(Polygon, conc(
			SplitConvex{vector(100,100), vector(130,70), vector(150,120), vector(120,160), vector(130,110) },
			SplitConvex{vector(607,53), vector(729,19), vector(790,135), vector(709,220), vector(707,108), vector(583,97), vector(624,75)},
			{ConvexHull{vector(250,250), vector(260,350), vector(320,410), vector(400,240), vector(300,190) },
			 ConvexHull{vector(500,200), vector(550,249), vector(490,210), vector(510,50) },
			 ConvexHull{vector(518,346), vector(456,455), vector(525,520), vector(592,475), vector(587,365) }}))

	player = Player(vector(400,300))
	cam = Camera(vector(400,300))
	hash = Spatialhash(100)
	for _,o in ipairs(objects) do
		hash:insertPolygon(o, o.vertices)
	end

	love.graphics.setLine(2)

--	profiler.start()
end

local points = {}
function love.draw()
	cam:predraw()
	player:predraw(objects)
	for _,o in ipairs(objects) do
		o:draw()
	end
	player:draw(cam)
	cam:postdraw()

	if #points >= 1 then
		points[#points+1] = vector(love.mouse.getPosition())
		love.graphics.setColor(100,100,255)
		love.graphics.line(unp(unpack(points)))
		points[#points] = nil
	end
	love.graphics.setColor(100,100,100)
	love.graphics.print(string.format("FPS: %d, Objects: %d", love.timer.getFPS(), #objects), 10,10)
end

function love.update(dt)
	cam.pos = cam.pos + (player.light.pos - cam.pos) * dt
	player:update(dt)
end

function love.keyreleased(key)
	if key == 'w' then debug.showWireframe = not debug.showWireframe end
	if key == 'n' then debug.showNormals = not debug.showNormals end
	if key == 'd' then debug.noDarkening = not debug.noDarkening end
	if key == 'c' then objects, hash = {}, Spatialhash(100) end
end

function love.mousereleased(x,y,btn)
	points[#points+1] = vector(x,y)
	if btn == 'r' and #points >= 3 then
		points = map(function(p) return cam:toWorldCoords(p) end, points)
		if not pcall(function()
				local new = map(Polygon, SplitConvex(points))
				objects = conc(objects, new)
				for _,o in ipairs(new) do
					hash:insertPolygon(o, o.vertices)
				end
			end) then
			pcall(function()
				for i=1,math.floor(#points/2) do
					points[i], points[#points+1-i] = points[#points+1-i], points[i]
				end
				local new = map(Polygon, SplitConvex(points))
				objects = conc(objects, new)
				for _,o in ipairs(new) do
					hash:insertPolygon(o, o.vertices)
				end
			end)
		end
		points= {}
	end
end
