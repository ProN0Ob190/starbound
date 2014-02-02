pounceAttack = {}

function pounceAttack.enter()
  if not canStartAttack() then return nil end

  if self.toTarget[1] < 0 then
    entity.setFacingDirection(-1)
  elseif self.toTarget[1] > 0 then
    entity.setFacingDirection(1)
  end

  return {
    pounceCooldown = 0.0,
    pounceAttackWindupTime = entity.configParameter("pounceAttackWindupTime"),
    pounceAttackFollowThrough = false
  }
end

function pounceAttack.enteringState(stateData)
  entity.setAnimationState("attack", "idle")
  entity.setActiveSkillName("pounceAttack")

  entity.setRunning(true)
  setAggressive(true, true)
end

function pounceAttack.update(dt, stateData)
  if not canContinueAttack() then return true end

  if stateData.pounceAttackWindupTime > 0 then
    stateData.pounceAttackWindupTime = stateData.pounceAttackWindupTime - dt
    entity.setAnimationState("movement", "chargeWindup")
  elseif not stateData.pounceAttackFollowThrough then
    entity.setAnimationState("movement", "jump")
    entity.playSound(entity.randomizeParameter("attackNoise"))

    stateData.pounceJumpHoldTime = entity.configParameter("pounceAttackJumpHoldTime")
    stateData.pounceWasOffGround = false
    stateData.pounceAttackFollowThrough = true
    entity.jump()
  end

  if stateData.pounceCooldown > 0.0 then
    entity.setAnimationState("movement", "idle")
    stateData.pounceCooldown = stateData.pounceCooldown - dt
    return stateData.pounceCooldown <= 0.0
  elseif stateData.pounceAttackFollowThrough then
    if self.toTarget[1] < 0 then
      entity.moveLeft()
      entity.setFacingDirection(-1)
    elseif self.toTarget[1] > 0 then
      entity.moveRight()
      entity.setFacingDirection(1)
    end

    if stateData.pounceJumpHoldTime > 0.0 then
      entity.holdJump()
      stateData.pounceJumpHoldTime = stateData.pounceJumpHoldTime - entity.dt()

      -- If the monster is on the ground and was off the ground, the attack is over
      if entity.onGround() then
        if stateData.pounceWasOffGround then
          stateData.pounceCooldown = entity.configParameter("pounceAttackCooldown")
        end
      else
        stateData.pounceWasOffGround = true
      end
    else
      if entity.onGround() then
        stateData.pounceCooldown = entity.configParameter("pounceAttackCooldown")
      end
    end
  end

  return false
end
