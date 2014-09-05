fleeState = {}

function fleeState.enter()
  local target = entity.closestValidTarget(entity.configParameter("fleeTriggerDistance"))
  if target ~= 0 then
    return {
      target = target,
      fleeDistance = entity.randomizeParameterRange("fleeDistanceRange"),
      overrideMovement = nil
    }
  end

  return nil
end

function fleeState.update(dt, stateData)
  local toTarget = entity.distanceToEntity(stateData.target)
  local targetDist = world.magnitude(toTarget)
  if targetDist > stateData.fleeDistance then
    return true
  end

  local movement = self.movement

  if stateData.overrideMovement ~= nil then
    -- Crossing to the other side of the target if blocked in the current direction
    if util.toDirection(toTarget[1]) ~= util.toDirection(stateData.overrideMovement[1]) then
      stateData.overrideMovement = nil
    else
      movement = stateData.overrideMovement
    end
  else
    movement = { -toTarget[1], -toTarget[2] }
  end

  if util.blockSensorTest("blockedSensors", movement[1]) then
    if targetDist > entity.configParameter("fleeTriggerDistance") then
      return true
    end
    stateData.overrideMovement = { -movement[1], movement[2] }
  end

  self.movementWeight = entity.configParameter("fleeMovementWeight")
  self.movement = {
    util.toDirection(movement[1]),
    math.min(math.max(-0.8, movement[2]), 0.8)
  }

  return false
end
