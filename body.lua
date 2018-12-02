local class = require "middleclass"
local Vector = require "vector"

--- Represents a physics body (AABB with acceleration, speed, and mass)
local Body = class("Body")

function Body:initialize(pos, size, mass)
	self.position = Vector(pos[1], pos[2])
	self.width = size[1]
	self.height = size[2]
	self.mass = mass
	self.speed = Vector(0, 0)
	self.acceleration = Vector(0, 0)
	self.on_ground = false
	self.immovable = false
end

function Body:teleport(x, y)
	self.position.x = x
	self.position.y = y
	self.speed.x = 0
	self.speed.y = 0
	self._update = true
end

function Body:getPos()
	return self.position.x, self.position.y
end

function Body:getAABB(offset_x, offset_y)
	local x, y = self.position.x + offset_x or 0, self.position.y + offset_y or 0
	local w, h = self.width, self.height
	return x, y, x + w, y + h
end

function Body:debugDraw()
	love.graphics.rectangle("line",
		self.position.x, self.position.y,
		self.width, self.height)
end

return Body