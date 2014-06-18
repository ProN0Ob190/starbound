function init(args)
  local states = { "move", "attack" }
  self.state = stateMachine.create(states)

  self.spawnTimer = 1.0

  entity.setDeathParticleBurst("deathPoof")
  setAnimation("invisible", true)
end

function isPenguinReinforcement()
  return true
end

function main()
  if self.spawnTimer ~= nil then
    self.spawnTimer = self.spawnTimer - entity.dt()
    if self.spawnTimer < 0 then
      self.spawnTimer = nil
      setAnimation("idle", true)
    end
  else
    trackTarget()

    self.state.update(entity.dt())
  end
end

function trackTarget()
  self.targetId = entity.closestValidTarget(25.0)

  if self.targetId ~= 0 then
    self.targetPosition = world.entityPosition(self.targetId)
  end
end

function aimAt(targetPosition)
  local gunBaseOffset = entity.configParameter("gunBaseOffset")
  gunBaseOffset[1] = -gunBaseOffset[1]
  local gunBasePosition = entity.toAbsolutePosition(gunBaseOffset)

  local gunBarrelOffset = entity.configParameter("gunBarrelOffset")
  gunBarrelOffset[1] = -gunBarrelOffset[1]
  local gunBarrelPosition = entity.toAbsolutePosition(gunBarrelOffset)

  local toTarget = world.distance(targetPosition, gunBasePosition)
  entity.setFacingDirection(util.toDirection(toTarget[1]))

  local desiredAimAngle = vec2.angle(toTarget)
  entity.rotateGroup("weapon", -desiredAimAngle)
  entity.rotateGroup("arms", -desiredAimAngle)

  local aimAngle = -entity.currentRotationAngle("weapon")
  local gunBarrel = vec2.rotate(world.distance(gunBarrelPosition, gunBasePosition), aimAngle * entity.facingDirection())

  gunBarrelPosition = vec2.add({ gunBasePosition[1], gunBasePosition[2] }, gunBarrel)
  gunBarrelOffset = world.distance(gunBarrelPosition, entity.position())
  gunBarrelOffset[1] = gunBarrelOffset[1] * entity.facingDirection()
  entity.setFireDirection(gunBarrelOffset, gunBarrel)

  -- Just put the empty hand down
  if entity.configParameter("hasEmptyHand") then
    entity.rotateGroup("emptyHand", math.pi / 2.0)
  end

  return math.abs(desiredAimAngle - aimAngle) < 0.05
end

function targetInRange()
  if self.targetPosition == nil then return false end

  local distance = world.magnitude(world.distance(self.targetPosition, entity.position()))
  return distance > 3.0 and distance < 15.0
end

function setAnimation(animationName, immediate)
  if immediate == nil then immediate = false end

  entity.setAnimationState("movement", animationName)

  -- Put the arms down and weapon in holstered position
  if animationName ~= "aim" then
    entity.rotateGroup("weapon", -math.pi / 2.0, immediate)
    entity.rotateGroup("arms", 0, immediate)
  end
end

--------------------------------------------------------------------------------
move = {}

move.enter = function()
  if self.targetPosition == nil or targetInRange() then
    return nil
  else
    setAnimation("walk")
    return {}
  end
end

move.update = function(dt, stateData)
  local toTarget = world.distance(self.targetPosition, entity.position())
  local distance = world.magnitude(toTarget)
  if distance < 4.0 then
    -- Back up
    entity.setFacingDirection(-toTarget[1])

    if toTarget[1] < 0 then
      entity.moveRight()
    else
      entity.moveLeft()
    end
  elseif distance > 14.0 then
    -- Move closer
    entity.setFacingDirection(toTarget[1])

    if toTarget[1] < 0 then
      entity.moveLeft()
    else
      entity.moveRight()
    end
  else
    entity.setFacingDirection(toTarget[1])
    setAnimation("idle")
    return true
  end

  return false
end

--------------------------------------------------------------------------------
attack = {}

attack.enter = function()
  if targetInRange() then
    setAnimation("aim")
    return {}
  else
    return nil
  end
end

attack.update = function(dt, stateData)
  if not targetInRange() then
    -- entity.stopFiring()
    setAnimation("idle")
    return true
  end

  if aimAt(self.targetPosition) then
    -- entity.startFiring(entity.configParameter("projectileType"))
  else
    -- entity.stopFiring()
  end

  return false
end