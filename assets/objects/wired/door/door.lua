function init(args)
  entity.setColliding(true)

  if isDoorClosed() then
    entity.setColliding(true)
    entity.setAllOutboundNodes(false)
  else
    entity.setColliding(false)
    entity.setAllOutboundNodes(true)
  end

  onNodeConnectionChange()
end

function onNodeConnectionChange(args)
  entity.setInteractive(not entity.isInboundNodeConnected(0))
  if entity.isInboundNodeConnected(0) then
    onInboundNodeChange({ level = entity.getInboundNodeLevel(0) })
  end
end

function onInboundNodeChange(args)
  if args.level then
    openDoor(-doorDirection())
  else
    closeDoor()
  end
end

function onInteraction(args)
  if (entity.isInboundNodeConnected(0)) then
    return
  end
  if isDoorClosed() then
    openDoor(args.source[1])
  else
    closeDoor()
  end
end

function hasCapability(capability)
  if (entity.isInboundNodeConnected(0)) then
    return
  end
  if capability == 'door' then
    return true
  elseif capability == 'closedDoor' then
    return isDoorClosed()
  else
    return false
  end
end

function isDoorClosed()
  return entity.animationState("doorState") == "closeLeft" or entity.animationState("doorState") == "closeRight"
end

function doorDirection()
  return (entity.animationState("doorState") == "closeLeft" or entity.animationState("doorState") == "openLeft") and -entity.direction() or entity.direction()
end

function closeDoor()
  if not isDoorClosed() then
    if entity.animationState("doorState") == "openLeft" then
      entity.setAnimationState("doorState", "closeLeft")
    else
      entity.setAnimationState("doorState", "closeRight")
    end
    entity.playSound("closeSounds")
    entity.setColliding(true)
    entity.setAllOutboundNodes(false)
  end
end

function openDoor(direction)
  if isDoorClosed() then
    if direction == nil or direction * entity.direction() < 0 then
      entity.setAnimationState("doorState", "openLeft")
    else
      entity.setAnimationState("doorState", "openRight")
    end
    entity.playSound("openSounds")
    entity.setColliding(false)
    entity.setAllOutboundNodes(true)
  end
end
