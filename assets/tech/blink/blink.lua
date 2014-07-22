function checkCollision(position)
  local collisionBounds = tech.collisionBounds()
  collisionBounds[1] = collisionBounds[1] - tech.position()[1] + position[1]
  collisionBounds[2] = collisionBounds[2] - tech.position()[2] + position[2]
  collisionBounds[3] = collisionBounds[3] - tech.position()[1] + position[1]
  collisionBounds[4] = collisionBounds[4] - tech.position()[2] + position[2]

  return not world.rectCollision(collisionBounds)
end

function blinkAdjust(position, doPathCheck, doCollisionCheck, doLiquidCheck, doStandCheck)
  local blinkCollisionCheckDiameter = tech.parameter("blinkCollisionCheckDiameter")
  local blinkVerticalGroundCheck = tech.parameter("blinkVerticalGroundCheck")
  local blinkFootOffset = tech.parameter("blinkFootOffset")

  if doPathCheck then
    local collisionBlocks = world.collisionBlocksAlongLine(tech.position(), position, true, 1)
    if #collisionBlocks ~= 0 then
      local diff = world.distance(position, tech.position())
      diff[1] = diff[1] / math.abs(diff[1])
      diff[2] = diff[2] / math.abs(diff[2])

      position = {collisionBlocks[1][1] - diff[1], collisionBlocks[1][2] - diff[2]}
    end
  end

  if doCollisionCheck and not checkCollision(position) then
    local spaceFound = false
    for i = 1, blinkCollisionCheckDiameter * 2 do
      if checkCollision({position[1] + i / 2, position[2] + i / 2}) then
        position = {position[1] + i / 2, position[2] + i / 2}
        spaceFound = true
        break
      end

      if checkCollision({position[1] - i / 2, position[2] + i / 2}) then
        position = {position[1] - i / 2, position[2] + i / 2}
        spaceFound = true
        break
      end

      if checkCollision({position[1] + i / 2, position[2] - i / 2}) then
        position = {position[1] + i / 2, position[2] - i / 2}
        spaceFound = true
        break
      end

      if checkCollision({position[1] - i / 2, position[2] - i / 2}) then
        position = {position[1] - i / 2, position[2] - i / 2}
        spaceFound = true
        break
      end
    end

    if not spaceFound then
      return nil
    end
  end

  if doStandCheck then
    local groundFound = false 
    for i = 1, blinkVerticalGroundCheck * 2 do
      local checkPosition = {position[1], position[2] - i / 2}

      if world.pointCollision(checkPosition, false) then
        groundFound = true
        position = {checkPosition[1], checkPosition[2] + 0.5 - blinkFootOffset}
        break
      end
    end

    if not groundFound then
      return nil
    end
  end

  if doLiquidCheck and (world.liquidAt(position) or world.liquidAt({position[1], position[2] + blinkFootOffset})) then
    return nil
  end

  if doCollisionCheck and not checkCollision(position) then
    return nil
  end

  return position
end

function findRandomBlinkLocation(doCollisionCheck, doLiquidCheck, doStandCheck)
  local randomBlinkTries = tech.parameter("randomBlinkTries")
  local randomBlinkDiameter = tech.parameter("randomBlinkDiameter")

  for i=1,randomBlinkTries do
    local position = tech.position()
    position[1] = position[1] + (math.random() * 2 - 1) * randomBlinkDiameter
    position[2] = position[2] + (math.random() * 2 - 1) * randomBlinkDiameter

    local position = blinkAdjust(position, false, doCollisionCheck, doLiquidCheck, doStandCheck)
    if position then
      return position
    end
  end

  return nil
end

function init()
  data.mode = "none"
  data.timer = 0
  data.targetPosition = nil
end

function uninit()
  tech.setParentAppearance("normal")
end

function input(args)
  if args.moves["special"] == 1 then
    return "blink"
  end

  return nil
end

function update(args)
  local energyUsage = tech.parameter("energyUsage")
  local blinkMode = tech.parameter("blinkMode")
  local blinkOutTime = tech.parameter("blinkOutTime")
  local blinkInTime = tech.parameter("blinkInTime")

  if args.actions["blink"] and data.mode == "none" and args.availableEnergy > energyUsage then
    local blinkPosition = nil
    if blinkMode == "random" then
      local randomBlinkAvoidCollision = tech.parameter("randomBlinkAvoidCollision")
      local randomBlinkAvoidMidair = tech.parameter("randomBlinkAvoidMidair")
      local randomBlinkAvoidLiquid = tech.parameter("randomBlinkAvoidLiquid")

      blinkPosition =
        findRandomBlinkLocation(randomBlinkAvoidCollision, randomBlinkAvoidMidair, randomBlinkAvoidLiquid) or
        findRandomBlinkLocation(randomBlinkAvoidCollision, randomBlinkAvoidMidair, false) or
        findRandomBlinkLocation(randomBlinkAvoidCollision, false, false)
    elseif blinkMode == "cursor" then
      blinkPosition = blinkAdjust(args.aimPosition, true, true, false, false)
    elseif blinkMode == "cursorPenetrate" then
      blinkPosition = blinkAdjust(args.aimPosition, false, true, false, false)
    end

    if blinkPosition then
      data.targetPosition = blinkPosition
      data.mode = "start"
    else
      -- Make some kind of error noise
    end
  end

  if data.mode == "start" then
    tech.setVelocity({0, 0})
    data.mode = "out"
    data.timer = 0

    return energyUsage
  elseif data.mode == "out" then
    tech.setParentAppearance("hidden")
    tech.setAnimationState("blinking", "out")
    tech.setVelocity({0, 0})
    data.timer = data.timer + args.dt

    if data.timer > blinkOutTime then
      tech.setPosition(data.targetPosition)
      data.mode = "in"
      data.timer = 0
    end

    return 0
  elseif data.mode == "in" then
    tech.setParentAppearance("normal")
    tech.setAnimationState("blinking", "in")
    tech.setVelocity({0, 0})
    data.timer = data.timer + args.dt

    if data.timer > blinkInTime then
      data.mode = "none"
    end

    return 0
  end
end
