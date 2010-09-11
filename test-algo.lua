require 'vector'
require 'algorithms'

function love.load()
	love.graphics.setBackgroundColor(255,255,255)
	points = {}
	ch = {}
	splitted = {}
end

local function unp(p, ...)
	if not p then return end
	return p.x,p.y, unp(...)
end

function drawPoly(points)
	if #points > 2 then
		love.graphics.polygon('line', unp(unpack(points)))
		for i,p in ipairs(points) do
			love.graphics.print(tostring(p), p.x, p.y+10)
		end
	end
end

function love.draw()
	if #ch > 2 then
		love.graphics.setColor(80,200,90,100)
		love.graphics.polygon('fill', unp(unpack(ch)))
	end

	love.graphics.setColor(0,0,90)
	drawPoly(points)
	for i,sp in ipairs(splitted) do
		if #sp > 2 then
			love.graphics.setColor(i / #splitted * 255,0,0,100)
			love.graphics.polygon('fill', unp(unpack(sp)))
			love.graphics.polygon('line', unp(unpack(sp)))
		end
	end

	love.graphics.setColor(0,0,150)
	for _,p in ipairs(points) do
		love.graphics.circle('line', p.x,p.y,3)
	end
end

function love.mousereleased(x,y,btn)
	if btn == 'r' then points, ch, splitted = {}, {}, {} return end
	if btn ~= 'l' then return end
	points[#points+1] = vector(x,y)

	ch = ConvexHull(points)
	splitted = SplitConvex(points)
end
