local t = 0

function update(dt)
    t = t + dt
    
    if t > 3600 then
        this.gui_text.text = "way too much"
    else 
        this.gui_text.text = string.format("%d:%02d", math.floor(t / 60), math.floor(t) % 60)
    end
end