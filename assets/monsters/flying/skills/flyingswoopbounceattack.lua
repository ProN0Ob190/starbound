-- Swoop from the current position towards the target, then retreat back towards
-- the starting position

flyingSwoopBounceAttack = {}

function flyingSwoopBounceAttack.enter()
  return { swoopBounceTimer = 0.0 }
end

function flyingSwoopBounceAttack.update(dt, stateData)
  entity.setFacingDirection(self.toTarget[1])

  if util.blockSensorTest("blockedSensors", entity.facingDirection()) then
    return true
  elseif util.blockSensorTest("downSensors", entity.facingDirection()) then
    return true
  elseif not entity.entityInSight(self.target) then
    return true
  else
    entity.setAggressive(true)
    if stateData.swoopBounceTimer > 0.0 then
      local bounceAngle = entity.configParameter("swoopBounceAngle") * math.pi / 180
      local vector = { math.cos(bounceAngle), math.sin(bounceAngle) }

      if self.toTarget[1] > 0 then
        vector[1] = -vector[1]
      end

      entity.fly(vec2.mul(vector, entity.flySpeed()), true)
      stateData.swoopBounceTimer = stateData.swoopBounceTimer - dt
      if stateData.swoopBounceTimer < 0.0 then
        return true
      end
    else
      entity.fly(vec2.mul({ self.toTarget[1], self.toTarget[2] }, entity.flySpeed()), true)

      if world.magnitude(self.toTarget) < entity.configParameter("swoopBounceLimit") then
        stateData.swoopBounceTimer = entity.configParameter("swoopBounceTime")
      end
    end

    return false
  end
end
