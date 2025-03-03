--[[

	TechAge
	=======

	Copyright (C) 2020-2021 Joachim Stolberg

	AGPL v3
	See LICENSE.txt for more information

	TA4 Move Controller

]]--

-- for lazy programmers
local M = minetest.get_meta
local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = minetest.string_to_pos
local S = techage.S

local MP = minetest.get_modpath("techage")
local fly  = dofile(MP .. "/basis/fly_lib.lua")
local mark = dofile(MP .. "/basis/mark_lib.lua")

local MAX_DIST = 100
local MAX_BLOCKS = 16

local WRENCH_MENU = {
	{
		type = "dropdown",
		choices = "0.5,1,2,4,6,8",
		name = "max_speed",
		label = S("Maximum Speed"),
		tooltip = S("Maximum speed for moving blocks"),
		default = "8",
	},
	{
		type = "number",
		name = "handoverB",
		label = S("Handover to B"),
		tooltip = S("Number of the next movecontroller"),
		default = "",
	},
	{
		type = "number",
		name = "handoverA",
		label = S("Handover to A"),
		tooltip = S("Number of the previous movecontroller"),
		default = "",
	},
	{
		type = "float",
		name = "height",
		label = S("Move block height"),
		tooltip = S("Value in the range of 0.0 to 1.0"),
		default = "1.0",
	},
	{
		type = "float",
		name = "offset",
		label = S("Object offset"),
		tooltip = S("Y-offset for non-player objects like vehicles (-0.5 to 0.5)"),
		default = "0.0",
	},
}

local function formspec(nvm, meta)
	local status = meta:get_string("status")
	local path = meta:contains("path") and meta:get_string("path") or "0,3,0"
	return "size[8,5]" ..
		default.gui_bg ..
		default.gui_bg_img ..
		default.gui_slots ..
		"box[0,-0.1;7.2,0.5;#c6e8ff]" ..
		"label[0.2,-0.1;" .. minetest.colorize( "#000000", S("TA4 Move Controller")) .. "]" ..
		techage.wrench_image(7.4, -0.05) ..
		"button[0.1,0.8;3.8,1;record;" .. S("Record") .. "]" ..
		"button[4.1,0.8;3.8,1;done;" .. S("Done") .. "]" ..
		"field[0.4,2.5;3.8,1;path;" .. S("Move distance (A to B)") .. ";" .. path .. "]" ..
		"button[4.1,2.2;3.8,1;store;" .. S("Store") .. "]" ..
		"button_exit[0.1,3.3;3.8,1;moveAB;" .. S("Move A-B") .. "]" ..
		"button_exit[4.1,3.3;3.8,1;moveBA;" .. S("Move B-A") .. "]" ..
		"label[0.3,4.3;" .. status .. "]"
end

minetest.register_node("techage:ta4_movecontroller", {
	description = S("TA4 Move Controller"),
	tiles = {
		-- up, down, right, left, back, front
		"techage_filling_ta4.png^techage_frame_ta4_top.png",
		"techage_filling_ta4.png^techage_frame_ta4_top.png",
		"techage_filling_ta4.png^techage_frame_ta4.png^techage_appl_movecontroller.png",
	},

	after_place_node = function(pos, placer, itemstack)
		local meta = M(pos)
		techage.logic.after_place_node(pos, placer, "techage:ta4_movecontroller", S("TA4 Move Controller"))
		techage.logic.infotext(meta, S("TA4 Move Controller"))
		local nvm = techage.get_nvm(pos)
		meta:set_string("formspec", formspec(nvm, meta))
	end,

	on_receive_fields = function(pos, formname, fields, player)
		if minetest.is_protected(pos, player:get_player_name()) then
			return
		end

		local meta = M(pos)
		local nvm = techage.get_nvm(pos)

		if fields.record then
			nvm.lpos1 = {}
			nvm.lpos2 = {}
			nvm.moveBA = false
			nvm.running = nil
			meta:set_string("status", S("Recording..."))
			local name = player:get_player_name()
			minetest.chat_send_player(name, S("Click on all blocks that shall be moved"))
			mark.start(name, MAX_BLOCKS)
			meta:set_string("formspec", formspec(nvm, meta))
		elseif fields.done then
			local name = player:get_player_name()
			local pos_list = mark.get_poslist(name)
			if fly.to_vector(fields.path or "", MAX_DIST) then
				meta:set_string("path", fields.path)
			end
			local text = #pos_list.." "..S("block positions are stored.")
			nvm.running = nil
			meta:set_string("status", text)
			nvm.lpos1 = pos_list
			mark.unmark_all(name)
			mark.stop(name)
			meta:set_string("formspec", formspec(nvm, meta))
		elseif fields.store then
			if fly.to_vector(fields.path or "", MAX_DIST) then
				meta:set_string("path", fields.path)
				meta:set_string("status", S("Stored"))
			else
				meta:set_string("status", S("Error: Invalid distance !!"))
			end
			meta:set_string("formspec", formspec(nvm, meta))
			local name = player:get_player_name()
			mark.stop(name)
			nvm.moveBA = false
			nvm.running = nil
		elseif fields.moveAB then
			meta:set_string("status", "")
			if fly.move_to_other_pos(pos, false) then
				nvm.moveBA = true
				nvm.running = true
				meta:set_string("formspec", formspec(nvm, meta))
				local name = player:get_player_name()
				mark.stop(name)
			end
			meta:set_string("formspec", formspec(nvm, meta))
		elseif fields.moveBA then
			meta:set_string("status", "")
			if fly.move_to_other_pos(pos, true) then
				nvm.moveBA = false
				nvm.running = true
				meta:set_string("formspec", formspec(nvm, meta))
				local name = player:get_player_name()
				mark.stop(name)
			end
			meta:set_string("formspec", formspec(nvm, meta))
		end
	end,

	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		local name = digger:get_player_name()
		mark.unmark_all(name)
		mark.stop(name)
		techage.remove_node(pos, oldnode, oldmetadata)
	end,

	ta4_formspec = WRENCH_MENU,
	paramtype2 = "facedir",
	groups = {choppy=2, cracky=2, crumbly=2},
	is_ground_content = false,
	sounds = default.node_sound_wood_defaults(),
})

local INFO = [[Commands: 'state', 'a2b', 'b2a', 'move']]

techage.register_node({"techage:ta4_movecontroller"}, {
	on_recv_message = function(pos, src, topic, payload)
		local nvm = techage.get_nvm(pos)
		if topic == "info" then
			return INFO
		elseif topic == "state" then
			return nvm.running and "running" or "stopped"
		elseif topic == "a2b" then
			nvm.moveBA = true
			nvm.running = true
			return fly.move_to_other_pos(pos, false)
		elseif topic == "b2a" then
			nvm.moveBA = false
			nvm.running = true
			return fly.move_to_other_pos(pos, true)
		elseif topic == "move" then
			nvm.moveBA = nvm.moveBA == false
			nvm.running = true
			return fly.move_to_other_pos(pos, nvm.moveBA == false)
		end
		return false
	end,
})

minetest.register_craft({
	output = "techage:ta4_movecontroller",
	recipe = {
		{"default:steel_ingot", "dye:blue", "default:steel_ingot"},
		{"default:mese_crystal_fragment", "techage:ta4_wlanchip", "default:mese_crystal_fragment"},
		{"group:wood", "basic_materials:gear_steel", "group:wood"},
	},
})
