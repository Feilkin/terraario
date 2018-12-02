local class = require "middleclass"

local Tilesheet = class("Tilesheet")

function Tilesheet.static.new_from(filename, tile_size)
	local t = Tilesheet()
	local image = love.graphics.newImage(filename)

	t:setImage(image)
	t.tile_size = tile_size

	t:prepareQuads()

	return t
end

function Tilesheet:setImage(image)
	self.image = image
end

function Tilesheet:prepareQuads()
	local tw, th = self.tile_size, self.tile_size
	local sw, sh = self.image:getDimensions()
	local quads = {}
	local i = 0

	for y = 0, sh, th do
		for x = 0, sw, tw do
			local quad = love.graphics.newQuad(x, y, tw, th, sw, sh)
			quads[i] = quad
			i = i + 1
		end
	end

	self.quads = quads
end

function Tilesheet:getTexture()
	return self.image
end

function Tilesheet:getQuad(tile)
	return self.quads[tile]
end

return Tilesheet