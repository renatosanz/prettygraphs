require("anchor")
require("globals")

chargeFolder("objects")
chargeFolder("views")

function init()
	love.math.setRandomSeed(os.time())

	an:anchor_start("prettygraphs", Gw, Gh, Sx, Sy, "tidal_waver")

	an:font(inter_font, "InterVariable.ttf", 8)

	an:input_bind_all()

	back = object():layer()
	game = object():layer()
	front = object():layer()
	effects = object():layer()

	function an:draw_layers()
		back:layer_draw_commands()
		game:layer_draw_commands()
		front:layer_draw_commands()
		effects:layer_draw_commands()

		self:layer_draw_to_canvas("main", function()
			back:layer_draw()
			game:layer_draw()
			front:layer_draw()
			effects:layer_draw()
		end)

		self:layer_draw("main", 0, 0, 0, self.sx, self.sy)
	end

	an:physics_world_set_physics_tags({ "Point" })
	--an:physics_world_set_gravity(0, 500)

	-- load rooms
	an:load_room(SandBox, "sandbox_room")

	-- set initial room
	an:set_current_room("sandbox_room")
end
