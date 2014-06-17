-- Fly around aimlessly
wanderState = {}

function wanderState.enter()
  if hasTarget() then return nil end
  return { wanderDirection = util.randomDirection() }
end

function wanderState.update(dt, stateData)
  if hasTarget() then return true end

  if self.sensors.blockedSensors.collision.any(true) then
    stateData.wanderDirection = -stateData.wanderDirection
  end

  local movement = { stateData.wanderDirection, 0 }

  vec2.add(movement, wanderState.calculateSeparationMovement())

  if self.sensors.upSensors.collision.any(true) then
    movement[2] = 1
  elseif self.sensors.downSensors.collision.any(true) then
    movement[2] = -1
  end

  if self.sensors.groundSensors.collisionTrace[3] and movement[2] == 0 then
    movement[2] = entity.configParameter("wanderLiftSpeed")
  end

  vec2.mul(movement, entity.flySpeed() * entity.configParameter("wanderSpeedMultiplier"))
  entity.fly(movement, true)
  entity.setFacingDirection(movement[1])

  return false
end

function wanderState.calculateSeparationMovement()
  local separationMovement = { 0, 0 }

  local position = entity.position()
  local selfId = entity.id()
  local entityIds = world.monsterQuery(entity.position(), 3.0, { callScript = "isFlyer" })
  for i, entityId in ipairs(entityIds) do
    if entityId ~= selfId then
      local fromEntity = world.distance(position, world.entityPosition(entityId))
      separationMovement[1] = separationMovement[1] + fromEntity[1] * math.random()
      separationMovement[2] = separationMovement[2] + fromEntity[2]
    end
  end

  return vec2.div(separationMovement, math.max(1, #entityIds))
end

