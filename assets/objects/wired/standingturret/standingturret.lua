function init(args)
  --Bunch of parameters
  self.baseOffset = entity.configParameter("baseOffset")
  self.tipOffset = entity.configParameter("tipOffset") --This is offset from BASE position, not object origin

  self.targetRange = entity.configParameter("targetRange")
  self.targetCooldown = entity.configParameter("targetCooldown")
  self.targetAngleRange = entity.configParameter("targetAngleRange")
  self.maxTrackingYVel = entity.configParameter("maxTrackingYVel")
  self.targetOffset = entity.configParameter("targetOffset")
  self.minTargetRange = entity.configParameter("minTargetRange")

  self.rotationRange = entity.configParameter("rotationRange")
  self.rotationTime = entity.configParameter("rotationTime")

  self.defaultBulletSpeed = entity.configParameter("defaultBulletSpeed")

  self.letGoCooldown = entity.configParameter("letGoCooldown")

  self.sounds = entity.configParameter("sounds")

  self.energy = entity.configParameter("energy")
  self.maxEnergy = self.energy.baseEnergy
  self.energyMultipliers = entity.configParameter("turretLevelEnergyMultiplier")

  self.gunEnergyCost = entity.configParameter("gunLevelEnergyCostPerDamage")

  self.state = stateMachine.create({
    "deadState",
    "attackState",
    "scanState"
  })
  self.active = true

  entity.setAnimationState("movement", "idle")
  entity.setInteractive(true)
  --entity.setAllOutboundNodes(false)
  
  self.gunStats = getGunStats(world.containerItemAt(entity.id(), 0))

  if storage.energy == nil then setEnergy(self.maxEnergy) end
  
  --checkInboundNode()
end

--------------------------------------------------------------------------------
function main(args)
  self.gunStats = getGunStats(world.containerItemAt(entity.id(), 0))
  self.state.update(entity.dt())
end

--------------------------------------------------------------------------------

function getGunStats(gun)
  local gunStats = {}
  if not gun or not gun.data.__content.projectileType or not gun.data.__content.projectile then return false end

  gunStats["spread"] = gun.data.__content.spread or 1
  gunStats["projectileType"] = gun.data.__content.projectileType or "bullet-1"
  gunStats["speed"] = gun.data.__content.projectile.speed or nil
  gunStats["power"] = gun.data.__content.projectile.power or 5
  gunStats["fireTime"] = gun.data.__content.fireTime or 1
  gunStats["level"] = gun.data.__content.level or 1
  gunStats["levelScale"] = gun.data.__content.levelScale or 1
  gunStats["classMultiplier"] = gun.data.__content.classMultiplier or 1
  gunStats["fireSound"] = getFireSound(gun) or self.sounds["fire"]

  gunStats["damagePerShot"] = gunStats.levelScale * gunStats.power * gunStats.spread
  gunStats["energyPerShot"] = getEnergyPerShot(gunStats.level, gunStats.damagePerShot, gunStats.classMultiplier)

  return gunStats
end

function getEnergyPerShot(level, damage, classMultiplier)
  local roundLevel = math.max(math.floor(level + 0.5), 1)
  local energyMultiplier = self.gunEnergyCost[3][2] --Default to level 1

  for i = 3, 12 do
    if self.gunEnergyCost[i][1] == roundLevel then
      energyMultiplier = self.gunEnergyCost[i][2]
    end
  end

  return damage * classMultiplier * energyMultiplier
end

function getFireSound(gun)
  if not gun.data.__content.muzzleEffect or not gun.data.__content.muzzleEffect.fireSound then return false end
  if gun.data.__content.muzzleEffect.fireSound[1]["file"] then
    return gun.data.__content.muzzleEffect.fireSound[1]["file"]
  end
  return false
end

function defaultBulletSpeed(projectileType)
  return self.defaultBulletSpeed[projectileType] or self.defaultBulletSpeed["default"]
end

--------------------------------------------------------------------------------
function getBasePosition()
  return entity.toAbsolutePosition(self.baseOffset)
end

--------------------------------------------------------------------------------

function visibleTarget(targetId)
  local targetPosition = targetPos(targetId)
  local basePosition = getBasePosition()
  local angleRange = self.targetAngleRange * math.pi / 180;

  --Check if target angle is in angle range
  local targetVector = world.distance(targetPosition, basePosition)
  local targetAngle = directionTransformAngle(math.atan2(targetVector[2], targetVector[1]))
  if targetAngle < -angleRange or targetAngle > angleRange then
    return false
  end
  
  --Check for blocks in the way
  local blocks = world.collisionBlocksAlongLine(basePosition, targetPosition, true, 1)
  if #blocks > 0 then
    return false
  end
  
  return true
end


function validTarget(targetId)
  local selfId = entity.id()
  
  --Does it exist?
  if world.entityExists(targetId) == false then
    return false
  end
  
  --Is it dead yet
  local targetHealth = world.entityHealth(targetId)
  if targetHealth ~= nil and targetHealth[1] <= 0 then
    return false
  end
  
  --Is it in range and visible
  local direction = entity.direction()
  local distance = world.magnitude(targetPos(targetId), getBasePosition())
  
  if distance < self.targetRange and distance > self.minTargetRange and visibleTarget(targetId) then
    return true
  else
    return false
  end
end

--------------------------------------------------------------------------------

function directionTransformAngle(angle)
  local direction = 1
  if entity.direction() < 0 then
    direction = -1
  end
  local angleVec = {direction * math.cos(angle), math.sin(angle)}
  return math.atan2(angleVec[2], angleVec[1])
end

--------------------------------------------------------------------------------

function potentialTargets()  
  --Gets all valid targets + all monsters
  local validTargetIds = world.entityQuery(getBasePosition(), self.targetRange, { validTargetOf = entity.id() })
  local monsterIds = world.monsterQuery(getBasePosition(), self.targetRange, { notAnObject = true })

  for key,validTargetId in ipairs(validTargetIds) do
    monsterIds[#monsterIds+1] = validTargetId
  end
  
  return monsterIds
end

--------------------------------------------------------------------------------
function findTarget()
  local selfId = entity.id()
  
  local minDistance = self.targetRange
  local winnerEntity = 0
  
  local entityIds = potentialTargets()
  
  for i, entityId in ipairs(entityIds) do
    
    local distance = world.magnitude(getBasePosition(), targetPos(entityId))
  
    if validTarget(entityId) then
      winnerEntity = entityId
      minDistance = distance
    end
  end
  
  return winnerEntity
end

--------------------------------------------------------------------------------

function setActive(active)
  self.active = active
end

function isActive()
  if entity.isInboundNodeConnected(0) and not entity.getInboundNodeLevel(0) then
    return false
  else
    return self.gunStats ~= false
  end
end

function setEnergy(energy)
  storage.energy = energy

  local energyMultiplier = getEnergyMultiplier()
  self.maxEnergy = self.energy.baseEnergy * energyMultiplier

  if storage.energy > self.maxEnergy then storage.energy = self.maxEnergy end
  
  local animationState = "full"
  
  if energy / self.maxEnergy <= 0.75 then animationState = "high" end
  if energy / self.maxEnergy <= 0.5 then animationState = "medium" end
  if energy / self.maxEnergy <= 0.25 then animationState = "low" end
  if energy / self.maxEnergy <= 0 then animationState = "none" end

  entity.scaleGroup("energy", {energy / self.maxEnergy * 11, 1})
  entity.scaleGroup("energyv", {1, energy / self.maxEnergy * 11})
  
  entity.setAnimationState("energy", animationState)
end

function consumeEnergy(amount)
  if storage.energy - amount < 0 then
    return false 
  end

  setEnergy(storage.energy - amount)
  return true
end

function regenEnergy()
  local energyMultiplier = getEnergyMultiplier()
  local energy = storage.energy + self.energy.energyRegen * energyMultiplier * entity.dt()
  setEnergy(energy)
end

function getEnergyMultiplier()
  if not isActive() then return 1 end

  local roundLevel = math.max(math.floor(self.gunStats.level + 0.5), 1)
  local energyMultiplier = self.energyMultipliers[3][2] --Default to level 1

  for i = 3, 12 do
    if self.energyMultipliers[i][1] == roundLevel then
      energyMultiplier = self.energyMultipliers[i][2]
    end
  end

  return energyMultiplier
end

--------------------------------------------------------------------------------

function targetPos(entityId)
  local position = world.entityPosition(entityId)
  --Until I can get the center of a target collision poly
  position[1] = position[1] + self.targetOffset[1]
  position[2] = position[2] + self.targetOffset[2]
  return position
end

function dotProduct(firstVector, secondVector)
  return firstVector[1] * secondVector[1] + firstVector[2] * secondVector[2]
end

function predictedPosition(targetPosition, basePosition, targetVel, bulletSpeed)
  local targetVector = world.distance(targetPosition, basePosition)
  local bs = bulletSpeed
  local dotVectorVel = dotProduct(targetVector, targetVel)
  local vector2 = dotProduct(targetVector, targetVector)
  local vel2 = dotProduct(targetVel, targetVel)
  
  --If the answer is a complex number, for the love of god don't continue
  if ((2*dotVectorVel) * (2*dotVectorVel)) - (4 * (vel2 - bs * bs) * vector2) < 0 then
    return targetPosition
  end
  
  local timesToHit = {} --Gets two values from solving quadratic equation
  --Quadratic formula up in dis
  timesToHit[1] = (-2 * dotVectorVel + math.sqrt((2*dotVectorVel) * (2*dotVectorVel) - 4*(vel2 - bs * bs) * vector2)) / (2 * (vel2 - bs * bs))
  timesToHit[2] = (-2 * dotVectorVel - math.sqrt((2*dotVectorVel) * (2*dotVectorVel) - 4*(vel2 - bs * bs) * vector2)) / (2 * (vel2 - bs * bs))
  
  --Find the nearest lowest positive solution
  local timeToHit = 0
  if timesToHit[1] > 0 and (timesToHit[1] <= timesToHit[2] or timesToHit[2] < 0) then timeToHit = timesToHit[1] end
  if timesToHit[2] > 0 and (timesToHit[2] <= timesToHit[1] or timesToHit[1] < 0) then timeToHit = timesToHit[2] end
  
  local predictedPos = vec2.add(targetPosition, vec2.mul(targetVel, timeToHit))
  return predictedPos
end

--------------------------------------------------------------------------------

deadState = {}

function deadState.enter()
  if not isActive() then
    return {}
  end
end

function deadState.enteringState(stateData)
  entity.setAnimationState("movement", "dead")
  local rotationRange = self.rotationRange * math.pi / 180;
  entity.rotateGroup("gun", -rotationRange)
  entity.setAllOutboundNodes(false)

  setEnergy(0)
end

function deadState.update(dt, stateData)
  local rotationRange = self.rotationRange * math.pi / 180;
  entity.rotateGroup("gun", -rotationRange)

  if isActive() then
    return true
  end

  return false
end

function deadState.leavingState(stateData)
  entity.playImmediateSound(self.sounds["powerUp"])
  self.state.pickState()
end

--------------------------------------------------------------------------------
scanState = {}

function scanState.enter()
  if isActive() then
    return {
      timer = 0,
      targetCooldown = self.targetCooldown,
      targetId = nil
    }
  end
end

function scanState.enteringState(stateData)
  entity.setAnimationState("movement", "idle")
  entity.setAllOutboundNodes(false)
end

function scanState.update(dt, stateData)
  if not isActive() then
    return true
  end
  
  regenEnergy()

  scanState.rotateGun(stateData)
  
  local targetEntity = scanState.scanForTargets(stateData)
  if targetEntity then
      stateData.targetId = targetEntity
      return true
  end

  return false
end

function scanState.rotateGun(stateData)
  local rotationRange = self.rotationRange * math.pi / 180;
  local angle = rotationRange * math.sin(stateData.timer / self.rotationTime * math.pi * 2)
  entity.rotateGroup("gun", angle)

  stateData.timer = stateData.timer + entity.dt()
  if stateData.timer > self.rotationTime then
    stateData.timer = 0
  end
end

function scanState.scanForTargets(stateData)
  --Look for targets
  if stateData.targetCooldown <= 0 then
    local targetEntity = findTarget()
    if targetEntity ~= 0 then
        return targetEntity
    end
    stateData.targetCooldown = self.targetCooldown
  end

  stateData.targetCooldown = stateData.targetCooldown - entity.dt()
  if stateData.targetCooldown < 0 then
    stateData.targetCooldown = 0
  end
  return false
end

function scanState.leavingState(stateData)
  if storage.energy <= 0 or isActive() == false then
    entity.playImmediateSound(self.sounds["powerDown"])
  end
  self.state.pickState(stateData.targetId)
end

--------------------------------------------------------------------------------
attackState = {}

function attackState.enterWith(targetId)
  if targetId ~= nil and world.entityPosition(targetId) ~= nil then
    return {
      fireTimer = 0,
      targetId = targetId,
      lastPosition = targetPos(targetId),
      letGoTimer = 0
    }
  end
end

function attackState.enteringState(stateData)
  entity.playImmediateSound(self.sounds["foundTarget"])
  
  entity.setAnimationState("movement", "attack")
  entity.setAllOutboundNodes(true)
end

function attackState.update(dt, stateData)
  if not isActive() then
    return true
  end

  regenEnergy()
  
  local haveTarget = attackState.haveValidTarget(stateData)
  
  if haveTarget then

    attackState.followTarget(stateData)
    
    if stateData.fireTimer >= self.gunStats.fireTime and consumeEnergy(self.gunStats.energyPerShot) then

      attackState.fire(stateData)

      entity.playImmediateSound(self.gunStats.fireSound)

      stateData.fireTimer = stateData.fireTimer - self.gunStats.fireTime
    end
    
    stateData.fireTimer = stateData.fireTimer + dt
  elseif stateData.letGoTimer > self.letGoCooldown or world.entityPosition == nil then
      return true
  end

  return false
end

function attackState.fire(stateData)
  local direction = entity.direction()
  
  local aimAngle = entity.currentRotationAngle("gun")

  local tipPosition = attackState.tipPosition(stateData, aimAngle)
  local aimVector = {direction * math.cos(aimAngle), math.sin(aimAngle)}
  
  if self.gunStats.spread == 1 then
    world.spawnProjectile(self.gunStats.projectileType, tipPosition, entity.id(), aimVector, false, {power = self.gunStats.damagePerShot, speed = self.gunStats.speed})
  elseif self.gunStats.spread > 1 then
    for i = 0, self.gunStats.spread do
      local angleOffset = (math.random() * 4 - 2) / 100 * self.gunStats.spread;
      local newAngle = aimAngle + angleOffset
      aimVector = {direction * math.cos(newAngle), math.sin(newAngle)}
      world.spawnProjectile(self.gunStats.projectileType, tipPosition, entity.id(), aimVector, false, {power = self.gunStats.damagePerShot / self.gunStats.spread, speed = self.gunStats.speed})
    end
  end
end

function attackState.haveValidTarget(stateData)
  if validTarget(stateData.targetId) then
    stateData.letGoTimer = 0
    return true
  end
  stateData.letGoTimer = stateData.letGoTimer + entity.dt()
  return false
end

function attackState.tipPosition(stateData, aimAngle)
  local tipOffset = {self.tipOffset[1], self.tipOffset[2]}
  if entity.direction() < 0 then tipOffset[2] = tipOffset[2] + 0.125 end --Most bullets are odd height, this fixes an offset issue where their origin is slightly below middle
  tipOffset = vec2.rotate(tipOffset, aimAngle)
  tipOffset[1] = entity.direction() * tipOffset[1]

  return vec2.add(getBasePosition(), tipOffset)
end

function attackState.targetVelocity(stateData)
  local targetPosition = targetPos(stateData.targetId)
  local deltaPos = {targetPosition[1] - stateData.lastPosition[1], targetPosition[2] - stateData.lastPosition[2]}
  stateData.lastPosition = targetPosition
  return vec2.div(deltaPos, entity.dt())
end

function attackState.followTarget(stateData)
  --Make it follow the target's predicted position
  local targetVelocity = attackState.targetVelocity(stateData)
  targetVelocity[2] = math.max(math.min(targetVelocity[2], self.maxTrackingYVel), -self.maxTrackingYVel) --Don't track the Y velocity too much because of jumping
  local predictedPos = predictedPosition(targetPos(stateData.targetId), getBasePosition(), targetVelocity, self.gunStats.speed or defaultBulletSpeed(self.gunStats.projectileType))
  
  local targetVector = world.distance(predictedPos, getBasePosition())
  angle = directionTransformAngle(math.atan2(targetVector[2], targetVector[1]))
  angle = math.max(math.min(angle, self.targetAngleRange), -self.targetAngleRange)
  
  entity.rotateGroup("gun", angle)
end

function attackState.leavingState(stateData)
  if storage.energy <= 0 or isActive() == false then
    entity.playImmediateSound(self.sounds["powerDown"])
  else
    entity.playImmediateSound(self.sounds["scan"])
  end
  self.state.pickState()
end