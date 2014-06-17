-- Factory that creates a flying ranged attack state for a specific skill
function createFlyingRangedAttack(skillName)
  -- Shoot a projectile at the target, moving up and down a bit while doing so
  local flyingRangedAttack = {}

  function flyingRangedAttack.enter()
    if entity.entityInSight(self.target) then
      return {
        timer = 0,
        totalTime = entity.randomizeSkillParameterRange(skillName, "timeRange"),
        projectile = entity.staticRandomizeSkillParameter(skillName, "projectile"),
        basePosition = entity.position(),
        startedFiring = false
      }
    end

    return nil
  end

  function flyingRangedAttack.update(dt, stateData)
    if not entity.entityInSight(self.target) then return true end
    if stateData.timer > stateData.totalTime then return true end

    entity.setDamageOnTouch(false)
    entity.setAggressive(true)

    if not stateData.startedFiring and entity.readyToFire() then
      entity.startFiring(stateData.projectile)
      stateData.startedFiring = true

      entity.setAnimationState("movement", "flyingAttack")
      stateData.attackAnimationTimer = entity.projectileConfigParameter(stateData.projectile, "fireTime")
    end

    local toTarget = entity.distanceToEntity(self.target)
    if stateData.startedFiring then
      entity.setFireDirection(entity.configParameter("projectileOffset"), toTarget)
    end

    if stateData.attackAnimationTimer ~= nil then
      stateData.attackAnimationTimer = stateData.attackAnimationTimer - dt
      if stateData.attackAnimationTimer <= 0.0 then
        entity.setAnimationState("movement", "flying")
        stateData.attackAnimationTimer = nil
      end
    end

    local ratio = stateData.timer / stateData.totalTime

    local position = entity.position()
    local destination = {
      position[1],
      stateData.basePosition[2] - math.sin(ratio * 2.0 * math.pi) * entity.skillConfigParameter(skillName, "movementRadius")
    }

    entity.flyTo(destination, true)
    entity.setFacingDirection(toTarget[1])

    stateData.timer = stateData.timer + dt
    return false
  end

  return flyingRangedAttack
end