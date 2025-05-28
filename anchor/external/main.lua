local bu = require("light")
local g = love.graphics
local w, h = g.getDimensions()

local sm = bu.newShadowMap(g.getDimensions()) -- full-screen shadowmap

local geo = bu.newOcclusionMesh()
--add a bunch of edges
geo:addEdge(w/2-50,h/2-50, w/2+50,h/2-50) -- ax,ay, bx,by
geo:addEdge(w/2+50,h/2-50, w/2+50,h/2+50)
geo:addEdge(w/2+50,h/2+50, w/2-50,h/2+50)
geo:addEdge(w/2-50,h/2+50, w/2-50,h/2-50)

--another new meshes
local circles = bu.newOcclusionMesh()
local a = 0
for i=1, 16 do
	local x,y = math.cos(a), math.sin(a)
		circles:addCircle(w/2+x*180,h/2+y*180,20,24)
	a = a + math.pi/8
end

local lights = bu.newLightsArray()
--add a bunch of lights, all 128 to be precise
for y=1,1 do
	for x=1,1 do
		lights:push( w/16*x-w/32, h*y/8-h/16, 400, .02,.02,.02)
	end
end

local count = geo.edge_count --remember the static count
function love.update(dt)
	--reset edge count to static
	geo.edge_count = count
	--move dynamic meshes
	circles:applyTransform(w/2,h/2,dt/10,1,1,w/2,h/2)
	--and add them to the geometry mesh
	geo:addOcclusionMesh(circles)
	--move one light to the mouse position(also make it brighter)
	local mx,my = love.mouse.getPosition()
	lights:set(1,mx,my,500, .3,.3,.3)
end

function love.draw()
	sm:render(geo, lights)
	lights:draw(sm)
end