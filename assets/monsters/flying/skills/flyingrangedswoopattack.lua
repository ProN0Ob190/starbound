-- Swoop over target while shooting projectiles

flyingRangedSwoopAttack = {}

function flyingRangedSwoopAttack.enter()
  if not entity.entityInSight(self.target) then
    return nil
  end

  local forwardSensor = entity.toAbsolutePosition({ entity.configParameter("rangedSwoopDistance"), 0 })
  if world.lineCollision(self.position, forwardSensor, true) then
    return nil
  end

  local downSensor = entity.toAbsolutePosition({ 0, -entity.configParameter("rangedSwoopRadius") })
  if world.lineCollision(self.position, downSensor, true) then
    return nil
  end

  local toTarget = entity.distanceToEntity(self.target)

  return {
    timer = 0,
    totalTime = entity.configParameter("rangedSwoopTime"),
    basePosition = entity.position(),
    startedFiring = false,
    direction = util.toDirection(toTarget[1])
  }
end

function flyingRangedSwoopAttack.update(dt, stateData)
  if not entity.entityInSight(self.target) then return true end
  if stateData.timer > stateData.totalTime then return true end

  entity.setDamageOnTouch(false)
  entity.setAggressive(true)

  if not stateData.startedFiring and entity.readyToFire() then
    entity.startFiring(entity.staticRandomizeParameter("rangedSwoopProjectile"))
    stateData.startedFiring = true
  end

  local toTarget = entity.distanceToEntity(self.target)

  if stateData.startedFiring then
    entity.setFireDirection({ 0, 0 }, toTarget)
  end

  local ratio = stateData.timer / stateData.totalTime

  local destination = {
    stateData.basePosition[1] + ratio * entity.configParameter("rangedSwoopDistance") * stateData.direction,
    stateData.basePosition[2] - math.sin(math.pi * ratio) * entity.configParameter("rangedSwoopRadius")
  }

  local movement = world.distance(destination, self.position)
  if movement[2] < 0 then
    entity.setAnimationState("movement", "gliding")
  else
    entity.setAnimationState("movement", "flying")
  end

  entity.flyTo(destination, true)
  entity.setFacingDirection(stateData.direction)

  stateData.timer = stateData.timer + dt
  return false
end
