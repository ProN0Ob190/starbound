function init(args)
  self.sensors = sensors.create()

  self.state = stateMachine.create({
    "moveState",
    "attackState"
  })

  self.state.leavingState = function(stateName)
    entity.setAnimationState("movement", "idle")
  end

  entity.setDeathParticleBurst("deathPoof")
end

--------------------------------------------------------------------------------
function main()
  if util.trackTarget(entity.configParameter("targetNoticeDistance")) then
    self.state.pickState(self.targetId)
  end

  self.movement = { 0, 0 }
  self.state.update(entity.dt())

  if entity.animationState("movement") ~= "attack" then
    local flockMovement = flocking.calculateMovement("swarpionFlockInfo")
    local movements = { { self.movement, 1.0 } }

    if not self.isFlockLeader then
      table.insert(movements, { flockMovement, entity.configParameter("flockMovementWeight") })
    end

    local combinedMovement = { 0, 0 }
    for i, movementComponent in ipairs(movements) do
      local movement, weight = table.unpack(movementComponent)
      combinedMovement = vec2.add(combinedMovement, vec2.mul(movement, weight))
    end

    self.movement = vec2.norm(combinedMovement)
    move(self.movement)
  end

  self.sensors.clear()
end

--------------------------------------------------------------------------------
function isOnPlatform()
  return entity.onGround() and
      not self.sensors.nearGroundSensor.collisionTrace.any(true) and
      self.sensors.midGroundSensor.collisionTrace.any(true)
end

--------------------------------------------------------------------------------
function swarpionFlockInfo()
  return {
    movement = self.movement,
    isLeader = self.isFlockLeader
  }
end

--------------------------------------------------------------------------------
function move(toTarget)
  entity.setAnimationState("movement", "move")

  if math.abs(toTarget[2]) < 4.0 and isOnPlatform() then
    entity.moveDown()
  end

  entity.setFacingDirection(toTarget[1])
  if toTarget[1] < 0 then
    entity.moveLeft()
  else
    entity.moveRight()
  end
end

--------------------------------------------------------------------------------
moveState = {}

function moveState.enter()
  return {
    timer = entity.randomizeParameterRange("moveTimeRange"),
    direction = util.randomDirection()
  }
end

function moveState.update(dt, stateData)
  if self.sensors.collisionSensors.collision.any(true) then
    stateData.direction = -stateData.direction
  end

  move({ stateData.direction, 0 })

  stateData.timer = stateData.timer - dt
  if stateData.timer <= 0 then
    return true, entity.randomizeParameterRange("idleTimeRange")
  end

  return false
end

--------------------------------------------------------------------------------
attackState = {}

function attackState.enterWith(targetId)
  if targetId == nil then return nil end

  entity.setAggressive(true)
  return {
    timer = entity.configParameter("attackTargetHoldTime"),
    attackPauseTimer = 0,
    lastTargetPosition = self.targetPosition
  }
end

function attackState.update(dt, stateData)
  if entity.animationState("movement") == "attack" then
    entity.setDamageOnTouch(true)
    return false
  end
  entity.setDamageOnTouch(false)

  if stateData.attackPauseTimer > 0 then
    stateData.attackPauseTimer = math.max(0, stateData.attackPauseTimer - dt)
    return false
  end

  local toTarget = world.distance(self.targetPosition, entity.position())
  local distance = world.magnitude(toTarget)

  local attackRange = entity.configParameter("attackRange")
  if distance < attackRange[1] then
    self.movement = { -toTarget[1], toTarget[2] }
  elseif distance > attackRange[2] then
    self.movement = toTarget
  else
    stateData.attackPauseTimer = entity.configParameter("attackPauseTime")
    entity.setAnimationState("movement", "attack")
    entity.setDamageOnTouch(true)
    entity.setFacingDirection(toTarget[1])
  end

  if self.targetId == nil then
    stateData.timer = stateData.timer - dt
  else
    stateData.timer = entity.configParameter("attackTargetHoldTime")
  end

  return stateData.timer <= 0
end

function attackState.leavingState(stateData)
  entity.setAggressive(false)
  entity.setDamageOnTouch(false)
end
