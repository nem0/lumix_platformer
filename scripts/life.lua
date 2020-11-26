life = true
picked = false
local a = 0
function update(dt)
    a = a + dt
    this.rotation = { 0, math.sin(a), 0, math.cos(a)}
end