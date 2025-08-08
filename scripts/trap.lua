trap = true
active = true;
closed_entity = Lumix.Entity.NULL

function triggerTrap()
    active = false
    this.model_instance.enabled = false
    closed_entity.model_instance.enabled = true
end
