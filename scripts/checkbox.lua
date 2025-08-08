active_img = Lumix.Entity.NULL
inactive_img = Lumix.Entity.NULL
checked = false
music_entity = Lumix.Entity.NULL

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
