require 'vector'

local function isConcave(p1,p2,p3)
	return (p3 - p1):perpendicular() * (p2 - p1) > 0
end

function clone(t)
	local tt = {}
	for k,v in pairs(t) do tt[k] = v end
	return tt
end
function ConvexHull(points)
	-- graham scan
	if #points <= 3 then return points end
	points = clone(points)
	table.sort(points)

	-- create upper hull
	local upper = {points[1], points[2]}
	for i=3,#points do
		upper[#upper+1] = points[i]
		while #upper > 2 and not isConcave(upper[#upper-2], upper[#upper-1], upper[#upper]) do
			table.remove(upper, #upper-1)
		end
	end

	-- create lower hull
	local lower = {points[#points], points[#points-1]}
	for i = #points-2,1,-1 do
		lower[#lower+1] = points[i]
		while #lower > 2 and not isConcave(lower[#lower-2], lower[#lower-1], lower[#lower]) do
			table.remove(lower, #lower-1)
		end
	end

	-- merge list
	local hull = upper
	for i=2,#lower-1 do hull[#hull+1] = lower[i] end
	return hull
end


function inTriangle(q, p1,p2,p3)
	local v1, v2 = p2 - p1, p3 - p1
	local qp = q - p1
	local dv = v1:cross(v2)
	local l, m = qp:cross(v2) / dv, v1:cross(qp) / dv
	return l > 0 and m > 0 and l+m < 1
end

-- the method of kong
function Triangulize(poly)
	if #poly <= 3 then return {poly} end
	local triangles = {}
	local concave = {}
	local adj = {}

	-- get list of (concave) points and save adjacencies
	for i,p in ipairs(poly) do
		local l, r  = (i == 1) and poly[#poly] or poly[i-1], (i == #poly) and poly[1] or poly[i+1]
		adj[p] = {p = p, l = l, r = r}
		if isConcave(l,p,r) then concave[p] = p end
	end
	-- test if edge is an 'ear'
	local function isEar(p1,p2,p3)
		if isConcave(p1,p2,p3) then return false end
		for q,_ in pairs(concave) do
			if inTriangle(q, p1,p2,p3) then return false end
		end
		return true
	end

	-- while still points left to triangulize
	local nPoints = #poly
	local p = adj[poly[2]]
	while nPoints > 3 do
		-- if ear, remove ear
		if not concave[p.p] and isEar(p.l, p.p, p.r) then
			triangles[#triangles+1] = {p.l,p.p,p.r}
			if concave[p.l] and not isConcave(adj[p.l].l, p.l, p.r) then
				concave[p.l] = nil
			end
			if concave[p.r] and not isConcave(p.l, p.r, adj[p.r].r) then
				concave[p.r] = nil
			end
			adj[p] = nil
			adj[p.l].r = p.r
			adj[p.r].l = p.l
			nPoints = nPoints - 1
			p = adj[p.l]
		else
			p = adj[p.r]
		end
	end
	triangles[#triangles+1] = {p.l,p.p,p.r}

	return triangles
end

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
	splitted = Triangulize(points)
end
