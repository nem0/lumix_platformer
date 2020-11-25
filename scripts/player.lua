local left = 0
local right = 0
local slow = 0
local speed_input_idx = -1
local jump_input_idx = -1
local dead_input_idx = -1
local dir = 1
local jump = 0
local is_collision_down = false
dead = false
local invincible = 0
local interact_obj = nil
fall_trigger = {}
start_pos = {}
respawn_msg = {}
local checkpoint = {}

Editor.setPropertyType(this, "start_pos", Editor.ENTITY_PROPERTY)
Editor.setPropertyType(this, "fall_trigger", Editor.ENTITY_PROPERTY)
Editor.setPropertyType(this, "respawn_msg", Editor.ENTITY_PROPERTY)


function onInputEvent(event)
    if event.type == LumixAPI.INPUT_EVENT_BUTTON then
		if event.device.type == LumixAPI.INPUT_DEVICE_KEYBOARD then
			if event.key_id == LumixAPI.INPUT_KEYCODE_SPACE then
                if event.down and is_collision_down then
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
			if dead and event.key_id == string.byte("R") and event.down then
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
                    interact_obj.lua_script[0].interact()
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

function start()
    checkpoint = start_pos;

    this.parent.lua_script[0].onTrigger = function(e, touch_lost)
        if e.lua_script then
            if e.lua_script[0].checkpoint then
                checkpoint = e
            end
            if e.lua_script[0].lever then
                if touch_lost then
                    if interact_obj then
                        interact_obj.lua_script[0].exited()
                    end
                    interact_obj = nil
                else
                    interact_obj = e
                    e.lua_script[0].entered()
                end
            end
        end
        
        if invincible > 0 then return end
        if e._entity == fall_trigger._entity then
            dead = true
            respawn_msg.gui_rect.enabled = true
        elseif e.lua_script[0].trap and e.lua_script[0].active then
            
            e.lua_script[0].triggerTrap()
            dead = true
            respawn_msg.gui_rect.enabled = true
        elseif e.lua_script[0].spikes == true then
            dead = true
            respawn_msg.gui_rect.enabled = true
        end
    end
end

function clamp(x, a, b)
    if x < a then return a end
    if x > b then return b end
    return x
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
        if jump > 0 then 
            this.parent.physical_controller:move({0, 30 * (jump * 2 - 1) * td, 0})
        else
            this.parent.physical_controller:move({0, td * -9.8, 0})
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