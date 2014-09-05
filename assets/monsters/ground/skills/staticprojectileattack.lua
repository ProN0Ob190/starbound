staticProjectileAttack = {}

function staticProjectileAttack.start()
  return { firing = false,
           cooldown = 0.0 }
end

function staticProjectileAttack.update(dt, stateData)
  monster.setDamageOnTouch(true)
  monster.setAggressive(true)
  monster.setActiveSkillName(monster.configParameter("staticSkillName"))
  
  if stateData.cooldown > 0 then
    stateData.cooldown = stateData.cooldown - dt
  end
  
  if stateData.firing and not monster.isFiring() then
    stateData.firing = false
    return true
  end
  
  toTargetX = data.toTarget[1]
  toTargetY = data.toTarget[2]

  if stateData.cooldown <= monster.configParameter("staticProjectileHoldTime") then
	if toTargetX < 0 then
	  monster.setFacingDirection(-1)
	  monster.moveLeft()
	elseif toTargetX > 0 then
	  monster.setFacingDirection(1)
	  monster.moveRight()
    end
	if monster.isFiring() then
	  monster.stopFiring()
	  stateData.firing = false
	  return true
    end
  end

  monster.setRunning(true)
  monster.setAnimationState("movement", "idle")

  if monster.readyToFire() and stateData.cooldown <= 0 then
    monster.startFiring(monster.staticRandomizeParameter("staticProjectile"), true)
    stateData.firing = true
	stateData.cooldown = monster.configParameter("staticProjectileCooldown")
  end

  if monster.isFiring() then
    monster.setAnimationState("attack", "shooting")
  else
    monster.setAnimationState("attack", "idle")
  end

  monster.setFireDirection(monster.configParameter("projectileSourcePosition"), data.toTarget)

  return false
end
