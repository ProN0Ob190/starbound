investigateState = {}

function investigateState.enter()
  local targetIds = world.itemDropQuery(entity.position(), entity.configParameter("investigateTriggerDistance"), { inSightOf = entity.id(), order = "nearest" })
  if #targetIds > 0 then
    return {
      target = targetIds[1],
      maxDistance = entity.randomizeParameterRange("investigateLoseInterestRange"),
      timer = entity.randomizeParameterRange("investigateTimeRange")
    }
  end

  return nil
end

function investigateState.update(dt, stateData)
  if not world.entityExists(stateData.target) then
    return true
  end

  if not entity.entityInSight(stateData.target) then
    return true
  end

  stateData.timer = stateData.timer - dt
  if stateData.timer < 0 then
    return true, entity.configParameter("investigateCooldownTime")
  end

  local toTarget = entity.distanceToEntity(stateData.target)
  local distance = world.magnitude(toTarget)
  if distance > stateData.maxDistance then
    return true
  end

  if distance < entity.configParameter("investigateStopDistance") then
    return true, entity.configParameter("investigateCooldownTime")
  end

  self.movement = toTarget
  return false
end