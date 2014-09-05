returnToStoreState = {
  -- Only spend some extra time moving into the store if the store position is
  -- at least this distance from the spawn position (keeps merchants that are
  -- very close to their store from moving back and forth for a moment after
  -- reaching their store)
  insideMoveMinDistance = 5,

  -- Keep moving for this long once we've gotten into the store (to ensure that
  -- merchants with big stores move past the entryway when coming from outside)
  insideMovetime = 2
}

function returnToStoreState.enterWith(args)
  if merchantState == nil then return nil end

  local sourceId, sayFollow, sayTout = nil, false, false

  if args.interactArgs ~= nil and args.interactArgs.sourceId ~= 0 then
    sourceId = args.interactArgs.sourceId
    sayFollow = true
  end

  -- TODO only within store hours
  if args.noticedPlayerId ~= nil and entity.configParameter("merchant.storeRadius", -1) ~= -1 then
    sourceId = args.noticedPlayerId
    sayTout = true
  end

  if sourceId == nil then
    return
  end

  if merchantState.isInStore() then
    return nil
  end

  if sayFollow then
    sayToTarget("returnToStore.dialog.follow", sourceId)
  end

  return {
    sourceId = sourceId,
    sayTout = sayTout,
    insideMoveTimer = returnToStoreState.insideMovetime
  }
end

function returnToStoreState.update(dt, stateData)
  local sourcePosition = world.entityPosition(stateData.sourceId)
  if sourcePosition == nil then return true end

  local position = entity.position()

  if stateData.waitTimer ~= nil then
    local toSource = world.distance(sourcePosition, position)
    setFacingDirection(toSource[1])

    if world.magnitude(toSource) < entity.configParameter("returnToStore.waitTargetDistance", -1) then
      stateData.waitTimer = entity.configParameter("returnToStore.waitTime")
    else
      stateData.waitTimer = stateData.waitTimer - dt
    end

    return stateData.waitTimer <= 0
  end

  if merchantState.isInStore() then
    if stateData.insideMoveTimer > 0 and math.abs(world.distance(storage.spawnPosition, position)[1]) > returnToStoreState.insideMoveMinDistance then
      stateData.insideMoveTimer = stateData.insideMoveTimer - dt
    else
      if stateData.sayTout then
        sayToTarget("returnToStore.dialog.tout", stateData.sourceId)
      else
        sayToTarget("returnToStore.dialog.welcome", stateData.sourceId)
      end

      stateData.waitTimer = entity.configParameter("returnToStore.waitTime")
    end
  end

  moveTo(storage.spawnPosition, dt)
  return false
end