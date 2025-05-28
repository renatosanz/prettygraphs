Point = class:class_new(object)
function Point:new(x, y, args)
	self:object("Point" .. args.number or math.random(0, 10000))
	self.x, self.y = x, y
	self.size = 6
	self.color = an.colors.green

	self:timer()

	self:collider("Point", "dynamic", "circle", self.size)
	self:collider_set_restitution(0)
	self:collider_set_friction(1)
	self:collider_set_damping(5)

	self.number = args.number
	self.relations = {}
end

function Point:update(dt)
	self:collider_update_transform()
	self:collider_draw(front, self.color[0], nil, 1)
	self:collider_draw(front, self.color[0], nil)

	if self.relations then
		for _, nn in ipairs(self.relations) do
			game:line(self.x, self.y, nn.x, nn.y, an.colors.white[0], nil, 1)
		end
	end
	front:draw_text(self.number, inter_font, self.x + 1, self.y + 1, self.angle, 1, 1, 1, 1, an.colors.black[0])
end
