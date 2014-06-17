-- Fly around aimlessly
wanderState = {}

function wanderState.enter()
  if hasTarget() then return nil end

  math.randomseed(os.time())

  return {
    wanderDirection = entity.facingDirection(),
    phaseTimer = entity.randomizeParameterRange("wanderRiseTimeRange"),
    rising = true
  }
end

function wanderState.update(dt, stateData)
  if hasTarget() then return true end

  if self.sensors.blockedSensors.collision.any(true) then
    stateData.wanderDirection = -stateData.wanderDirection
  end

  local movement = { stateData.wanderDirection, 0 }

  if self.sensors.upSensors.collision.any(true) then
    movement[2] = entity.configParameter("wanderRiseSpeed")
  elseif self.sensors.downSensors.collision.any(true) then
    movement[2] = -entity.configParameter("wanderGlideSpeed")
  elseif stateData.rising then
    stateData.phaseTimer = stateData.phaseTimer - dt

    entity.setAnimationState("movement", "flying")

    if stateData.phaseTimer > 0 or self.sensors.groundSensors.collisionTrace[4].value then
      movement[2] = entity.configParameter("wanderRiseSpeed")
    else
      --stop rising and glide
      stateData.rising = false
      stateData.phaseTimer = entity.randomizeParameterRange("wanderGlideTimeRange")
    end
  else --gliding
    stateData.phaseTimer = stateData.phaseTimer - dt

    if math.sin(stateData.phaseTimer * 2) > 0.4 then
      entity.setAnimationState("movement", "flying")
    else
      entity.setAnimationState("movement", "gliding")
    end

    if stateData.phaseTimer > 0 and not self.sensors.groundSensors.collisionTrace[3].value then
      movement[2] = -entity.configParameter("wanderGlideSpeed")
    else
      if math.random() <= entity.configParameter("wanderEndChance") then
        entity.fly(movement, true)
        return true, 0.5
      else
        stateData.rising = true
        stateData.phaseTimer = entity.randomizeParameterRange("wanderRiseTimeRange")
      end
    end
  end

  movement = vec2.add(movement, wanderState.calculateSeparationMovement())
  movement = vec2.mul(movement, entity.flySpeed() * entity.configParameter("wanderSpeedMultiplier"))

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

