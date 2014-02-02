function init(args)
  self.state = stateMachine.create({
    "deadState",
    "attackState",
    "scanState"
  })
  self.active = true

  entity.setAnimationState("movement", "idle")
  entity.setInteractive(true)
  entity.setAllOutboundNodes(false)
  
  if storage.energy == nil then setEnergy(0) end
  
  checkInboundNode()
end

--------------------------------------------------------------------------------

function onInteraction(args)
  local maxEnergy = entity.configParameter("maxEnergy")
  
  setEnergy(maxEnergy)
end

function onNodeConnectionChange(args)
  if entity.isInboundNodeConnected(0) then
    checkInboundNode()
  else
    setActive(true)
  end
end

function onInboundNodeChange(args)
  checkInboundNode()
end

function checkInboundNode()
  if entity.isInboundNodeConnected(0) then
    if entity.getInboundNodeLevel(0) then
      setActive(true)
    else
      setActive(false)
    end
  end
end

--------------------------------------------------------------------------------
function main(args)
  self.state.update(entity.dt())
end

--------------------------------------------------------------------------------
function toAbsolutePosition(offset)
  local width = entity.configParameter("objectWidth")
  if entity.direction() < 0 then
    offset[1] = width - offset[1]
  end
  
  return vec2.add(entity.position(), offset)
end

--------------------------------------------------------------------------------
function getBasePosition()
  local baseOffset = entity.configParameter("baseOffset")
  return toAbsolutePosition(baseOffset)
end

--------------------------------------------------------------------------------

function visibleTarget(targetId)
  local targetPosition = targetPos(targetId)
  local basePosition = getBasePosition()
  local targetAngleRange = entity.configParameter("targetAngleRange") * math.pi / 180;

  --Check if target angle is in angle range
  local targetVector = world.distance(targetPosition, basePosition)
  local targetAngle = directionTransformAngle(math.atan2(targetVector[2], targetVector[1]))
  if targetAngle < -targetAngleRange or targetAngle > targetAngleRange then
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
  local radius = entity.configParameter("targetRange")
  local minRadius = entity.configParameter("minTargetRange")
  
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
	local distanceVec = vec2.sub(targetPos(targetId), getBasePosition())
	local distance = math.sqrt(distanceVec[1] * distanceVec[1] + distanceVec[2] * distanceVec[2])
	
  if distance < radius and distance > minRadius and visibleTarget(targetId) then
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
  local radius = entity.configParameter("targetRange")
  
  --Gets all valid targets + all monsters
  local validTargetIds = world.entityQuery(getBasePosition(), radius, { validTargetOf = entity.id() })
  local monsterIds = world.monsterQuery(getBasePosition(), radius, { notAnObject = true })
  
  for key,validTargetId in ipairs(validTargetIds) do
    monsterIds[#monsterIds+1] = validTargetId
  end
  
  return monsterIds
end

--------------------------------------------------------------------------------
function findTarget()
  local selfId = entity.id()
  local radius = entity.configParameter("targetRange")
  
  local minDistance = radius;
  local winnerEntity = 0;
  
  local entityIds = potentialTargets()
  
  for i, entityId in ipairs(entityIds) do
    
    local distanceVec = world.distance(getBasePosition(), targetPos(entityId))
    local distance = math.sqrt(distanceVec[1] * distanceVec[1] + distanceVec[2] * distanceVec[2])
	
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
  return self.active
end

function getEnergy()
  return storage.energy
end

function setEnergy(energy)
  storage.energy = energy
  local maxEnergy = entity.configParameter("maxEnergy")
  
  local animationState = "full"
  
  if energy / maxEnergy <= 0.75 then animationState = "high" end
  if energy / maxEnergy <= 0.5 then animationState = "medium" end
  if energy / maxEnergy <= 0.25 then animationState = "low" end
  if energy / maxEnergy <= 0 then animationState = "none" end
  
  entity.setAnimationState("energy", animationState)
end

--------------------------------------------------------------------------------

function targetPos(entityId)
  local position = world.entityPosition(entityId)
  --Until I can get the center of a target collision poly
  local targetOffset = entity.configParameter("targetOffset")
  position[1] = position[1] + targetOffset[1]
  position[2] = position[2] + targetOffset[2]
  return position
end

function dotProduct(firstVector, secondVector)
  return firstVector[1] * secondVector[1] + firstVector[2] * secondVector[2]
end

function predictedPosition(targetPosition, basePosition, targetVel, bulletSpeed)
  local targetVector = vec2.sub(vec2.dup(targetPosition), basePosition)
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
  if timesToHit[1] > 0 and (timesToHit[2] <= timesToHit[1] or timesToHit[2] < 0) then timeToHit = timesToHit[1] end
  if timesToHit[2] > 0 and (timesToHit[2] <= timesToHit[1] or timesToHit[1] < 0) then timeToHit = timesToHit[2] end
  
  local predictedPos = vec2.add(vec2.dup(targetPosition), vec2.mul(targetVel, timeToHit))
  return predictedPos
end

--------------------------------------------------------------------------------

deadState = {}

function deadState.validate()
  if getEnergy() > 0 and isActive() then
    return false
  end

  return true
end

function deadState.enter()
  if deadState.validate() then
    return {}
  end
end

function deadState.enteringState(stateData)
    
    entity.setAnimationState("movement", "dead")
    local rotationRange = entity.configParameter("rotationRange") * math.pi / 180;
    entity.rotateGroup("gun", -rotationRange)
    entity.setAllOutboundNodes(false)
    
    if getEnergy() < 0 then setEnergy(0) end
end

function deadState.update(dt, stateData)
  local rotationRange = entity.configParameter("rotationRange") * math.pi / 180;
  entity.rotateGroup("gun", -rotationRange)
  if deadState.validate() == false then
    self.state.endState()
    self.state.pickState()
  end
end

function deadState.leavingState(stateData)
  local powerUpSound = entity.configParameter("powerUpSound")
  entity.playImmediateSound(powerUpSound)
end

--------------------------------------------------------------------------------
scanState = {}

function scanState.validate()
  if getEnergy() > 0 and isActive() then
    return true
  end
  
  return false
end

function scanState.enter()
  if scanState.validate() then
    return {
      timer = 0,
      targetCooldown = entity.configParameter("targetCooldown")
    }
  end
end

function scanState.enteringState(stateData)
  entity.setAnimationState("movement", "idle")
  entity.setAllOutboundNodes(false)
end

function scanState.update(dt, stateData)
  if scanState.validate() == false then
	  self.state.endState()
    self.state.pickState()
  end
  
  --Rotate gun up and down in a scanning motion
  local rotationRange = entity.configParameter("rotationRange") * math.pi / 180;
  local rotationTime = entity.configParameter("rotationTime")
  local angle = rotationRange * math.sin(stateData.timer / rotationTime * math.pi * 2)
  entity.rotateGroup("gun", angle)
  
  --Look for targets
  if stateData.targetCooldown <= 0 then
    local targetEntity = findTarget()
    if targetEntity ~= 0 then
      self.state.endState()
      self.state.pickState(targetEntity)
    end
  end
  
  --Tick timer
  stateData.timer = stateData.timer + dt
  if stateData.timer > rotationTime then
    stateData.timer = 0
  end
  stateData.targetCooldown = stateData.targetCooldown - dt
  if stateData.targetCooldown < 0 then
    stateData.targetCooldown = 0
  end
  
  --Tick energy
  local energy = getEnergy()
  local energyTickTime = entity.configParameter("energyTickTime")
  energy = energy - dt * energyTickTime
  setEnergy(energy)
  
  return false
end

function scanState.leavingState(stateData)
  if getEnergy() <= 0 or isActive() == false then
    local powerDownSound = entity.configParameter("powerDownSound")
    entity.playImmediateSound(powerDownSound)
  end
end

--------------------------------------------------------------------------------
attackState = {}

function attackState.validate(targetId)
  if targetId ~= nil and world.entityPosition(targetId) ~= nil then
    return true
  end
  
  return false
end

function attackState.enterWith(targetId)
  if attackState.validate(targetId) then
    return {
      fireTimer = 0,
      targetId = targetId,
      lastPosition = targetPos(targetId),
      letGoTimer = 0
    }
  end
end

function attackState.enteringState(stateData)
  local foundTargetSound = entity.configParameter("foundTargetSound")
  entity.playImmediateSound(foundTargetSound)
  
  
  entity.setAnimationState("movement", "attack")
  entity.setAllOutboundNodes(true)
end

function attackState.update(dt, stateData)
  local energy = getEnergy()
  local active = isActive()
  local haveTarget = true
  
  if energy <= 0 or active ~= true then
	  self.state.endState() 
    self.state.pickState()
  end
  
  if validTarget(stateData.targetId) == false then
    local letGoCooldown = entity.configParameter("letGoCooldown")
    if stateData.letGoTimer > letGoCooldown or world.entityPosition == nil then
      self.state.endState() 
      self.state.pickState()
    end
    stateData.letGoTimer = stateData.letGoTimer + dt
    haveTarget = false
  else
    stateData.letGoTimer = 0
    haveTarget = true
  end
  
  if haveTarget then
    local radius = entity.configParameter("targetRange")
    local basePosition = getBasePosition()
    local targetPosition = targetPos(stateData.targetId)
    local maxTrackingYVel = entity.configParameter("maxTrackingYVel")
    
    --Make it follow the target's predicted position
    local deltaPos = vec2.sub(vec2.dup(targetPosition), stateData.lastPosition)
    local targetVel = vec2.div(deltaPos, dt)
    targetVel[2] = math.max(math.min(targetVel[2], maxTrackingYVel), -maxTrackingYVel) --Keeps the turret from going nuts when a target jumps, motion prediction is mostly for the x axis anyway
    stateData.lastPosition = targetPosition
    local bulletSpeed = entity.configParameter("bulletSpeed")
    local predictedPos = predictedPosition(targetPosition, basePosition, targetVel, bulletSpeed)
    
    local targetVector = world.distance(predictedPos, basePosition)
    angle = directionTransformAngle(math.atan2(targetVector[2], targetVector[1]))
    local maxAngle = entity.configParameter("targetAngleRange")
    angle = math.max(math.min(angle, maxAngle), -maxAngle)
    
    entity.rotateGroup("gun", angle)
    
    --Fire
    local fireCooldown = entity.configParameter("fireCooldown")
    if stateData.fireTimer >= fireCooldown then
      local tipOffset = entity.configParameter("tipOffset")
      local bulletSize = entity.configParameter("bulletSize")
      local baseOffset = entity.configParameter("baseOffset")
      local direction = entity.direction()
      
      --Make bullet edge spawn at the nozzle rather than bullet center
      tipOffset[1] = tipOffset[1] + (bulletSize[1] / 8) / 2 -- divide by 8 because bulletSize is in pixels
      
      --Bullet anchor is half a pixel off, might only be a problem for odd height/width values
      if bulletSize[1] % 2 ~= 0 then tipOffset[1] = tipOffset[1] - 0.0625 end
      if bulletSize[2] % 2 ~= 0 then tipOffset[2] = tipOffset[2] - direction * 0.0625 end --multiplying by direction fixes rotation problem
      
      --get aim angle and tip position
      local aimAngle = entity.currentRotationAngle("gun")
      local tipVector = vec2.sub(tipOffset, baseOffset)
      tipVector = vec2.rotate(tipVector, aimAngle)
      local tipPosition = toAbsolutePosition(vec2.add(baseOffset, tipVector))
      local aimVector = {direction * math.cos(aimAngle), math.sin(aimAngle)}
      
      local bulletType = entity.configParameter("bulletType")
      
      world.spawnProjectile(bulletType, tipPosition, entity.id(), aimVector)
      stateData.fireTimer = 0
      
      local fireSound = entity.configParameter("fireSound")
      entity.playImmediateSound(fireSound)
      
      local energyPerShot = entity.configParameter("energyPerShot")
      local energy = getEnergy()
      energy = energy - energyPerShot
      setEnergy(energy)
    end
    
    stateData.fireTimer = stateData.fireTimer + dt
  end
  return false
end

function attackState.leavingState(stateData)
  if getEnergy() <= 0 or isActive() == false then
    local powerDownSound = entity.configParameter("powerDownSound")
    entity.playImmediateSound(powerDownSound)
  else
    local scanSound = entity.configParameter("scanSound")
    entity.playImmediateSound(scanSound)
  end
end