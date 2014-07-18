function init()
  local states = { "moveState", "fireState" }
  self.state = stateMachine.create(states)

  self.spawnTimer = 1.0

  entity.setDeathParticleBurst("deathPoof")
  entity.setAnimationState("movement", "invisible")

  rangedAttack.loadConfig()
end

function isPenguinReinforcement()
  return true
end

function main()
  if self.spawnTimer ~= nil then
    self.spawnTimer = self.spawnTimer - entity.dt()
    if self.spawnTimer < 0 then
      self.spawnTimer = nil
      entity.setAnimationState("movement", "open")
    end

    return
  end

  if entity.animationState("movement") == "open" then
    return
  end

  self.targetId = entity.closestValidTarget(50.0)
  if self.targetId ~= 0 then
    self.targetPosition = world.entityPosition(self.targetId)
  else
    self.targetPosition = nil
  end

  if not self.state.update(entity.dt()) then
    entity.setAnimationState("movement", "idle")
  end
end

function aimAt(targetPosition)
  local gunBaseOffset = entity.configParameter("gunBaseOffset")
  local gunBasePosition = entity.toAbsolutePosition(gunBaseOffset)

  local toTarget = world.distance(targetPosition, gunBasePosition)
  local targetAngle = vec2.angle(toTarget)
  if targetAngle > math.pi then targetAngle = math.pi * 2.0 - targetAngle end
  targetAngle = math.max(0, math.min(targetAngle, math.pi / 4.0))
  entity.rotateGroup("gun", targetAngle)

  local gunBarrelOffset = entity.configParameter("gunBarrelOffset")
  local gunBarrelPosition = entity.toAbsolutePosition(gunBarrelOffset)

  local aimAngle = entity.currentRotationAngle("gun")
  local gunBarrel = vec2.rotate(world.distance(gunBarrelPosition, gunBasePosition), aimAngle * entity.facingDirection())

  gunBarrelPosition = vec2.add({ gunBasePosition[1], gunBasePosition[2] }, gunBarrel)
  gunBarrelOffset = world.distance(gunBarrelPosition, entity.position())
  gunBarrelOffset[1] = gunBarrelOffset[1] * entity.facingDirection()
  rangedAttack.aim(gunBarrelOffset, gunBarrel)

  local difference = aimAngle - targetAngle
  return math.abs(difference) < 0.05
end

function isTargetInRange()
  if self.targetId == 0 then return false end

  local range = entity.configParameter("firingRange")
  local distance = world.magnitude(world.distance(self.targetPosition, entity.position()))

  if distance < range[1] or distance > range[2] then
    return false
  else
    return true
  end
end

function moveForward()
  if entity.facingDirection() > 0 then
    entity.moveRight()
  else
    entity.moveLeft()
  end
end

function moveBackward()
  if entity.facingDirection() > 0 then
    entity.moveLeft()
  else
    entity.moveRight()
  end
end

--------------------------------------------------------------------------------
moveState = {}

moveState.enter = function()
  if self.targetId == 0 or isTargetInRange() then
    return nil
  else
    entity.setAnimationState("movement", "move")

    return { }
  end
end

moveState.update = function(dt, stateData)
  if self.targetId == 0 then return true end

  local toTarget = world.distance(self.targetPosition, entity.position())
  entity.setFacingDirection(util.toDirection(toTarget[1]))

  aimAt(self.targetPosition)

  local range = entity.configParameter("firingRange")
  local distance = world.magnitude(world.distance(self.targetPosition, entity.position()))

  if distance < range[1] then
    moveBackward()
  elseif distance > range[2] then
    moveForward()
  else
    return true
  end

  return false
end

--------------------------------------------------------------------------------
fireState = {}

fireState.enter = function()
  if isTargetInRange() then
    return { timer = 0 }
  else
    return nil
  end
end

fireState.update = function(dt, stateData)
  if not isTargetInRange() then
    return true
  end

  if entity.animationState("movement") ~= "attack" and stateData.timer <= 0 then
    if aimAt(self.targetPosition) then
      entity.setAnimationState("movement", "attack")
      rangedAttack.fireOnce()
      stateData.timer = 3.0
    end
  end

  if stateData.timer > 0 then
    stateData.timer = stateData.timer - dt
  end

  return false
end