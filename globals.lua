-- global vars
grid_size = 16
grid_x = 16 --rows
grid_y = 16 --cols
Gw, Gh = grid_x * grid_size, grid_y * grid_size --window size
Sx, Sy = 2, 2
--scale
-- fonts
monogram_font = "monogram"
monogram_italics_font = "monogram_italics"
inter_font = "inter"
icons_font = "zicons"

BG_color_light = { 203 / 255, 219 / 255, 252 / 255 }
BG_color_dark = { 0 / 255, 0 / 255, 0 / 255 }

QuartCircle = math.pi / 2
FullCircle = 2 * math.pi

level_list = {}
lights_up = false

--controls
-- ui controls

select_button = nil
back_button = nil

-- block types
block_types = {
	{
		label = "Cube",
		obj_name = "CubeBlock",
		data = {},
	},
	{
		label = "Ramp",
		obj_name = "RampBlock",
		data = {
			direction = 0,
		},
	},
	{
		label = "Jump",
		obj_name = "JumpBlock",
		data = {
			impulse_jump = 10,
			angle = 40,
		},
	},
	{
		label = "Player",
		obj_name = "Player",
		data = {},
	},
}

-- game controls

Controls_p1 = {
	name = "p1",
	left = "a",
	right = "d",
	up = "w",
	down = "s",
}

Controls_p2 = {
	name = "p2",
	left = "left",
	right = "right",
	up = "up",
	down = "down",
}

-- global functions
function chargeFolder(path)
	for file in io.popen('ls "' .. path .. '"'):lines() do
		-- Verifica si el archivo es un archivo Lua (.lua)
		if file:match("%.lua$") then
			-- Requiere el archivo
			require(path .. "." .. file:gsub("%.lua$", ""))
		end
	end
end

function chargeLevels(level_list, path)
	for file in io.popen('ls "' .. path .. '"'):lines() do
		-- print(path .. "/" .. file)
		-- Verifica si el archivo es un archivo Lua (.lua)
		if file:match("%.lua$") then
			local chunk = loadfile(path .. "/" .. file)
			if chunk then
				local data = chunk()
				table.insert(level_list, data)
			end
		end
	end
end

function LoadImage(path)
	local info = love.filesystem.getInfo(path)
	if info then
		return love.graphics.newImage(path)
	end
end

function CirclePoints(n, r)
	local ang = 360 / n
	local p = {}
	for i = 1, n, 1 do
		table.insert(p, math.cos(n * ang) * r)
		table.insert(p, math.sin(n * ang) * r)
	end
	return p
end

function CopyContact(event)
	local ret = { normal = {}, points = {} }
	ret.normal.x, ret.normal.y = event.contact:getNormal()
	ret.points.x, ret.points.y = event.contact:getPositions()
	return ret
end

function Resize(s)
	love.window.setMode(s * Gw, s * Gh)
	Sx, Sy = s, s
end

function UUID()
	local fn = function(x)
		local r = math.random(16) - 1
		r = (x == "x") and (r + 1) or (r % 4) + 9
		return ("0123456789abcdef"):sub(r, r)
	end
	return (("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"):gsub("[xy]", fn))
end

function toggleFullscreen()
	fullscreen, fstype = love.window.getFullscreen()
	if fullscreen then
		love.window.setFullscreen(false)
		return "fullscreen"
	else
		love.window.setFullscreen(true)
		return "window"
	end
end

function closeGame()
	love.event.quit(0)
end

function setGridSize()
	grid_size = Gh / grid_x
end

function getDistanceToPlayer(obj)
	local dx, dy = obj.x - Player.x, obj.y - Player.y
	local distance_squared = dx * dx + dy * dy
	local radius_squared = Player.light_r * Player.light_r
	return distance_squared, radius_squared
end

-- prints key and values of and object (recursivetly)
function deepPrinter(obj, level)
	local actual_level = level or 0
	local indent = string.rep("  ", actual_level) -- Crear sangrado según el nivel
	if actual_level > 3 then
		return
	end
	for key, value in pairs(obj) do
		if type(value) == "table" then
			print(indent .. tostring(key) .. ":")
			deepPrinter(value, actual_level + 1)
		else
			print(indent .. tostring(key) .. ":", value)
		end
	end
end

-- load assets
function loadButtonIcons()
	an:image({
		"key_a",
		"key_s",
		"key_d",
		"key_e",
		"btn_x",
		"btn_y",
		"btn_a",
		"btn_b",
		"btn_square",
		"btn_circle",
		"btn_cross",
		"btn_triangle",
		"key_arrow_left",
		"key_arrow_down",
		"key_arrow_right",
		"key_arrow_up",
	}, "assets/img/keys_w12.png", 12, 12) -- assets 12px width
	an:image({ "key_w" }, "assets/img/keys_w13.png", 13, 12, 0) -- assets 13px width
	an:image({ "key_tab" }, "assets/img/key_tab.png", 20, 12, 0) -- assets 13px width
end

-- serialize

function serialize(file, o)
	if type(o) == "number" then
		file:write(o)
	elseif type(o) == "string" then
		file:write(string.format("%q", o))
	elseif type(o) == "boolean" then
		file:write(tostring(o))
	elseif type(o) == "table" then
		file:write("{\n")
		-- matrix style
		local n, f = math.modf(math.sqrt(#o))
		if f == 0.0 then
			local i = 1
			for k, v in pairs(o) do
				if type(k) ~= "number" then
					file:write("  ", k, " = ")
				end
				serialize(file, v)
				file:write(",")
				if i % n == 0 then
					file:write("\n")
				end
				i = i + 1
			end
		else
			for k, v in pairs(o) do
				if type(k) ~= "number" then
					file:write("  ", k, " = ")
				end
				serialize(file, v)
			end
			file:write(",\n")
		end
		file:write("}\n")
	else
		error("cannot serialize a " .. type(o))
	end
end
