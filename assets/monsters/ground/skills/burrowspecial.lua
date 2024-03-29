burrowSpecial = {}

function burrowSpecial.enter()
  -- if hasTarget() and self.skillCooldownTimers["burrowSpecial"] <= 0 and self.onGround then
  --   if not isBlocked() then
  --     world.logInfo("Can't burrow because NOT BLOCKED")
  --   elseif world.magnitude(self.toTarget) > entity.configParameter("burrowSpecial.maxRange") then
  --     world.logInfo("Can't burrow because TOO FAR (max)")
  --   elseif self.toTarget[2] > 5 or self.toTarget[2] < -5 then
  --     world.logInfo("Can't burrow because TOO FAR (vertical)")
  --   elseif burrowSpecial.canJumpUp() then
  --     world.logInfo("Can't burrow because CAN JUMP UP")
  --   elseif #world.collisionBlocksAlongLine(entity.position(), world.entityPosition(self.target)) > entity.configParameter("burrowSpecial.maxThickness") then
  --     world.logInfo("Can't burrow because TOO THICKE")
  --   end
  -- end

  if not hasTarget()
      or self.skillCooldownTimers["burrowSpecial"] > 0
      or not self.onGround
      or not isBlocked()
      --or self.toTarget[2] > 5 or self.toTarget[2] < -5 --don't dig too directly into the ceiling or floor
      or world.magnitude(self.toTarget) > entity.configParameter("burrowSpecial.maxRange")
      or burrowSpecial.canJumpUp() --don't dig through short cliffs
      or #world.collisionBlocksAlongLine(entity.position(), world.entityPosition(self.target)) > entity.configParameter("burrowSpecial.maxThickness")
    then
      if self.skillCooldownTimers["burrowSpecial"] <= 0 then self.skillCooldownTimers["burrowSpecial"] = 0.2 end --don't check again immediately
      return nil
  end

  return { digTimer = 0 }
end

function burrowSpecial.canJumpUp()
  local canJumpUp
  local bb = entity.boundBox()
  local pos = entity.position()

  -- world.debugLine(pos, {pos[1], pos[2] + jumpHeight() + bb[4]}, "#FF00FF")
  -- world.debugLine({pos[1], pos[2] + jumpHeight() + bb[2]}, entity.toAbsolutePosition({ bb[3] + 2, jumpHeight() + bb[2]}), "#FF00FF")

  local upLine = { pos, {pos[1], pos[2] + jumpHeight() + bb[4]} }
  if world.lineCollision(upLine[1], upLine[2]) then
    canJumpUp = false
  else
    local overLine = { {pos[1], pos[2] + jumpHeight() + bb[2]}, entity.toAbsolutePosition({ bb[3] + 2, jumpHeight() + bb[2]})  }
    canJumpUp = not world.lineCollision(overLine[1], overLine[2])
  end

  return canJumpUp
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

      local digPosition
      if self.toTarget[2] > 1.5 then
        digPosition = entity.toAbsolutePosition({1.75, 1.0})
      elseif self.toTarget[2] < -1.5 then
        digPosition = entity.toAbsolutePosition({1.75, 0.0})
      else
        digPosition = entity.toAbsolutePosition({1.75, -1.5})
      end


      world.spawnProjectile("invisibleprojectile", digPosition, entity.id(), {entity.facingDirection(), 0}, false, pConfig)
      stateData.digTimer = entity.configParameter("burrowSpecial.digTime")
    end

    --rotate head
    local timeFraction = stateData.digTimer / entity.configParameter("burrowSpecial.digTime")
    local maxRotate = math.pi / 180 * 30
    entity.rotateGroup("projectileAim", timeFraction * 1.5 * maxRotate - maxRotate)
  end

  return false
end