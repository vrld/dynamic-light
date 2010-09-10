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

local light_img
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
		love.graphics.setColor(0,0,0,self.intensity*255)
		love.graphics.rectangle('fill', ul.x,ul.y,(lr-ul):unpack())
	end
end

function love.load()
	local light_img_id = love.image.newImageData(600,600)
	light_img_id:mapPixel(function(x,y) x,y = x/300-1,y/300-1
		if x*x+y*y >= 1 then return 0,0,0,0 end
		local i = (1 - math.min(1, math.sqrt(x*x+y*y)) ^ 2) * 255
		return 255,255,255,i
	end)
	light_img = love.graphics.newImage(light_img_id)

	light_mask = love.image.newImageData(600,600)
	light_mask:mapPixel(function(x,y) x,y = x/300-1, y/300-1
		if x*x+y*y >= 1 then return 0,0,0,255 end
		local i = (1 - math.min(1, math.sqrt(x*x+y*y)) ^ 2) * 255
		return 0,0,0,255-i
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
			Triangulize{vector(100,100), vector(130,70), vector(150,120), vector(120,160), vector(130,110) },
			Triangulize{vector(607,53), vector(729,19), vector(790,135), vector(709,220), vector(707,108), vector(583,97), vector(624,75)},
			{{vector(166,416), vector(71,504), vector(218,551), vector(190,493)}},
			{ConvexHull{vector(250,250), vector(260,350), vector(320,410), vector(400,240), vector(300,190) },
			 ConvexHull{vector(500,200), vector(550,249), vector(490,210), vector(510,50) },
			 ConvexHull{vector(518,346), vector(456,455), vector(525,520), vector(592,475), vector(587,365) }}))

	light = Light(vector(500,400), 400, 1, {255,230,180})
end

function love.mousereleased(x,y,btn)
	print(vector(x,y))
end

function love.draw()
	light:draw()
	love.graphics.setColor(0,0,0)
	for _,o in ipairs(objects) do
		love.graphics.polygon('fill', light:castShadow(o))
	end
	for _,o in ipairs(objects) do
		o:draw()
	end
	-- black out the rest
	light:drawMask()

	love.graphics.setColor(100,100,100)
	love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 10,10)
end

local t = 0
function love.update(dt)
	t = t + dt
	light.pos = vector(love.mouse.getPosition())
end
