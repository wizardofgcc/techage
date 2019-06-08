--[[

	TechAge
	=======

	Copyright (C) 2019 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information
	
	TA3 Coal Power Station Boiler Base

]]--

-- for lazy programmers
local S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local P = minetest.string_to_pos
local M = minetest.get_meta

-- Load support for intllib.
local MP = minetest.get_modpath("techage")
local I,_ = dofile(MP.."/intllib.lua")

local Pipe = techage.SteamPipe

minetest.register_node("techage:coalboiler_base", {
	description = I("TA3 Boiler Base"),
	tiles = {"techage_coal_boiler_mesh_base.png"},
	drawtype = "mesh",
	mesh = "techage_boiler_large.obj",
	selection_box = {
		type = "fixed",
		fixed = {-13/32, -16/32, -13/32, 13/32, 16/32, 13/32},
	},

	on_construct = tubelib2.init_mem,
	
	drop = "",
	paramtype2 = "facedir",
	on_rotate = screwdriver.disallow,
	groups = {cracky=2},
	is_ground_content = false,
	sounds = default.node_sound_stone_defaults(),
})

techage.power.register_node({"techage:coalboiler_base"}, {
	conn_sides = {"F"},
	power_network = Pipe,
})
	
-- for logical communication
techage.register_node({"techage:coalboiler_base"}, {
	on_transfer = function(pos, in_dir, topic, payload)
		if topic == "start" then
			return true
		elseif topic == "stop" then
			return true
		end
	end
})

minetest.register_craft({
	output = "techage:coalboiler_base",
	recipe = {
		{"default:stone", "", "default:stone"},
		{"techage:iron_ingot", "", "techage:iron_ingot"},
		{"default:stone", "default:stone", "default:stone"},
	},
})

techage.register_help_page(I("TA3 Boiler Base"), 
I([[Part of the Coal Power Station.
Has to be placed on top of the 
TA3 Coal Power Station Firebox
and filled with water.
(see TA3 Coal Power Station)]]), "techage:coalboiler_base")
