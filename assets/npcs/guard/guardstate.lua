guardState = {}

function guardState.enter()
  local timer = entity.randomizeParameterRange("guard.timeRange", { 0, 0 })
  if timer == 0 then timer = nil end

  return {
    patrolDistance = entity.configParameter("guard.patrolDistance", -1),
    hailDistance = entity.configParameter("guard.hailDistance", -1),
    stopDistance = entity.configParameter("guard.stopDistance", -1),
    attackDistance = entity.configParameter("guard.attackDistance", -1),
    loseSightTimer = entity.configParameter("guard.loseSightTime", nil),
    guardTimer = timer,
    saidHail = false,
    saidStop = false,
  }
end

function guardState.enterWith(params)
  if params.noticedPlayerId == nil then return nil end

  local attackDistance = entity.configParameter("guard.attackDistance", -1)
  if attackDistance < 0 then
    return nil
  end

  local distance = world.magnitude(entity.position(), world.entityPosition(params.noticedPlayerId))
  if distance > attackDistance then
    return nil
  end

  return guardState.enter()
end

function guardState.enteringState(stateData)
  entity.setAimPosition(vec2.add({ entity.facingDirection(), -1 }, entity.position()))
end

function guardState.update(dt, stateData)
  local lastTargetId = stateData.targetId
  if stateData.targetId == nil then
    stateData.targetId = entity.closestValidTarget(entity.configParameter("guard.noticeDistance"))
    if stateData.targetId == 0 then
      stateData.targetId = nil
    end
  end

  if stateData.targetId == nil then
    return guardState.updateNoTarget(dt, stateData)
  else
    stateData.patrolTarget = nil
    stateData.timer = nil
  end

  -- Make sure target still exists
  local targetPosition = world.entityPosition(stateData.targetId)
  if targetPosition == nil then
    return true
  end

  -- Handle acquisition of a new target
  local targetChanged = stateData.targetId ~= lastTargetId
  if targetChanged then
    if shouldAttackOnSight(stateData.targetId) and attack(stateData.targetId) then
      sayToTarget("guard.dialog.reattack", stateData.targetId)
      return true
    end

    stateData.saidHail = false
    stateData.saidStop = false
  end

  -- Might need to get aggressive on the target, depending on what they are doing
  if self.state.pickState({ preAttackTargetId = stateData.targetId }) then
    return true
  end

  local position = entity.position()

  -- Forget about the target if they are out of sight for a while
  if stateData.loseSightTimer ~= nil then
    if entity.entityInSight(stateData.targetId) and world.magnitude(position, targetPosition) < entity.configParameter("guard.loseSightDistance") then
      stateData.loseSightTimer = entity.configParameter("guard.loseSightTime", nil)
    else
      stateData.loseSightTimer = stateData.loseSightTimer - dt
      return stateData.loseSightTimer < 0
    end
  end

  local toTarget = world.distance(targetPosition, position)
  local distance = world.magnitude(toTarget)

  if stateData.attackDistance ~= -1 and distance < stateData.attackDistance then
    setFacingDirection(toTarget[1])

    if attack(stateData.targetId) and math.random(100) <= entity.configParameter("guard.attackSayingPercent", 100) then
      sayToTarget("guard.dialog.attack", stateData.targetId)
    end

    return true
  elseif stateData.stopDistance ~= -1 and distance < stateData.stopDistance then
    setFacingDirection(toTarget[1])

    if not stateData.saidStop then
      stateData.saidStop = true

      sayToTarget("guard.dialog.stop", stateData.targetId)
    end
  elseif stateData.hailDistance ~= -1 and distance < stateData.hailDistance then
    setFacingDirection(toTarget[1])

    if not stateData.saidHail then
      stateData.saidHail = true

      if not world.isMonster(stateData.targetId) and math.random(100) <= entity.configParameter("guard.hailPercent", 100) then
        sayToTarget("guard.dialog.hail", stateData.targetId)
      end
    end
  end

  return false
end

function guardState.updateNoTarget(dt, stateData)
  if stateData.guardTimer ~= nil then
    stateData.guardTimer = stateData.guardTimer - dt
    if stateData.guardTimer <= 0 then
      return true
    end
  end

  if stateData.timer ~= nil then
    stateData.timer = stateData.timer - dt
    if stateData.timer <= 0 then
      stateData.timer = nil
    end

    return false
  end

  local direction = entity.facingDirection()
  local position = entity.position()

  if stateData.patrolDistance == -1 then
    -- Just face away from walls instead of actually patrolling
    if not world.lineCollision(position, vec2.add({ -direction * entity.configParameter("guard.wallCheckDistance"), 0 }, position), true) then
      setFacingDirection(-direction)
    end

    stateData.timer = entity.randomizeParameterRange("guard.changeDirectionTimeRange")
    return false
  end

  if stateData.patrolTarget ~= nil then
    moveTo(stateData.patrolTarget, dt)

    local toTarget = world.distance(stateData.patrolTarget, position)
    if world.magnitude(toTarget) < 3.0 and toTarget[1] < 1.0 then
      stateData.patrolTarget = nil
      stateData.timer = entity.randomizeParameterRange("guard.changeDirectionTimeRange")
    end
  else
    setFacingDirection(-direction)
    stateData.patrolTarget = vec2.add({ -direction * stateData.patrolDistance, 0 }, storage.spawnPosition)
  end

  return false
end
