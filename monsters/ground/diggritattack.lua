digGritAttack = {
  minDistance = 3,
  maxDistance = 9,
  maxMoveInRangeTime = 3,
  digTime = 2,
  fireTime = 0.2,
}

--------------------------------------------------------------------------------
function digGritAttack.enter()
  if not canStartAttack() then return nil end

  return { run = coroutine.wrap(digGritAttack.run) }
end

--------------------------------------------------------------------------------
function digGritAttack.enteringState(stateData)
  entity.setAnimationState("movement", "idle")
  entity.setAnimationState("attack", "idle")

  entity.setActiveSkillName("digGritAttack")
end

--------------------------------------------------------------------------------
function digGritAttack.update(dt, stateData)
  if not canContinueAttack() then return true end

  return stateData.run(stateData)
end

--------------------------------------------------------------------------------
function digGritAttack.run(stateData)
  local targetPosition = world.entityPosition(self.target)

  if not digGritAttack.moveInRange(targetPosition) then
    return true
  end

  entity.setAnimationState("movement", "run")

  local feetOffset = entity.configParameter("metaBoundBox")[2]

  local timer, projectileTimer = digGritAttack.digTime, digGritAttack.fireTime
  while timer > 0 do
    targetPosition = world.entityPosition(self.target)
    local toTarget = world.distance(targetPosition, entity.position())
    entity.setFacingDirection(-toTarget[1])

    if projectileTimer < 0 then
      world.spawnProjectile("rock", vec2.add(entity.position(), { 0, feetOffset }), entity.id(), toTarget, false, {
        speed = 20,
        physics = "bullet",
        actionOnReap = {
          {
            action = "tile",
            materials = {
              { kind = "sand" }
            },
            allowEntityOverlap = true
          }
        }
      })
      projectileTimer = digGritAttack.fireTime
    end

    local dt = entity.dt()
    projectileTimer = projectileTimer - dt
    timer = timer - dt

    coroutine.yield(false)
  end

  return true
end

--------------------------------------------------------------------------------
function digGritAttack.moveInRange(targetPosition)
  local timer = digGritAttack.maxMoveInRangeTime
  while timer > 0 do
    local toTarget = world.distance(targetPosition, entity.position())
    local distance = world.magnitude(toTarget)
    if distance < digGritAttack.minDistance then
      move({ -toTarget[1], -toTarget[2] })
    elseif distance > digGritAttack.maxDistance then
      move(toTarget)
    else
      return true
    end

    timer = timer - entity.dt()
    coroutine.yield(false)
  end

  return false
end

--------------------------------------------------------------------------------
function digGritAttack.wait(duration, action)
  local timer = 0
  while timer < duration do
    if action ~= nil then action() end

    timer = timer + entity.dt()
    coroutine.yield(false)
  end
end
