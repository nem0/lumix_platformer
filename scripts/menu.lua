restart_button = {}
player = {}

Editor.setPropertyType(this, "restart_button", Editor.ENTITY_PROPERTY)
Editor.setPropertyType(this, "player", Editor.ENTITY_PROPERTY)

function onInputEvent(event)
    if event.type == "button" then
		if event.device.type == "keyboard" and event.down then
            if event.key_id == string.byte("M") then
                if this.gui_rect.enabled  then
                    this.gui_rect.enabled = false
                    player.lua_script[0].pause = false
                    this.world:getModule("gui"):getSystem():enableCursor(false)
                else
                    this.gui_rect.enabled = true
                    player.lua_script[0].pause = true
                    this.world:getModule("gui"):getSystem():enableCursor(true)
                end
            end
        end
    end
end

function start()
    this.gui_rect.enabled = false
    this.world:getModule("gui"):getSystem():enableCursor(false)
    restart_button.lua_script[0].onButtonClicked = function()
        player.lua_script[0].restart()
        this.gui_rect.enabled = false
        player.lua_script[0].pause = false
        this.world:getModule("gui"):getSystem():enableCursor(false)
    end
end
