function createRangedAttack(skillName)
  local rangedAttack = {}

  function rangedAttack.loadSkillParameters()
    local params = entity.configParameter(skillName)

    --parameters to be used within this state
    rangedAttack.pType = type(entity.configParameter(skillName..".projectile")) == "table" and entity.staticRandomizeParameter(skillName..".projectile") or entity.configParameter(skillName..".projectile")
    rangedAttack.pPower = root.evalFunction("monsterLevelPowerMultiplier", entity.level()) * params.power
    rangedAttack.pSpeed = params.speed
    rangedAttack.pGrav = root.projectileGravityMultiplier(rangedAttack.pType)
    rangedAttack.pArc = params.arc
    rangedAttack.shots = params.shots or 1.0
    rangedAttack.fireInterval = params.fireInterval or 1
    rangedAttack.range = params.range or 15.0
    rangedAttack.giveUpRange = rangedAttack.range + 3
    rangedAttack.fireSound = params.fireSound
    rangedAttack.fireAnimation = params.fireAnimation
    rangedAttack.fireAnimationTiming = params.fireAnimationTiming or 0
    rangedAttack.windupTime = params.windupTime or 0.3
    rangedAttack.winddownTime = params.winddownTime or 0.3
    rangedAttack.lockAim = params.lockAim or false

    --parameters to be used by the main script
    params.skillTimeLimit = rangedAttack.windupTime + rangedAttack.fireInterval * (rangedAttack.shots - 1) + rangedAttack.winddownTime
    params.cooldownTime = params.cooldownTime or 5.0

    --create geometry
    params.approachPoints = { {-rangedAttack.range + 3, 0}, {rangedAttack.range - 3, 0} }
    params.startRects = { {-rangedAttack.range, -7, math.min(-rangedAttack.range + 10.5, -1), 5}, {math.max(rangedAttack.range - 10.5, 1), -7, rangedAttack.range, 5} }

    return params
  end

  function rangedAttack.enter()
    if not canStartSkill(skillName) then return nil end

    return { fireCooldown = math.max(rangedAttack.windupTime, rangedAttack.fireAnimationTiming), shotsRemaining = rangedAttack.shots }
  end

  function rangedAttack.enteringState(stateData)
    setAggressive(true, true)

    rangedAttack.aim(world.distance(world.entityPosition(self.target), entity.toAbsolutePosition(entity.configParameter("projectileSourcePosition"))))

    entity.setActiveSkillName(skillName)
  end

  function rangedAttack.update(dt, stateData)
    if not canContinueSkill() then return true end

    if stateData.shotsRemaining <= 0 then return false end

    local toTarget = world.distance(world.entityPosition(self.target), entity.toAbsolutePosition(entity.configParameter("projectileSourcePosition")))

    if math.abs(toTarget[1]) > rangedAttack.giveUpRange
       or toTarget[1] * entity.facingDirection() < 0
       or not entity.entityInSight(self.target)
      then return true end

    if not rangedAttack.lockAim then rangedAttack.aim(toTarget) end

    if not rangedAttack.fireAnimation then entity.setAnimationState("attack", "shooting") end

    if rangedAttack.fireAnimation and stateData.fireCooldown <= rangedAttack.fireAnimationTiming then
      entity.setAnimationState("attack", rangedAttack.fireAnimation)
    end

    if stateData.fireCooldown <= 0 then
      if not rangedAttack.lockAim or not stateData.fireVector then
        stateData.fireVector = toTarget
        if rangedAttack.pArc ~= nil then
          stateData.fireVector = util.aimVector(toTarget, rangedAttack.pSpeed, rangedAttack.pGrav, rangedAttack.pArc == "high")
        end
      end

      rangedAttack.fire(stateData.fireVector)

      stateData.shotsRemaining = stateData.shotsRemaining - 1
      stateData.fireCooldown = rangedAttack.fireInterval
    end
    stateData.fireCooldown = stateData.fireCooldown - dt

    local movement = calculateSeparationMovement()
    if movement ~= 0 then
      entity.setAnimationState("movement", "walk")

      if movement > 0 then
        moveX(1)
      else
        moveX(-1)
      end
    else
      entity.setAnimationState("movement", "idle")
    end

    return false
  end

  function rangedAttack.aim(direction)
    entity.rotateGroup("projectileAim", 0)
    entity.setFacingDirection(util.toDirection(direction[1]))

    local maxRotate = math.pi / 180 * 30
    local rotateAmount = math.atan2(-direction[2],math.abs(direction[1]))

    if rotateAmount > 0 then
      rotateAmount = math.min(rotateAmount, maxRotate)
    else
      rotateAmount = math.max(rotateAmount, -maxRotate)
    end

    entity.rotateGroup("projectileAim", rotateAmount);
  end

  function rangedAttack.fire(direction)
    local pConfig = {
      power = rangedAttack.pPower,
      speed = rangedAttack.pSpeed
    }
    world.spawnProjectile(rangedAttack.pType, entity.toAbsolutePosition(entity.configParameter("projectileSourcePosition")), entity.id(), direction, false, pConfig)

    -- if rangedAttack.telegraph then
    --   local tpConfig = {
    --     speed = 0.001,
    --     power = 0,
    --     timeToLive = rangedAttack.telegraphTime,
    --     actionOnReap = {{
    --       action = "projectile",
    --       type = rangedAttack.pType,
    --       config = pConfig
    --     }}
    --   }
    --   world.spawnProjectile(rangedAttack.telegraph, entity.toAbsolutePosition(entity.configParameter("projectileSourcePosition")), entity.id(), direction, false, tpConfig)
    -- else
    --   world.spawnProjectile(rangedAttack.pType, entity.toAbsolutePosition(entity.configParameter("projectileSourcePosition")), entity.id(), direction, false, pConfig)
    -- end

    if rangedAttack.fireSound then
      entity.playSound(entity.randomizeParameter(rangedAttack.fireSound))
    end
  end

  function rangedAttack.leavingState(stateData)
    entity.rotateGroup("projectileAim", 0)
  end

  return rangedAttack
end