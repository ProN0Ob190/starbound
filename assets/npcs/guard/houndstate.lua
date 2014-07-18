-- Follow target around, warning them to put their weapons away
houndState = {
  hounderCheckRadius = 60
}

function houndState.enterWith(args)
  if args.preAttackTargetId == nil then return nil end

  local targetWeaponType = houndState.targetWeaponType(args.preAttackTargetId)
  if targetWeaponType == nil then
    return nil
  end

  local targetPosition = world.entityPosition(args.preAttackTargetId)
  if targetPosition == nil then return nil end

  local hounderIds = world.entityQuery(targetPosition, houndState.hounderCheckRadius, {
    includedTypes = {"npc"}, callScript = "stateName", callScriptResult = "houndState"
  })
  for _, hounderId in pairs(hounderIds) do
    if world.callScriptedEntity(hounderIds[1], "stateTargetId") == args.preAttackTargetId then
      return nil
    end
  end

  return {
    targetId = args.preAttackTargetId,
    timer = 0,
    warningCount = 0,
    loseSightTimer = nil,
    sayComeBackTimer = 0
  }
end

function houndState.enteringState(stateData)
  self.stateTargetId = stateData.targetId
end

function houndState.update(dt, stateData)
  local targetPosition = world.entityPosition(stateData.targetId)
  if targetPosition == nil then
    return true
  end

  if stateData.sayComeBackTimer > 0 then
    stateData.sayComeBackTimer = math.max(0, stateData.sayComeBackTimer - dt)
  end

  local position = entity.position()
  local targetWeaponType = houndState.targetWeaponType(stateData.targetId)

  if entity.entityInSight(stateData.targetId) and world.magnitude(position, targetPosition) < entity.configParameter("hound.loseSightDistance") then
    stateData.loseSightTimer = nil

    if targetWeaponType == nil then
      sayToTarget("hound.dialog.weaponSheathed", stateData.targetId)
      return true
    end
  else
    stateData.timer = entity.configParameter("hound.warningTime")

    if stateData.loseSightTimer == nil then
      if stateData.sayComeBackTimer == 0 then
        sayToTarget("hound.dialog.comeBack", stateData.targetId)
        stateData.sayComeBackTimer = entity.configParameter("hound.sayComeBackCooldown")
      end

      stateData.loseSightTimer = entity.configParameter("hound.loseSightTime")
    end

    stateData.loseSightTimer = stateData.loseSightTimer - dt
    if stateData.loseSightTimer <= 0 then
      return true
    end
  end

  if stateData.timer <= 0 then
    stateData.timer = entity.configParameter("hound.warningTime")

    if stateData.warningCount > 2 then
      attack(stateData.targetId)
      return true
    else
      sayToTarget("hound.dialog.warnings[" .. stateData.warningCount .. "]." .. targetWeaponType, stateData.targetId)
      stateData.warningCount = stateData.warningCount + 1
    end
  else
    stateData.timer = stateData.timer - dt

    local toTarget = world.distance(targetPosition, position)
    if world.magnitude(toTarget) > entity.configParameter("hound.followDistance") then
      moveTo(targetPosition, dt)
    else
      setFacingDirection(toTarget[1])
    end
  end

  return false
end

function houndState.targetWeaponType(targetId)
  local primaryItem = world.entityHandItem(targetId, "primary")
  if primaryItem ~= nil then
    local primaryItemType = world.itemType(primaryItem)
    if primaryItemType == "sword" or primaryItemType == "gun" then
      return primaryItemType
    end
  end

  local altItem = world.entityHandItem(targetId, "alt")
  if altItem ~= nil then
    local altItemType = world.itemType(altItem)
    if altItemType == "sword" or altItemType == "gun" then
      return altItemType
    end
  end

  return nil
end