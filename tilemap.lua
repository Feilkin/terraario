local class = require "middleclass"
local Tilesheet = require "tilesheet"

local Tilemap = class("Tilemap")

function Tilemap:initialize(tilesheet_file, tile_size, map_size)
	self.tile_size = tile_size
	self.tilesheet = Tilesheet.new_from(tilesheet_file, tile_size)
	self.width_tiles = map_size[1]
	self.height_tiles = map_size[2]
	self.width_pixels = map_size[1] * tile_size
	self.height_pixels = map_size[2] * tile_size
	self.spritebatch = love.graphics.newSpriteBatch(self.tilesheet:getTexture(), map_size[1] * map_size[2])
	self.dirty = false
	self.data = {}
	self.tile_data = {}
	self.collision_data = {}
	--self:generate()
end

function tree(x, y, data, width_tiles)
	print("happy little tree")
	for i = 1, 10 do
		data[(y-i) * width_tiles + x + 1] = { tile = 195, tile_variant = love.math.random(0, 1) }
	end
end

--[[
function Tilemap:generate()
	-- fills with random data
	for y = 0, self.height_tiles do
		local offset = y * self.width_tiles + 1
		for x = 0, self.width_tiles do
			local height = (love.math.noise(x / 300.1) * 0.2 + 0.35) * self.height_tiles
			local tile

			if y > height then
				local height_stone = (love.math.noise(x / 280.3) * 0.3 + 0.4) * self.height_tiles
				if y > height_stone then
					tile = 130
				else
					tile = 0
				end
			elseif (y - math.floor(height) > -2) or (math.floor(height) - y < 1) then
				tile = 65
			end

			if (y == math.floor(height)) and (love.math.random(1, 10) == 5) then
				tree(x, y, self.data, self.width_tiles)
			end

			if x == 0 or x == self.width_tiles then
				tile = 130
			end

			if tile then
				-- random variant
				local var = love.math.random(0, 1)
				self.data[offset + x] = { tile = tile, tile_variant = var }
			end
		end
	end

	self.dirty = true
end
--]]

function Tilemap:generate(generator)
	local w, h = self.width_tiles, self.height_tiles
	local d = generator(w, h)
	-- flip the data
	print("flipping data")
	local data = {}
	for y = 0, h - 1 do
		for x = 0, w - 1 do
			data[y * w + x + 1] = d[(h-y) * w + x + 1]
		end
	end
	-- instanciate the tiles
	for i = 1, w*h do
		if data[i] then
			data[i] = { tile = data[i].base_id, tile_variant = love.math.random(0, #data[i].variants - 1) }
		end
	end

	self.data = data
	self.dirty = true
end

-- returns 4 bit bitmask for the tile
function Tilemap:bitmask(x, y)
	local t1 = self:getTile(x, y)
	if not t1 then return nil end

	local mask = 0
	local w = self.width_tiles - 1
	local h = self.height_tiles - 1

	if y > 0 and self:getTile(x, y - 1) then mask = mask + 1 end
	if x > 0 and self:getTile(x - 1, y) then mask = mask + 2 end
	if x < w and self:getTile(x + 1, y) then mask = mask + 4 end
	if y < h and self:getTile(x, y + 1) then mask = mask + 8 end

	return mask
end

function Tilemap:autotile()
	local tile_data = {}

	for y = 0, self.height_tiles - 1 do
		local offset = y * self.width_tiles + 1
		for x = 0, self.width_tiles - 1 do
			local tile = self.data[offset + x]
			if tile then
				local bitmask = self:bitmask(x, y)
				tile_data[offset + x] = tile.tile + tile.tile_variant * 16 + bitmask
			end
		end
	end

	self.tile_data = tile_data
end

function Tilemap:setTile(x, y, tile)
	self.data[y * self.width_tiles + x + 1] = tile
	self.dirty = true
end

function Tilemap:getTile(x, y)
	if x < 0 or y < 0 or x > self.width_tiles - 1 or y > self.height_tiles - 1 then
		return nil
	end
	return self.data[y * self.width_tiles + x + 1]
end

function Tilemap:updateSpritebatch()
	self:autotile()

	self.spritebatch:clear()
	local tw, th = self.tile_size, self.tile_size

	for y = 0, self.height_tiles - 1 do
		local offset = y * self.width_tiles + 1
		for x = 0, self.width_tiles - 1 do
			local tile = self.tile_data[offset + x]
			if tile then
				local quad = self.tilesheet:getQuad(tile)
				self.spritebatch:add(quad, x * tw, y * th)
			end
		end
	end
end

function Tilemap:updateCollisions()
	local removed = self.collision_data
	local bodies = {}

	local x, y = 0,0
	local w,h = self.width_tiles, self.height_tiles

	while y < h do
		x = 0
		while x < w do
			if self:getTile(x, y) then
				local body = { x, y, 1, 1 }
				x = x + 1

				-- expand right
				while self:getTile(x, y) do
					body[3] = body[3] + 1
					x = x + 1					
				end
				body = { body[1] * 8, body[2] * 8, body[3] * 8, body[4] * 8 }
				table.insert(bodies, body)
			else
				x = x + 1
			end
		end

		y = y + 1
	end

	-- expand down
	local expanded_bodies = bodies
	local expanded = true

	while expanded do
		local temp_bodies = {}
		expanded = false
		for _, body in ipairs(expanded_bodies) do
			if not body.used then
				for _, other in ipairs(expanded_bodies) do
					if body ~= other and not other.used then
						if body[1] == other[1] and
							body[3] == other[3] and
							body[2] + body[4] == other[2]
						then
							body[4] = body[4] + other[4]
							other.used = true
							expanded = true
						end
					end
				end

				table.insert(temp_bodies, body)
			end
		end

		for _, b in ipairs(temp_bodies) do
			b.used = nil
			b._map_body = true
		end
		expanded_bodies = temp_bodies
	end

	self.collision_data = expanded_bodies
	return expanded_bodies, removed
end

function Tilemap:draw()
	if self.dirty then
		self:updateSpritebatch()
		self.dirty = false
	end

	love.graphics.draw(self.spritebatch)
end

function Tilemap:getBodiesInCircle(x, y, radius)
	if not self.collision_data then return end

	local bodies = {}

	for _, b in ipairs(self.collision_data) do
		-- math is hard, for now, lets just return a AABB match lol
		if x - radius < b[1] + b[2] and x + radius > b[1] and
			y - radius < b[2] + b[4] and y + radius > b[2]
		then
			table.insert(bodies, b)
		end
	end

	return bodies
end

function Tilemap:getSortedEndpoints(x, y, range)
	-- get all bodies in range
	local bodies = self:getBodiesInCircle(x, y, range)
	if not bodies then return end
	-- endpoints of the bodies
	local endpoints = {}

	for _, b in ipairs(bodies) do
		local e1, e2, e3, e4 = { b[1], b[2] }, { b[1] + b[3], b[2] },
		                       { b[1], b[2] + b[4] }, { b[1] + b[3], b[2] + b[4] }
		if not endpoints[e1] then table.insert(endpoints, e1); endpoints[e1] = true end
		if not endpoints[e2] then table.insert(endpoints, e2); endpoints[e2] = true end
		if not endpoints[e3] then table.insert(endpoints, e3); endpoints[e3] = true end
		if not endpoints[e4] then table.insert(endpoints, e4); endpoints[e4] = true end
	end

	-- sort by angle
	table.sort(endpoints, function(a, b)
		return math.atan2(a[1] - x, a[2] - y) < math.atan2(b[1] - x, b[2] - y)
	end)

	return endpoints
end

function Tilemap:castVision(x, y, range)
	local triangles = {}
	-- ???

	local find_nearest = function(walls)
		if #walls == 0 then return end
		local nearest, nearest_d = nil, math.huge
		for _, w in ipairs(walls) do
			local x1, y1, x2, y2 = w[1][1], w[1][2], w[2][1], w[2][2]
			local d = math.abs((y2 - y1)*x + (x2 - x1)*y + x2*y1 - y2*x1)/math.sqrt((y2-y1)^2 + (x2-x1)^2)
			if d < nearest_d then
				nearest = w
				nearest_d = d
			end
		end

		return nearest
	end

	local open_walls = {}
	local closed_walls = {}
	local open_triange
	local nearest_wall
	for _, ep in ipairs(endpoints) do
		-- remove the walls that close at this endpoint
		local new_walls = {}
		for _, w in ipairs(open_walls) do
			if w[1] ~= ep and w[2] ~= ep then
				table.insert(new_walls, w)
			else
				closed_walls[w] = true
			end
		end
		-- add the walls that start at this endpoint
		for i, w in ipairs(walls) do
			if w[1] == ep or w[2] == ep and not closed_walls[w] then
				table.insert(new_walls, w)
			end
		end

		open_walls = new_walls
		local new_nearest = find_nearest(open_walls)
		if new_nearest ~= nearest then
			if open_triange then

			end

			open_triange = {x,y, nearest[1][1], nearest[1][2]}
		end
	end

	return triangles
end

return Tilemap