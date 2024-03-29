-- Move in a flattened circle (ellipse) around a point above the target
glideState = {}

function glideState.enter()
  if hasTarget() then return nil end

  if self.sensors.groundSensors.collisionTrace[4].value then
    return nil
  end

  return {
    timer = entity.configParameter("glideTime"),
    baseDirection = entity.facingDirection()
  }
end

function glideState.update(dt, stateData)
  if hasTarget() then return true end

  if self.sensors.groundSensors.collisionTrace[2].value or stateData.timer < 0 then
    return true, entity.configParameter("glideCooldownTime")
  end
  stateData.timer = stateData.timer - dt

  entity.setAnimationState("movement", "gliding")

  local vector = {
    stateData.baseDirection,
    -entity.configParameter("glideSinkingSpeed")
  }

  --don't turn around immediately before switching states
  if stateData.timer > 0.5 then
    util.toDirection(math.sin(entity.configParameter("glideSpiralDispersion") * math.pi * 2.0 * stateData.timer))
  end

  if self.sensors.blockedSensors.collision.any(true) then
    stateData.baseDirection = -stateData.baseDirection
    vector[1] = -vector[1]
  end

  -- world.debugLine(entity.position(), entity.toAbsolutePosition(vector), "cornflowerblue")
  entity.fly(vec2.mul(vector, entity.flySpeed()), true)
  entity.setFacingDirection(util.toDirection(vector[1]))

  return false
end
