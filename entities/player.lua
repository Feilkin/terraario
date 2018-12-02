local class = require "middleclass"
local machine = require "statemachine"

local Body = require "body"
local Spritesheet = require "spritesheet"

local Player = class("Player")

local player_animations = {
	idle = {
		head = { "player_head_1" },
		torso = { "player_torso_1" },
		legs = { "player_legs_1" },
	},
	falling = {
		head = { "player_head_1" },
		torso = { "player_torso_1_falling" },
		legs = { "player_legs_1_falling" },
	},
	walking = {
		head = { "player_head_1" },
		torso = { "player_torso_1" },
		legs = { "player_legs_1", "player_legs_1_falling" },
	},
	jumping = {
		head = { "player_head_1" },
		torso = { "player_torso_1" },
		legs = { "player_legs_1" },
	},
	mining = {
		head = { "player_head_1" },
		torso = { "player_torso_1", "player_torso_1_mining" },
		legs = { "player_legs_1" },
	},
}

function Player:initialize()
	self.body = Body({200,0}, {13, 22}, 120)
	self.body.acceleration.y = 400

	self.frame = 0
	self.frame_buffer = 0
	self.animation = machine.create({
		initial = "idle",
		events = {
			{ name = "idle", from = "*",                              to = "idle" },
			{ name = "fall", from = { "idle", "walking", "jumping" }, to = "falling" },
			{ name = "walk", from = { "idle" },                       to = "walking" },
			{ name = "jump", from = { "idle", "walking" },            to = "jumping" },
			{ name = "mine", from = { "idle", "walking", "jumping" }, to = "mining"  },
		},
		callbacks = {
			onstatechange = function(s, event, from, to)
				self.frame = 0
				self.frame_buffer = 0
			end,
		}
	})

	local player_sprite_data = love.filesystem.load("res/players.lua")
	self.sheet = Spritesheet("res/players.png", player_sprite_data())
	self.batch = self.sheet:newSpritebatch(16, "dynamic")

	self.flip_x = false

	self.toolbelt = { "pickaxe" }
	self.active_slot = 1
end

function Player:respawn()
	self.body:teleport(200, 0)
end

function Player:update(dt)
	self.frame_buffer = self.frame_buffer + dt
	if self.frame_buffer >= 1/12 then
		self.frame_buffer = 0
		self.frame = self.frame + 1
	end
end

function Player:getHeadQuad()
	local anim = self.animation
	local anims = player_animations
	local frame = self.frame
	local part = anims[anim.current].head
	local current_quad_name = part[frame % #part + 1]
	return self.sheet:getQuad(current_quad_name)
end

function Player:getTorsoQuad()
	local anim = self.animation
	local anims = player_animations
	local frame = self.frame
	local part = anims[anim.current].torso
	local current_quad_name = part[frame % #part + 1]
	return self.sheet:getQuad(current_quad_name)
end

function Player:getLegsQuad()
	local anim = self.animation
	local anims = player_animations
	local frame = self.frame
	local part = anims[anim.current].legs
	local current_quad_name = part[frame % #part + 1]
	return self.sheet:getQuad(current_quad_name)
end

function Player:draw()
	self.batch:clear()
	self.batch:add(self:getLegsQuad(), -1, 10)
	self.batch:add(self:getTorsoQuad(), -1, 4)
	self.batch:add(self:getHeadQuad(), -1, -4)

	local x, y = self.body:getPos()
	love.graphics.draw(self.batch, math.floor(x - (self.flip_x and -14 or 0)+.5),
		math.floor(y+.5), 0, self.flip_x and -1 or 1, 1)

	--[[
	do -- draw debug hitboxes
		love.graphics.setColor(0.1, 0.1, 0.1, 0.5)
		love.graphics.rectangle("line", x, y, self.body.width, self.body.height)

		local y_bot = y + self.body.height
		local y_grid = math.ceil((y_bot)/8)*8-8 - self.body.height
		love.graphics.setColor(1.0, 1.0, 1.0, 0.7)
		love.graphics.rectangle("line", x + (self.flip_x and -1 or 1), y_grid, self.body.width, self.body.height)
	end
	--]]
end

return Player