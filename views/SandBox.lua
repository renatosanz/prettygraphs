SandBox = class:class_new(object)
function SandBox:new(args)
	self:object("SandBox", args)
	self.nodes = self:ChargeNodes("./test/nodes3.txt")
	an:input_bind("toggle_menu", { "key:tab" })
	an:input_bind("quit", { "key:q" })

	self:add(Simulator(100, 0.95, 2000, self.nodes)) --instance a Simulator
end

function SandBox:update(dt)
	back:rectangle(an.w / 2, an.h / 2, an.w, an.h, 0, 0, an.colors.bg[0]) -- bg color

	if an:is_pressed("quit") then
		love.event.quit(0)
	end

	-- menu controls
	if an:is_pressed("toggle_menu") then
	end
end

function SandBox:ChargeNodes(file)
	local f = io.open(file, "rb")
	if f then
		f:close()
	end
	local lines = {}
	for line in io.lines(file) do
		lines[#lines + 1] = line
	end

	local nodes = {}

	for k, v in ipairs(lines) do
		if string.find(v, "node") then
			print(v)
			local nums = {}
			for num in string.gmatch(v, "%d+") do
				table.insert(nums, tonumber(num))
				print(num)
			end
			local p_aux = Point(nums[2], nums[3], { number = nums[1] })
			self:add(p_aux)
			table.insert(nodes, p_aux)
		elseif string.find(v, "rel") then
			print(v)
			local nums = {}
			for num in string.gmatch(v, "%d+") do
				table.insert(nums, tonumber(num))
				print(num)
			end
			if nums[1] ~= nums[2] then
				print(nodes[nums[1]].number)
				table.insert(nodes[nums[1]].relations, nodes[nums[2]])
				print(#nodes[nums[1]].relations)
			end
		end
	end

	for k, v in ipairs(nodes) do
		print(k, v.number)
	end

	return nodes
end
