function init(virtual)
  if virtual then return end
  
  entity.setInteractive(entity.configParameter("interactive", true))
  if storage.state == nil then
    output(false)
  else
    output(storage.state)
  end

  if storage.triggered == nil then
    storage.triggered = false
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

function main(args)
  if entity.getInboundNodeLevel(0) and not storage.triggered then
    storage.triggered = true
    output(not storage.state)
  elseif storage.triggered and not entity.getInboundNodeLevel(0) then
    storage.triggered = false
  end
end