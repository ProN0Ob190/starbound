gravitySlamAttack = {
  minDistance = 3,
  maxMoveTime = 4,
  liftMultiplier = 3,
  baseDamage = 5,
}

function gravitySlamAttack.enter()
  if not canStartAttack() then return nil end

  return { run = coroutine.wrap(gravitySlamAttack.run) }
end

function gravitySlamAttack.enteringState(stateData)
  entity.setAnimationState("movement", "idle")
  entity.setAnimationState("attack", "idle")

  entity.setActiveSkillName("gravitySlamAttack")
end

function gravitySlamAttack.update(dt, stateData)
  if not hasTarget() then return true end

  return stateData.run(stateData)
end

function gravitySlamAttack.leavingState(stateData)
  entity.setRunning(false)
  entity.setParticleEmitterActive("gravitySlamAttackUp", false)
  entity.setParticleEmitterActive("gravitySlamAttackDown", false)
end

function gravitySlamAttack.run(stateData)
  local timer = gravitySlamAttack.maxMoveTime
  while timer > 0 and math.abs(self.toTarget[1]) < gravitySlamAttack.minDistance do
    move({ -self.toTarget[1], 0 })
    timer = timer - entity.dt()
    coroutine.yield(false)
  end

  entity.setFacingDirection(self.toTarget[1])
  entity.setAnimationState("movement", "idle")
  entity.setAnimationState("attack", "charge")

  entity.setParticleEmitterActive("gravitySlamAttackUp", true)
  entity.playSound(entity.randomizeParameter("gravitySlamAttack.sounds"))

  util.wait(0.6, function()
    world.spawnProjectile("grabbed", world.entityPosition(self.target), entity.id(), { 0, 0 }, false)

    local gravity = world.gravity(world.entityPosition(self.target))
    gravitySlamAttack.applyVerticalForceToTarget(gravity * gravitySlamAttack.liftMultiplier)
  end)

  entity.setParticleEmitterActive("gravitySlamAttackUp", false)
  entity.setParticleEmitterActive("gravitySlamAttackDown", true)

  util.wait(0.2, function()
    world.spawnProjectile("grabbed", world.entityPosition(self.target), entity.id(), { 0, 0 }, false)

    local gravity = world.gravity(world.entityPosition(self.target))
    gravitySlamAttack.applyVerticalForceToTarget(-gravity)
  end)
  entity.playSound(entity.randomizeParameter("gravitySlamAttack.sounds"))

  util.wait(0.5, function()
    world.spawnProjectile("grabbed", world.entityPosition(self.target), entity.id(), { 0, 0 }, false)

    gravitySlamAttack.applyVerticalForceToTarget(-600)
  end)

  return true
end

function gravitySlamAttack.applyVerticalForceToTarget(amount)
  local targetPosition = world.entityPosition(self.target)
  local region = {
    targetPosition[1] - 1, targetPosition[2] - 3,
    targetPosition[1] + 1, targetPosition[2] + 3,
  }
  entity.setForceRegion(region, { 0, amount } )
end