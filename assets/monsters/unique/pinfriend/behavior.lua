function init(args)
  self.dead = false
  self.targetId = nil

  self.state = stateMachine.create({
    "moveState",
    "attackState",
    "captiveState"
  })
  self.state.leavingState = function(stateName)
    entity.setAnimationState("movement", entity.randomizeParameter("idleAnimations"))
  end

  entity.setAggressive(false)
  entity.setDeathParticleBurst("deathPoof")

  capturepod.onInit()

  self.movement = groundMovement.create(1, 1, function(animationState)
    entity.setAnimationState("movement", "move")
  end)
end

--------------------------------------------------------------------------------
function main()
  self.state.update(entity.dt())
end

--------------------------------------------------------------------------------
function damage(args)
  if not capturepod.onDamage(args) then
    self.state.pickState(args.sourceId)
  end
end

--------------------------------------------------------------------------------
function move(direction)
  entity.setAnimationState("movement", "move")

  entity.setFacingDirection(direction)
  if direction < 0 then
    entity.moveLeft()
  else
    entity.moveRight()
  end
end

--------------------------------------------------------------------------------
-- Called when a monster has been killed, on the entity that dealt the death-blow
function monsterKilled(entityId)
  capturepod.onMonsterKilled()
end

--------------------------------------------------------------------------------
function die()
  capturepod.onDie()
end

--------------------------------------------------------------------------------
function shouldDie()
  return self.dead or entity.health() <= 0
end

--------------------------------------------------------------------------------
moveState = {}

function moveState.enter()
  if capturepod.isCaptive() then return nil end

  return {
    timer = entity.randomizeParameterRange("moveTimeRange"),
    direction = util.randomDirection()
  }
end

function moveState.update(dt, stateData)
  if not self.movement.move(entity.position(), stateData.direction, false) then
    stateData.direction = -stateData.direction
  end

  stateData.timer = stateData.timer - dt
  if stateData.timer <= 0 then
    return true, entity.randomizeParameterRange("idleTimeRange")
  end

  return false
end

--------------------------------------------------------------------------------
attackState = {}

function attackState.enterWith(targetId)
  if targetId == 0 then return nil end

  attackState.setAggressive(targetId)

  return { timer = entity.configParameter("attackTargetHoldTime") }
end

function attackState.update(dt, stateData)
  util.trackExistingTarget()

  if self.attackHoldTimer ~= nil then
    self.attackHoldTimer = self.attackHoldTimer - dt
    if self.attackHoldTimer > 0 then
      return false
    else
      self.attackHoldTimer = nil
    end
  end

  if self.targetPosition ~= nil then
    local position = entity.position()
    local toTarget = world.distance(self.targetPosition, entity.position())

    if world.magnitude(toTarget) < entity.configParameter("attackDistance") then
      attackState.setAttackEnabled(true)
    else
      attackState.setAttackEnabled(false)
      self.movement.move(position, util.toDirection(toTarget[1]), true)
    end
  end

  if self.targetId == nil then
    stateData.timer = stateData.timer - dt
  else
    stateData.timer = entity.configParameter("attackTargetHoldTime")
  end

  if stateData.timer <= 0 then
    attackState.setAttackEnabled(false)
    attackState.setAggressive(nil)
    return true
  else
    return false
  end
end

function attackState.setAttackEnabled(enabled)
  if enabled then
    entity.setAnimationState("movement", "attack")
    self.attackHoldTimer = entity.configParameter("attackHoldTime")
  else
  end

end

function attackState.setAggressive(targetId)
  self.targetId = targetId

  if targetId ~= nil then
    entity.setAggressive(true)
  else
    entity.setAnimationState("movement", "idle")
    entity.setAggressive(false)
  end
end

function attackState.hasTarget()
  return self.targetId ~= nil
end

--------------------------------------------------------------------------------
captiveState = {
  closeDistance = 4,
  runDistance = 12,
  teleportDistance = 36,
}

function captiveState.enter()
  if not capturepod.isCaptive() or attackState.hasTarget() then return nil end

  return { running = false }
end

function captiveState.enterWith(params)
  if not capturepod.isCaptive() then return nil end

  return { running = false }
end

function captiveState.update(dt, stateData)
  if attackState.hasTarget() then return true end

  if not capturepod.updateOwnerEntityId() then
    -- Owner is nowhere around
    return false
  end

  local position = entity.position()
  local ownerPosition = world.entityPosition(self.ownerEntityId)
  local toOwner = world.distance(ownerPosition, position)
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

  if movement ~= 0 then
    self.movement.move(position, movement, true)
  else
    local animation = entity.animationState("movement")
    local playingIdleAnimation = false
    for _, idleAnimation in pairs(entity.configParameter("idleAnimations")) do
      playingIdleAnimation = playingIdleAnimation or idleAnimation == animation
    end

    if not playingIdleAnimation then
      entity.setAnimationState("movement", entity.randomizeParameter("idleAnimations"))
    end
  end
  entity.setRunning(stateData.running)

  return false
end
