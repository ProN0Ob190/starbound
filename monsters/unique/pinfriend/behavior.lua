function init(args)
  self.state = stateMachine.create({
    "moveState",
    "idleState",
    "attackState"
  })
  self.state.leavingState = function(stateName)
    entity.setAnimationState("movement", "idle")
  end

  entity.setAggressive(false)
  entity.setDeathParticleBurst("deathPoof")
end

function main()
  self.state.update(entity.dt())
end

function damage(args)
  self.state.pickState(args.sourceId)
end

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
moveState = {}

function moveState.enter()
  local direction
  if math.random(100) > 50 then
    direction = 1
  else
    direction = -1
  end

  return {
    timer = entity.randomizeParameterRange("moveTimeRange"),
    direction = direction
  }
end

function moveState.update(dt, stateData)
  local position = entity.position()
  local bounds = entity.configParameter("metaBoundBox")
  bounds = {
    bounds[1] + position[1] + stateData.direction,
    bounds[2] + position[2] + 1,
    bounds[3] + position[1] + stateData.direction,
    bounds[4] + position[2],
  }

  if world.rectCollision(bounds, false) then
    stateData.direction = -stateData.direction
  end

  move(stateData.direction)

  stateData.timer = stateData.timer - dt
  if stateData.timer <= 0 then
    return true, 1.0
  end

  return false
end

--------------------------------------------------------------------------------
idleState = {}

function idleState.enter()
  return { timer = entity.randomizeParameterRange("idleTimeRange") }
end

function idleState.enteringState(stateData)
  entity.setAnimationState("movement", entity.randomizeParameter("idleAnimations"))
end

function idleState.update(dt, stateData)
  stateData.timer = stateData.timer - dt
  return stateData.timer <= 0
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
    local toTarget = world.distance(self.targetPosition, entity.position())

    if world.magnitude(toTarget) < entity.configParameter("attackDistance") then
      attackState.setAttackEnabled(true)
    else
      attackState.setAttackEnabled(false)
      move(util.toDirection(toTarget[1]))
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
