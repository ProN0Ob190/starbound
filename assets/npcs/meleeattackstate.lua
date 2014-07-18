meleeAttackState = {
  notificationInterval = 2,
}

function meleeAttackState.inRange(targetPosition)
  local maxRange = entity.configParameter("meleeAttack.switchDistance", nil)
  if maxRange == nil then
    maxRange = entity.configParameter("meleeAttack.swingDistance")
  end

  return world.magnitude(entity.position(), targetPosition) < maxRange
end

function meleeAttackState.enterWith(args)
  if args.attackTargetId == nil then return nil end
  if not self.hasMeleeWeapon and not self.hasSheathedMeleeWeapon then return nil, 100 end

  local targetPosition = world.entityPosition(args.attackTargetId)
  if targetPosition == nil then return nil end

  -- Only switch from a ranged weapon to a sheathed melee weapon if in melee range
  if self.hasRangedWeapon and self.hasSheathedMeleeWeapon and not meleeAttackState.inRange(targetPosition) then
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
    swingTimer = 0,
    swingCooldownTimer = 0,
    backoffDistance = entity.randomizeParameterRange("meleeAttack.backoffDistanceRange"),
    notificationTimer = 0
  }
end

function meleeAttackState.enteringState(stateData)
  if not self.hasMeleeWeapon and self.hasSheathedMeleeWeapon then
    stateData.swappedWeapon = true
    swapItemSlot("primary")
  end
end

function meleeAttackState.update(dt, stateData)
  if not world.entityExists(stateData.targetId) then
    return true
  end

  -- This just prevents switching sides too frequently when multiple npcs are
  -- attacking the same target and coordinating their attacks (since there may
  -- be a period of time where another npc moving to a better position is
  -- counted as a closer attacker)
  if stateData.repositionCooldownTimer ~= nil then
    stateData.repositionCooldownTimer = stateData.repositionCooldownTimer - dt
    if stateData.repositionCooldownTimer <= 0 then
      stateData.repositionCooldownTimer = nil
    end
  end

  -- Finish swinging weapon
  if stateData.swingTimer > 0 then
    stateData.swingTimer = math.max(0, stateData.swingTimer - dt)
    if stateData.swingTimer == 0 then
      entity.endPrimaryFire()
      stateData.swingCooldownTimer = entity.configParameter("meleeAttack.swingCooldownTime", 0)
    end
    return false
  end

  local position = entity.position()
  local toTarget = world.distance(stateData.targetPosition, position)

  -- Block after swinging
  if stateData.swingCooldownTimer > 0 then
    if self.hasShield then
      entity.beginAltFire()
      entity.setFacingDirection(toTarget[1])
      entity.setAimPosition(stateData.targetPosition)
    end

    stateData.swingCooldownTimer = math.max(0, stateData.swingCooldownTimer - dt)
    return false
  end

  -- Keep the target in sight
  local entityInSight = entity.entityInSight(stateData.targetId)
  if entityInSight then
    stateData.searchTimer = 0

    stateData.targetPosition = world.entityPosition(stateData.targetId)
    if stateData.targetPosition == nil then
      return true
    end

    stateData.notificationTimer = stateData.notificationTimer - dt
    if stateData.notificationTimer <= 0 then
      sendNotification("attack", { targetId = stateData.targetId, sourceId = entity.id(), sourceDamageTeam = entity.damageTeam() })
      stateData.notificationTimer = meleeAttackState.notificationInterval
    end
  else
    if not world.entityExists(stateData.targetId) then
      return true
    end

    stateData.searchTimer = stateData.searchTimer + dt
    if stateData.searchTimer >= entity.configParameter("meleeAttack.searchTime") then
      return true
    end
  end

  local distance = world.magnitude(toTarget)

  local movementTargetPosition, running = nil, true
  if stateData.moveToSide ~= nil then
    movementTargetPosition = {
      stateData.targetPosition[1] + stateData.moveToSide * stateData.backoffDistance,
      stateData.targetPosition[2]
    }
    entity.endAltFire()

    if distance >= stateData.backoffDistance and stateData.moveToSide == util.toDirection(-toTarget[1]) then
      stateData.moveToSide = nil
      stateData.repositionCooldownTimer = entity.randomizeParameterRange("meleeAttack.repositionCooldownTimeRange")
    end
  else
    if entityInSight then
      entity.setFacingDirection(toTarget[1])
      entity.setAimPosition(stateData.targetPosition)

      if distance < stateData.backoffDistance then
        -- Coordinate attacks with other attackers so they don't all stack up
        if stateData.repositionCooldownTimer == nil then
          if meleeAttackState.hasCloserAttacker(position, stateData) then
            if meleeAttackState.otherSideOpen(toTarget, stateData) then
              stateData.moveToSide = util.toDirection(toTarget[1])
              return false
            end

            -- Just stay back a bit so the closer guy can fight
            return false
          else
            stateData.repositionCooldownTimer = entity.randomizeParameterRange("meleeAttack.repositionCooldownTimeRange")
          end
        end
      end

      -- Start new attack if close enough
      if distance < entity.configParameter("meleeAttack.swingDistance") then
        -- Make sure we're not standing on a platform just above the target
        if toTarget[2] < -1.5 then
          entity.moveDown()
        end

        entity.beginPrimaryFire()
        stateData.swingTimer = entity.configParameter("meleeAttack.swingTime")
        return false
      elseif self.hasSheathedRangedWeapon and not meleeAttackState.inRange(stateData.targetPosition) then
        attack(stateData.targetId, entity.id(), true)
        return false
      end
    end

    -- Get close enough to attack
    movementTargetPosition = stateData.targetPosition
    running = distance > entity.configParameter("meleeAttack.runThreshold")
    if self.hasShield and not running then
      entity.beginAltFire()
    else
      entity.endAltFire()
    end
  end

  moveTo(movementTargetPosition, dt, { run = running })
  return false
end

function meleeAttackState.leavingState(stateData)
  entity.endPrimaryFire()
  entity.endAltFire()

  if stateData.swappedWeapon then
    swapItemSlot("primary")
  end

  stopAttacking(stateData.targetId)
end

function meleeAttackState.hasCloserAttacker(position, stateData)
  local npcIds = world.entityLineQuery(stateData.targetPosition, position, { includedTypes = {"npc"}, callScript = "attackTargetId", callScriptResult = stateData.targetId })
  if #npcIds == 0 then
    return false
  end

  local selfId = entity.id()

  if #npcIds == 1 then
    return npcIds[1] ~= selfId
  end

  if #npcIds > 1 then
    local distance = world.magnitude(position, stateData.targetPosition)
    for _, npcId in pairs(npcIds) do
      if npcId ~= selfId then
        local npcPosition = world.entityPosition(npcId)
        if world.magnitude(npcPosition, stateData.targetPosition) < distance then
          return true
        end
      end
    end
  end

  return false
end

function meleeAttackState.otherSideOpen(toTarget, stateData)
  local direction = util.toDirection(toTarget[1])
  local offsetX = direction * stateData.backoffDistance

  local otherSidePosition = {
    stateData.targetPosition[1] + offsetX,
    stateData.targetPosition[2]
  }
  local npcIds = world.entityLineQuery(stateData.targetPosition, otherSidePosition, { includedTypes = {"npc"}, callScript = "attackTargetId", callScriptResult = stateData.targetId })
  if #npcIds > 0 and npcIds[1] ~= entity.id() then
    return false
  end

  local otherSideRegion = {
    math.floor(stateData.targetPosition[1] + 0.5) - 1, math.floor(stateData.targetPosition[2] + 0.5) - 3,
    math.floor(stateData.targetPosition[1] + 0.5) + 1, math.floor(stateData.targetPosition[2] + 0.5) + 1
  }
  if direction < 0 then
    otherSideRegion[1] = otherSideRegion[1] + offsetX
    otherSideRegion[3] = otherSideRegion[3] - 2
  else
    otherSideRegion[1] = otherSideRegion[1] + 2
    otherSideRegion[3] = otherSideRegion[3] + offsetX
  end

  return not world.rectCollision(otherSideRegion, true)
end