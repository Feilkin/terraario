local class = require "middleclass"

local Vector = class("Vector")

function Vector:initialize(x, y)
	self.x = x
	self.y = y
end

function Vector.__add(a, b)
	return Vector(a.x + b.x, a.y + b.y)
end

function Vector.__sub(a, b)
	return Vector(a.x - b.x, a.y - b.y)
end

function Vector.__mul(a, b)
	if type(a) == "table" then
		if type(b) == "number" then
			return Vector(a.x * b, a.y * b)
		else
			error("Can only multiply vector by number")
		end
	elseif type(a == "number") then
		return Vector(b.x * a, b.y * a)
	end
end

return Vector