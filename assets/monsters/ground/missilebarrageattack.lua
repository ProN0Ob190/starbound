missileBarrageAttack = {
  missileCount = 3,
  fireTime = 0.75
}

--------------------------------------------------------------------------------
function missileBarrageAttack.enter()
  if not canStartSkill("missileBarrageAttack") then return nil end

  return { ammo = missileBarrageAttack.missileCount, fireTimer = 0 }
end

--------------------------------------------------------------------------------
function missileBarrageAttack.enteringState(stateData)
  entity.setAnimationState("movement", "idle")
  entity.setAnimationState("attack", "idle")

  entity.setActiveSkillName("missileBarrageAttack")
end

--------------------------------------------------------------------------------
function missileBarrageAttack.update(dt, stateData)
  if not canContinueSkill() then return true end

  if stateData.fireTimer <= 0 then
    local missileId = world.spawnMonster("missile", entity.toAbsolutePosition({0, 4}))
    world.callScriptedEntity(missileId, "setTarget", self.target)

    entity.playSound(entity.randomizeParameter("missileBarrageAttack.sounds"))

    stateData.ammo = stateData.ammo - 1
    if stateData.ammo <= 0 then return true end

    stateData.fireTimer = missileBarrageAttack.fireTime
  end

  stateData.fireTimer = stateData.fireTimer - dt
end