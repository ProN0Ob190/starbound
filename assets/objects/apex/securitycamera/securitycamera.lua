function init(args)
  self.state = stateMachine.create({
    "alertState",
    "scanState"
  })

  entity.setAnimationState("movement", "idle")
  entity.setInteractive(false)
  entity.setAllOutboundNodes(false)
end

function main(args)
  self.state.update(entity.dt())
end

function toAbsolutePosition(offset)
  if entity.direction() > 0 then
    return vec2.add(entity.position(), offset)
  else
    return vec2.sub(entity.position(), offset)
  end
end

function getBasePosition()
  local baseOffset = entity.configParameter("baseOffset")
  return toAbsolutePosition(baseOffset)
end

function setAimAngle(basePosition, targetAimAngle)
  entity.rotateGroup("camera", -targetAimAngle)

  local tipOffset = entity.configParameter("tipOffset")
  local tipPosition = toAbsolutePosition(tipOffset)

  local aimAngle = entity.currentRotationAngle("camera")
  local facingDirection = entity.direction()
  local aimVector = vec2.rotate(world.distance(tipPosition, basePosition), aimAngle * facingDirection)

  tipPosition = vec2.add(basePosition, aimVector)
  tipOffset = world.distance(tipPosition, entity.position())

  aimVector = vec2.norm(aimVector)
  --monster.setFireDirection(tipOffset, aimVector)

  local laserVector = vec2.mul(aimVector, entity.configParameter("maxLaserLength"))
  local laserEndpoint = vec2.add({ tipPosition[1], tipPosition[2] }, laserVector)

  local blocks = world.collisionBlocksAlongLine(tipPosition, laserEndpoint, true, 1)
  if #blocks > 0 then
    local blockPosition = blocks[1]
    local delta = world.distance(blockPosition, tipPosition)

    local x0, x1 = blockPosition[1], blockPosition[1] + 1
    if delta[1] < 0 then x0, x1 = x1, x0 end

    local y0, y1 = blockPosition[2], blockPosition[2] + 1
    if delta[2] < 0 then y0, y1 = y1, y0 end

    local xIntersection = vec2.intersect(tipPosition, laserEndpoint, { x0, y0 }, { x0, y1 })
    local yIntersection = vec2.intersect(tipPosition, laserEndpoint, { x0, y0 }, { x1, y0 })

    if yIntersection == nil then
      if xIntersection ~= nil then laserEndpoint = xIntersection end
    elseif xIntersection == nil then
      if yIntersection ~= nil then laserEndpoint = yIntersection end
    else
      local xSegment = world.distance(xIntersection, tipPosition)
      local ySegment = world.distance(yIntersection, tipPosition)
      if world.magnitude(xSegment) > world.magnitude(ySegment) then
        laserEndpoint = yIntersection
      else
        laserEndpoint = xIntersection
      end
    end
  end

  world.debugLine(tipPosition, laserEndpoint, "red")

  return -aimAngle, tipPosition, laserEndpoint
end

--------------------------------------------------------------------------------
scanState = {}

function scanState.enter()
  return {
    timer = -entity.configParameter("rotationPauseTime"),
    direction = 1
  }
end

function scanState.update(dt, stateData)
  local rotationRange = vec2.mul(entity.configParameter("rotationRange"), math.pi / 180)
  local rotationTime = entity.configParameter("rotationTime")

  local angle = util.easeInOutQuad(
    util.clamp(stateData.timer, 0, rotationTime) / rotationTime,
    rotationRange[1],
    rotationRange[2]
  )

  if stateData.direction < 0 then
    angle = rotationRange[2] - angle
  end

  if stateData.timer < 0 or stateData.timer > rotationTime then
    entity.setAnimationState("movement", "idle")
  else
    entity.setAnimationState("movement", "move")
  end

  local basePosition = getBasePosition()
  local aimAngle, laserOrigin, laserEndpoint = setAimAngle(basePosition, angle)

  local targetId = scanState.findTarget(laserOrigin, laserEndpoint)
  if targetId ~= 0 then
    self.state.pickState(targetId)
    return true
  end

  stateData.timer = stateData.timer + dt
  if stateData.timer > rotationTime then
    stateData.timer = -entity.configParameter("rotationPauseTime")
    stateData.direction = -stateData.direction
  end

  return false
end

function scanState.findTarget(startPosition, endPosition)
  local selfId = entity.id()

  local entityIds = world.entityLineQuery(startPosition, endPosition, { includedTypes = {"creature"}, withoutEntityId = selfId })
  for i, entityId in ipairs(entityIds) do
    if entity.isValidTarget(entityId) then
      return entityId
    end
  end

  return 0
end

--------------------------------------------------------------------------------
alertState = {}

function alertState.enterWith(targetId)
  entity.rotateGroup("camera", entity.currentRotationAngle("camera"))
  entity.setAnimationState("movement", "alert")
  entity.setAllOutboundNodes(true)
  return { timer = 0, targetId = targetId }
end

function alertState.update(dt, stateData)
  local targetPosition = world.entityPosition(stateData.targetId)
  if targetPosition == nil then
    entity.setAnimationState("movement", "idle")
    entity.setAllOutboundNodes(false)
    return true
  end

  local basePosition = getBasePosition()
  local toTarget = world.distance(targetPosition, basePosition)

  local desiredAimAngle = vec2.angle(toTarget) * entity.direction()
  if desiredAimAngle > math.pi then desiredAimAngle = 2 * math.pi - desiredAimAngle end

  local rotationRange = vec2.mul(entity.configParameter("rotationRange"), math.pi / 180)
  desiredAimAngle = util.clamp(desiredAimAngle, rotationRange[1], rotationRange[2])

  local aimAngle, laserOrigin, laserEndpoint = setAimAngle(basePosition, desiredAimAngle)

  if not alertState.isVisible(laserOrigin, laserEndpoint, stateData.targetId) then
    entity.rotateGroup("camera", entity.currentRotationAngle("camera"))
    stateData.timer = stateData.timer + dt
  else
    stateData.timer = 0
  end

  if stateData.timer > 4.0 then
    entity.setAnimationState("movement", "idle")
    entity.setAllOutboundNodes(false)
    return true
  end

  return false
end

function alertState.isVisible(startPosition, endPosition, targetId)
  local entityIds = world.entityLineQuery(startPosition, endPosition, {includedTypes = {"creature"}})
  for i, entityId in ipairs(entityIds) do
    if entityId == targetId then
      return true
    end
  end

  return false
end
