gustAttack = {
  minDistance = 3.5,
  maxMoveTime = 4,
  gustTime = 0.8,
  startGustForce = 100,
  endGustForce = 50,
  gustLiftFactor = 1.2,
  minGustRegionWidth = 5,
  maxGustRegionWidth = 15,
}

function gustAttack.enter()
  if not canStartSkill("gustAttack") then return nil end

  return { run = coroutine.wrap(gustAttack.run) }
end

function gustAttack.enteringState(stateData)
  entity.setAnimationState("movement", "idle")
  entity.setAnimationState("attack", "idle")

  entity.setActiveSkillName("gustAttack")
end

function gustAttack.update(dt, stateData)
  if not hasTarget() then return true end

  return stateData.run(stateData)
end

function gustAttack.leavingState(stateData)
  entity.setParticleEmitterActive("gust", false)
end

function gustAttack.run(stateData)
  local timer = gustAttack.maxMoveTime
  while timer > 0 and math.abs(self.toTarget[1]) < gustAttack.minDistance do
    move({ -self.toTarget[1], 0 })
    timer = timer - entity.dt()
    coroutine.yield(false)
  end

  entity.setAnimationState("movement", "idle")
  entity.setAnimationState("attack", "shooting")

  local bounds = entity.configParameter("metaBoundBox")
  local height = math.abs(bounds[2]) + math.abs(bounds[4])

  -- Make sure to stop all x-movement so the monster doesn't run into its own
  -- force region before stopping
  entity.setVelocity({ 0, entity.velocity()[2] })

  entity.playSound(entity.randomizeParameter("gustAttack.sounds"))

  local gustTimer = 0
  util.wait(gustAttack.gustTime, function(dt)
    local direction = util.toDirection(self.toTarget[1])
    local changingDirection = direction ~= entity.facingDirection()
    entity.setFacingDirection(direction)

    local gustRegionWidth = gustAttack.lerp(gustTimer, gustAttack.minGustRegionWidth, gustAttack.maxGustRegionWidth)
    local region
    if direction < 0 then
      region = {
        self.position[1] + bounds[1] - gustRegionWidth,
        self.position[2] + bounds[2] * 2,
        self.position[1] + bounds[1] - 0.1,
        self.position[2] + bounds[4] * 2,
      }
    else
      region = {
        self.position[1] + bounds[3] + 0.1,
        self.position[2] + bounds[2] * 2,
        self.position[1] + bounds[3] + gustRegionWidth,
        self.position[2] + bounds[4] * 2,
      }
    end

    local gustForce = gustAttack.lerp(gustTimer, gustAttack.startGustForce, gustAttack.endGustForce)
    entity.setForceRegion(region, { gustForce * direction, gustAttack.gustLiftFactor * world.gravity(self.position) } )

    entity.setParticleEmitterActive("gust", not changingDirection)

    gustTimer = gustTimer + dt
  end)

  return true
end

function gustAttack.lerp(time, min, max)
  return min + (max - min) * time / gustAttack.gustTime
end