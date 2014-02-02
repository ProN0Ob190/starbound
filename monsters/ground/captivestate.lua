captiveState = {
  closeDistance = 4,
  runDistance = 12,
  teleportDistance = 36,
}

function captiveState.enter()
  if not isCaptive() or hasTarget() then return nil end

  return { running = false }
end

function captiveState.enterWith(params)
  if not isCaptive() then return nil end

  -- We're masquerading as wander for captive monsters
  if params.wander then
    return { running = false }
  end

  return nil
end

function captiveState.update(dt, stateData)
  if hasTarget() then return true end

  -- Translate owner uuid to entity id
  if self.ownerEntityId ~= nil then
    if not world.entityExists(self.ownerEntityId) then
      self.ownerEntityId = nil
    end
  end

  if self.ownerEntityId == nil then
    local playerIds = world.playerQuery(self.position, 50)
    for _, playerId in pairs(playerIds) do
      if world.entityUuid(playerId) == storage.ownerUuid then
        self.ownerEntityId = playerId
        break
      end
    end
  end

  -- Owner is nowhere around
  if self.ownerEntityId == nil then
    return false
  end

  local ownerPosition = world.entityPosition(self.ownerEntityId)
  local toOwner = world.distance(ownerPosition, self.position)
  local distance = math.abs(toOwner[1])

  local movement
  if distance > captiveState.teleportDistance then
    movement = 0
    entity.setPosition(ownerPosition)
  elseif distance < captiveState.closeDistance then
    stateData.running = false
    movement = 0
  elseif toOwner[1] < 0 then
    movement = -1
  elseif toOwner[1] > 0 then
    movement = 1
  end

  if distance > captiveState.runDistance then
    stateData.running = true
  end

  entity.setAnimationState("attack", "idle")
  move({ movement, toOwner[2] }, captiveState.closeDistance)
  entity.setRunning(stateData.running)

  return false
end
