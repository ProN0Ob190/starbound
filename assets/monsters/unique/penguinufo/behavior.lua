function init(args)
  self.tookDamage = false
  self.dead = false

  self.minionState = {
    timer = 0,
    spawnTimer = 0,
    slots = { 0, 0, 0, 0 }
  }

  -- These are in a specific order, since each state is moved to the end of the
  -- list when it ends, ensuring that states are performed in the same order
  -- each time (if the state.enter functions allow that)
  self.state = stateMachine.create({
    "dieState",
    "moveState",
    "spawnReinforcementsAttack",
    "moveState",
    "pulseCannonAttack",
    "moveState",
    "trustAttack",
    "moveState",
    "slamAttack",
  })

  self.state.enteringState = function(stateName)
    -- entity.setFireDirection(entity.configParameter("beamSourceOffset"), { 0, -1 })
  end

  self.state.leavingState = function(stateName)
    -- entity.stopFiring()
    self.state.moveStateToEnd(stateName)
  end

  self.teleportState = stateMachine.create({ "teleportAttack" })
  self.teleportState.autoPickState = false
  self.teleportState.leavingState = function(stateName)
    entity.setParticleEmitterActive("teleport", false)
    entity.setVelocity({ 0, 0 })
    setAnimation(true)
  end

  entity.setDeathParticleBurst("deathPoof")
  setAnimation()
end

function isPenguinMaster()
  return true
end

function minionState()
  return self.minionState
end

function main()
--  entity.playSound("/sfx/npc/unique/ufo_hover_loop.wav")
  util.trackTarget(50.0, 10.0)

  if self.teleportState.hasState() and self.teleportState.update(entity.dt()) then
    -- teleport superceeds all other states
  else
    if not self.state.update(entity.dt()) then
      entity.fly({ 0, 0 }, true)
    end
  end

  self.tookDamage = false
end

function damage(args)
  self.tookDamage = true

  setAnimation()

  if entity.health() <= 0 then
    if not self.state.pickState({ die = true }) then
      self.state.endState()
      self.dead = true
    end
  end
end

function shouldDie()
  return self.dead
end

function findReinforcements()
  local selfId = entity.id()
  local position = entity.position()
  local min = { position[1] - 50.0, position[2] - 50.0 }
  local max = { position[1] + 50.0, position[2] + 50.0 }

  return world.monsterQuery(min, max, { callScript = "isPenguinReinforcement" })
end

function updateMinions(dt, minionState, minionType)
  for minionIndex, entityId in pairs(minionState.slots) do
    if entityId == 0 or not world.entityExists(entityId) then
      if minionType ~= nil and minionState.spawnTimer <= 0 then
        minionState.slots[minionIndex] = world.spawnMonster(minionType, entity.toAbsolutePosition({ 0.0, -4.0 }), { level = entity.level() })
        minionState.spawnTimer = 10.0
      else
        minionState.slots[minionIndex] = 0
      end
    end
  end

  if minionState.spawnTimer > 0 then
    minionState.spawnTimer = minionState.spawnTimer - dt
  end

  -- minionTimer provides a single timer for minions to perform synchronized actions
  minionState.timer = minionState.timer + dt
end

function currentPhase()
  local healthRatio = entity.health() / entity.maxHealth()

  if healthRatio > 0.66 then
    return 1
  elseif healthRatio > 0.33 then
    return 2
  else
    return 3
  end
end

function setAnimation(force)
  if not force and entity.animationState("movement") == "invisible" then
    return
  end

  local phase = currentPhase()

  if phase == 1 then
    entity.setAnimationState("movement", "phase1")
  elseif phase == 2 then
    entity.setAnimationState("movement", "phase2")
  else
    entity.setAnimationState("movement", "phase3")
  end
end

function flyToTargetYOffsetRange(targetPosition)
  local position = entity.position()
  local yOffsetRange = entity.configParameter("targetYOffsetRange")
  local destination = {
    targetPosition[1],
    util.clamp(position[2], targetPosition[2] + yOffsetRange[1], targetPosition[2] + yOffsetRange[2])
  }

  if math.abs(destination[2] - position[2]) < 1.0 then
    return true
  else
    entity.flyTo(destination, true)
  end

  return false
end

function moveTo(destination)
  local movement = world.distance(destination, entity.position())
  entity.setVelocity(vec2.div(movement, entity.dt()))
end

function shouldTeleport()
  return currentPhase() > 1 and math.random(100) > 20
end

function smashBlockingTiles(position, targetPosition, direction, regions)
  for _, region in pairs(regions) do
    local positionedRegion = {
      region[1] + position[1],
      region[2] + position[2],
      region[3] + position[1],
      region[4] + position[2]
    }

    if (direction[2] < 0 and targetPosition[2] <= positionedRegion[4]) or
       (direction[2] > 0 and targetPosition[2] >= positionedRegion[2]) then
      if world.rectCollision(positionedRegion, true) then
        local midpoint = {
          region[1] + (region[3] - region[1]) / 2,
          region[2] + (region[4] - region[2]) / 2
        }
        -- entity.setFireDirection(midpoint, direction)
        -- entity.startFiring("blockbreaker")
        break
      end
    end
  end
end

--------------------------------------------------------------------------------
moveState = {}

moveState.enter = function()
  return {
    timer = 0,
    basePosition = entity.position()
  }
end

moveState.update = function(dt, stateData)
  -- entity.stopFiring()

  stateData.timer = stateData.timer + dt

  local angle = 2.0 * math.pi * stateData.timer / 4.0
  local targetPosition = {
    stateData.basePosition[1] + 15.0 * math.sin(angle),
    stateData.basePosition[2] + 2.0 * math.sin(angle * 5.0)
  }
  entity.flyTo(targetPosition, true)

  if self.targetPosition ~= nil then
    -- Avoid targets that jump, but don't get too far away
    local yOffsetRange = entity.configParameter("targetYOffsetRange")
    stateData.basePosition[2] = util.clamp(
      stateData.basePosition[2],
      self.targetPosition[2] + yOffsetRange[1],
      self.targetPosition[2] + yOffsetRange[2]
    )

    -- Move base position towards target, so we dont get too far away
    local toTarget = world.distance(self.targetPosition, stateData.basePosition)
    stateData.basePosition[1] = stateData.basePosition[1] + toTarget[1] * 0.1
  end

  local position = entity.position()
  if targetPosition[2] < position[2] then
    smashBlockingTiles(entity.position(), targetPosition, { 0, -1 }, entity.configParameter("slamAttackBlockedRegions"))
  else
    smashBlockingTiles(entity.position(), targetPosition, { 0, 1 }, entity.configParameter("moveUpBlockedRegions"))
  end

  entity.configParameter("slamAttackBlockedRegions")

  if currentPhase() < 3 then
    updateMinions(dt, self.minionState)
  else
    updateMinions(dt, self.minionState, "penguinMiniUfo")
  end

  if stateData.timer > 4.0 then
    entity.flyTo(stateData.basePosition, true)
    return true
  else
    return false
  end
end

--------------------------------------------------------------------------------
pulseCannonAttack = {}

pulseCannonAttack.enter = function()
  if self.targetPosition == nil then return nil end

  local toTarget = world.distance(self.targetPosition, entity.position())
  return {
    timer = 0,
    deltaX = 10.0 * toTarget[1] / math.abs(toTarget[1]),
    lastPosition = nil,
    teleport = shouldTeleport()
  }
end

pulseCannonAttack.update = function(dt, stateData)
  local position = entity.position()

  if false then --not entity.isFiring() then
    if stateData.teleport then
      self.teleportState.pickState()
      stateData.teleport = false
      return false
    end

    if flyToTargetYOffsetRange({ position[1], self.targetPosition[2] }) then
      -- entity.startFiring("pulsecannon", true)
    else
      return false
    end
  end

  if false then --entity.isFiring() then
    -- Change direction if stuck, or too far away
    if stateData.lastPosition ~= nil and world.magnitude(world.distance(position, stateData.lastPosition)) < 0.01 then
      stateData.deltaX = -stateData.deltaX
    else
      local toTarget = world.distance(self.targetPosition, position)
      if toTarget[1] * stateData.deltaX < 0 and math.abs(toTarget[1]) > 15.0 then
        stateData.deltaX = -stateData.deltaX
      end
    end
    stateData.lastPosition = position

    entity.flyTo({ position[1] + stateData.deltaX, position[2] }, true)
  end

  updateMinions(dt, self.minionState)

  stateData.timer = stateData.timer + dt
  if stateData.timer > 5.0 then
    return true, 4.0
  else
    return false
  end
end

--------------------------------------------------------------------------------
trustAttack = {}

trustAttack.enter = function()
  if self.targetPosition == nil then return nil end

  local toTarget = world.distance(self.targetPosition, entity.position())
  local distance = math.abs(toTarget[1])
  if distance < 3.0 or distance > 25.0 then
    return nil
  end

  return {
    timer = 0.0,
    fullCircleTime = 4,
    tookDamage = false
  }
end

trustAttack.update = function(dt, stateData)
  if self.tookDamage then
    stateData.tookDamage = true
    entity.setDamageOnTouch(false)
    entity.setVelocity({0,0})
  end

  if stateData.tookDamage then
    entity.fly({ 0, entity.flySpeed() })
    stateData.timer = stateData.timer + dt
    return stateData.timer > stateData.fullCircleTime * 0.3
  end

  local position = entity.position()

  if stateData.basePosition == nil then
    local startPosition = { position[1], self.targetPosition[2] }
    if flyToTargetYOffsetRange(startPosition) then
      stateData.basePosition = { self.targetPosition[1], position[2] }
      stateData.toTarget = world.distance(vec2.add({ 0, 4.0 }, self.targetPosition), position)

      entity.setDamageOnTouch(true)
    else
      return false
    end
  end

  stateData.timer = stateData.timer + dt

  local timerRatio = stateData.timer / stateData.fullCircleTime
  local angle = math.min(timerRatio * math.pi * 2.0, math.pi)
  local targetPosition = {
    stateData.basePosition[1] - math.cos(angle) * stateData.toTarget[1],
    stateData.basePosition[2] + math.sin(angle) * stateData.toTarget[2]
  }
  moveTo(targetPosition)

  if stateData.timer > stateData.fullCircleTime * 0.3 then
    entity.setDamageOnTouch(false)
    entity.setVelocity({0,0})
    return true, 4.0
  else
    return false
  end
end

--------------------------------------------------------------------------------
spawnReinforcementsAttack = {}

spawnReinforcementsAttack.enter = function()
  local reinforcements = findReinforcements()
  if #reinforcements >= 4 then
    return nil
  end

  return {
    timer = 0,
    basePosition = entity.position(),
    totalTime = 4.0
  }
end

spawnReinforcementsAttack.update = function(dt, stateData)
  local angle = 2.0 * math.pi * stateData.timer / stateData.totalTime
  local sinAngle = math.sin(angle)

  if math.abs(1.0 - math.abs(sinAngle)) < 0.1 then
    local percent = math.random(100)
    if percent > 90 then
      -- entity.startFiring("tankspawn", true)
    elseif percent > 60 then
      -- entity.startFiring("generalspawn", true)
    elseif percent > 30 then
      -- entity.startFiring("rockettrooperspawn", true)
    else
      -- entity.startFiring("trooperspawn", true)
    end

    entity.fly({ 0, 0 }, true)
  else
    local targetPosition = {
      stateData.basePosition[1] + math.sin(angle) * 25.0,
      stateData.basePosition[2]
    }
    entity.flyTo(targetPosition, true)
  end

  updateMinions(dt, self.minionState)

  stateData.timer = stateData.timer + dt
  if stateData.timer >= stateData.totalTime then
    return true
  else
    return false
  end
end

--------------------------------------------------------------------------------
slamAttack = {}

slamAttack.enter = function()
  if self.targetPosition == nil then return nil end

  return {
    direction = 1,
    timer = 0,
    teleport = shouldTeleport()
  }
end

slamAttack.update = function(dt, stateData)
  -- entity.stopFiring()

  local position = entity.position()

  stateData.timer = stateData.timer + dt

  if stateData.direction > 0 then
    local startPosition = { position[1], self.targetPosition[2] }
    if stateData.timer < 2.0 then
      startPosition[1] = self.targetPosition[1]
    end

    if stateData.teleport then
      self.teleportState.pickState()
      stateData.teleport = false
      return false
    end

    if flyToTargetYOffsetRange(startPosition) then
      stateData.direction = -1

      entity.setDamageOnTouch(true)
    else
      return false
    end
  end

  if stateData.timer > 10.0 then
    entity.setDamageOnTouch(false)
    return true
  end

  if self.targetPosition ~= nil then -- and not entity.isFiring() then
    -- Smash through any attempts at blocking off the target
    smashBlockingTiles(position, self.targetPosition, { 0, -1 }, entity.configParameter("slamAttackBlockedRegions"))
  end

  if entity.onGround() then -- and not entity.isFiring() then
    entity.setDamageOnTouch(false)
    return true
  else
    entity.fly({ 0, -entity.flySpeed() })
  end

  return false
end

--------------------------------------------------------------------------------
teleportAttack = {}

teleportAttack.enter = function()
  if self.targetPosition == nil then return nil end

  entity.setParticleEmitterActive("teleport", true)
  return { timer = 0 }
end

teleportAttack.update = function(dt, stateData)
  if stateData.timer < 0.55 then
    if stateData.timer > 0 then
      entity.setParticleEmitterActive("teleport", false)
    end

    entity.fly({ 0, 0 }, true)
  elseif stateData.timer < 2.0 then
    if entity.animationState("movement") ~= "invisible" then
      entity.setAnimationState("movement", "invisible")
    end

    if self.targetPosition ~= nil then
      moveTo({
        self.targetPosition[1],
        self.targetPosition[2] + entity.configParameter("targetYOffsetRange")[1]
      })
    else
      entity.fly({ 0, 1 }, true)
    end
  else
    entity.setVelocity({ 0, 0 })
    entity.fly({ 0, 0 }, true)
    return true
  end

  stateData.timer = stateData.timer + dt
  return false
end

--------------------------------------------------------------------------------
dieState = {}

dieState.enterWith = function(params)
  if not params.die then return nil end

  self.teleportState.endState()

  -- entity.stopFiring()
  -- entity.startFiring("deathexplosion")

  return {
    timer = 6.0,
    basePosition = entity.position(),
  }
end

dieState.update = function(dt, stateData)
  if entity.onGround() then
    if stateData.timer > 1.6 then
      stateData.timer = 1.6
    end

    entity.rotateGroup("all", -13 * math.pi / 180)

    if stateData.timer > 1.0 then
      entity.moveLeft()
    end
  else
    if stateData.timer > 4.0 then
      local inverseTimer = 6.0 - stateData.timer
      local angle = stateData.timer * 2.0 * math.pi
      local sinAngle = math.sin(angle)
      local radius = 0.5 + stateData.timer / 2.0

      local targetPosition = {
        stateData.basePosition[1] + sinAngle * radius,
        stateData.basePosition[2]
      }
      entity.flyTo(targetPosition, true)

      entity.rotateGroup("all", sinAngle * inverseTimer * math.pi / 180)
    else
      entity.setDamageOnTouch(true)
      entity.moveLeft()
      entity.rotateGroup("all", -13 * math.pi / 180)
    end
  end

  if stateData.timer <= 0.0 then
    self.dead = true
  else
    local explosionAngle = math.random() * math.pi * 2.0
    local explosionOffset = { math.cos(explosionAngle) * 16.0, math.sin(explosionAngle) * 3.0 }
    local explosionPosition = vec2.rotate(explosionOffset, -entity.currentRotationAngle("all"))
    -- entity.setFireDirection(explosionPosition, {1, 0})
  end

  stateData.timer = stateData.timer - dt
  return false
end