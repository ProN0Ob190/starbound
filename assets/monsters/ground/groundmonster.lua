function init()
  self.position = {0, 0}

  -- 0 for inside territory, -1 for territory to the left of us, 1 for
  -- territory to the right of us.
  self.territory = 0

  self.target = 0
  self.toTarget = {0, 0}
  self.fromTarget = {0, 0}

  self.lastTargetPosition = {0, 0}
  self.staleTargetTime = 1.0
  self.staleTargetTimer = 0
  self.skillOptions = {}
  self.noOptionCount = 0

  self.aggressive = entity.configParameter("alwaysAggressive", false) or entity.configParameter("aggressive", false)

  if capturepod ~= nil then
    capturepod.onInit()
  end

  self.skillTimer = 0

  self.targetSearchTimer = 0
  self.targetHoldTimer = 0
  
  self.lastAggressGroundPosition = {0, 0}
  self.stuckCount = 0
  self.stuckPosition = {0, 0}
  self.onGround = entity.onGround()

  self.isBlocked = false
  self.willFall = false

  self.pathing = {}

  self.dead = false

  self.jumpTimer = 0

  self.painSoundTimer = 0
  self.idleSoundTimer = 0

  local states = stateMachine.scanScripts(entity.configParameter("scripts"), "(%a+State)%.lua")
  local attacks = stateMachine.scanScripts(entity.configParameter("scripts"), "(%a+Attack)%.lua")
  for _, attack in pairs(attacks) do
    table.insert(states, 1, attack)
  end
  local specials = stateMachine.scanScripts(entity.configParameter("scripts"), "(%a+Special)%.lua")
  for _, special in pairs(specials) do
    table.insert(states, 1, special)
  end

  self.skillCooldownTimers = {}
  self.skillParameters = {}
  for _, skillName in pairs(entity.configParameter("skills")) do
    local params = entity.configParameter(skillName)

    --create generic attacks from factories
    if params and params.factory then
      if type(_ENV[params.factory]) == "function" then
        if not _ENV[skillName] then
          _ENV[skillName] = _ENV[params.factory](skillName)
          table.insert(states, 1, skillName)
        else
          world.logInfo("Failed to create skill %s from factory %s: Table %s already exists in this context", skillName, params.factory, skillName)
        end
      else
        world.logInfo("Failed to create skill %s from factory %s: factory function does not exist in this context", skillName, params.factory)
      end
    end

    self.skillParameters[skillName] = loadSkillParameters(skillName)
    self.skillCooldownTimers[skillName] = 0
  end

  self.skillChains = {}

  self.state = stateMachine.create(states)

  self.state.enteringState = function(stateName)
    if isSkillState(stateName) then
      self.skillTimer = self.skillParameters[stateName].skillTimeLimit

      --increment or reset the attack chain tracker
      if self.skillChains[stateName] then
        self.skillChains[stateName] = self.skillChains[stateName] + 1
      else
        self.skillChains = { [stateName] = 1 }
      end
    end
  end

  self.state.leavingState = function(stateName)
    entity.setActiveSkillName(nil)
    if isSkillState(stateName) then
      setAggressive(true, false)
      self.skillCooldownTimers[stateName] = self.skillParameters[stateName].cooldownTime
    end
  end

  entity.setDeathSound(entity.randomizeParameter("deathNoise"))
  entity.setDeathParticleBurst(entity.configParameter("deathParticles"))
end

--------------------------------------------------------------------------------
-- get the skill parameters from the relevant configParameter and make necessary adjustments
function loadSkillParameters(skillName)
  -- world.logInfo("%s %s loading parameters for skill %s", entity.type(), entity.id(), skillName)
  if type(_ENV[skillName].loadSkillParameters) == "function" then
    return _ENV[skillName].loadSkillParameters()
  elseif entity.configParameter(skillName) then
    local params = entity.configParameter(skillName)

    local xAdjust = entity.configParameter("projectileSourcePosition", {0, 0})[1]
    local yAdjust = -(entity.boundBox()[2] + 2.5) + entity.configParameter("projectileSourcePosition", {0, 0})[2]

    for i, rect in ipairs(params.startRects) do
      local startRect = normalizeRect(rect)

      --adjust rect for monster mouth position
      if startRect[1] > 0 then
        startRect[1] = startRect[1] + xAdjust
      elseif startRect[1] < 0 then
        startRect[1] = startRect[1] - xAdjust
      end
      if startRect[3] > 0 then
        startRect[3] = startRect[3] + xAdjust
      elseif startRect[1] < 0 then
        startRect[3] = startRect[3] - xAdjust
      end

      --adjust rect for monster standing height compared to player
      startRect[2] = startRect[2] + yAdjust
      startRect[4] = startRect[4] + yAdjust

      params.startRects[i] = startRect

      --adjust corresponding approachPoint
      local approachPoint = params.approachPoints[i]
      if approachPoint[1] > 0 then
        approachPoint[1] = approachPoint[1] + xAdjust
      elseif approachPoint[1] < 0 then
        approachPoint[1] = approachPoint[1] - xAdjust
      end

      approachPoint[2] = approachPoint[2] + yAdjust

      params.approachPoints[i] = approachPoint
    end

    return params
  else
    world.logInfo("Unable to load parameters for skill %s!", skillName)
  end
end

--------------------------------------------------------------------------------
function damage(args)
  if capturepod ~= nil and capturepod.onDamage(args) then
    return
  end

  --execute skill hooks
  for skillName, params in pairs(self.skillParameters) do
    if type(_ENV[skillName].onDamage) == "function" then
      _ENV[skillName].onDamage(args)
    end
  end

  if args.sourceId ~= self.target and args.sourceId ~= 0 then setTarget(args.sourceId) end

  if self.painSoundTimer <= 0 then
    entity.playSound(entity.randomizeParameter("painNoise"))
    self.painSoundTimer = entity.configParameter("painSoundTimer")
  end

  if entity.health() <= 0 then
    if self.state.pickState({ knockout = true }) then
      world.callScriptedEntity(args.sourceId, "monsterKilled", entity.id())
    end
  end

  local entityId = entity.id()
  local damageNotificationRegion = entity.configParameter("damageNotificationRegion", { -10, -4, 10, 4 })
  world.monsterQuery(
    vec2.add({ damageNotificationRegion[1], damageNotificationRegion[2] }, self.position),
    vec2.add({ damageNotificationRegion[3], damageNotificationRegion[4] }, self.position),
    {
      withoutEntityId = entityId,
      inSightOf = entityId,
      callScript = "monsterDamaged",
      callScriptArgs = { entityId, entity.seed(), args.sourceId }
    }
  )
end

--------------------------------------------------------------------------------
-- Called when a nearby monster has been damaged (by anything)
function monsterDamaged(entityId, entitySeed, damageSourceId)
  if entitySeed == entity.seed() then
    self.state.pickState({ familyMemberDamagedBy = damageSourceId })
  end
end

--------------------------------------------------------------------------------
-- Called when a monster has been killed, on the entity that dealt the death-blow
function monsterKilled(entityId)
  if capturepod ~= nil then
    capturepod.onMonsterKilled()
  end
end

--------------------------------------------------------------------------------
function shouldDie()
  return self.dead
end

--------------------------------------------------------------------------------
function die()
  if capturepod ~= nil then
    capturepod.onDie()
  end
end

--------------------------------------------------------------------------------
function main()
  self.position = entity.position()
  self.onGround = entity.onGround()

  if storage.basePosition == nil then
    storage.basePosition = self.position
  end

  local dt = entity.dt()
  local inState = self.state.stateDesc()

  --don't automatically switch states in combat
  self.state.autoPickState = not hasTarget()

  if entity.stunned() or inState == "stunState" or inState == "fleeState" or knockedOut() then
    self.state.update(dt)
  else
    checkTerritory()
    track()

    if not inSkill() and hasTarget() then
      --calculate skill positions relative to target
      updateSkillOptions()
      
      --this should end up in skills, approach, or fall back into flee
      self.state.pickState()
    end

    if not self.state.update(dt) then
      if hasTarget() then
        -- Force flee
        self.state.pickState({flee = true})
      else
        -- Force wandering
        self.state.pickState({wander = true})
      end
    end
  end

  if hasTarget() then
    drawDebugSkillOptions()
  end

  decrementTimers()
  
  entity.setScriptDelta(hasTarget() and 1 or 10)
end

--------------------------------------------------------------------------------
function move(delta, jumpThresholdX, changeFacing)
  checkTerrain(delta[1])

  if delta[1] > 0 then
    if changeFacing ~= false then setFacingDirection(1) end
    entity.moveRight()
  elseif delta[1] < 0 then
    if changeFacing ~= false then setFacingDirection(-1) end
    entity.moveLeft()
  end

  if self.jumpTimer > 0 and not self.onGround then
    entity.holdJump()
  else
    if self.jumpTimer <= 0 then
      if jumpThresholdX == nil then jumpThresholdX = 4 end

      -- We either need to be blocked by something, the target is above us and
      -- we are about to fall, or the target is significantly high above us
      local doJump = false
      if isBlocked() then
        doJump = true
      elseif (delta[2] >= 0 and willFall() and math.abs(delta[1]) > 7) then
        doJump = true
      elseif (math.abs(delta[1]) < jumpThresholdX and delta[2] > entity.configParameter("jumpTargetDistance")) then
        doJump = true
      end

      if doJump then
        self.jumpTimer = entity.randomizeParameterRange("jumpTime")
        jump()
      end
    end
  end

  if delta[2] < 0 then
    entity.moveDown()
  end

  if not self.onGround then
    entity.setAnimationState("movement", "jump")
  elseif delta[1] ~= 0 then
    entity.setAnimationState("movement", "run")
  else
    entity.setAnimationState("movement", "idle")
  end
end

--------------------------------------------------------------------------------
function jump()
  entity.jump()
  entity.playSound(entity.randomizeParameter("jumpNoise"))
end

--------------------------------------------------------------------------------
function moveX(direction)
  checkTerrain(direction)

  if direction < 0 then
    entity.moveLeft()
  elseif direction > 0 then
    entity.moveRight()
  end
end

--------------------------------------------------------------------------------
-- NOTE: this will be inaccurate if called more than once per tick
function checkStuck()
  local newPos = entity.position()
  if newPos[1] == self.stuckPosition[1] and newPos[2] == self.stuckPosition[2] then
    self.stuckCount = self.stuckCount + 1
  else
    self.stuckCount = 0
    self.stuckPosition = newPos
  end

  return self.stuckCount
end

--------------------------------------------------------------------------------
function calculateSeparationMovement()
  local entityIds = world.monsterQuery(self.position, 0.5, { withoutEntityId = entity.id(), order = "nearest" })
  if #entityIds > 0 then
    local separationMovement = world.distance(self.position, world.entityPosition(entityIds[1]))
    return util.toDirection(separationMovement[1])
  end

  return 0
end

--------------------------------------------------------------------------------
function travelTime(distance)
  local runSpeed = entity.runSpeed()
  return math.abs(distance / runSpeed)
end

--------------------------------------------------------------------------------
-- estimate the maximum jump duration
function jumpTime()
  return (2 * entity.jumpSpeed()) / (world.gravity(entity.position()) * 1.5)
end

--------------------------------------------------------------------------------
-- estimate the maximum jump height
function jumpHeight()
  return (entity.jumpSpeed() * jumpTime()) / 4
end

--------------------------------------------------------------------------------
function faceTarget()
  if self.onGround then
    if self.toTarget[1] < 0 then
      entity.setFacingDirection(-1)
    elseif self.toTarget[1] > 0 then
      entity.setFacingDirection(1)
    end
  end
end

--------------------------------------------------------------------------------
function setFacingDirection(direction)
  if self.onGround then
    entity.setFacingDirection(direction)
  end
end

--------------------------------------------------------------------------------
--TODO: this could probably be further optimized by creating a list of discrete points and using sensors... project for another time
function checkTerrain(direction)
  --normalize to 1 or -1
  direction = direction > 0 and 1 or -1

  local reverse = false
  if direction ~= nil then
    reverse = direction ~= entity.facingDirection()
  end

  local boundBox = entity.boundBox()

  -- update self.isBlocked
  local blockLine
  if not reverse then
    blockLine = {entity.toAbsolutePosition({boundBox[3] + 0.75, boundBox[4]}), entity.toAbsolutePosition({boundBox[3] + 0.75, boundBox[2] - 1.0})}
  else
    blockLine = {entity.toAbsolutePosition({-boundBox[3] - 0.75, boundBox[4]}), entity.toAbsolutePosition({-boundBox[3] - 0.75, boundBox[2] - 1.0})}
  end

  local blockBlocks = world.collisionBlocksAlongLine(blockLine[1], blockLine[2])
  self.isBlocked = false
  if #blockBlocks > 0 then
    --check for basic blockage
    local topOffset = blockBlocks[1][2] - blockLine[2][2]
    if topOffset > 2.75 then
      self.isBlocked = true
    elseif topOffset > 0.75 then
      --also check for that stupid little hook ledge thing
      self.isBlocked = not world.pointCollision({blockBlocks[1][1] - direction, blockBlocks[1][2] - 1})
    end
  end

  -- world.debugLine(blockLine[1], blockLine[2], self.isBlocked and "red" or "blue")
  -- if #blockBlocks > 0 then world.debugPoint({blockBlocks[1][1] - direction, blockBlocks[1][2] - 1}, self.isBlocked and "red" or "blue") end

  -- update self.willFall
  local fallLine
  if reverse then
    fallLine = {entity.toAbsolutePosition({-0.5, boundBox[2] - 0.75}), entity.toAbsolutePosition({boundBox[3], boundBox[2] - 0.75})}
  else
    fallLine = {entity.toAbsolutePosition({0.5, boundBox[2] - 0.75}), entity.toAbsolutePosition({-boundBox[3], boundBox[2] - 0.75})}
  end
  self.willFall =
      world.lineCollision(fallLine[1], fallLine[2]) == false and
      world.lineCollision({fallLine[1][1], fallLine[1][2] - 1}, {fallLine[2][1], fallLine[2][2] - 1}) == false

  -- world.debugLine(fallLine[1], fallLine[2], self.willFall and "red" or "blue")
  -- world.debugLine({fallLine[1][1], fallLine[1][2] - 1}, {fallLine[2][1], fallLine[2][2] - 1}, self.willFall and "red" or "blue")
end

--------------------------------------------------------------------------------
function isBlocked()
  return self.isBlocked
end

--------------------------------------------------------------------------------
function willFall()
  return self.willFall
end

--------------------------------------------------------------------------------
function checkTerritory()
  local tdist = entity.configParameter("territoryDistance")
  local hdist = world.distance(self.position, storage.basePosition)[1]

  if hdist > tdist then
    self.territory = -1
    return
  elseif hdist < -tdist then
    self.territory = 1
  else
    self.territory = 0
  end
end

--------------------------------------------------------------------------------
function track()
  -- Keep holding on our target while we are attacking
  if not world.entityExists(self.target) or (not inSkill() and self.targetHoldTimer <= 0) then
    setTarget(0)
  elseif inSkill() then
    self.targetHoldTimer = entity.configParameter("targetHoldTime")
  end

  local doAggroHop = false
  if self.aggressive and self.target == 0 and self.targetSearchTimer <= 0 then
    -- Use either the territorialTargetRadius or the minimalTargetRadius,
    -- depending on whether we are in our territory or not
    local targetId
    if self.territory == 0 then
      targetId = entity.closestValidTarget(entity.configParameter("territorialTargetRadius"))
    else
      targetId = entity.closestValidTarget(entity.configParameter("minimalTargetRadius"))
    end

    if targetId ~= 0 then
      -- Pets don't attack npcs unless they are attacking the owner
      if isCaptive() and world.isNpc(targetId) and world.callScriptedEntity(targetId, "attackTargetId") ~= self.ownerEntityId then
        targetId = 0
      end

      setTarget(targetId)
      doAggroHop = true
    end

    self.targetSearchTimer = entity.configParameter("targetSearchTime")
  end

  if hasTarget() then
    self.toTarget = entity.distanceToEntity(self.target)
  else
    self.toTarget = {0, 0}
  end

  if doAggroHop then
    faceTarget()
    self.state.pickState({aggroHop=true})
  end

  self.fromTarget = {-self.toTarget[1], -self.toTarget[2]}
end

--------------------------------------------------------------------------------
function hasTarget()
  return self.target ~= 0
end

--------------------------------------------------------------------------------
function setTarget(target)
  if target ~= 0 then
    self.targetHoldTimer = entity.configParameter("targetHoldTime")

    if self.target ~= target then
      entity.playSound(entity.randomizeParameter("turnHostileNoise"))
    end
  end

  self.target = target
end

--------------------------------------------------------------------------------
function setAggressive(enabled, damageOnTouch)
  if enabled then
    entity.setAggressive(true)
  else
    local aggressive = entity.configParameter("alwaysAggressive", false)
    entity.setAggressive(aggressive)
    if not aggressive then
      damageOnTouch = false
    end
  end

  if damageOnTouch then
    entity.setDamageOnTouch(true)
    entity.setParticleEmitterActive("damage", true)
  else
    entity.setDamageOnTouch(false)
    entity.setParticleEmitterActive("damage", false)
  end
end

--------------------------------------------------------------------------------
function updateSkillOptions()
  if not hasTarget() then return nil end

  local targetMoveTolerance = 0.5
  local collisionTolerance = 2

  local newTargetPosition = world.entityPosition(self.target)
  local targetMovement = world.distance(self.lastTargetPosition, newTargetPosition)

  --if target has moved or information is stale, perform full update
  if self.staleTargetTimer <= 0 or math.abs(targetMovement[1]) > targetMoveTolerance or math.abs(targetMovement[2]) > targetMoveTolerance then
    local validOptionCount = 0
    self.skillOptions = {}

    --find starting points and rects for each skill
    for skillName, params in pairs(self.skillParameters) do
      for i, offset in ipairs(self.skillParameters[skillName].approachPoints) do
        local approachPoint = {newTargetPosition[1] + offset[1], newTargetPosition[2] + offset[2]}
        local startRect = translate(self.skillParameters[skillName].startRects[i], newTargetPosition)

        self.skillOptions[#self.skillOptions + 1] = {
          skillName = skillName,
          approachPoint = approachPoint,
          startRect = startRect,
          valid = false
        }

        approachPoint = world.resolvePolyCollision(entity.configParameter("movementSettings.collisionPoly"), approachPoint, collisionTolerance)
        if approachPoint
           and pointWithinRect(approachPoint, startRect) --approachPoint hasn't been shifted out of the startRect
           and (params.requireLos == false or world.lineCollision(approachPoint, newTargetPosition) == false) --space is in LoS of target
           and self.skillCooldownTimers[skillName] <= travelTime(world.distance(entity.position(), approachPoint)[1]) + 0.4 --skill will be ready when we get there
            then

          --now check for ground below. first try a line down from the approach point
          local canStand = world.lineCollision(approachPoint, {approachPoint[1], startRect[2] + entity.boundBox()[2]}, false)

          --if that fails, try placing a collision poly at the bottom edge of the startRect
          if not canStand then
            local fallPoint = {approachPoint[1], startRect[2]}
            local resolvedFallPoint = world.resolvePolyCollision(entity.configParameter("movementSettings.collisionPoly"), fallPoint, collisionTolerance)

            if (resolvedFallPoint == nil) or math.abs(fallPoint[2] - resolvedFallPoint[2]) > 0.2 then
              if resolvedFallPoint and pointWithinRect(resolvedFallPoint, startRect) then approachPoint = resolvedFallPoint end
              canStand = true
            end
          end

          if canStand then
            self.skillOptions[#self.skillOptions].approachPoint = approachPoint
            self.skillOptions[#self.skillOptions].valid = true
            validOptionCount = validOptionCount + 1
          end
        end
      end
    end

    if validOptionCount == 0 then
      self.noOptionCount = self.noOptionCount + 1
    else
      self.noOptionCount = 0
    end

    self.lastTargetPosition = newTargetPosition
    self.staleTargetTimer = self.staleTargetTime
  end

  --update deltas, distances and scores
  for _, option in pairs(self.skillOptions) do
    option.approachDelta = world.distance(option.approachPoint, entity.position())
    option.approachDistance = world.magnitude(option.approachDelta)
    
    option.score = -option.approachDistance
    if option.valid == false then option.score = -1000 end

    if self.skillChains[option.skillName] then
      option.score = option.score - self.skillChains[option.skillName]
    end
  end
  
  --rank options
  table.sort(self.skillOptions, function(a,b) return a.score > b.score end)
end

--------------------------------------------------------------------------------
-- adjusts the vec2 or rect by the specified vec2
-- TODO: this should probably be in util
function translate(pointOrRect, offset)
  if #pointOrRect == 4 then
    return {pointOrRect[1] + offset[1], pointOrRect[2] + offset[2], pointOrRect[3] + offset[1], pointOrRect[4] + offset[2]}
  elseif #pointOrRect == 2 then
    return {pointOrRect[1] + offset[1], pointOrRect[2] + offset[2]}
  end
end

--------------------------------------------------------------------------------
-- order the X and Y pairs of a {x1, y1, x2, y2} rect
function normalizeRect(rect)
  if rect[1] > rect[3] then rect[1], rect[3] = rect[3], rect[1] end
  if rect[2] > rect[4] then rect[2], rect[4] = rect[4], rect[2] end
  return rect
end

--------------------------------------------------------------------------------
-- simple inclusion test, requires normalized rect
function pointWithinRect(point, rect)
  local dist1, dist2 = world.distance(point, {rect[1], rect[2]}), world.distance(point, {rect[3], rect[4]})
  return dist1[1] > 0 and dist1[2] > 0 and dist2[1] < 0 and dist2[2] < 0
end

--------------------------------------------------------------------------------
-- draw lines to display the specified rect {x1, y1, x2, y2} in the specified color, optionally offset by basePos
function drawDebugRect(rect, color, basePos)
  if basePos then rect = translate(rect, basePos) end
  world.debugLine({rect[1], rect[2]}, {rect[1], rect[4]}, color)
  world.debugLine({rect[1], rect[2]}, {rect[3], rect[2]}, color)
  world.debugLine({rect[3], rect[4]}, {rect[1], rect[4]}, color)
  world.debugLine({rect[3], rect[4]}, {rect[3], rect[2]}, color)
end

--------------------------------------------------------------------------------
-- draw points and rects for each approach point and valid attack start zone
function drawDebugSkillOptions()
  for _, option in pairs(self.skillOptions) do
    world.debugPoint(option.approachPoint, "green")
    drawDebugRect(option.startRect, option.valid and "#AAFFBB" or "#FF3333")
    world.debugText(option.skillName, {option.startRect[1], option.startRect[4]}, "#BBBBFF")
  end
end

--------------------------------------------------------------------------------
function canStartSkill(skillName)
  if skillName and hasTarget() and not knockedOut() then
    if self.skillCooldownTimers[skillName] <= 0 then
      for _, option in ipairs(self.skillOptions) do
        if option.skillName == skillName and (option.startOnGround == false or entity.onGround()) and pointWithinRect(entity.position(), option.startRect) then
          return true
        end
      end
    end
  end

  return false
end

--------------------------------------------------------------------------------
function canContinueSkill()
  return hasTarget() and
    self.skillTimer > 0
end

--------------------------------------------------------------------------------
function inSkill()
  local stateName = self.state.stateDesc()

  if stateName == nil then
    stateName = ""
  end

  return stateName == "aggroHopState" or isSkillState(stateName)
end

--------------------------------------------------------------------------------
function isSkillState(stateName)
  return string.find(stateName, 'Attack$') or string.find(stateName, 'Special$')
end

--------------------------------------------------------------------------------
function knockedOut()
  return self.state.stateDesc() == "knockoutState"
end

--------------------------------------------------------------------------------
function isCaptive()
  return capturepod ~= nil and capturepod.isCaptive()
end

--------------------------------------------------------------------------------
function decrementTimers()
  dt = entity.dt()

  self.targetSearchTimer = self.targetSearchTimer - dt
  self.idleSoundTimer = self.idleSoundTimer - dt
  self.jumpTimer = self.jumpTimer - dt
  self.targetHoldTimer = self.targetHoldTimer - dt
  self.skillTimer = self.skillTimer - dt
  self.painSoundTimer = self.painSoundTimer - dt
  self.staleTargetTimer = self.staleTargetTimer - dt

  for k,cooldown in pairs(self.skillCooldownTimers) do
    self.skillCooldownTimers[k] = cooldown - dt
  end
end