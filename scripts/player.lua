local left = 0
local right = 0
local slow = 0
local speed_input_idx = -1
local jump_input_idx = -1
local dead_input_idx = -1
local dir = 1
local jump = 0
 is_collision_down = false
local checkpoint = {}
local invincible = 0
local interact_obj = nil
local num_lives = 3
local vspeed = 0
dead = false

fall_trigger = Lumix.Entity.NULL
start_pos = Lumix.Entity.NULL
respawn_msg = Lumix.Entity.NULL
coin_counter = Lumix.Entity.NULL
life_icon_0 = Lumix.Entity.NULL
life_icon_1 = Lumix.Entity.NULL
life_icon_2 = Lumix.Entity.NULL
game_over_msg = Lumix.Entity.NULL
coins = 0
coin_sound = Lumix.Resource:newEmpty("clip")
life_sound = Lumix.Resource:newEmpty("clip")
death_sound = Lumix.Resource:newEmpty("clip")
jump_sound = Lumix.Resource:newEmpty("clip")

function playSound(audio_module, entity, sound)
	local path = sound.path
	audio_module:play(entity, path, false)
end

function onInputEvent(event)
	if event.type == "button" then
		if event.device.type == "keyboard" then
			if event.key_id == LumixAPI.INPUT_KEYCODE_SPACE or event.key_id == string.byte("W") then
				if event.down and is_collision_down then
					local audio_module = this.world:getModule("audio")
					playSound(audio_module, this, jump_sound)
					jump = 1
				end
			end
			if event.key_id == LumixAPI.INPUT_KEYCODE_SHIFT then
				if event.down then
					slow = 1
				else
					slow = 0
				end
			end
			if dead and num_lives > 0 and event.key_id == string.byte("R") and event.down then
				this.parent.position = checkpoint.position
				respawn_msg.gui_rect.enabled = false
				dead = false
				invincible = 0.5
			end
			if event.key_id == string.byte("D") then
				if event.down then
					right = 1
				else
					right = 0
				end
			end
			if event.key_id == string.byte("E") then
				if event.down and interact_obj ~= nil then
					interact_obj.lua_script[1].interact()
				end
			end
			if event.key_id == string.byte("A") then
				if event.down then
					left = 1
				else
					left = 0
				end
			end
		end		
	end
end

function upadte_lives_icons()
	life_icon_0.gui_rect.enabled = num_lives > 0
	life_icon_1.gui_rect.enabled = num_lives > 1
	life_icon_2.gui_rect.enabled = num_lives > 2
end

function kill()
	dead = true
	local audio_module = this.world:getModule("audio")
	playSound(audio_module, this, death_sound)
	num_lives = num_lives - 1
	upadte_lives_icons()
	if num_lives > 0 then
		respawn_msg.gui_rect.enabled = true
	else
		game_over_msg.gui_rect.enabled = true
	end
end

function start()
	checkpoint = start_pos;

	this.parent.lua_script[1].onTrigger = function(e, touch_lost)
		if e.lua_script then
			if e.lua_script[1].life and num_lives < 3 then
				if not e.lua_script[1].picked  then
					local audio_module = this.world:getModule("audio")
					playSound(audio_module, this, life_sound)
					num_lives = num_lives + 1
					upadte_lives_icons()
					e.model_instance.enabled = false
					e.lua_script[1].picked = true
				end
			end
			if e.lua_script[1].coin then
				if not e.lua_script[1].picked then
					local audio_module = this.world:getModule("audio")
					playSound(audio_module, this, coin_sound)
					coins = coins + 1
					coin_counter.gui_text.text = tostring(coins)
					e.model_instance.enabled = false
					e.lua_script[1].picked = true
				end
			end
			if e.lua_script[1].checkpoint then
				checkpoint = e
			end
			if e.lua_script[1].lever then
				if touch_lost then
					if interact_obj then
						interact_obj.lua_script[1].exited()
					end
					interact_obj = nil
				else
					interact_obj = e
					e.lua_script[1].entered()
				end
			end
		end
		
		if invincible > 0 or dead then return end
		if e._entity == fall_trigger._entity then
			kill()
		elseif e.lua_script[1].trap and e.lua_script[1].active then
			e.lua_script[1].triggerTrap()
			kill()
		elseif e.lua_script[1].spikes == true then
			kill()
		end
	end
end

function clamp(x, a, b)
	if x < a then return a end
	if x > b then return b end
	return x
end

function restart()
	this.parent.position = start_pos.position
end

function update(td)
	local p = this.parent.position
	this.parent.position = {p[1], p[2], -4}

	if speed_input_idx == -1 then 
		speed_input_idx = this.animator:getInputIndex("speed")
		jump_input_idx = this.animator:getInputIndex("jump")
		dead_input_idx = this.animator:getInputIndex("dead")
	end

	local speed = math.max(right, left) * 10
	if slow > 0 then
		speed = speed * 0.25
	end
	this.animator:setFloatInput(speed_input_idx, speed)
	this.animator:setBoolInput(jump_input_idx, jump > 0)
	this.animator:setBoolInput(dead_input_idx, dead)

	jump = jump - td / 0.508

	invincible = invincible - td

	if not dead then
		is_collision_down = this.parent.physical_controller:isCollisionDown()
		if is_collision_down then
			vspeed = 0
		end
		vspeed = vspeed - 9.8 * td
		vspeed = math.max(vspeed, -5.0)

		if jump > 0 then 
			this.parent.physical_controller:move({0, 30 * (jump * 2 - 1) * td, 0})
		else
			this.parent.physical_controller:move({0, 0.6 * td * vspeed * 9.8, 0})
		end
		if right > 0 then
			this.parent.physical_controller:move({-1 * td * speed, 0, 0})
		end
		if left > 0 then
			this.parent.physical_controller:move({1 * td * speed, 0, 0})
		end
		dir = 0
		if right > 0 then
			dir = 1
			this.rotation = {0, -0.707, 0, 0.707}
		end
		if left > 0 then
			dir = -1
			this.rotation = {0, 0.707, 0, 0.707}
		end
	else
		speed = 0
	end

	this.animator:setFloatInput(speed_input_idx, speed)
end
