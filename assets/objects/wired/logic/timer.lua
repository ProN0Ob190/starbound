function init(args)
  entity.setInteractive(false)
  if storage.state == nil then
    output(false)
  else
    output(storage.state)
  end
  if storage.timer == nil then
    storage.timer = 0
  end
  self.interval = entity.configParameter("interval")
end

function output(state)
  if storage.state ~= state then
    storage.state = state
    entity.setAllOutboundNodes(state)
    if state then
      entity.setAnimationState("switchState", "on")
    else
      entity.setAnimationState("switchState", "off")
    end
  else
  end
end

function main()
  if not entity.getInboundNodeLevel(0) then
    if storage.timer == 0 then
      storage.timer = self.interval
      output(not storage.state)
    else
      storage.timer = storage.timer - 1 
    end
  end
end
