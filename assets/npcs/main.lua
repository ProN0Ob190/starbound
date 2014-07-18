function init(args)
  self.timers = createTimers()

  local states = stateMachine.scanScripts(entity.configParameter("scripts"), "(%a+State)%.lua")
  self.state = stateMachine.create(states)

  self.state.enteringState = function(stateName)
--    debugLog("entering %s", stateName)
  end

  self.state.leavingState = function(stateName)
    self.state.moveStateToEnd(stateName)
    self.stateTargetId = nil
  end

  entity.setInteractive(true)

  self.pathing = {}

  self.noticePlayersRadius = entity.configParameter("noticePlayersRadius", -1)
  self.forgetPlayerTime = entity.configParameter("forgetPlayerTime", 3)

  local primaryItemType = itemType("primary"), false
  self.hasMeleeWeapon = primaryItemType == "sword"
  self.hasRangedWeapon = primaryItemType == "gun"

  local sheathedPrimaryItemType = itemType("sheathedprimary")
  self.hasSheathedMeleeWeapon = sheathedPrimaryItemType == "sword"
  self.hasSheathedRangedWeapon = sheathedPrimaryItemType == "gun"

  self.hasShield = itemType("alt") == "shield"
  self.hasSheathedShield = itemType("sheathedalt") == "shield"

  if storage.attackOnSightIds == nil then
    storage.attackOnSightIds = {}
  end

  if storage.spawnPosition == nil then
    local position = entity.position()

    -- NPCs aren't always placed right on the ground. They may need to be
    -- moved up or down a few blocks so their spawn position is actually on the
    -- ground
    local supportRegion = {
      math.floor(position[1] + 0.5) - 1, math.floor(position[2] + 0.5) - 3,
      math.floor(position[1] + 0.5) + 1, math.floor(position[2] + 0.5) - 2,
    }

    for i = 0, 3, 1 do
      if world.rectCollision(supportRegion, true) then
        supportRegion[2] = supportRegion[2] + 1
        supportRegion[4] = supportRegion[4] + 1
      else
        break
      end
    end

    for i = 0, 3, 1 do
      supportRegion[2] = supportRegion[2] - 1
      supportRegion[4] = supportRegion[4] - 1
      if world.rectCollision(supportRegion, false) then
        break
      end
    end

    storage.spawnPosition = { position[1], supportRegion[2] + 3.5 }
  end
end

--------------------------------------------------------------------------------
function itemType(slot)
  local item = entity.getItemSlot(slot)
  if item ~= nil and item.name ~= "" then
    return world.itemType(item)
  end

  return nil
end

--------------------------------------------------------------------------------
-- Sheathe the current item in the given slot, switching to the previously
-- sheathed item (if there was one)
function swapItemSlot(slot)
  local newItem, oldItem
  if storage["sheathed" .. slot .. "Item"] == nil then
    newItem = entity.getItemSlot("sheathed" .. slot)
    oldItem = entity.getItemSlot(slot)
  else
    newItem = storage["sheathed" .. slot .. "Item"]
    oldItem = nil
  end

  -- Workaround for blank items coming back from getItemSlot as ["", ...]
  if newItem ~= nil and newItem["name"] == "" then
    newItem = nil
  end

  entity.setItemSlot(slot, newItem)
  storage["sheathed" .. slot .. "Item"] = oldItem

  if slot == "primary" then
    self.hasMeleeWeapon, self.hasSheathedMeleeWeapon = self.hasSheathedMeleeWeapon, self.hasMeleeWeapon
    self.hasRangedWeapon, self.hasSheathedRangedWeapon = self.hasSheathedRangedWeapon, self.hasRangedWeapon
  elseif slot == "alt" then
    self.hasShield, self.hasSheathedShield = self.hasSheathedShield, self.hasShield
  end
end

--------------------------------------------------------------------------------
function isAttacking()
  return attackTargetId() ~= nil
end

--------------------------------------------------------------------------------
function attackTargetId()
  if string.find(stateName(), 'AttackState$') then
    return self.attackTargetId
  end

  return nil
end

--------------------------------------------------------------------------------
function stateName()
  local name = self.state.stateDesc()

  if name ~= nil then
    return name
  else
    return ""
  end
end

--------------------------------------------------------------------------------
-- Can differ from the attackTargetId - this entity is the "focus" of the
-- current state, whatever "focus" may mean to that state
function stateTargetId()
  return self.stateTargetId
end

--------------------------------------------------------------------------------
function shouldAttackOnSight(targetId)
  for _, attackOnSightId in pairs(storage.attackOnSightIds) do
    if targetId == attackOnSightId then return true end
  end

  if entity.isValidTarget(targetId) then
    -- Always attack aggressive monsters
    if world.isMonster(targetId, true) then
      return true
    end

    -- Attack other npcs on different damage teams (if they are a valid
    -- target, then they have a different damage team)
    if world.isNpc(targetId) then
      return true
    end
  end

  return false
end

--------------------------------------------------------------------------------
function attack(targetId, sourceId, allowReAttack)
  if targetId == self.attackTargetId and not allowReAttack then
    return true
  end

  if not entity.isValidTarget(targetId) then
    return false
  end

  if self.state.pickState({ attackTargetId = targetId, attackSourceId = sourceId }) then
    self.attackTargetId = targetId

    -- Only re-broadcast attacks if this entity was the originator
    if sourceId == entity.id() then
      sendNotification("attack", { targetId = targetId, sourceId = sourceId, sourceDamageTeam = entity.damageTeam() })
    end

    -- TODO: add a timer to this table so they don't re-attack on sight forever
    table.insert(storage.attackOnSightIds, targetId)

    return true
  else
    return false
  end
end

--------------------------------------------------------------------------------
function stopAttacking(targetId)
  if targetId == self.attackTargetId then
    self.attackTargetId = nil
    return true
  else
    return false
  end
end

--------------------------------------------------------------------------------
function nearbyAttackerCount(targetId)
  local position = world.entityPosition(targetId)
  local radius = entity.configParameter("attackerLimitRadius", 50)
  local attackerIds = world.entityQuery(position, radius, { includedTypes = {"npc"}, callScript = "attackTargetId", callScriptResult = targetId })
  return #attackerIds
end

--------------------------------------------------------------------------------
-- Where "inside" is just a position with a building material in the background
function isInside(position)
  local material = world.material(position, "background")
  return material ~= nil and material ~= "dirt" and material ~= "drysand"
end

--------------------------------------------------------------------------------
-- Returns true if the current time of day (ranging from 0 to 1) falls into one
-- of the buckets defined in the given configuration value. The config value
-- can be defined as one of the following (or a combination thereof):
--
--  // returns true between 0.0 and 0.5
--  [ [ 0, 0.5 ] ]
--
--  // returns true between 0.0 and 0.5 - and between 0.75 and 0.8
--  [ [ 0, 0.5 ], [ 0.75, 0.8 ]
--
--  // returns true starting at <a random time between 0.6 and 0.7> and 0.8
--  [ [ [ 0.6, 0.7 ], 0.8 ] ]
--
function isTimeFor(configKey)
  local timeRanges = entity.configParameter(configKey, nil)
  if timeRanges == nil then return false end

  local timeOfDay = world.timeOfDay()
  for i, timeRange in ipairs(timeRanges) do
    local startTimeOfDay, endTimeOfDay = timeRange[1], timeRange[2]

    if type(startTimeOfDay) == "table" then
      startTimeOfDay = entity.randomizeParameterRange(configKey .. "[" .. (i - 1) .. "][0]", nil)
    end

    if type(endTimeOfDay) == "table" then
      endTimeOfDay = entity.randomizeParameterRange(configKey .. "[" .. (i - 1) .. "][1]", nil)
    end

    if startTimeOfDay == nil then startTimeOfDay = 0 end
    if endTimeOfDay == nil then endTimeOfDay = 1 end

    if timeOfDay > startTimeOfDay and timeOfDay < endTimeOfDay then
      return true
    end
  end

  return false
end

--------------------------------------------------------------------------------
-- Calls receiveNotification for all nearby NPCs
function sendNotification(name, args, radius)
  local selfId = entity.id()
  local notification = {
    name = name,
    handled = false,
    sourceEntityId = selfId,
    args = args
  }

  if radius == nil then
    radius = entity.configParameter("notificationRadius", 25)
  end

  for _, entityId in pairs(world.entityQuery(entity.position(), radius, { includedTypes = {"npc"}, withoutEntityId = selfId })) do
    if entity.entityInSight(entityId) then
      notification.handled = world.callScriptedEntity(entityId, "receiveNotification", notification) or notification.handled
    end
  end

  return notification.handled
end

--------------------------------------------------------------------------------
-- Handles notifications from nearby NPCs
function receiveNotification(notification)
  if notification.name == "attack" then
    local attackTargetId = notification.args.targetId

    if notification.args.sourceDamageTeam ~= nil then
      -- If the source of the notification is on a different team, we
      -- might want to attack _them_ instead of their target
      local damageTeam = entity.damageTeam()
      if damageTeam.type ~= notification.args.sourceDamageTeam.type or
         damageTeam.team ~= notification.args.sourceDamageTeam.team then

        attackTargetId = notification.args.sourceId
      end
    end

    local handled = false

    if not isAttacking() then
      attack(attackTargetId)
      handled = true
    end

    -- Handle death notifications
    if notification.args.dead and not notification.handled then
      if not entity.isValidTarget(notification.sourceEntityId) then
        local name = world.entityName(notification.sourceEntityId)
        if name ~= nil and math.random() < entity.configParameter("deathNoticed.chance", 1.0) then
          self.timers.start(1, function()
            sayToTarget("deathNoticed.dialog", nil, { name = name })
          end)
        end

        handled = true
      end
    end

    return handled
  else
    return self.state.pickState({ notification = notification })
  end

  return false
end

--------------------------------------------------------------------------------
-- Called from C++
function interact(args)
  if self.state.pickState({ interactArgs = args }) then
    if self.tradingConfig ~= nil and self.state.stateDesc() == "merchantState" then
      return { "OpenNpcCraftingInterface", self.tradingConfig }
    end
  end
end

--------------------------------------------------------------------------------
-- Called from C++
function damage(args)
  local dead = entity.health() <= 0
  if not dead and not isAttacking() then
    attack(args.sourceId, entity.id())
  else
    sendNotification("attack", { targetId = args.sourceId, sourceId = entity.id(), sourceDamageTeam = entity.damageTeam(), dead = dead })
  end
end

--------------------------------------------------------------------------------
-- Called from C++
function main()
  noticePlayers()

  local dt = entity.dt()

  self.state.update(dt)
  self.timers.tick(dt)
end

--------------------------------------------------------------------------------
-- Optionally, pick a new state upon a player entering a certian radius (with
-- line of sight
function noticePlayers()
  if self.noticePlayersRadius == -1 then
    return
  end

  if storage.noticedPlayerIds == nil then
    storage.noticedPlayerIds = {}
  end

  local changedState = false
  local time = world.time()

  local playerIds = world.entityQuery(entity.position(), self.noticePlayersRadius, { includedTypes = {"player"} })
  for _, playerId in pairs(playerIds) do
    if entity.entityInSight(playerId) then
      if storage.noticedPlayerIds[playerId] == nil then
        if not changedState then
          changedState = self.state.pickState({ noticedPlayerId = playerId })

          if not changedState and shouldAttackOnSight(playerId) then
            changedState = attack(playerId)
          end

          if changedState then
            storage.noticedPlayerIds[playerId] = time + self.forgetPlayerTime
          end
        end
      else
        storage.noticedPlayerIds[playerId] = time + self.forgetPlayerTime
      end
    end
  end

  -- Forget players we haven't seen in a while
  for playerId, forgetTime in pairs(storage.noticedPlayerIds) do
    if time > forgetTime then
      storage.noticedPlayerIds[playerId] = nil
    end
  end
end

--------------------------------------------------------------------------------
function setFacingDirection(direction)
  entity.setFacingDirection(direction)
  entity.setAimPosition(vec2.add({ util.toDirection(direction), -1 }, entity.position()))
end

--------------------------------------------------------------------------------
function debugLog(format, ...)
  world.logInfo("[" .. entity.id() .. "] " .. format, ...)
end

--------------------------------------------------------------------------------
function debugRect(rect, color)
  world.debugLine({rect[1], rect[2]}, {rect[3], rect[2]}, color)
  world.debugLine({rect[3], rect[2]}, {rect[3], rect[4]}, color)
  world.debugLine({rect[3], rect[4]}, {rect[1], rect[4]}, color)
  world.debugLine({rect[1], rect[4]}, {rect[1], rect[2]}, color)
end

--------------------------------------------------------------------------------
function move(delta, dt, options)
  return moveTo(vec2.add(entity.position(), delta), dt, options)
end

--------------------------------------------------------------------------------
function hasCapability(capability)
  if capability == 'spawnedBy' then
    return true
  end
  return false
end

function spawnedBy(args)
  return entity.configParameter("spawnedBy", nil)
end

--------------------------------------------------------------------------------
-- Valid options:
--   openDoorCallback: function that will be passed a door entity id and should
--                     return true if the door can be opened
--   run: whether npc should run
function moveTo(targetPosition, dt, options)
  if options == nil then options = {} end
  if options.run == nil then options.run = false end

  targetPosition = {
    math.floor(targetPosition[1]) + 0.5,
    math.floor(targetPosition[2]) + 0.5
  }

  -- TODO just check if this is an x-only movement and the path is clear

--  world.debugLine(entity.position(), targetPosition, "red")
--  world.debugPoint(targetPosition, "red")

  local pathTargetPosition = self.pathing.targetPosition
  if pathTargetPosition == nil or
      targetPosition[1] ~= pathTargetPosition[1] or
      targetPosition[2] ~= pathTargetPosition[2] then

    local innerRadius, outerRadius
    if options.fleeDistance ~= nil then
      innerRadius = options.fleeDistance
      outerRadius = options.fleeDistance * 2
    else
      innerRadius = -1
      outerRadius = 1
    end

    if entity.findPath(targetPosition, innerRadius, outerRadius) then
      self.pathing.targetPosition = targetPosition
    else
      self.pathing.targetPosition = nil
    end

    self.pathing.delta = nil
  end

  if self.pathing.targetPosition then
    local pathDelta = entity.followPath()

    -- Store the path delta in case pathfinding doesn't succeed on the next try
    if pathDelta ~= nil then
      self.pathing.delta = pathDelta
    else
      self.pathing.targetPosition = nil
    end
  end

  local position = entity.position()
  local delta
  if self.pathing.delta ~= nil then
    delta = self.pathing.delta
  else
    if options.fleeDistance ~= nil then
      delta = world.distance(position, targetPosition)
    else
      delta = world.distance(targetPosition, position)
    end

    delta = vec2.mul(vec2.norm(delta), math.min(world.magnitude(delta), 2))
  end

  setFacingDirection(delta[1])

  -- Open doors in the way
  local closedDoorIds = world.entityLineQuery(position, { position[1] + util.clamp(delta[1], -2, 2), position[2] }, { includedTypes = {"object"}, callScript = "hasCapability", callScriptArgs = { "closedDoor" } })
  for _, closedDoorId in pairs(closedDoorIds) do
    if options.openDoorCallback == nil or options.openDoorCallback(closedDoorId) then
      world.callScriptedEntity(closedDoorId, "openDoor")
    end
  end

  -- Keep jumping
  if entity.isJumping() or (not entity.onGround() and self.pathing.jumpHoldTimer ~= nil) then
    if self.pathing.jumpHoldTimer ~= nil then
      entity.holdJump()

      self.pathing.jumpHoldTimer = self.pathing.jumpHoldTimer - dt
      if self.pathing.jumpHoldTimer <= 0 then
        self.pathing.jumpHoldTimer = nil
      end
    end

    entity.move(delta[1], options.run)

    return true
  end
  self.pathing.jumpHoldTimer = nil

  local region = {
    math.floor(position[1] + 0.5) - 1, math.floor(position[2] + 0.5) - 3,
    math.floor(position[1] + 0.5) + 1, math.floor(position[2] + 0.5) + 1,
  }
  local endpointGroundRegion = {
    region[1] + delta[1], region[2] + delta[2] - 1,
    region[3] + delta[1], region[2] + delta[2]
  }
  local verticalMovementRatio
  if delta[1] == 0 then
    verticalMovementRatio = 10 -- arbitrary "large" number
  else
    verticalMovementRatio = math.abs(delta[2]) / math.abs(delta[1])
  end

  -- The path might just be taking us up some stairs, so we'll only jump if the
  -- endpoint is not supported, or it's really taking us quite vertical
  if delta[2] > 0 and (not world.rectCollision(endpointGroundRegion, false) or verticalMovementRatio > 2.0) then
-- TODO only jump if we have clearance when adding the deltaY to head pos (i.e. move "region" up by deltaY and check)
    entity.jump()
    self.pathing.jumpHoldTimer = verticalMovementRatio
  elseif delta[2] < 0 and verticalMovementRatio > 1.75 then
-- TODO trace from end of path to feet and see if path is trying to move us through a platform
    -- Drop down through a platform
    entity.moveDown()
  else
    local direction = util.toDirection(delta[1])

    -- Might be a quick hop over an obstruction before we can follow the path,
    -- note that we're not including the first block at the feet in this check,
    -- but are checking a point just inside that block, so we don't always jump
    -- when running up to the top of stairs (unless there is a ledge there)
    local nextStepRegion = {
      region[1] + direction, region[2] + 1,
      region[3] + direction, region[4]
    }
    if world.rectCollision(nextStepRegion, true) then
      entity.jump()
      self.pathing.jumpHoldTimer = 0
      entity.move(direction, options.run)
      return true
    end

    -- Jump over gaps
    local maxFallDistance = 8
    local nextStepLowerRegion = {
      nextStepRegion[1] + direction, nextStepRegion[2] - maxFallDistance,
      nextStepRegion[3] + direction, nextStepRegion[4]
    }

    if not world.rectCollision(nextStepLowerRegion, false) then
      local maxJumpDistance = 8

      local jumpRegion = {
        nextStepRegion[1] + direction, nextStepRegion[2] - maxFallDistance,
        nextStepRegion[3] + direction, nextStepRegion[4] - 2
      }
      for offset = 1, maxJumpDistance, 1 do
        if world.rectCollision(jumpRegion, false) then
          entity.jump()
          entity.move(delta[1], options.run)
          self.pathing.jumpHoldTimer = offset * 0.5
          return true
        end
        jumpRegion[1] = jumpRegion[1] + direction
        jumpRegion[3] = jumpRegion[3] + direction
      end

      return false, "ledge"
    end
  end

  entity.move(delta[1], options.run)

  return true
end

--------------------------------------------------------------------------------
function sayToTarget(dialogType, targetId, tags)
  local dialog = nil

  local withSpecies = dialogType .. "." .. entity.species()

  if targetId ~= nil then
    local targetSpecies = world.entitySpecies(targetId)
    if targetSpecies ~= nil then
      dialog = entity.staticRandomizeParameter(withSpecies .. "." .. targetSpecies)
    end
  end

  if dialog == nil then
    dialog = entity.staticRandomizeParameter(withSpecies .. ".default")
  end

  if dialog == nil then
    dialog = entity.staticRandomizeParameter(withSpecies)
  end

  if dialog == nil then
    dialog = entity.randomizeParameter(dialogType .. ".default")
  end

  if dialog ~= nil then
    return entity.say(dialog, tags)
  end

  return false
end
