restart_button = Lumix.Entity.NULL
player = Lumix.Entity.NULL

function onInputEvent(event)
    if event.type == "button" then
		if event.device.type == "keyboard" and event.down then
            if event.key_id == string.byte("M") then
                if this.gui_rect.enabled  then
                    this.gui_rect.enabled = false
                    player.lua_script[1].pause = false
                    this.world:getModule("gui"):getSystem():enableCursor(false)
                else
                    this.gui_rect.enabled = true
                    player.lua_script[1].pause = true
                    this.world:getModule("gui"):getSystem():enableCursor(true)
                end
            end
        end
    end
end

function start()
    this.gui_rect.enabled = false
    this.world:getModule("gui"):getSystem():enableCursor(false)
    restart_button.lua_script[1].onButtonClicked = function()
        player.lua_script[1].restart()
        this.gui_rect.enabled = false
        player.lua_script[1].pause = false
        this.world:getModule("gui"):getSystem():enableCursor(false)
    end
end
