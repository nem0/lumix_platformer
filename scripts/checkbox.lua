active_img = {}
inactive_img = {}
checked = false
music_entity = {}
Editor.setPropertyType(this, "active_img", Editor.ENTITY_PROPERTY)
Editor.setPropertyType(this, "inactive_img", Editor.ENTITY_PROPERTY)
Editor.setPropertyType(this, "music_entity", Editor.ENTITY_PROPERTY)

function start()
    checked = false
    onButtonClicked()
end

function onButtonClicked()
    checked = not checked
    active_img.gui_image.enabled = checked
    inactive_img.gui_image.enabled = not checked

    if checked then
        music_entity.ambient_sound:resume()
    else
        music_entity.ambient_sound:pause()
    end

end