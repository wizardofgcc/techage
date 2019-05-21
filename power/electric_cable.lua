--[[

	TechAge
	=======

	Copyright (C) 2019 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information
	
	TA3/TA4 Cable for electrical power distribution

]]--

-- for lazy programmers
local S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local P = minetest.string_to_pos
local M = minetest.get_meta

-- Load support for intllib.
local MP = minetest.get_modpath("techage")
local I,_ = dofile(MP.."/intllib.lua")

local Cable = tubelib2.Tube:new({
	dirs_to_check = {1,2,3,4,5,6},
	max_tube_length = 1000, 
	show_infotext = false,
	tube_type = "electric_cable",
	primary_node_names = {"techage:electric_cableS", "techage:electric_cableA"},
	secondary_node_names = {},
	after_place_tube = function(pos, param2, tube_type, num_tubes)
		-- Don't replace "hidden" cable
		if M(pos):get_string("techage_hidden_nodename") == "" then
			minetest.swap_node(pos, {name = "techage:electric_cable"..tube_type, param2 = param2 % 32})
		end
		M(pos):set_int("tl2_param2", param2)
	end,
})

techage.ElectricCable = Cable


-- Overridden method of tubelib2!
function Cable:get_primary_node_param2(pos, dir) 
	return techage.get_primary_node_param2(pos, dir)
end

function Cable:is_primary_node(pos, dir)
	return techage.is_primary_node(pos, dir)
end


minetest.register_node("techage:electric_cableS", {
	description = I("TA Electric Cable"),
	tiles = {
		-- up, down, right, left, back, front
		"techage_electric_cable.png",
		"techage_electric_cable.png",
		"techage_electric_cable.png",
		"techage_electric_cable.png",
		"techage_electric_cable_end.png",
		"techage_electric_cable_end.png",
	},
	
	after_place_node = function(pos, placer, itemstack, pointed_thing)
		if not Cable:after_place_tube(pos, placer, pointed_thing) then
			minetest.remove_node(pos)
			return true
		end
		return false
	end,
	
	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		if oldmetadata and oldmetadata.fields and oldmetadata.fields.tl2_param2 then
			oldnode.param2 = oldmetadata.fields.tl2_param2
			Cable:after_dig_tube(pos, oldnode)
		end
	end,
	
	paramtype2 = "facedir", -- important!
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-3/32, -3/32, -4/8,  3/32, 3/32, 4/8},
		},
	},
	on_rotate = screwdriver.disallow, -- important!
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 3, techage_trowel = 1},
	sounds = default.node_sound_defaults(),
})

minetest.register_node("techage:electric_cableA", {
	description = I("TA Electric Cable"),
	tiles = {
		-- up, down, right, left, back, front
		"techage_electric_cable.png",
		"techage_electric_cable_end.png",
		"techage_electric_cable.png",
		"techage_electric_cable.png",
		"techage_electric_cable.png",
		"techage_electric_cable_end.png",
	},
	
	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		if oldmetadata and oldmetadata.fields and oldmetadata.fields.tl2_param2 then
			oldnode.param2 = oldmetadata.fields.tl2_param2
			Cable:after_dig_tube(pos, oldnode)
		end
	end,
	
	paramtype2 = "facedir", -- important!
	drawtype = "nodebox",
	node_box = {
		type = "fixed",
		fixed = {
			{-3/32, -4/8, -3/32,  3/32, 3/32,  3/32},
			{-3/32, -3/32, -4/8,  3/32, 3/32, -3/32},
		},
	},
	on_rotate = screwdriver.disallow, -- important!
	paramtype = "light",
	sunlight_propagates = true,
	is_ground_content = false,
	groups = {snappy = 2, choppy = 2, oddly_breakable_by_hand = 3, 
			techage_trowel = 1, not_in_creative_inventory = 1},
	sounds = default.node_sound_defaults(),
	drop = "techage:electric_cableS",
})

Cable:register_on_tube_update(function(node, pos, out_dir, peer_pos, peer_in_dir)
	minetest.registered_nodes[node.name].after_tube_update(node, pos, out_dir, peer_pos, peer_in_dir)
end)

minetest.register_craft({
	output = "techage:electric_cableS 6",
	recipe = {
		{"basic_materials:plastic_sheet", "", ""},
		{"", "default:copper_ingot", ""},
		{"", "", "basic_materials:plastic_sheet"},
	},
})

