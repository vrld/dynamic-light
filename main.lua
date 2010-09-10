require 'vector'
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
--	love.graphics.setColor(100,100,100)
--	for _,e in ipairs(self.edges) do
--		local m = (e.p1 + e.p2) / 2
--		local k = m + e.normal
--		love.graphics.line(m.x,m.y,k.x,k.y)
--	end
end

function ConvexHull(points)
	-- graham scan
	table.sort(points)
	if #points <= 3 then return points end

	local function makeRightTurn(p1,p2,p3)
		return (p3 - p1):perpendicular() * (p2 - p3) > 0
	end

	-- create upper hull
	local upper = {points[1], points[2]}
	for i=3,#points do
		upper[#upper+1] = points[i]:clone()
		while #upper > 2 and not makeRightTurn(upper[#upper-2], upper[#upper-1], upper[#upper]) do
			table.remove(upper, #upper-1)
		end
	end

	-- create lower hull
	local lower = {points[#points], points[#points-1]}
	for i = #points-2,1,-1 do
		lower[#lower+1] = points[i]:clone()
		while #lower > 2 and not makeRightTurn(lower[#lower-2], lower[#lower-1], lower[#lower]) do
			table.remove(lower, #lower-1)
		end
	end

	-- merge list
	local hull = upper
	for i=2,#lower-1 do hull[#hull+1] = lower[i] end
	return hull
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
	love.graphics.setColor(self.color[1], self.color[2], self.color[3], self.intensity * 255)
	love.graphics.draw(light_img, self.pos.x, self.pos.y, 0, self.range,self.range, 300,300)
end

function love.load()
	local light_img_id = love.image.newImageData(600,600)
	light_img_id:mapPixel(function(x,y) x,y = x/300-1,y/300-1
		local i = (1 - math.min(1, math.sqrt(x*x+y*y)) ^ 1.4) * 150
		return 0,0,0,i
	end)
	light_img = love.graphics.newImage(light_img_id)

	love.graphics.setBackgroundColor(255,230,180)
	objects = {}
	objects[#objects+1] = Polygon(ConvexHull{ vector(250,250), vector(260,350), vector(320,410), vector(400,240), vector(300,190) })
	objects[#objects+1] = Polygon(ConvexHull{ vector(500,200), vector(550,249), vector(490,210), vector(510,50) })
	objects[#objects+1] = Polygon(ConvexHull{ vector(518,346), vector(456,455), vector(525,520), vector(592,475), vector(587,365) })
	light = Light(vector(500,400), 200, 1, {255,230,180})

	fbo = love.graphics.newFramebuffer(800,600)
end

function love.mousereleased(x,y,btn)
	if btn == 'wu' then light.range = light.range * 1.1 end
	if btn == 'wd' then light.range = light.range/ 1.1 end
end

function love.draw()
	love.graphics.setRenderTarget(fbo)
	love.graphics.setColor(255,255,255)
	love.graphics.rectangle('fill',0,0,800,600)
	light:draw()
	love.graphics.setRenderTarget()

	love.graphics.setColor(0,0,0)
	for _,o in ipairs(objects) do
		love.graphics.polygon('fill', light:castShadow(o))
	end

	for _,o in ipairs(objects) do
		o:draw()
	end

	love.graphics.setBlendMode('subtractive')
	love.graphics.setColor(255,255,255)
	love.graphics.draw(fbo,0,0)
	love.graphics.setBlendMode('alpha')

	love.graphics.setColor(100,100,100)
	love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 10,10)
end

local t = 0
function love.update(dt)
	t = t + dt
	light.pos = vector(love.mouse.getPosition())
--	light.intensity = .5 * math.sin(60 * t) + .5
end
