local active = false
lever = true
interact_msg = {}
subject = {}
Editor.setPropertyType(this, "interact_msg", Editor.ENTITY_PROPERTY)
Editor.setPropertyType(this, "subject", Editor.ENTITY_PROPERTY)

function entered()
    interact_msg.gui_rect.enabled = true
end

function exited()
    interact_msg.gui_rect.enabled = false
end

function interact()
    active = not active
    if active then
        subject.lua_script[0].speed = 0.7
    else
        subject.lua_script[0].speed = 0
    end
end