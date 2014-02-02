grabAttack = {
  maxHoldDistance = { 3, 4 },
  estimatedTargetMass = 0.6,
  maxMoveTime = 5,
  maxDistanceMismatch = 1,
  holdTime = 3
}

function grabAttack.enter()
  if not canStartAttack() then return nil end

  return { run = coroutine.wrap(grabAttack.run) }
end

function grabAttack.enteringState(stateData)
  entity.setAnimationState("movement", "idle")
  entity.setAnimationState("attack", "idle")

  entity.setActiveSkillName("grabAttack")
end

function grabAttack.update(dt, stateData)
  if not hasTarget() then return true end

  return stateData.run(stateData)
end

function grabAttack.leavingState(stateData)
  entity.setRunning(false)
end

function grabAttack.run(stateData)
  local timer = grabAttack.maxMoveTime
  while timer > 0 and not grabAttack.withinHoldDistance() do
    move({ self.toTarget[1], 0 })
    timer = timer - entity.dt()
    coroutine.yield(false)
  end

  entity.setFacingDirection(self.toTarget[1])

  if math.abs(self.toTarget[1]) - grabAttack.maxHoldDistance[1] > grabAttack.maxDistanceMismatch then
    return true
  end

  util.wait(grabAttack.holdTime, function()
    if not grabAttack.withinHoldDistance() then
      entity.setAnimationState("attack", "idle")
      if timer > 0 then
        move({ self.toTarget[1], 0 })
        timer = timer - entity.dt()
        return false
      else
        return true
      end
    end
    entity.setAnimationState("movement", "idle")
    entity.setAnimationState("attack", "shooting")
    world.spawnProjectile("grabbed", world.entityPosition(self.target), entity.id(), { 0, 0 }, false)
  end)

  return true
end

function grabAttack.withinHoldDistance()
  return math.abs(self.toTarget[1]) <= grabAttack.maxHoldDistance[1] and
    math.abs(self.toTarget[2]) <= grabAttack.maxHoldDistance[2]
end