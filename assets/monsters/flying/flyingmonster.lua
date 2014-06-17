function init(args)
  self.position = {0, 0}

  self.target = 0
  self.toTarget = {0, 0}
  if entity.configParameter("alwaysAggressive", false) then
    self.aggressive = true
  else
    self.aggressive = entity.configParameter("aggressive", false)
  end
  
  self.knockout = false
  self.dead = false

  self.targetSearchTimer = 0
  self.knockoutTimer = 0
  self.targetHoldTimer = 0
  self.attackCooldownTimer = 0

  self.sensors = sensors.create()

  self.debug = false

  local scripts = entity.configParameter("scripts")

  local states = stateMachine.scanScripts(scripts, "(%a+State)%.lua")
  self.state = stateMachine.create(states)

  local attacks = {}
  local attackStateTables = {}
  for i, skillName in ipairs(entity.configParameter("skills")) do
    local params = entity.configParameter(skillName)

    --create generic attacks from factories
    if params and params.factory then
      if type(_ENV[params.factory]) == "function" then
        if not _ENV[skillName] then
          _ENV[skillName] = _ENV[params.factory](skillName)
        else
          world.logInfo("Failed to create attack %s from factory %s: Table %s already exists in this context", skillName, params.factory, skillName)
        end
      else
        world.logInfo("Failed to create attack %s from factory %s: factory function does not exist in this context", skillName, params.factory)
      end
    end

    if _ENV[skillName] then
      table.insert(attacks, 1, skillName)
    end
  end

  self.attackState = stateMachine.create(attacks, attackStateTables)
  self.attackState.autoPickState = false

  self.attackState.enteringState = function(state)
    entity.setActiveSkillName(state)
    setAggressive(true)
    self.attackState.moveStateToEnd(state)
  end

  self.attackState.leavingState = function(state)
    setAggressive(false)
    entity.setActiveSkillName(nil)
    self.attackCooldownTimer = entity.configParameter("attackCooldownTime")
  end

  entity.setDeathSound(entity.randomizeParameter("deathNoise"))
  entity.setDeathParticleBurst(entity.configParameter("deathParticles"))

  entity.setFacingDirection(util.randomDirection())
  entity.setAnimationState("movement", "flying")
end

function isFlyer()
  return true
end

function damage(args)
  setTarget(args.sourceId)

  if entity.health() <= 0 then
    self.knockoutTimer = entity.configParameter("knockoutTime")
    self.knockout = true
  else
    self.state.endState()
  end
end

function shouldDie()
  return self.dead
end

function setAggressive(enabled)
  if enabled then
    entity.setAggressive(true)
    entity.setDamageOnTouch(true)
  else
    entity.setDamageOnTouch(entity.configParameter("alwaysDamageOnTouch", false))
    entity.setAggressive(entity.configParameter("alwaysAggressive", false))
  end
end

function main()
  self.position = entity.position()

  if self.knockout then
    entity.setAnimationState("movement", "knockout")
    entity.setEffectActive(entity.configParameter("knockoutEffect"), true)

    setAggressive(true)
    entity.setDamageOnTouch(false)
    self.attackState.endState()

    if self.knockoutTimer <= 0 then
      self.dead = true
    end

  elseif entity.stunned() then
    entity.setAnimationState("movement", "knockback")
    setAggressive(true)
    self.attackState.endState()
    entity.fly({0,0}, true)
  else
    if entity.animationState("movement") ~= "flyingAttack" then
      entity.setAnimationState("movement", "flying")
    end

    trackTarget()
    
    -- Attacks can interrupt any normal state
    if self.target ~= 0 then
      if attacking() then
        local attackMaxDistance = entity.configParameter("attackMaxDistance", math.huge)

        if world.magnitude(self.toTarget) > attackMaxDistance then
          self.attackState.endState()
        else
          self.attackState.update(entity.dt())
        end
      else
        local attackStartDistance = entity.configParameter("attackStartDistance")

        if world.magnitude(self.toTarget) <= attackStartDistance and self.attackCooldownTimer <= 0 then
          self.attackState.pickState()
        end
      end
    end

    if not attacking() then
      setAggressive(false)
      self.state.update(entity.dt())
    end
  end

  decrementTimers()

  entity.setScriptDelta(hasTarget() and 1 or 10)

  if self.debug then
    if attacking() then
      world.debugText(self.attackState.stateDesc(), entity.toAbsolutePosition({ 0, 2 }), "red")
    elseif self.state.hasState() then
      world.debugText(self.state.stateDesc(), entity.toAbsolutePosition({ 0, 2 }), "blue")
    end

    for i, groundSensorIndex in ipairs({ 3, 2, 1 }) do
      local sensor = self.sensors.groundSensors.collisionTrace[groundSensorIndex]
      if sensor.value then
        world.debugLine(entity.position(), sensor.position, "green")
        world.debugPoint(sensor.position, "green")
      else
        world.debugLine(entity.position(), sensor.position, "red")
        world.debugPoint(sensor.position, "red")
      end
    end
  end

  self.sensors.clear()
end

function trackTarget()
  -- Keep holding on our target while we are attacking
  if not world.entityExists(self.target) or (not attacking() and self.targetHoldTimer <= 0) then
    setTarget(0)
  end

  if self.aggressive and self.target == 0 and self.targetSearchTimer <= 0 then
    setTarget(entity.closestValidTarget(entity.configParameter("targetRadius")))
    self.targetSearchTimer = entity.configParameter("targetSearchTime")
  end

  if self.target == 0 then
    self.toTarget = {0, 0}
  else
    self.toTarget = entity.distanceToEntity(self.target)
  end
end

function setTarget(target)
  if target ~= 0 then
    self.targetHoldTimer = entity.configParameter("targetHoldTime")

    if self.target ~= target then
      entity.playSound(entity.randomizeParameter("turnHostileNoise"))

      -- Don't attack immediately when turning aggressive
      self.attackCooldownTimer = entity.configParameter("attackCooldownTime")
    end
  end

  self.target = target
end

function hasTarget()
  return self.target ~= 0
end

function decrementTimers()
  dt = entity.dt()

  self.targetSearchTimer = self.targetSearchTimer - dt
  self.knockoutTimer = self.knockoutTimer - dt
  self.targetHoldTimer = self.targetHoldTimer - dt
  self.attackCooldownTimer = self.attackCooldownTimer - dt
end

function attacking()
  return self.attackState.hasState()
end
