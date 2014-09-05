rangedAttackState = {
  meleeRangeAttackTime = 1,
  notificationInterval = 2,
}

function rangedAttackState.enterWith(args)
  if args.attackTargetId == nil then return nil end
  if not self.hasRangedWeapon and not self.hasSheathedRangedWeapon then return nil, 100 end

  local targetPosition = world.entityPosition(args.attackTargetId)
  if targetPosition == nil then return nil end

  -- Only switch a melee weapon to a sheathed ranged weapon if outside of
  -- melee range
  if self.hasMeleeWeapon and self.hasSheathedRangedWeapon and
     meleeAttackState ~= nil and meleeAttackState.inRange(targetPosition) then
    return nil
  end

  local attackerLimit = entity.configParameter("attackerLimit", nil)
  if attackerLimit ~= nil then
    if nearbyAttackerCount(args.attackTargetId) >= attackerLimit then
      return nil, entity.configParameter("attackerLimitCooldown", nil)
    end
  end

  return {
    targetId = args.attackTargetId,
    targetPosition = targetPosition,
    searchTimer = 0,
    coverHideTimer = 0,
    coverFireTimer = entity.randomizeParameterRange("rangedAttack.coverFireTimeRange"),
    meleeAttackTimer = 0,
    notificationTimer = 0
  }
end

function rangedAttackState.enteringState(stateData)
  if not self.hasRangedWeapon and self.hasSheathedRangedWeapon then
    stateData.swappedWeapon = true
    swapItemSlot("primary")
  end
end

function rangedAttackState.update(dt, stateData)
  local position = entity.position()

  local entityInSight = entity.entityInSight(stateData.targetId)
  if entityInSight then
    stateData.searchTimer = 0
    stateData.targetPosition = world.entityPosition(stateData.targetId)

    stateData.notificationTimer = stateData.notificationTimer - dt
    if stateData.notificationTimer <= 0 then
      sendNotification("attack", { targetId = stateData.targetId, sourceId = entity.id(), sourceDamageTeam = entity.damageTeam() })
      stateData.notificationTimer = rangedAttackState.notificationInterval
    end
  else
    if not world.entityExists(stateData.targetId) then
      return true
    end

    stateData.searchTimer = stateData.searchTimer + dt
    if stateData.searchTimer >= entity.configParameter("rangedAttack.searchTime") then
      return true
    end
  end

  if stateData.targetPosition == nil then
    return true
  end

  local toTarget = world.distance(stateData.targetPosition, position)
  local distance = math.abs(toTarget[1])

  if entityInSight and distance < entity.configParameter("rangedAttack.maxDistance") then
    -- Switch to a melee weapon if we're close enough
    if self.hasSheathedMeleeWeapon and meleeAttackState ~= nil and meleeAttackState.inRange(stateData.targetPosition) then
      stateData.meleeAttackTimer = stateData.meleeAttackTimer + dt
      if stateData.meleeAttackTimer > rangedAttackState.meleeRangeAttackTime then
        attack(stateData.targetId, entity.id(), true)
        return false
      end
    else
      stateData.meleeAttackTimer = 0
    end

    local attackerSpacing = entity.configParameter("rangedAttack.attackerSpacing")
    local closerAttackerPosition = rangedAttackState.closerAttackerPosition(position, stateData, distance)
    if closerAttackerPosition ~= nil then
      -- Back up a bit to give the closer guy room
      if world.magnitude(world.distance(position, closerAttackerPosition)) < attackerSpacing and
          distance < entity.configParameter("rangedAttack.maxDistance") - attackerSpacing then
        move({ -toTarget[1], 0 }, dt)
      end
    else
      -- Move up a bit if we're at the limit of the range and the first line of defense, so
      -- there's room for others behind us
      if distance > entity.configParameter("rangedAttack.maxDistance") - attackerSpacing then
        move({ toTarget[1], 0 }, dt)
      end
    end

    if rangedAttackState.hasCoverAvailable(position, stateData.targetPosition) then
      if rangedAttackState.behindCover(position, toTarget) then
        if stateData.coverFireTimer > 0 then
          entity.setCrouching(false)
          entity.setAimPosition(stateData.targetPosition)
          entity.beginPrimaryFire()

          stateData.coverFireTimer = math.max(0, stateData.coverFireTimer - dt)
          if stateData.coverFireTimer == 0 then
            stateData.coverHideTimer = entity.randomizeParameterRange("rangedAttack.coverHideTimeRange")
          end
        else
          entity.setCrouching(true)
          entity.endPrimaryFire()

          stateData.coverHideTimer = math.max(0, stateData.coverHideTimer - dt)
          if stateData.coverHideTimer == 0 then
            stateData.coverFireTimer = entity.randomizeParameterRange("rangedAttack.coverFireTimeRange")
          end
        end
      else
        entity.setCrouching(false)
        entity.setAimPosition(stateData.targetPosition)
        entity.beginPrimaryFire()
      end
    else
      -- Don't crouch if there's a guy in front of us - he's probably crouching
      entity.setCrouching(closerAttackerPosition == nil)

      entity.setAimPosition(stateData.targetPosition)
      entity.beginPrimaryFire()
    end
  else
    -- Move closer to last known target position
    entity.setCrouching(false)
    entity.endPrimaryFire()
    move(toTarget, dt, { run = true })
  end

  return false
end

function rangedAttackState.hasCoverAvailable(position, targetPosition)
  return world.lineCollision({ position[1], position[2] + entity.configParameter("rangedAttack.coverYOffset") }, targetPosition, true) and
      not world.lineCollision({ position[1], position[2] + entity.configParameter("rangedAttack.coverYClearanceOffset") }, targetPosition, true)
end

function rangedAttackState.behindCover(position, toTarget)
  local coverPosition = { position[1], position[2] + entity.configParameter("rangedAttack.coverYOffset") }
  local coverEndpoint = vec2.add(vec2.mul(vec2.norm(toTarget), entity.configParameter("rangedAttack.coverDistance")), coverPosition)
  return not world.lineCollision(coverPosition, coverEndpoint, true)
end

function rangedAttackState.closerAttackerPosition(position, stateData, distance)
  local entityIds = world.entityLineQuery(position, stateData.targetPosition, { includedTypes = {"npc"}, callScript = "attackTargetId", callScriptResult = stateData.targetId })
  if #entityIds <= 1 then return nil end

  local selfId = entity.id()
  for i, entityId in ipairs(entityIds) do
    if entityId ~= selfId then
      local entityPosition = world.entityPosition(entityId)
      local toTarget = world.distance(stateData.targetPosition, entityPosition)
      if math.abs(toTarget[1]) < distance then
        return entityPosition
      end
    end
  end

  return nil
end

function rangedAttackState.leavingState(stateData)
  entity.setCrouching(false)
  entity.endPrimaryFire()

  if stateData.swappedWeapon then
    swapItemSlot("primary")
  end

  stopAttacking(stateData.targetId)
end