function init(args)
  entity.setInteractive(false)
  if storage.state == nil then
    output(false)
  else
    output(storage.state)
  end
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
  if entity.getInboundNodeLevel(1) then
    output(entity.getInboundNodeLevel(0))
  end
end
