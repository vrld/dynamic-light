require 'algorithms'
require 'class'

Polygon = Class{function(self, vertices)
	self.vertices = {}
	for i,v in ipairs(vertices) do
		self.vertices[i] = v:clone()
	end

	local function unp(v, ...)
		if not v then return end
		return v.x, v.y, unp(...)
	end
	self.points = {unp(unpack(vertices))}

	local function edge(p1,p2)
		return {p1=p1,p2=p2, normal = (p2-p1):perpendicular()}
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
	love.graphics.setColor(200,120,30)
	love.graphics.polygon('fill', self.points)
	-- debug: draw normals
	--love.graphics.setColor(100,100,100)
	--for _,e in ipairs(self.edges) do
	--	local m = (e.p1 + e.p2) / 2
	--	local k = m + e.normal
	--	love.graphics.line(m.x,m.y,k.x,k.y)
	--end
	-- debug: draw outline
	--love.graphics.setColor(100,100,100)
	--love.graphics.polygon('line', self.points)
end

Light = Class{function(self, pos, range, intensity, color)
	self.pos = pos
	self.range = range and range / 300 or 1
	self.intensity = intensity or 1
	self.color = color or {255,255,255}
end}

function Light:castShadow(poly)
	local inRange = false
	local vertices = {}
	for _,e in ipairs(poly.edges) do
		local d = (e.p1 + e.p2)/2
		if (self.pos - d):len2() < (self.range * 300)^2 then inRange = true end
		if (d - self.pos) * e.normal > 0 then
			vertices[#vertices+1] = e.p1
			vertices[#vertices+1] = e.p2

			vertices[#vertices+1] = e.p1 + 800 * (e.p1 - self.pos):normalized()
			vertices[#vertices+1] = e.p2 + 800 * (e.p2 - self.pos):normalized()
		end
	end

	if not inRange then return {} end

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
	love.graphics.draw(light_img, self.pos.x, self.pos.y, 0, self.range,self.range, 300,300)
end

function Light:drawMask()
	love.graphics.setColor(0,0,0)
	love.graphics.draw(light_mask, self.pos.x, self.pos.y, 0, self.range,self.range,300,300)
	local ul = self.pos - vector(self.range,self.range)*300
	if ul.x > 0 then love.graphics.rectangle('fill', 0,0,ul.x,600) end
	if ul.y > 0 then love.graphics.rectangle('fill', 0,0,800,ul.y) end

	local lr = self.pos + vector(self.range,self.range)*300
	if lr.x < 800 then love.graphics.rectangle('fill', lr.x,0,800,600) end
	if lr.y < 600 then love.graphics.rectangle('fill', 0,lr.y,800,600) end

	if self.intensity < 1 then
		love.graphics.setColor(0,0,0,(1-self.intensity)*255)
		love.graphics.rectangle('fill', ul.x,ul.y,(lr-ul):unpack())
	end
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
	for _,o in ipairs(objects) do
		love.graphics.polygon('fill', self.light:castShadow(o))
	end
end

function Player:draw()
	love.graphics.setColor(0,0,0)
	love.graphics.circle('line', self.light.pos.x, self.light.pos.y, 10)
	-- black out the rest
	self.light:drawMask()
end

function Player:update(dt)
--	self.light.pos = vector(love.mouse.getPosition())
	self.t = self.t + dt
	local a = vector(0,0)
	if love.keyboard.isDown('a') or love.keyboard.isDown('left') then
		a.x = -1
	elseif love.keyboard.isDown('d') or love.keyboard.isDown('right') then
		a.x = 1
	end
	if love.keyboard.isDown('w') or love.keyboard.isDown('up') then
		a.y = -1
	elseif love.keyboard.isDown('s') or love.keyboard.isDown('down') then
		a.y = 1
	end

	self.vel = self.vel / 1.2 + a * 60 * dt
	self.vel.y = self.vel.y + .07 * math.sin(math.pi * self.t)
	self.vel.x = self.vel.x + .02 * math.cos(math.pi * math.pi * self.t)

	self.light.pos = self.light.pos + self.vel
	self.light.pos.x = math.max(0, math.min(800, self.light.pos.x))
	self.light.pos.y = math.max(0, math.min(600, self.light.pos.y))

	self.last = math.min(1, math.max(0, 2*math.random()-1 + self.last * self.last))
	self.light.intensity = .98 + .03 * self.last
	self.light.range = self.light.intensity / 1.25
end


--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==
-- commencing holy trinity
--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==--==
function love.load()
	local light_img_id = love.image.newImageData(600,600)
	light_img_id:mapPixel(function(x,y) x,y = x/300-1,y/300-1
		if x*x+y*y >= 1 then return 0,0,0,0 end
		local i = (1 - math.min(1, math.sqrt(x*x+y*y)) ^ 2) * 255
		return 255,255,255,i
	end)
	light_img = love.graphics.newImage(light_img_id)

	light_mask = love.image.newImageData(600,600)
	light_mask:mapPixel(function(x,y)
		local _,_,_,a = light_img_id:getPixel(x,y)
		return 0,0,0,255-a
	end)
	light_mask = love.graphics.newImage(light_mask)

	love.graphics.setBackgroundColor(0,0,0)

	-- prepare magic
	local function map(func, tbl) for k,v in pairs(tbl) do tbl[k] = func(v) end return tbl end
	local function conc(tbl1,tbl2,...)
		if not tbl2 then return tbl1 end
		for i,v in ipairs(tbl2) do tbl1[#tbl1+1] = v end
		return conc(tbl1,...)
	end
	objects = map(Polygon, conc(
			SplitConvex{vector(100,100), vector(130,70), vector(150,120), vector(120,160), vector(130,110) },
			SplitConvex{vector(607,53), vector(729,19), vector(790,135), vector(709,220), vector(707,108), vector(583,97), vector(624,75)},
			SplitConvex{vector(166,416), vector(71,504), vector(218,551), vector(190,493)},
			{ConvexHull{vector(250,250), vector(260,350), vector(320,410), vector(400,240), vector(300,190) },
			 ConvexHull{vector(500,200), vector(550,249), vector(490,210), vector(510,50) },
			 ConvexHull{vector(518,346), vector(456,455), vector(525,520), vector(592,475), vector(587,365) }}))

	player = Player(vector(400,300))

	love.mouse.setVisible(false)
end

function love.mousereleased(x,y,btn)
	print(vector(x,y))
end

function love.draw()
	player:predraw(objects)
	for _,o in ipairs(objects) do
		o:draw()
	end
	player:draw()

	love.graphics.setColor(100,100,100)
	love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 10,10)
end

local t = 0
function love.update(dt)
	player:update(dt)
end
