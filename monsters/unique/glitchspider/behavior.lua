function init(args)
  self.debug = false
  self.groundDirection = { 0, -1 }
  self.groundChangeCooldownTimer = 0

  self.state = stateMachine.create({
    "moveState",
    "dropState"
  })

  self.state.leavingState = function(stateName)
    self.state.shuffleStates()
    entity.setAnimationState("movement", "idle")
  end

  entity.setAnimationState("movement", "idle")
  entity.setDeathParticleBurst("deathPoof")
end

--------------------------------------------------------------------------------
function main()
  if util.trackTarget(entity.configParameter("noticeDistance")) then
    self.state.pickState({ targetId = self.targetId })
  end
  entity.setAggressive(self.targetId ~= nil)
  entity.setDamageOnTouch(self.targetId ~= nil)

  local dt = entity.dt()
  if self.groundChangeCooldownTimer > 0 then
    self.groundChangeCooldownTimer = math.max(0, self.groundChangeCooldownTimer - dt)
  end

  if not self.state.update(dt) then
    entity.fly({ 0, 0 }, true)
  end
end

--------------------------------------------------------------------------------
function damage(args)
  if self.targetId == nil then
    self.state.pickState({ targetId = args.sourceId })
  end
end

--------------------------------------------------------------------------------
function setSpawnVelocity(velocity)
  entity.setVelocity(velocity)
end

--------------------------------------------------------------------------------
function setGroundDirection(groundDirection)
  if self.groundChangeCooldownTimer > 0 then return false end

  self.groundDirection = groundDirection
  self.groundChangeCooldownTimer = entity.configParameter("changeGroundCooldown")

  local desiredAngle = math.atan2(self.groundDirection[2], self.groundDirection[1]) + math.pi / 2
  entity.rotateGroup("all", -entity.facingDirection() * desiredAngle)

  return true
end

--------------------------------------------------------------------------------
function headingFromDirection(direction)
  return {
    direction * -self.groundDirection[2],
    direction * self.groundDirection[1]
  }
end

--------------------------------------------------------------------------------
function boundingBox()
  local position = entity.position()
  local bounds = entity.configParameter("metaBoundBox")
  bounds[1] = position[1] + bounds[1]
  bounds[2] = position[2] + bounds[2]
  bounds[3] = position[1] + bounds[3]
  bounds[4] = position[2] + bounds[4]
  return bounds
end

--------------------------------------------------------------------------------
function onGround()
  local bounds = boundingBox()

  local floorCheckRegion = {
    bounds[1] + self.groundDirection[1] * 0.5,
    bounds[2] + self.groundDirection[2] * 0.5,
    bounds[3] + self.groundDirection[1] * 0.5,
    bounds[4] + self.groundDirection[2] * 0.5
  }
  return world.rectCollision(floorCheckRegion, true)
end

--------------------------------------------------------------------------------
function move(direction)
  entity.setFacingDirection(direction)

  local bounds = boundingBox()
  local heading = headingFromDirection(direction)

  -- Check for concave ground transitions
  local wallCheckRegion = {
    bounds[1] + heading[1] + 0.125,
    bounds[2] + heading[2] + 0.125,
    bounds[3] + heading[1] - 0.125,
    bounds[4] + heading[2] - 0.125
  }
  -- Walls must be higher than one block off the ground
  if self.groundDirection[1] < 0 then wallCheckRegion[1] = wallCheckRegion[1] + 1.0 end
  if self.groundDirection[1] > 0 then wallCheckRegion[3] = wallCheckRegion[3] - 1.0 end
  if self.groundDirection[2] < 0 then wallCheckRegion[2] = wallCheckRegion[2] + 1.0 end
  if self.groundDirection[2] > 0 then wallCheckRegion[4] = wallCheckRegion[4] - 1.0 end

  if world.rectCollision(wallCheckRegion, true) then
    if setGroundDirection(heading) then
      util.debugLog("hit wall at %s", heading)
      heading = headingFromDirection(direction)
    end
  end

  local falling = false

  -- Check for convex ground transitions
  local floorCheckRegion = {
    bounds[1] + self.groundDirection[1] * 1.25,
    bounds[2] + self.groundDirection[2] * 1.25,
    bounds[3] + self.groundDirection[1] * 1.25,
    bounds[4] + self.groundDirection[2] * 1.25
  }
  if not world.rectCollision(floorCheckRegion, true) then
    local newGroundDirection = { -heading[1], -heading[2] }
    local convexCheckRegion = {
      floorCheckRegion[1] + newGroundDirection[1] * 1.125,
      floorCheckRegion[2] + newGroundDirection[2] * 1.125,
      floorCheckRegion[3] + newGroundDirection[1] * 1.125,
      floorCheckRegion[4] + newGroundDirection[2] * 1.125
    }
    if world.rectCollision(convexCheckRegion, true) then
      if setGroundDirection(newGroundDirection) then
        util.debugLog("convex at %s", heading)
        heading = headingFromDirection(direction)
      end
    else
      if setGroundDirection({ 0, -1 }) then
        util.debugLog("falling at %s", heading)
        heading = headingFromDirection(direction)
      end

      falling = true
    end
  end

  local moveSpeed = entity.configParameter("moveSpeed")
  local toGroundMovementMultiplier = 0.5
  if falling then
    entity.setAnimationState("movement", "fall")

    -- Simulate gravity somewhat
    toGroundMovementMultiplier = 8.0
  else
    entity.setAnimationState("movement", "move")

    if self.groundChangeCooldownTimer > 0 then
      -- Move slower around corners
      moveSpeed = moveSpeed * 0.4
    else
      -- Push away from the ground a bit if blocked by a one-block-high step
      local stepCheckRegion = {
        bounds[1] + heading[1] * 0.5,
        bounds[2] + heading[2] * 0.5,
        bounds[3] + heading[1] * 0.5,
        bounds[4] + heading[2] * 0.5
      }
      if self.groundDirection[1] < 0 then stepCheckRegion[3] = stepCheckRegion[3] - 1.5 end
      if self.groundDirection[1] > 0 then stepCheckRegion[1] = stepCheckRegion[1] + 1.5 end
      if self.groundDirection[2] < 0 then stepCheckRegion[4] = stepCheckRegion[4] - 1.5 end
      if self.groundDirection[2] > 0 then stepCheckRegion[2] = stepCheckRegion[2] + 1.5 end

      if world.rectCollision(stepCheckRegion, true) then
        util.debugRect(stepCheckRegion, "red")
        toGroundMovementMultiplier = -0.1
      else
        util.debugRect(stepCheckRegion, "green")
      end
    end
  end

  util.debugLine(entity.position(), vec2.add(entity.position(), vec2.mul(vec2.dup(self.groundDirection), 3)), "blue")
  util.debugLine(entity.position(), vec2.add(entity.position(), vec2.mul(vec2.dup(heading), 3)), "green")

  if math.abs(direction) > 0 then
    local movement = vec2.mul(vec2.dup(heading), 0.5 * moveSpeed)
    vec2.add(movement, vec2.mul(vec2.dup(self.groundDirection), toGroundMovementMultiplier * moveSpeed))
    entity.fly(movement, false)
  end
end

--------------------------------------------------------------------------------
moveState = {}

function moveState.enter()
--  if self.targetId ~= nil then return nil end

  return {
    direction = util.randomDirection(),
    timer = entity.randomizeParameterRange("moveTimeRange")
  }
end

function moveState.update(dt, stateData)
  move(stateData.direction)

  stateData.timer = stateData.timer - dt
  if stateData.timer <= 0 then
    return true, entity.randomizeParameterRange("moveCooldownRange")
  else
    return false
  end
end

--------------------------------------------------------------------------------
dropState = {}

function dropState.enter()
  --  if self.targetId ~= nil then return nil end

  if math.abs(self.groundDirection[1]) ~= 0 or self.groundDirection[2] ~= 1 then
    return nil
  end

  local position = entity.position()
  local dropDistance = entity.configParameter("dropDistance")

  if not world.lineCollision(position, vec2.add(vec2.mul(vec2.dup(self.groundDirection), -dropDistance), position), true) then
    return nil
  end

  local newGroundDirection = vec2.mul(vec2.dup(self.groundDirection), -1)
  if not setGroundDirection(newGroundDirection) then
    return nil
  end

  return {
    direction = newGroundDirection,
    timer = entity.configParameter("dropInitialTime")
  }
end

function dropState.enteringState(stateData)
  entity.setAnimationState("movement", "jump")
end

function dropState.update(dt, stateData)
  stateData.timer = stateData.timer - dt

  if onGround() or stateData.timer < -entity.configParameter("dropTimeLimit") then
    return true, entity.configParameter("dropCooldown")
  end

  if stateData.timer > 0 then
    entity.fly(vec2.mul(vec2.dup(stateData.direction), entity.configParameter("dropSpeed")), false)
  else
    move(0) -- Re-orient to new ground surface
  end

  return false
end
