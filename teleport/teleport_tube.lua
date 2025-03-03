--[[

	TechAge
	=======

	Copyright (C) 2017-2022 Joachim Stolberg

	AGPL v3
	See LICENSE.txt for more information

	TA5 teleport tube

]]--

-- for lazy programmers
local P2S = function(pos) if pos then return minetest.pos_to_string(pos) end end
local S2P = minetest.string_to_pos
local M = minetest.get_meta
local S = techage.S

local Tube = techage.Tube
local teleport = techage.teleport
local Cable = techage.ElectricCable
local power = networks.power

local STANDBY_TICKS = 4
local COUNTDOWN_TICKS = 4
local CYCLE_TIME = 2
local PWR_NEEDED = 12
local EX_POINTS = 60
local MAX_DIST = 200
local DESCRIPTION = S("TA5 Teleport Block Items")

local function formspec(self, pos, nvm)
	local title = DESCRIPTION .. " " .. M(pos):get_string("tele_status")
	return "size[8,2]"..
		"box[0,-0.1;7.8,0.5;#c6e8ff]" ..
		"label[0.5,-0.1;" .. minetest.colorize( "#000000", title) .. "]" ..
		"image_button[3.5,1;1,1;" .. self:get_state_button_image(nvm) .. ";state_button;]" ..
		"tooltip[3.5,1;1,1;" .. self:get_state_tooltip(nvm) .. "]"
end

local function can_start(pos, nvm, state)
	return teleport.is_connected(pos)
end

local State = techage.NodeStates:new({
	node_name_passive = "techage:ta5_tele_tube",
	infotext_name = DESCRIPTION,
	cycle_time = CYCLE_TIME,
	standby_ticks = STANDBY_TICKS,
	countdown_ticks = COUNTDOWN_TICKS,
	formspec_func = formspec,
	can_start = can_start,
})

local function consume_power(pos, nvm)
	if techage.needs_power(nvm) then
		local taken = power.consume_power(pos, Cable, nil, PWR_NEEDED)
		if techage.is_running(nvm) then
			if taken < PWR_NEEDED then
				State:nopower(pos, nvm)
			else
				return true  -- keep running
			end
		elseif taken == PWR_NEEDED then
			State:start(pos, nvm)
		end
	end
end

minetest.register_node("techage:ta5_tele_tube", {
	description = DESCRIPTION,
	tiles = {
		-- up, down, right, left, back, front
		"techage_filling_ta4.png^techage_frame_ta5_top.png^techage_appl_tele_tube.png",
		"techage_filling_ta4.png^techage_frame_ta5_top.png",
		"techage_filling_ta4.png^techage_frame_ta5.png^techage_appl_teleport.png",
		"techage_filling_ta4.png^techage_frame_ta5.png^techage_appl_hole_tube.png",
		"techage_filling_ta4.png^techage_frame_ta5.png^techage_appl_teleport.png",
		"techage_filling_ta4.png^techage_frame_ta5.png^techage_appl_teleport.png",
	},

	after_place_node = function(pos, placer)
		local meta = M(pos)
		local nvm = techage.get_nvm(pos)
		local node = minetest.get_node(pos)
		local tube_dir = techage.side_to_outdir("L", node.param2)
		local number = techage.add_node(pos, "techage:ta5_tele_tube")
		State:node_init(pos, nvm, number)
		meta:set_int("tube_dir", tube_dir)
		meta:set_string("owner", placer:get_player_name())
		Tube:after_place_node(pos, {tube_dir})
		Cable:after_place_node(pos)
		teleport.prepare_pairing(pos, "ta5_tele_tube")
	end,

	on_receive_fields = function(pos, formname, fields, player)
		if minetest.is_protected(pos, player:get_player_name()) then
			return
		end
		if teleport.is_connected(pos) then
			local nvm = techage.get_nvm(pos)
			State:state_button_event(pos, nvm, fields)
			M(pos):set_string("formspec", formspec(State, pos, nvm))
		else
			teleport.after_formspec(pos, player, fields, MAX_DIST, EX_POINTS)
		end
	end,

	on_rightclick = function(pos, clicker, listname)
		if teleport.is_connected(pos) then
			local nvm = techage.get_nvm(pos)
			M(pos):set_string("formspec", formspec(State, pos, nvm))
		else
			M(pos):set_string("formspec", teleport.formspec(pos))
		end
	end,

	on_timer = function(pos, elapsed)
		local nvm = techage.get_nvm(pos)
		consume_power(pos, nvm)
		-- the state has to be triggered by on_push_item
		State:idle(pos, nvm)
		return State:is_active(nvm)
	end,

	after_dig_node = function(pos, oldnode, oldmetadata, digger)
		techage.remove_node(pos, oldnode, oldmetadata)
		teleport.stop_pairing(pos, oldmetadata)
		Tube:after_dig_node(pos)
		Cable:after_dig_node(pos)
		techage.del_mem(pos)
	end,

	paramtype2 = "facedir", -- important!
	on_rotate = screwdriver.disallow, -- important!
	is_ground_content = false,
	groups = {choppy=2, cracky=2, crumbly=2},
	sounds = default.node_sound_wood_defaults(),
})

minetest.register_craft({
	output = "techage:ta5_tele_tube",
	recipe = {
		{"techage:aluminum", "dye:red", "techage:aluminum"},
		{"techage:ta4_tubeS", "techage:usmium_nuggets", "techage:ta5_aichip"},
		{"techage:ta4_carbon_fiber", "", "techage:ta4_carbon_fiber"},
	},
})

techage.register_node({"techage:ta5_tele_tube"}, {
	on_push_item = function(pos, in_dir, stack)
		local nvm = techage.get_nvm(pos)
		if techage.is_operational(nvm) then
			local rmt_pos = teleport.get_remote_pos(pos)
			if rmt_pos then
				local rmt_nvm = techage.get_nvm(rmt_pos)
				if techage.is_operational(rmt_nvm) then
					local tube_dir = M(rmt_pos):get_int("tube_dir")
					if techage.push_items(rmt_pos, tube_dir, stack) then
						State:keep_running(pos, nvm, COUNTDOWN_TICKS)
						State:keep_running(rmt_pos, rmt_nvm, COUNTDOWN_TICKS)
						return true
					end
				else
					State:blocked(pos, nvm, S("Remote block error"))
				end
			end
		end
		return false
	end,
	is_pusher = true,  -- is a pulling/pushing node

	on_recv_message = function(pos, src, topic, payload)
		return State:on_receive_message(pos, topic, payload)
	end,
})

power.register_nodes({"techage:ta5_tele_tube"}, Cable, "con", {"B", "R", "F", "D", "U"})
Tube:set_valid_sides("techage:ta5_tele_tube", {"L"})
