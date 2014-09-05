pounceAttack = {}

function pounceAttack.loadSkillParameters()
  local params = entity.configParameter("pounceAttack")

  local jumpSpeed = pounceAttack.jumpSpeed()
  local maxJumpDistance = 0.8 * ( (jumpSpeed * jumpSpeed * 0.7071) / (world.gravity(entity.position()) * 1.5) )
  local tolerance = {-1, -9.0, 6, 7}

  params.approachPoints = { {-(maxJumpDistance), 3}, {(maxJumpDistance), 3} }
  params.startRects = {}
  for i, point in ipairs(params.approachPoints) do
    if point[1] > 0 then
      params.startRects[i] = {point[1] + tolerance[1], point[2] + tolerance[2], point[1] + tolerance[3], point[2] + tolerance[4]}
    else
      params.startRects[i] = {point[1] - tolerance[3], point[2] + tolerance[2], point[1] - tolerance[1], point[2] + tolerance[4]}
    end
  end

  return params
end

function pounceAttack.jumpSpeed()
  return math.min(entity.jumpSpeed() * entity.configParameter("pounceAttack.jumpSpeedMultiplier"), entity.configParameter("pounceAttack.jumpSpeedMax"))
end

function pounceAttack.enter()
  if not canStartSkill("pounceAttack") then return nil end

  if self.toTarget[1] < 0 then
    entity.setFacingDirection(-1)
  elseif self.toTarget[1] > 0 then
    entity.setFacingDirection(1)
  end

  return {
    winddownTime = 0.0,
    windupTime = entity.configParameter("pounceAttack.windupTime"),
    followThrough = false
  }
end

function pounceAttack.enteringState(stateData)
  entity.setAnimationState("attack", "idle")
  entity.setActiveSkillName("pounceAttack")

  stateData.airFriction = 0.5 --TODO: measure the actual previous friction, not just default
  entity.applyMovementParameters({airFriction=0})
end

function pounceAttack.update(dt, stateData)
  if not canContinueSkill() then return true end

  if stateData.windupTime > 0 then
    stateData.windupTime = stateData.windupTime - dt

    entity.setAnimationState("movement", "chargeWindup")
    faceTarget()

  elseif not stateData.followThrough then
    setAggressive(true, true)
    entity.setAnimationState("movement", "jump")
    entity.playSound(entity.randomizeParameter("attackNoise"))

    stateData.pounceJumpHoldTime = entity.configParameter("pounceAttack.jumpHoldTime")
    stateData.pounceWasOffGround = false
    stateData.followThrough = true

    local jumpSpeed = pounceAttack.jumpSpeed()
    stateData.jumpVector = util.aimVector(self.toTarget, jumpSpeed, 1.5, true)
    entity.setVelocity(stateData.jumpVector)
  end

  if stateData.winddownTime > 0.0 then
    entity.setAnimationState("movement", "idle")
    entity.setAnimationState("attack", "idle")
    stateData.winddownTime = stateData.winddownTime - dt
    return stateData.winddownTime <= 0.0
  elseif stateData.followThrough then
    entity.setAnimationState("attack", "charge")

    -- --re-set the velocity until we've properly left the ground to avoid the initial falloff
    if not stateData.pounceWasOffGround then
      entity.setVelocity(stateData.jumpVector)
    end

    -- If the monster is on the ground and was off the ground, the attack is over
    if entity.onGround() then
      if stateData.pounceWasOffGround then
        stateData.winddownTime = entity.configParameter("pounceAttack.winddownTime")
      end
    else
      stateData.pounceWasOffGround = true
    end
  end

  return false
end

function pounceAttack.leavingState(stateData)
  entity.applyMovementParameters({airFriction=stateData.airFriction})
end