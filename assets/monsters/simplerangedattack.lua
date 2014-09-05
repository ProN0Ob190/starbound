rangedAttack = {
  attackTimer = 0,
  fireTimer = 0,
  cooldownTimer = 0,
  firing = false,
  aimVector = {1, 0}
}

function rangedAttack.loadConfig()
  rangedAttack.attackTime = entity.configParameter("attackTime", 1)
  rangedAttack.fireInterval = entity.configParameter("fireInterval", 1)
  rangedAttack.cooldownTime = entity.configParameter("cooldownTime", 0)

  rangedAttack.projectile = entity.configParameter("projectileType", "bullet-1")
  rangedAttack.config = entity.configParameter("projectileConfig", { power = root.evalFunction("monsterLevelPowerMultiplier", entity.level()) * 10 })
  rangedAttack.sourceOffset = entity.configParameter("projectileSourcePosition", {0, 0})
end

function rangedAttack.setConfig(projectile, config, fireInterval)
  if projectile then rangedAttack.projectile = projectile end
  if config then rangedAttack.config = config end
  if fireInterval then rangedAttack.fireInterval = fireInterval end
end

function rangedAttack.aim(sourceOffset, aimVector)
  rangedAttack.sourceOffset = sourceOffset
  rangedAttack.aimVector = aimVector
end

function rangedAttack.fireOnce(projectile, config, aimVector, trackEntity)
-- world.logInfo("Ranged attack firing with projectile %s, position %s, direction %s, trackEntity %s, config %s", projectile or rangedAttack.projectile, entity.toAbsolutePosition(rangedAttack.sourceOffset), aimVector or rangedAttack.aimVector, trackEntity or false, config or rangedAttack.config)
  world.spawnProjectile(projectile or rangedAttack.projectile, entity.toAbsolutePosition(rangedAttack.sourceOffset), entity.id(), aimVector or rangedAttack.aimVector, trackEntity or false, config or rangedAttack.config)
end

function rangedAttack.fireContinuous(trackEntity)
  if not rangedAttack.firing then
    rangedAttack.firing = true
    rangedAttack.attackTimer = rangedAttack.attackTime
  elseif rangedAttack.cooldownTimer <= 0 then
    rangedAttack.attackTimer = rangedAttack.attackTimer - entity.dt()
    if rangedAttack.attackTimer <= 0 then
      rangedAttack.cooldownTimer = rangedAttack.cooldownTime
      rangedAttack.attackTimer = rangedAttack.attackTime
    else
      rangedAttack.fireTimer = rangedAttack.fireTimer - entity.dt()
      if rangedAttack.fireTimer <= 0 then
        rangedAttack.fireOnce(nil, nil, nil, trackEntity)
        rangedAttack.fireTimer = rangedAttack.fireInterval
      end
    end
  else
    rangedAttack.cooldownTimer = rangedAttack.cooldownTimer - entity.dt()
  end
end

function rangedAttack.stopFiring()
  rangedAttack.firing = false
end