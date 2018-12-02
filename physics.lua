local class = require "middleclass"
local bump = require "bump"

local physics = {}
local World = class("World")

function ignore_self(body)
	return function(item)
		if body == item then
			return nil
		end
		return true
	end
end

function World:initialize()
	self.bodies = {}
	self.map_data = {}
	self._b = bump.newWorld(64)
end

function World:setMapCollisionData(new_data, removed)
	self.map_data = {}
	if removed then
		for _, b in ipairs(removed) do
			self._b:remove(b)
		end
	end

	for _, b in ipairs(new_data) do
		self.map_data[b] = true
		self._b:add(b, b[1], b[2], b[3], b[4])
	end
end

function World:addBody(body)
	table.insert(self.bodies, body)
	self._b:add(body, body.position.x, body.position.y, body.width, body.height)
end

function World:update(dt)
	for _, body in ipairs(self.bodies) do
		-- move
		if not body.immovable then
			if body._update then
				self._b:update(body, body.position.x, body.position.y)
				body._update = nil
			end

			body.on_ground = false
			body.falling = false
			body.speed = body.speed + body.acceleration * dt
			local new_position = body.position + body.speed * dt
			local ax, ay, cols, len = self._b:move(body, new_position.x, new_position.y)
			body.position.x, body.position.y = ax, ay

			for i=1,len do
				local col = cols[i]
				if self.map_data[col.other] then 
					if col.normal.y < 0 then
						body.on_ground = true
						body.speed.y = 0
					elseif col.normal.y > 0 then
						body.speed.y = 0
					else -- collision in x axis
						-- check if we can step up
						local w, h = body.width, body.height
						local offset_x = -2 * col.normal.x
						local y_bot = body.position.y + h
						local y_grid = math.ceil((y_bot)/8) * 8 - 8
						local y =  y_grid - h
						local x = body.position.x + offset_x
						local cols, len = self._b:queryRect(x, y, w, h, ignore_self(body))

						if len == 0 then
							-- instead of moving the body straight away, make it jump a little
							body.speed.y = -50
							--self._b:update(body, x, y)
							--body.position.x, body.position.y = x, y
						end
					end
				end
			end
		end
	end
end

physics.World = World

return physics