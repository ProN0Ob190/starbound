burrowSpecial = {}

function burrowSpecial.enter()
  if not hasTarget()
      or self.skillCooldownTimers["burrowSpecial"] > 0
      or not isBlocked()
      or world.magnitude(self.toTarget) > entity.configParameter("burrowSpecial.maxRange")
      or #world.collisionBlocksAlongLine(entity.position(), world.entityPosition(self.target)) > entity.configParameter("burrowSpecial.maxThickness")
    then return nil end

  return { digTimer = 0 }
end

function burrowSpecial.enteringState(stateData)
  entity.setAnimationState("attack", "idle")
  entity.setRunning(true)

  entity.setActiveSkillName("burrowSpecial")
end

function burrowSpecial.update(dt, stateData)
  if not canContinueSkill() then return true end
  if willFall() then return true end

  local obstructed = isBlocked() or not entity.entityInSight(self.target)
  if not obstructed and world.magnitude(self.toTarget) < entity.configParameter("burrowSpecial.minRange") then return true end

  stateData.digTimer = stateData.digTimer - dt

  faceTarget()
  if math.abs(self.toTarget[1]) > entity.configParameter("burrowSpecial.minRange") then
    --approach
    moveX(self.toTarget[1])
  else
    --target is above or below... hmmm....
  end

  --run if we're moving
  if isBlocked() then
    entity.setAnimationState("movement", "idle")
  else
    entity.setAnimationState("movement", "run")
  end

  if obstructed then
    --dig
    if stateData.digTimer <= 0 then
      local pConfig = {
        speed = 5,
        timeToLive = 0.01,
        actionOnReap = {
          {
            action = "explosion",
            foregroundRadius = entity.configParameter("burrowSpecial.digSize"),
            backgroundRadius = 0,
            explosiveDamageAmount = entity.configParameter("burrowSpecial.digDamage")
          }
        }
      }
      world.spawnProjectile("invisibleprojectile", entity.toAbsolutePosition({1.75, -0.5}), entity.id(), {entity.facingDirection(), 0}, false, pConfig)
      stateData.digTimer = entity.configParameter("burrowSpecial.digTime")
    end

    --rotate head
    local timeFraction = stateData.digTimer / entity.configParameter("burrowSpecial.digTime")
    local maxRotate = math.pi / 180 * 30
    entity.rotateGroup("projectileAim", timeFraction * 1.5 * maxRotate - maxRotate)
  end

  return false
end