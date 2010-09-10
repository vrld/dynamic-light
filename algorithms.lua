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

-- test if point in triangle
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
	local p, lastP = adj[poly[2]], nil
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
			lastP = p
		else
			p = adj[p.r]
			if p == lastP then
				error("Cannot triangulize")
			end
		end
	end
	triangles[#triangles+1] = {p.l,p.p,p.r}

	return triangles
end
