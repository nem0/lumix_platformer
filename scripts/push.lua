function onControllerHit(obj)
    local a = obj.rigid_actor
    a:applyForce({10, 0, 0})
end
