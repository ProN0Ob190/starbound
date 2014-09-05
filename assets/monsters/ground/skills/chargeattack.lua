chargeAttack = {}

function chargeAttack.enter()
  if not canStartSkill("chargeAttack") then return nil end

  -- Don't start a charge attack if we're blocked or about to fall
  if isBlocked() or willFall() then
    return nil
  end

  local chargeAttackDirection = 0
  if self.toTarget[1] < 0 then
    chargeAttackDirection = -1
    entity.setFacingDirection(-1)
  else
    chargeAttackDirection = 1
    entity.setFacingDirection(1)
  end

  return {
    windupTime = entity.configParameter("chargeAttack.windupTime"),
    winddownTime = 0,
    chargeAttackDirection = chargeAttackDirection
  }
end

function chargeAttack.enteringState(stateData)
  entity.setAnimationState("attack", "idle")
  setAggressive(true, true)

  entity.setActiveSkillName("chargeAttack")

  stateData.baseRunSpeed = entity.runSpeed()
  entity.applyMovementParameters({runSpeed=stateData.baseRunSpeed + entity.configParameter("chargeAttack.speedBonus")})
end

function chargeAttack.update(dt, stateData)
  if not canContinueSkill() then return true end

  if stateData.windupTime > 0 then
    stateData.windupTime = stateData.windupTime - dt
    entity.setRunning(false)
    entity.setAnimationState("movement", "chargeWindup")
  elseif stateData.winddownTime > 0 then
    stateData.winddownTime = stateData.winddownTime - dt

    entity.setAnimationState("attack", "idle")
    setAggressive(true, false)

    entity.applyMovementParameters({runSpeed=stateData.baseRunSpeed})

    if isBlocked() then
      entity.setAnimationState("movement", "idle")
    else
      if 2 * stateData.winddownTime > entity.configParameter("chargeAttack.winddownTime") / 3 then
        entity.setRunning(true)
        entity.setAnimationState("movement", "charge")
        moveX(stateData.chargeAttackDirection)
      elseif stateData.winddownTime > entity.configParameter("chargeAttack.winddownTime") / 3 then
        entity.setRunning(false)
        entity.setAnimationState("movement", "walk")
        moveX(stateData.chargeAttackDirection)
      else
        entity.setAnimationState("movement", "idle")
      end
    end

    if stateData.winddownTime <= 0 then
      return true
    end
  else
    entity.setRunning(true)
    moveX(stateData.chargeAttackDirection)
    entity.setAnimationState("movement", "charge")

    if isBlocked() then
      --CRASH
      entity.playSound(entity.randomizeParameter("chargeAttack.crashSounds"))

      local crashTiles = {}
      local basePos = entity.configParameter("projectileSourcePosition")
      for xOffset = 2, 3 do
        for yOffset = -1, 1 do
          table.insert(crashTiles, entity.toAbsolutePosition({basePos[1] + xOffset, basePos[2] + yOffset}))
        end
      end
      world.damageTiles(crashTiles, "foreground", entity.toAbsolutePosition({10, 0}), "plantish", entity.configParameter("chargeAttack.crashDamageAmount"))

      self.state.pickState({stun=true,duration=entity.configParameter("chargeAttack.crashStunTime")})
      return true
    end

    if entity.animationState("attack") ~= "chargeAttack" then
      if math.abs(self.toTarget[1]) < entity.configParameter("chargeAttack.attackDistance") then
        entity.setAnimationState("attack", "chargeAttack")
        entity.playSound(entity.randomizeParameter("attackNoise"))
      elseif self.toTarget[1] * entity.facingDirection() > 0 then
        entity.setAnimationState("attack", "charge")
      else
        stateData.winddownTime = entity.configParameter("chargeAttack.winddownTime")
      end
    else
      if math.abs(self.toTarget[1]) > entity.configParameter("chargeAttack.attackDistance") then
        stateData.winddownTime = entity.configParameter("chargeAttack.winddownTime")
      end
    end
  end

  return false
end

function chargeAttack.leavingState(stateData)
  entity.applyMovementParameters({runSpeed=stateData.baseRunSpeed})  
end