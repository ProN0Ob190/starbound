blinkAttack = {
  initialDelay = 1,
  postBlinkDelay = 0.2,
  chargeDuration = 0.25,
}

function blinkAttack.enter()
  if not canStartAttack() then return nil end

  local destination = blinkAttack.findDestination(world.entityPosition(self.target))
  if destination == nil then return nil end

  return {
    originalDestination = destination,
    run = coroutine.wrap(blinkAttack.run)
  }
end

function blinkAttack.enteringState(stateData)
  entity.setAnimationState("movement", "idle")
  entity.setAnimationState("attack", "idle")

  entity.setActiveSkillName("blinkAttack")
end

function blinkAttack.update(dt, stateData)
  if not canContinueAttack() then return true end

  return stateData.run(stateData)
end

function blinkAttack.leavingState(stateData)
  entity.setRunning(false)
end

function blinkAttack.run(stateData)
  blinkAttack.wait(blinkAttack.initialDelay, function()
    if self.toTarget ~= nil then
      entity.setFacingDirection(self.toTarget[1])
    end
  end)

  -- Might have a better destination at this point
  local destination = blinkAttack.findDestination(world.entityPosition(self.target))
  if destination == nil then
    destination = stateData.originalDestination
  end

  if self.toTarget ~= nil then
    entity.setFacingDirection(self.toTarget[1])
  end

  entity.burstParticleEmitter("blinkout")
  entity.setVelocity({ 0, 0 })
  entity.setPosition(destination)
  coroutine.yield(false)

  blinkAttack.wait(blinkAttack.postBlinkDelay, function()
    if self.toTarget ~= nil then
      entity.setFacingDirection(self.toTarget[1])
    end
  end)

  entity.setAnimationState("movement", "charge")
  entity.setAnimationState("attack", "charge")

  entity.setRunning(true)

  local movement = self.toTarget
  blinkAttack.wait(blinkAttack.chargeDuration, function()
    move(movement)
  end)

  return true
end

function blinkAttack.wait(duration, action)
  local timer = 0
  while timer < duration do
    if action ~= nil then action() end

    timer = timer + entity.dt()
    coroutine.yield(false)
  end
end

function blinkAttack.findDestination(targetPosition)
  if targetPosition == nil then return nil end

  local bounds = entity.configParameter("metaBoundBox")
  local region = {
    bounds[1] + targetPosition[1],
    bounds[2] + targetPosition[2],
    bounds[3] + targetPosition[1],
    bounds[4] + targetPosition[2]
  }
  local direction = util.toDirection(self.toTarget[1])
  local offsetXRange = entity.configParameter("blinkAttackOffsetXRange")
  for offsetX = offsetXRange[2], offsetXRange[1], -1 do
    local destinationRegion = {
      region[1] + bounds[1] + direction * offsetX,
      region[2],
      region[3] + bounds[3],
      region[4]
    }
    if not world.rectCollision(destinationRegion, true) then
      return { targetPosition[1] + direction * offsetX, targetPosition[2] }
    end
  end

  return nil
end