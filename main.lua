local suit = require "suit"

local Tilemap = require "tilemap"
local physics = require "physics"
local Body = require "body"
local Player = require "entities.player"
local Spritesheet = require "spritesheet"

local map
local collision_data = {}
local world = {}

local player

local background_image

local item_icons_spritesheet
local item_icons_batch

local shadow_map_canvas
local shadow_shader
local light_sources = {}

local camera = { x = 0, y = 0, zoom = 2 }
function camera:getOffset()
	local gw, gh = love.graphics.getDimensions()
	local ox, oy = gw/2, gh/2
	ox, oy = math.floor(ox / self.zoom), math.floor(oy / self.zoom)
	local px, py = player.body:getPos()
	local c_x, c_y = math.floor(-(px + camera.x) + ox) + 0.5, math.floor(-(py + camera.y) + oy) + 0.5
	return c_x, c_y, self.zoom
end

function ui_toolbelt()
	item_icons_batch:clear()
	for i = 1, 10 do
		if player.active_slot == i then
			love.graphics.setColor(251/256, 242/256, 54/256, 1)
		else
			love.graphics.setColor(105/256, 106/256, 106/256, 1)
		end
		love.graphics.rectangle("line", 10 + (i-1) * 36, 10, 32, 32)
		if player.toolbelt[i] then
			item_icons_batch:add(item_icons_spritesheet:getQuad(player.toolbelt[i]), 10 + (i-1) * 36, 10)
		end
	end
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(item_icons_batch)
end


function camera:screenToWorld(x, y)
	local gw, gh = love.graphics.getDimensions()
	local px, py = player.body:getPos()
	return (x-gw/2)/self.zoom + self.x+px, (y-gh/2)/self.zoom + self.y + py
	--return -(gw/2)/self.zoom+(self.x+px-x)*self.zoom, -(gh/2)/self.zoom+(self.y+py-y)
end

function love.load()
	love.graphics.setDefaultFilter("nearest", "nearest", 4)

	local item_icons_data = love.filesystem.load("res/item_icons.lua")
	item_icons_spritesheet = Spritesheet("res/item_icons.png", item_icons_data())
	item_icons_batch = item_icons_spritesheet:newSpritebatch(16, "dynamic")

	map = Tilemap("res/tiles.png", 8, {1024, 128})
	generator = love.filesystem.load("worldgen/world_1.lua")
	map:generate(generator())
	collision_data = map:updateCollisions()

	player = Player()

	love.graphics.setBackgroundColor(0.0, 0.0, 0.0, 1.0)
	background_image = love.graphics.newImage("res/world_1_overworld_background.png")

	world = physics.World()
	world:setMapCollisionData(collision_data)
	world:addBody(player.body)

	shadow_map_canvas = love.graphics.newCanvas(1280, 720)
	shadow_shader = require "shader"
end

function love.keypressed(key, code)
	if key == "escape" then
		love.event.quit()
	end

	if key == "q" then
		camera.zoom = camera.zoom - 1
	elseif key == "e" then
		camera.zoom = camera.zoom + 1
	end

	if camera.zoom > 4 then camera.zoom = 4 end
	if camera.zoom < 1 then camera.zoom = 1 end
end

function love.update(dt)
	if love.keyboard.isDown("left") then
		camera.x = camera.x - 4
	elseif love.keyboard.isDown("right") then
		camera.x = camera.x + 4
	end

	if love.keyboard.isDown("up") then
		camera.y = camera.y - 4
	elseif love.keyboard.isDown("down") then
		camera.y = camera.y + 4
	end

	if love.keyboard.isDown("home") then
		camera.x, camera.y = 0,0
	end

	if love.keyboard.isDown("a") then
		player.body.speed.x = -75
		player.flip_x = true
		player.animation:walk()
	elseif love.keyboard.isDown("d") then
		player.body.speed.x = 75
		player.flip_x = false
		player.animation:walk()
	else
		player.body.speed.x = 0
		player.animation:idle()
	end

	if love.keyboard.isDown("w") and player.body.on_ground then
		player.body.speed.y = -200
	end

	--if love.keyboard.isDown("q") then
	--	camera.zoom = camera.zoom + 0.1
	--elseif love.keyboard.isDown("e") then
	--	camera.zoom = camera.zoom - 0.1
	--end

	if camera.zoom < 0.3 then camera.zoom = 0.3 end
	world:update(dt)
	player:update(dt)

	if not player.body.on_ground and player.body.speed.y > 20 then
		player.animation:fall()
	elseif player.animation.current == "falling" and player.body.on_ground then
		player.animation:idle()
	end

	if love.mouse.isDown(1) then
		local mx, my = love.mouse.getPosition()
		local wx, wy = camera:screenToWorld(mx, my)

		-- check if it is in mining range
		local px, py = player.body:getPos()
		local ptx, pty = math.floor(px / 8), math.floor(py / 8) + 1
		local tx, ty = math.floor(wx / 8), math.floor(wy / 8)
		if math.sqrt((tx - ptx)^2 + (ty - pty)^2 ) < 8 then
			local tile = map:getTile(tx, ty)
			if tile and (tile.tile ~= 130) then
				map:setTile(tx, ty, nil)
				collision_data, removed = map:updateCollisions()
				world:setMapCollisionData(collision_data, removed)
				player.animation:mine()
			end
		end
	end

	if love.mouse.isDown(2) then
		local mx, my = love.mouse.getPosition()
		local wx, wy = camera:screenToWorld(mx, my)

		table.insert(light_sources, { wx, wy, 200, 10 })
	end

	if player.body.position.y > 10000 then
		player:respawn()
	end
end

function map_filter(item)
	if item._map_body then
		return true
	end
end

function testStencil()
-- experimental raycasting vision
	do
		local x, y = player.body:getPos()
		x, y = x + 7, y + 4
		local range = 400
		--local endpoints = map:getSortedEndpoints(x, y, range)
		local angles = {}
		--for _, e in ipairs(endpoints) do
		--	table.insert(angles, math.atan2(y - e[2], x - e[1]))
		--end
		for i=0,128 do
			table.insert(angles, math.pi*2/128*i)
		end

		local triangles = {}
		local last_point
		for _, a in ipairs(angles) do
			local x2, y2 = x + math.cos(a) * range, y + math.sin(a) * range
			local itemInfo, len = world._b:querySegmentWithCoords(x, y, x2, y2, map_filter)
			local x3, y3 = x2 + math.cos(a) * 8, y2 + math.sin(a) * 8
			if len > 0 then
				x3, y3 = itemInfo[1].x1 + math.cos(a) * 8, itemInfo[1].y1 + math.sin(a) * 8
			end

			if last_point then
				table.insert(triangles, {x, y, last_point[1], last_point[2], x3, y3 })
			end
			last_point = { x3, y3 }
		end

		for _, t in ipairs(triangles) do
			assert(love.math.isConvex(t))
			love.graphics.polygon("fill", t)
		end
	end
end

function set_camera()
	local c_x, c_y, c_z = camera:getOffset()
	love.graphics.scale(c_z, c_z)
	love.graphics.translate(c_x, c_y)
end

function update_shadow_map()
	-- draw shadow map
	love.graphics.setCanvas(shadow_map_canvas)
	love.graphics.clear(1,1,1,1)
	love.graphics.setColor(0, 0, 0, 1)
	love.graphics.push()
	set_camera()
	map:draw()
	--player:draw()
	love.graphics.pop()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setCanvas()
	shadow_shader:send("shadow_map", shadow_map_canvas)
end

function update_light_sources()
	if #light_sources == 0 then
		shadow_shader:send("light_source_count", 0)
		return
	end

	local c_x, c_y, c_z = camera:getOffset()
	local sc_lights = {}

	-- transform to screen space coords
	for _, l in ipairs(light_sources) do
		table.insert(sc_lights, {
			l[1] + c_x,
			l[2] + c_y,
			l[3],
			l[4],
			})
	end

	shadow_shader:send("light_sources", unpack(sc_lights))
	shadow_shader:send("light_source_count", #sc_lights)
end

function love.draw()
	update_light_sources()
	update_shadow_map()

	-- draw game world
	love.graphics.push()
	set_camera()
	love.graphics.setColor(0.2, 0.2, 0.2, 0.5)
	love.graphics.rectangle("fill", 0, 0, map.width_pixels, map.height_pixels)
	map:draw()
	love.graphics.setColor(1, 1, 1, 1)

	--love.graphics.stencil(testStencil, "replace", 1)
	--love.graphics.setStencilTest("greater", 0)
	love.graphics.setColor(95/256, 205/256, 228/256, 1)
	love.graphics.setShader(shadow_shader)
	love.graphics.rectangle("fill", 0, 0, map.width_pixels, map.height_pixels)
	love.graphics.setColor(1, 1, 1, 1)
	--map:draw()

	-- debug draw collision data
	--love.graphics.setColor(1, 1, 1, 0.4)
	--for i, body in ipairs(collision_data) do
	--	love.graphics.rectangle("line", body[1], body[2], body[3], body[4])
	--end
	love.graphics.setColor(1, 1, 1, 1)
	player:draw()
	love.graphics.setStencilTest()

	love.graphics.setShader()
	love.graphics.pop()

	love.graphics.setColor(1, 1, 1, 1)
	-- draw UI
	love.graphics.scale(2, 2)
	ui_toolbelt()
end