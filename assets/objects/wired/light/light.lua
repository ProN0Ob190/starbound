function init(virtual)
  if virtual then return end

  if storage.state == nil then storage.state = entity.configParameter("defaultLightState", true) end

  self.interactive = entity.configParameter("interactive", true)
  entity.setInteractive(self.interactive)

  if entity.configParameter("inboundNodes") then
    processWireInput()
  end

  setLightState(storage.state)
end

function onNodeConnectionChange(args)
  processWireInput()
end

function onInboundNodeChange(args)
  processWireInput()
end

function onInteraction(args)
  if not entity.configParameter("inboundNodes") or not entity.isInboundNodeConnected(0) then
    storage.state = not storage.state
    setLightState(storage.state)
  end
end

function processWireInput()
  if entity.isInboundNodeConnected(0) then
    entity.setInteractive(false)
    storage.state = entity.getInboundNodeLevel(0)
    setLightState(storage.state)
  elseif self.interactive then
    entity.setInteractive(true)
  end
end

function setLightState(newState)
  if newState then
    entity.setAnimationState("light", "on")
    entity.setSoundEffectEnabled(true)
    entity.playSound("onSounds");
    --TODO: support lightColors configuration
    entity.setLightColor(entity.configParameter("lightColor", {255, 255, 255}))
  else
    entity.setAnimationState("light", "off")
    entity.setSoundEffectEnabled(false)
    entity.playSound("offSounds");
    entity.setLightColor({0, 0, 0, 0})
  end
end