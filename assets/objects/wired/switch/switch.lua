function init(virtual)
  if virtual then return end
  
  entity.setInteractive(true)
  if storage.state == nil then
    output(entity.configParameter("defaultSwitchState", false))
  else
    output(storage.state)
  end
end

function onInteraction(args)
  output(not storage.state)
end

function output(state)
  storage.state = state
  if state then
    entity.setAnimationState("switchState", "on")
    if not (entity.configParameter("alwaysLit")) then entity.setLightColor(entity.configParameter("lightColor", {0, 0, 0, 0})) end
    entity.playSound("onSounds");
    entity.setAllOutboundNodes(true)
  else
    entity.setAnimationState("switchState", "off")
    if not (entity.configParameter("alwaysLit")) then entity.setLightColor({0, 0, 0, 0}) end
    entity.playSound("offSounds");
    entity.setAllOutboundNodes(false)
  end
end