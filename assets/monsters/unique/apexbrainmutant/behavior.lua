function init(args)
  self.sensors = sensors.create()

  self.state = stateMachine.create({
    "moveState",
    "attackState"
  })
  self.state.enteringState = function(stateName)
    entity.rotateGroup("arm", -math.pi / 2)
  end
  self.state.leavingState = function(stateName)
    entity.stopFiring()
    entity.setAnimationState("movement", "idle")
  end

  entity.setAggressive(true)
  entity.setDeathParticleBurst("deathPoof")
end

--------------------------------------------------------------------------------
function main()
  if util.trackTarget(entity.configParameter("targetAcquisitionDistance")) then
    self.state.pickState(self.targetId)
  end

  self.state.update(entity.dt())
  self.sensors.clear()
end

--------------------------------------------------------------------------------
function damage(args)
  self.state.pickState(args.sourceId)
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
function aimAt(targetPosition)
  local armBaseOffset = entity.configParameter("armBaseOffset")
  local armBasePosition = entity.toAbsolutePosition(armBaseOffset)

  local toTarget = world.distance(targetPosition, armBasePosition)
  local targetAngle = vec2.angle(toTarget)
  if targetAngle > math.pi then targetAngle = targetAngle - math.pi * 2.0 end
  targetAngle = math.max(-math.pi / 2.0, math.min(targetAngle, math.pi / 2.0))
  entity.rotateGroup("arm", targetAngle)

  local aimAngle = entity.currentRotationAngle("arm")
  local armTipOffset = entity.configParameter("armTipOffset")
  local armTipPosition = entity.toAbsolutePosition(armTipOffset)
  local armVector = vec2.rotate(world.distance(armTipPosition, armBasePosition), aimAngle * entity.facingDirection())

  armTipPosition = vec2.add(vec2.dup(armBasePosition), armVector)
  armTipOffset = world.distance(armTipPosition, entity.position())
  armTipOffset[1] = armTipOffset[1] * entity.facingDirection()
  entity.setFireDirection(armTipOffset, armVector)

  local difference = aimAngle - targetAngle
  return math.abs(difference) < 0.05
end

--------------------------------------------------------------------------------
function isOnPlatform()
  return entity.onGround() and
    not self.sensors.nearGroundSensor.collisionTrace.any(true) and
    self.sensors.midGroundSensor.collisionTrace.any(true)
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

  if isOnPlatform() then
    entity.moveDown()
  end

  move({ stateData.direction, 0 })

  stateData.timer = stateData.timer - dt
  if stateData.timer <= 0 then
    return true, entity.configParameter("moveCooldownTime")
  end

  return false
end

--------------------------------------------------------------------------------
attackState = {}

function attackState.enterWith(targetId)
  if targetId == 0 then return nil end
  if self.state.stateDesc() == "attackState" then return nil end


  self.targetId = targetId
  return { timer = entity.configParameter("attackTargetHoldTime") }
end

function attackState.enteringState(stateData)
  entity.setDamageOnTouch(true)
end

function attackState.update(dt, stateData)
  if self.targetPosition ~= nil then
    local toTarget = world.distance(self.targetPosition, entity.position())
    local distance = world.magnitude(toTarget)

    if distance < entity.configParameter("attackDistance") then
      entity.setAnimationState("movement", "attack")

      entity.setFacingDirection(toTarget[1])

      if aimAt(vec2.add(entity.configParameter("aimCorrectionOffset"), self.targetPosition)) then
        entity.startFiring("lightning")
      end
    else
      move(toTarget)
    end
  end

  if self.targetId == nil then
    stateData.timer = stateData.timer - dt
  else
    stateData.timer = entity.configParameter("attackTargetHoldTime")
  end

  return stateData.timer <= 0
end

function attackState.leavingState(stateData)
  entity.setDamageOnTouch(false)
end