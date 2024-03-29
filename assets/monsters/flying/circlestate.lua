-- Move in a flattened circle (ellipse) around a point above the target
circleState = {}

function circleState.enter()
  if not hasTarget() then return nil end

  return {
    timer = entity.configParameter("circleTime"),
    a = entity.randomizeParameterRange("circleWidthRange"),
    b = entity.configParameter("circleHeight"),
    yOffset = entity.randomizeParameterRange("circleOffsetYRange"),
  }
end

function circleState.update(dt, stateData)
  if not hasTarget() then return true end
  if stateData.timer < 0 then return true end

  -- Advance timer through to the next quarter of the circle if running
  -- in to an impedence, which will switch the direction
  if util.blockSensorTest("blockedSensors") then
    stateData.timer = stateData.timer - entity.configParameter("circleTime") * 0.25
  end

  local toTarget = entity.distanceToEntity(self.target)
  toTarget[2] = toTarget[2] + stateData.yOffset

  local ratio = stateData.timer / entity.configParameter("circleTime")
  local phase = math.pi * 2.0 * (1.0 - ratio)

  local x = stateData.a * math.cos(phase)
  local y = stateData.b * math.sin(phase)

  -- The circle gets tilted up while climbing and down while gliding to
  -- emphasize the gain and loss of altitude
  local tiltRatio = 0

  if ratio > 0.75 then
    -- Initial quarter of circle; climbing (1.0 -> 0.75) => (0.0 -> 1.0)
    tiltRatio = 1.0 - (ratio - 0.75) * 4.0
  elseif ratio < 0.25 then
    -- Last quarter of circle; climing (0.25 -> 0.0) => (-2.0 -> 0.0)
    tiltRatio = ratio * -8.0
  else
    -- Middle half of circle; gliding (0.75 -> 0.25) => (1.0 -> -2.0)
    tiltRatio = (ratio - 0.25) * 6.0 - 2.0
  end

  local destination = {
    self.position[1] + toTarget[1] + x,
    self.position[2] + toTarget[2] + y + tiltRatio * entity.configParameter("circleTiltRadius")
  }

  local movement = world.distance(destination, self.position)

  if movement[2] < 0 then
    entity.setAnimationState("movement", "gliding")
  else
    entity.setAnimationState("movement", "flying")
  end

  world.debugLine(entity.position(), destination, "blue")
  entity.flyTo(destination, true)
  entity.setFacingDirection(util.toDirection(movement[1]))

  stateData.timer = stateData.timer - dt
  return false
end
