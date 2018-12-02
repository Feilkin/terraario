local map_width, map_height, data
local tiles = require "res.tiles"

function set_tile(x, y, t)
	data[y * map_width + x + 1] = t
end

function get_tile(x, y)
	return data[y * map_width + x + 1]
end

function find_top(x)
	for y = 0, map_height do
		if not data[y * map_width + x + 1] then
			return y
		end
	end
end

--- makes a happy little tree
function tree(space)

end

--- adds happy little trees to the world
function spawn_trees()
	local space = find_space()
	while space do
		tree(space)
		space = find_space()
	end
end

--- fills the world with stone
--- this sets the foundation for the world,
--- as all is build on top/inside/below the stone layer
function spawn_stone()
	print("Filling the world with stone")
	for x = 0, map_width - 1 do
		local height = math.floor(love.math.noise(x/map_width) * map_height * 0.5)
		for y = 0, height do
			set_tile(x, y, tiles.stone)
		end
	end
end

function spawn_dirt()
	print("Adding a layer of dirt")
	local pepper = (love.math.random() * 0.5 + 0.5)
	for x = 0, map_width - 1 do
		local height = math.floor(love.math.noise(x/map_width + pepper) * 20) + 5
		local top = find_top(x)
		for y = 0, height do
			set_tile(x, top + y, tiles.dirt)
		end
	end
end

function spawn_grass()
	print("Adding grass to dirt")
	for x = 0, map_width - 1 do
		local top = find_top(x) - 1
		local top_tile = get_tile(x, top)
		if top_tile and top_tile == tiles.dirt then
			set_tile(x, top, tiles.grass)
		end
	end
end

function generate(width, height)
	map_width = width
	map_height = height
	data = {}
	spawn_stone()
	spawn_dirt()
	spawn_grass()
	--spawn_trees()

	return data
end

return generate