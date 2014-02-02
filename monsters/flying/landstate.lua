-- Land on the ground and chill out for a while

landState = {}

function landState.enter()
  if hasTarget() then return nil end

  if not self.sensors.groundSensors.collisionTrace[2] then
    return nil
  end

  -- Don't land if we're practically on the ground already, it would be better
  -- to let some other state move us away from the ground
  if self.sensors.groundSensors.collisionTrace[1] then
    return nil
  end

  if entity.closestValidTarget(entity.configParameter("landDisturbDistance")) ~= 0 then
    return nil
  end

  return { restTime = entity.randomizeParameterRange("landRestTimeRange") }
end

function landState.update(dt, stateData)
  if hasTarget() then return true end

  if entity.closestValidTarget(entity.configParameter("landDisturbDistance")) ~= 0 then
    return true, entity.randomizeParameterRange("landCooldownTimeRange")
  end

  if entity.onGround() then
    entity.setAnimationState("movement", "standing")

    stateData.restTime = stateData.restTime - dt
    if stateData.restTime < 0.0 then
      return true, entity.randomizeParameterRange("landCooldownTimeRange")
    end
  else
    entity.setAnimationState("movement", "flying")
    entity.fly({ 0, -entity.flySpeed() }, true)
  end

  return false
end
