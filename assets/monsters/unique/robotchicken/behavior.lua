function init(args)
  self.dead = false
  self.sensors = sensors.create()

  self.state = stateMachine.create({
    "moveState",
    "fleeState",
    "dieState"
  })
  self.state.leavingState = function(stateName)
    entity.setAnimationState("movement", "idle")
    entity.setRunning(false)
  end

  entity.setAggressive(false)
  entity.setAnimationState("movement", "idle")
end

function main()
  self.state.update(entity.dt())
  self.sensors.clear()
end

function damage(args)
  if entity.health() <= 0 then
    self.state.pickState({ die = true })
  else
    self.state.pickState({ targetId = args.sourceId })
  end
end

function shouldDie()
  return self.dead
end

function move(direction)
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
  if self.sensors.blockedSensors.collision.any(true) then
    stateData.direction = -stateData.direction
  end

  entity.setAnimationState("movement", "move")
  move(stateData.direction)

  stateData.timer = stateData.timer - dt
  if stateData.timer <= 0 then
    return true, 1.0
  end

  return false
end

--------------------------------------------------------------------------------
fleeState = {}

function fleeState.enterWith(args)
  if args.die then return nil end
  if args.targetId == nil then return nil end
  if self.state.stateDesc() == "fleeState" then return nil end

  return {
    targetId = args.targetId,
    timer = entity.configParameter("fleeMaxTime"),
    distance = entity.randomizeParameterRange("fleeDistanceRange")
  }
end

function fleeState.update(dt, stateData)
  entity.setRunning(true)
  entity.setAnimationState("movement", "run")

  local targetPosition = world.entityPosition(stateData.targetId)
  if targetPosition ~= nil then
    local toTarget = world.distance(targetPosition, entity.position())
    if world.magnitude(toTarget) > stateData.distance then
      return true
    else
      stateData.direction = -toTarget[1]
    end
  end

  if stateData.direction ~= nil then
    move(stateData.direction)
  else
    return true
  end

  stateData.timer = stateData.timer - dt
  return stateData.timer <= 0
end

--------------------------------------------------------------------------------
dieState = {}

function dieState.enterWith(args)
  if not args.die then return nil end
  if self.state.stateDesc() == "dieState" then return nil end

  return {}
end

function dieState.update(dt, stateData)
  local animationState = entity.animationState("movement")
  if animationState == "invisible" then
    self.dead = true
  elseif animationState ~= "die" then
    entity.setAnimationState("movement", "die")
  end

  return false
end
