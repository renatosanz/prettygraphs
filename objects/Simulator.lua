-- In order to reduce memory usage
-- I created a only-computing Object that don't
-- render images/draws or instance colliders (this reduces
-- collision detections processing)

Node = {}
Node.__index = Node

function Node:new(x, y, relations)
	local instance = {
		relations = relations or {},
		x = x or 0,
		y = y or 0,
	}
	setmetatable(instance, Node)
	return instance
end

Simulator = class:class_new(object)
-- Ti : initial temperature ~ 150
-- Cof: cooling factor ~ 0.95
-- mI: max iterations ~ 1000 to 2000 (variable)
function Simulator:new(Ti, Cof, mI, nodes)
	self:object("Simulator Annealing")
	self:timer()
	-- extract just the relations
	self.graph = {}
	for i, n in ipairs(nodes) do
		for _, v in ipairs(n.relations) do
			table.insert(self.graph, { n.number, v.number })
			print("{ " .. n.number .. "," .. v.number .. " }")
		end
	end

	local actualState = nodes
	actualEnergyState = CalculateEnergyState(actualState, self.graph)
	local bestState = actualState
	local bestEnergyState = actualEnergyState
	temperature = Ti
	i = 1 -- iterations
	maxI = mI
	Cf = Cof

	-- main iterative loop (core of the simulation)
	self:timer_after(5, function()
		self:timer_every(0.01, function()
			if temperature > 1e-10 or i < maxI then
				local newState = GenerateNeighbor(actualState)
				local newEnergyState = CalculateEnergyState(newState, self.graph)

				if newEnergyState < actualEnergyState then
					actualState = newState
					actualEnergyState = newEnergyState

					if newEnergyState < bestEnergyState then
						bestState = newState
						bestEnergyState = newEnergyState
					end
				else
					local prob = math.exp((actualEnergyState - newEnergyState) / temperature)
					if love.math.random() < prob then
						actualState = newState
						actualEnergyState = newEnergyState
					end
				end

				for i, nodo in ipairs(nodes) do
					nodo.body:setLinearVelocity(0, 0)
					nodo.body:setLinearVelocity(bestState[i].x - nodes[i].x, bestState[i].y - nodes[i].y)
				end

				-- reduce temperature
				temperature = temperature * Cf
				i = i + 1
			else
				self:timer_cancel("execute_simulation") -- cancel the loop
			end
		end, nil, nil, function() end, "execute_simulation")
	end)
end

function Simulator:update(dt)
	-- display some metrics
	front:draw_text_lt("iterations: " .. i .. "/" .. maxI, inter_font, 5, 5, 0, 1, 1, 1, 1, an.colors.blue[0])
	front:draw_text_lt("energy: " .. actualEnergyState, inter_font, 5, 15, 0, 1, 1, 1, 1, an.colors.orange[0])
	front:draw_text_lt("temperature: " .. temperature, inter_font, 5, 25, 0, 1, 1, 1, 1, an.colors.yellow[0])
	front:draw_text_lt("cooling factor: " .. Cf, inter_font, Gw / 2, 5, 0, 1, 1, 1, 1, an.colors.red[0])
end

--[[
  Energy Function
  Params:
  nodes = table with elements Nodes
  graph = table with elements of the form {k, l}
  where k and l are the indices of the nodes that 
  form the relation (edge)
]]
--
local min_dist_nodes = 50
local min_dist_edge = 10
local ideal_length = 20
function CalculateEnergyState(nodes, graph)
	local energy = 0
	-- valores entre 0 y 1
	local params = {
		node_dist = 1,
		edges = 1,
		intersections = 1,
		angles = 0, -- this param is under experiemtal dev and might cause bugs
		edge_length = 1,
	}

	for i, node1 in ipairs(nodes) do
		for k, node2 in ipairs(nodes) do
			local d = Distance(node1, node2)
			if d < min_dist_nodes then
				energy = energy + params.node_dist * (min_dist_nodes - d) ^ 2 / min_dist_nodes
			end
		end
	end

	for _, nodo in ipairs(nodes) do
		local dx = math.min(nodo.x, Gw - nodo.x)
		local dy = math.min(nodo.y, Gh - nodo.y)
		local dist_edge = math.min(dx, dy)

		if dist_edge < min_dist_edge then
			energy = energy + params.edges * (min_dist_edge - dist_edge) ^ 2 / min_dist_edge
		end
	end

	for _, beard in ipairs(graph) do
		local nodeA = nodes[beard[1]]
		local nodeB = nodes[beard[2]]
		local d = Distance(nodeA, nodeB)
		energy = energy + params.edge_length * (d - ideal_length) ^ 2 / ideal_length
	end

	for i, beard1 in ipairs(graph) do
		local nodeA = nodes[beard1[1]]
		local nodeB = nodes[beard1[2]]

		for k, beard2 in ipairs(graph) do
			if i ~= k then
				local nodoC = nodes[beard2[1]]
				local nodoD = nodes[beard2[2]]

				if intersect(nodeA, nodeB, nodoC, nodoD) then
					energy = energy
						+ params.intersections * 1 / (1 / Distance(nodeA, nodeB) + 1 / Distance(nodoC, nodoD))
				end
			end
		end
	end

	for _, node in ipairs(nodes) do
		for i, node_neighbor1 in ipairs(node.relations) do
			for k, node_neighbor2 in ipairs(node.relations) do
				if node_neighbor1 ~= node_neighbor2 then
					local ang = CalculateAngle(node, node_neighbor1, node_neighbor2)
					local angulo_ideal = 60
					energy = energy + params.angles * (ang - angulo_ideal) ^ 2 / angulo_ideal
				end
			end
		end
	end
	return energy
end

function GenerateNewNodes(numNodos)
	local nodes = {}
	for i = 1, numNodos do
		local node = Node:new(math.random() * Gw, math.random() * Gh)
		table.insert(nodes, node)
	end
	return nodes
end

function Distance(nodeA, nodeB)
	return math.sqrt((nodeA.x - nodeB.x) ^ 2 + (nodeA.y - nodeB.y) ^ 2)
end

function CalculateAngle(nodo, nodo_negthbor1, nodo_neigthbor2)
	local slope_L1 = slope(nodo.x, nodo.y, nodo_negthbor1.x, nodo_negthbor1.y)
	local slope_L2 = slope(nodo.x, nodo.y, nodo_neigthbor2.x, nodo_neigthbor2.y)

	return findAngle(slope_L1, slope_L2)
end

-- Generar un vecino alterando ligeramente las coordenadas de un nodo
function GenerateNeighbor(nodos)
	local nuevoNodos = {}
	for i, nodo in ipairs(nodos) do
		local nuevoX = nodo.x + (math.random() * 2 - 1) * 10 -- Mover en x ligeramente
		local nuevoY = nodo.y + (math.random() * 2 - 1) * 10 -- Mover en y ligeramente
		table.insert(nuevoNodos, Node:new(nuevoX, nuevoY, nodo.relations))
	end
	return nuevoNodos
end

function ccw(A, B, C)
	return (C.y - A.y) * (B.x - A.x) > (B.y - A.y) * (C.x - A.x)
end

function intersect(A, B, C, D)
	return ccw(A, C, D) ~= ccw(B, C, D) and ccw(A, B, C) ~= ccw(A, B, D)
end

-- function to find the slope of a straight line
function slope(x1, y1, x2, y2)
	if x2 - x1 ~= 0 then
		return (y2 - y1) / (x2 - x1)
	else
		return 999
	end
end

function findAngle(M1, M2)
	-- Store the tan value  of the angle
	local angle = math.abs((M2 - M1) / (1 + M1 * M2))

	-- Calculate tan inverse of the angle
	local ret = math.atan(angle)

	-- Convert the angle from  radian to degree
	local val = math.deg(ret)
	return val
end
