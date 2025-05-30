--[[
MIT License

Copyright (c) 2023 a13X-B

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local g = love.graphics
local max_lights = 32 * 4

local shadowmap_shader = g.newShader([[#pragma language glsl3
flat varying int light_id;
uniform vec2 lights_positions[128];
#ifdef VERTEX
vec4 position( mat4 transform_projection, vec4 vertex_position ){
	light_id = gl_InstanceID;
	vec2 light_pos = lights_positions[gl_InstanceID];
	if (gl_VertexID%2 != 0) {
		vertex_position.xy += normalize(vertex_position.xy-light_pos)*99999999999.;
	}
	vertex_position.z = float(gl_InstanceID)/128.;
	return transform_projection * vertex_position;
}
#endif
#ifdef PIXEL
void effect(){
	vec2 shadow_id[4];
	shadow_id[0] = vec2(0.);
	shadow_id[1] = vec2(0.);
	shadow_id[2] = vec2(0.);
	shadow_id[3] = vec2(0.);
	shadow_id[light_id/32][(light_id/16)&1] = float(1<<(light_id%16)) / 65535.;
	love_Canvases[0] = vec4(shadow_id[0], 0., 1.);
	love_Canvases[1] = vec4(shadow_id[1], 0., 1.);
	love_Canvases[2] = vec4(shadow_id[2], 0., 1.);
	love_Canvases[3] = vec4(shadow_id[3], 0., 1.);
}
#endif
]])

local light_shader = g.newShader([[#pragma language glsl3
varying vec2 w_p;
#ifdef VERTEX
vec4 position( mat4 transform_projection, vec4 vertex_position ){
	vec4 pos = vertex_position;
	w_p = VertexTexCoord.xy;
	pos.xy *= love_ScreenSize.xy;
	return ProjectionMatrix * pos;
}
#endif
#ifdef PIXEL
uniform ArrayImage shadowmap;
uniform vec2 lights_positions[128];
uniform int lights_colors[128];
uniform float lights_radii[128];
uniform int count;
vec4 effect(vec4 col, Image tex, vec2 uv, vec2 sc){
	vec2 shadow[4];
	for (int i = 0; i < 4; i++){
		shadow[i] = Texel(shadowmap, vec3(sc/love_ScreenSize.xy,float(i))).xy;
	}
	vec3 color = vec3(0.);
	for (int i = 0; i<count; i++) {
		if((int(shadow[i/32][(i/16)&1]*65535.) & (1<<(i%16))) != 0) continue;
		ivec3 rgb = 0xff&(ivec3(lights_colors[i])>>ivec3(0,8,16));
		vec3 col = vec3(rgb)/255.;
		float att = sqrt(clamp(length(w_p-lights_positions[i])/lights_radii[i],0.,1.));
		col = mix(col,vec3(0.),att);
		color+=col;
	}
	return vec4(color, 1.);
}
#endif
]])

local shadowmap_api = {
  __index = {
    render = function(self, occlusion_mesh, lights)
      if occlusion_mesh.edge_count < 1 then return end
      g.push("all")
      g.setMeshCullMode("none")
      g.setDepthMode("less", true)
      g.setBlendMode("add", "premultiplied")
      g.setCanvas(self.map)
      g.clear()
      shadowmap_shader:send("lights_positions", lights.pos)
      g.setShader(shadowmap_shader)
      occlusion_mesh.mesh:setDrawRange(1, occlusion_mesh.edge_count * 6)
      g.drawInstanced(occlusion_mesh.mesh, lights.count)
      g.pop()
    end
  }
}

local function newShadowMap(width, height)
  local l = max_lights / 32
  local array = g.newCanvas(width, height, l, { type = "array", format = "rg16" })
  local map = {
    depthstencil = g.newCanvas(w, h, { format = "depth16", readable = false })
  }
  for i = 1, l do
    map[i] = { array, layer = i }
  end
  return setmetatable({ texture = array, map = map }, shadowmap_api)
end

local tmp_transform = love.math.newTransform()

local occlusion_mesh_api = {
  __index = {
    getEdge = function(self, i)
      local n = (i - 1) * 6
      local ax, ay = self.mesh:getVertex(n + 2)
      local bx, by = self.mesh:getVertex(n + 3)
      return ax, ay, bx, by
    end,
    setEdge = function(self, id, ax, ay, bx, by)
      local n = (id - 1) * 6
      self.mesh:setVertex(n + 1, ax, ay)
      self.mesh:setVertex(n + 2, ax, ay)
      self.mesh:setVertex(n + 3, bx, by)
      self.mesh:setVertex(n + 4, bx, by)
      self.mesh:setVertex(n + 5, bx, by)
      self.mesh:setVertex(n + 6, ax, ay)
    end,
    addEdge = function(self, ax, ay, bx, by)
      local n = self.edge_count + 1
      self.edge_count = n
      self:setEdge(n, ax, ay, bx, by)
    end,
    addCircle = function(self, x, y, r, seg)
      seg = math.max(3, seg or 13)
      local a = math.pi * 2 / seg
      local c, s = math.cos(a), math.sin(a)
      local ax, ay
      local bx, by = r, 0
      for i = 1, seg - 1 do
        ax, ay = bx, by
        bx, by = ax * c - ay * s, ax * s + ay * c
        self:addEdge(x + ax, y + ay, x + bx, y + by)
      end
      self:addEdge(x + bx, y + by, x + r, y)
    end,
    addRectangle = function(self, x, y, w, h)
      local x1, y1 = x, y
      local x2, y2 = x + w, y
      local x3, y3 = x + w, y + h
      local x4, y4 = x, y + h
      self:addEdge(x1, y1, x2, y2)
      self:addEdge(x2, y2, x3, y3)
      self:addEdge(x3, y3, x4, y4)
      self:addEdge(x4, y4, x1, y1)
    end,
    addPolygon,
    addLine,
    addOcclusionMesh = function(self, mesh)
      for i = 1, mesh.edge_count do
        self:addEdge(mesh:getEdge(i))
      end
    end,
    applyTransform = function(self, t_x, y, angle, sx, sy, ox, oy, kx, ky)
      if type(t_x) == "number" then
        t_x = tmp_transform:setTransformation(t_x, y, angle, sx, sy, ox, oy, kx, ky)
      else
        assert(t_x.type, "argument is not a number or Transform")
        assert(t_x:type() == "Transform", "argument is not a number or Transform")
      end
      for i = 1, self.edge_count do
        local ax, ay, bx, by = self:getEdge(i)
        ax, ay = t_x:transformPoint(ax, ay)
        bx, by = t_x:transformPoint(bx, by)
        self:setEdge(i, ax, ay, bx, by)
      end
    end,
  }
}
local occlusion_mesh_vf = { { "VertexPosition", "float", 2 } }
local function newOcclusionMesh(max_edges)
  local mesh = g.newMesh(occlusion_mesh_vf, (max_edges or 10000) * 6, "triangles", "dynamic")
  return setmetatable({ mesh = mesh, edge_count = 0 }, occlusion_mesh_api)
end

local fs_mesh = g.newMesh(occlusion_mesh_vf, { { 0, 0 }, { 2, 0 }, { 0, 2 } }, "fan", "static")
local world_pos = g.newMesh({ { "VertexTexCoord", "float", 2 } }, 3, "fan", "dynamic")
fs_mesh:attachAttribute("VertexTexCoord", world_pos)

local light_transform = function(x, y, r, g, b, a)
  r, g = tmp_transform:transformPoint(r, g)
  return r, g, b, a
end

local light_array_api = {
  __index = {
    push = function(self, x, y, radius, r, g, b)
      self.pos:setPixel(self.count, 0, x, y, 0, 0)
      self.rad:setPixel(self.count, 0, radius, 0, 0, 0)
      self.col:setPixel(self.count, 0, r, g, b, 0)
      self.count = self.count + 1
    end,
    set = function(self, id, x, y, radius, r, g, b)
      self.pos:setPixel(id - 1, 0, x, y, 0, 0)
      self.rad:setPixel(id - 1, 0, radius, 0, 0, 0)
      self.col:setPixel(id - 1, 0, r, g, b, 0)
    end,
    get = function(self, id)
      local x, y = self.pos:getPixel(id - 1, 0)
      local rad = self.rad:getPixel(id - 1, 0)
      local r, g, b = self.col:getPixel(id - 1, 0)
      return x, y, rad, r, g, b
    end,
    pop = function(self)
      local id = self.count - 1
      self.count = id
      local x, y = self.pos:getPixel(id, 0)
      local rad = self.rad:getPixel(id, 0)
      local r, g, b = self.col:getPixel(id, 0)
      return x, y, rad, r, g, b
    end,
    applyTransform = function(self, t_x, y, angle, sx, sy, ox, oy, kx, ky)
      if type(t_x) == "number" then
        tmp_transform:setTransformation(t_x, y, angle, sx, sy, ox, oy, kx, ky)
      else
        assert(t_x.type, "argument is not a number or Transform")
        assert(t_x:type() == "Transform", "argument is not a number or Transform")
        tmp_transform = t_x:clone()
      end
      self.pos:mapPixel(light_transform, 0, 0, self.count, 1)
    end,
    draw = function(self, sm)
      g.push("all")
      light_shader:send("count", self.count)
      light_shader:send("lights_positions", self.pos)
      light_shader:send("lights_radii", self.rad)
      light_shader:send("lights_colors", self.col)
      light_shader:send("shadowmap", sm.texture)
      g.setShader(light_shader)
      local w, h = g.getDimensions()
      world_pos:setVertex(1, g.inverseTransformPoint(0, 0))
      world_pos:setVertex(2, g.inverseTransformPoint(2 * w, 0))
      world_pos:setVertex(3, g.inverseTransformPoint(0, 2 * h))
      g.draw(fs_mesh)
      g.pop()
    end,
  }
}

local function newLightsArray()
  local pos = love.image.newImageData(max_lights, 1, "rg32f")
  local col = love.image.newImageData(max_lights, 1, "rgba8")
  local rad = love.image.newImageData(max_lights, 1, "r32f")
  return setmetatable({ pos = pos, col = col, rad = rad, count = 0 }, light_array_api)
end

return {
  newShadowMap = newShadowMap,
  newOcclusionMesh = newOcclusionMesh,
  newLightsArray = newLightsArray,
}
