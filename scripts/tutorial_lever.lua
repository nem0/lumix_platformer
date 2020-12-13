local t = 0
blinking = false
function update(td)
    if blinking then
        t = t + td
        this.scale = 9 + math.cos(t * 5) 
    end
end