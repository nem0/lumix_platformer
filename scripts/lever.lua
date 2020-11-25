local active = false
show_msg = true
lever = true
interact_msg = {}
subject = {}
Editor.setPropertyType(this, "interact_msg", Editor.ENTITY_PROPERTY)
Editor.setPropertyType(this, "subject", Editor.ENTITY_PROPERTY)

function entered()
    if show_msg then
        interact_msg.gui_rect.enabled = true
    end
end

function exited()
    interact_msg.gui_rect.enabled = false
end

function interact()
    active = not active
    if active then
        subject.lua_script[0].speed = 0.7
        this.rotation = {0, 0, 0.25, 0.866}
    else
        show_msg = false
        interact_msg.gui_rect.enabled = false
        subject.lua_script[0].speed = 0
        this.rotation = {0, 0, 0, 1}
    end
end