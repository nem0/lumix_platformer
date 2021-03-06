from = {}
to = {}
speed = 1
Editor.setPropertyType(this, "from", Editor.ENTITY_PROPERTY)
Editor.setPropertyType(this, "to", Editor.ENTITY_PROPERTY)
local t = 0

local function mix(a, b, t)
    local it = 1 - t
    return { 
        a[1] * it + b[1] * t,
        a[2] * it + b[2] * t,
        a[3] * it + b[3] * t
    }
end

function update(dt)
    t = (t + dt * speed) % 2

    local f = t
    if f > 1 then 
        f = 2 - f
    end

    this.position = mix(from.position, to.position, f)
end