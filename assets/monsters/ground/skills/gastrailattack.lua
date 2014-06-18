gasTrailAttack = {
  fireTime = 0.5
}

function gasTrailAttack.enter()
  if not canStartSkill("gasTrailAttack") then return nil end

  return {fireTimer = 0.2} --give it a bit of time to back up and telegraph
end

function gasTrailAttack.enteringState(stateData)
  entity.setAnimationState("attack", "shooting")

  stateData.baseRunSpeed = entity.runSpeed()
  entity.applyMovementParameters({runSpeed=3.0})

  entity.setFacingDirection(self.toTarget[1])

  entity.setActiveSkillName("gasTrailAttack")
end

function gasTrailAttack.update(dt, stateData)
  if isBlocked() or not canContinueSkill() then return true end

  entity.setRunning(true)
  entity.setAnimationState("movement", "walk")

  -- move({-entity.facingDirection(), 0}, 1, false)
  moveX(-entity.facingDirection())

  if stateData.fireTimer <= 0 then
    gasTrailAttack.fire()
    stateData.fireTimer = gasTrailAttack.fireTime
  end

  stateData.fireTimer = stateData.fireTimer - dt

  return false
end

function gasTrailAttack.leavingState(stateData)
  entity.applyMovementParameters({runSpeed=stateData.baseRunSpeed})  
end

function gasTrailAttack.fire()
  local projectileStartPosition = entity.toAbsolutePosition({entity.configParameter("projectileSourcePosition", {0, 0})[1] + 1.0, entity.configParameter("projectileSourcePosition", {0, 0})[2]})
  local projectileName = entity.configParameter("gasTrailAttack.projectile")
  world.spawnProjectile(projectileName, projectileStartPosition, entity.id(), {entity.facingDirection(), 0}, false, {speed = 0, timeToLive = 1.8, animationCycle = 1.8})
end