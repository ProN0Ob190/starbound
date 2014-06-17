meleeAttack = {}

--allow force entering state without canStartSkill
function meleeAttack.enterWith(args)
  if not args.meleeAttack then return nil end

  return { didAttack = false, wasInRange = false }
end

function meleeAttack.enter()
  if not canStartSkill("meleeAttack") then return nil end

  return { didAttack = false, wasInRange = false }
end

function meleeAttack.enteringState(stateData)
  setAggressive(true, false)
  if entity.setAnimationState("attack", "melee") then
    entity.playSound(entity.randomizeParameter("attackNoise"))
  end

  stateData.projectileSourcePosition = {
      entity.configParameter("projectileSourcePosition", {0, 0})[1] + entity.configParameter("meleeProjectileOffset", {0, 0})[1] - 1.0,
      entity.configParameter("projectileSourcePosition", {0, 0})[2] + entity.configParameter("meleeProjectileOffset", {0, 0})[2]
    }

  stateData.baseRunSpeed = entity.runSpeed()

  if stateData.baseRunSpeed < 11.0 then
    entity.applyMovementParameters({runSpeed=11.0})
  elseif stateData.baseRunSpeed > 15.0 then
    entity.applyMovementParameters({runSpeed=15.0})
  end

  entity.applyMovementParameters({groundForce=50})

  entity.setFacingDirection(self.toTarget[1])

  entity.setActiveSkillName("meleeAttack")
end

function meleeAttack.update(dt, stateData)
  if not canContinueSkill() then return true end

  entity.setRunning(true)
  entity.setAnimationState("movement", "run")

  local attackCompletion = (entity.configParameter("meleeAttack.skillTimeLimit") - self.skillTimer) / entity.configParameter("meleeAttack.skillTimeLimit")

  -- if attackCompletion <= 0.5 then
  --   moveX(self.toTarget[1])
  -- else
  --   moveX(-self.toTarget[1])
  -- end

  -- if attackCompletion <= 0.25 or attackCompletion >= 0.75 then
  --   entity.applyMovementParameters({runSpeed=10.0})
  -- else
  --   entity.applyMovementParameters({runSpeed=7.0})
  -- end

  if stateData.wasInRange == false and math.abs(self.toTarget[1]) > math.abs(entity.configParameter("projectileSourcePosition", {0, 0})[1]) + 1.0 then
    moveX(self.toTarget[1])
  else
    stateData.wasInRange = true
    moveX(-self.toTarget[1])
  end
  
  if stateData.didAttack == false and attackCompletion >= 0.25 then
    local projectileStartPosition = entity.toAbsolutePosition(stateData.projectileSourcePosition)
    local projectileName = entity.configParameter("meleeProjectile") or entity.configParameter("meleeAttack.projectile")
    local power = root.evalFunction("monsterLevelPowerMultiplier", entity.level()) * entity.configParameter("meleeAttack.power")
    world.spawnProjectile(projectileName, projectileStartPosition, entity.id(), {entity.facingDirection(), 0}, true, {speed = 7.0, power = power})
    stateData.didAttack = true
  end

  return false
end

function meleeAttack.leavingState(stateData)
  entity.applyMovementParameters({runSpeed=stateData.baseRunSpeed,groundForce=100})  
end