-- Move in a flattened circle (ellipse) around a point above the target
glideState = {}

function glideState.enter()
  if hasTarget() then return nil end

  if self.sensors.groundSensors.collisionTrace[3] then
    return nil
  end

  return {
    timer = entity.configParameter("glideTime"),
    baseDirection = entity.facingDirection()
  }
end

function glideState.update(dt, stateData)
  if hasTarget() then return true end

  if self.sensors.groundSensors.collisionTrace[2] or stateData.timer < 0 then
    return true, entity.configParameter("glideCooldownTime")
  end
  stateData.timer = stateData.timer - dt

  entity.setAnimationState("movement", "gliding")

  local vector = {
    stateData.baseDirection * util.toDirection(math.sin(entity.configParameter("glideSpiralDispersion") * math.pi * 2.0 * stateData.timer)),
    -entity.configParameter("glideSinkingSpeed")
  }

  if util.blockSensorTest("blockedSensors", vector[1]) then
    stateData.baseDirection = -stateData.baseDirection
    vector[1] = -vector[1]
  end

  world.debugLine(entity.position(), entity.toAbsolutePosition(vector), "cornflowerblue")
  entity.fly(vec2.mul(vector, entity.flySpeed()), true)
  entity.setFacingDirection(util.toDirection(vector[1]))

  return false
end
