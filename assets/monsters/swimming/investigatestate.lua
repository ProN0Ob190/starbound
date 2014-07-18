investigateState = {}

function investigateState.enter()
  local targetIds = world.entityQuery(entity.position(), entity.configParameter("investigateTriggerDistance"), { includedTypes = {"itemDrop"}, inSightOf = entity.id(), order = "nearest" })
  for k,targetId in pairs(targetIds) do
    if entity.entityInSight(targetId) then
      return {
        target = targetId,
        maxDistance = entity.randomizeParameterRange("investigateLoseInterestRange"),
        timer = entity.randomizeParameterRange("investigateTimeRange")
      }
    end
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