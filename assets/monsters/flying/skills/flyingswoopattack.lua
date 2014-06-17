-- Swoop through the target, ending on the opposite side

flyingSwoopAttack = {}

function flyingSwoopAttack.enter()
  local toTarget = entity.distanceToEntity(self.target)

  local xDist = math.abs(toTarget[1])
  local swoopDiameter = entity.configParameter("swoopDiameter")
  if xDist > swoopDiameter * 1.5 or xDist < swoopDiameter * 0.5 then
    return nil
  end

  return {
    timer = entity.configParameter("swoopTime"),
    basePosition = entity.position(),
    height = toTarget[2],
    direction = toTarget[1]
  }
end

function flyingSwoopAttack.update(dt, stateData)
  if util.blockSensorTest("blockedSensors", entity.facingDirection()) then
    return true
  elseif util.blockSensorTest("downSensors", entity.facingDirection()) then
    return true
  elseif not entity.entityInSight(self.target) then
    return true
  else
    entity.setAggressive(true)
    stateData.timer = stateData.timer - dt
    if stateData.timer < 0 then return true end

    local ratio = stateData.timer / entity.configParameter("swoopTime")
    local xOffset = stateData.direction * (1.0 - ratio) * entity.configParameter("swoopDiameter")

    local phase = math.pi / 2.0 + math.pi * ratio
    local yOffset = math.cos(phase) * stateData.height

    if stateData.timer < 0.5 then
      entity.setAnimationState("movement", "flying")
    else
      entity.setAnimationState("movement", "gliding")
    end

    local destination = {
      stateData.basePosition[1] + xOffset,
      stateData.basePosition[2] - yOffset
    }

    entity.flyTo(destination, true)
    entity.setFacingDirection(stateData.direction)

    return false
  end
end
