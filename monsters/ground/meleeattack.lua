meleeAttack = {}

function meleeAttack.enter()
  if not canStartAttack() then return nil end

  return { meleeMovement = util.toDirection(self.toTarget[1]) }
end

function meleeAttack.enteringState(stateData)
  entity.setRunning(true)
  setAggressive(true, true)
  if entity.setAnimationState("attack", "melee") then
    entity.playSound(entity.randomizeParameter("attackNoise"))
  end

  entity.setActiveSkillName("meleeAttack")
end

function meleeAttack.update(dt, stateData)
  if not canContinueAttack() then return true end

  if stateData.meleeMovement < 0 then
    entity.setFacingDirection(-1)
    entity.moveLeft()
  else
    entity.setFacingDirection(1)
    entity.moveRight()
  end

  return false
end
