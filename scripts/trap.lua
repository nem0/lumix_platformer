trap = true
active = true;
closed_entity = {}
Editor.setPropertyType(this, "closed_entity", Editor.ENTITY_PROPERTY)

function triggerTrap()
    active = false
    this.model_instance.enabled = false
    closed_entity.model_instance.enabled = true
end