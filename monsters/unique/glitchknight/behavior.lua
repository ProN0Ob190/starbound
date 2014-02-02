--------------------------------------------------------------------------------
function init(args)
  self.state = stateMachine.create({
    "chargeAttack"
  })
  self.state.leavingState = function(stateName)
    setAnimationState("idle")
    entity.setDamageOnTouch(false)
    entity.setRunning(false)
  end

  self.dismounted = false

  entity.setAggressive(false)
  setAnimationState("idle")
end

--------------------------------------------------------------------------------
function main()
  self.position = entity.position()

  if util.trackTarget(entity.configParameter("targetNoticeRadius")) then
    entity.setAggressive(true)
    self.state.pickState()
  elseif self.targetId == nil then
    entity.setAggressive(false)
  end

  self.state.update(entity.dt())
end

--------------------------------------------------------------------------------
function damage(args)
  if not self.dismounted then
    local dismountHealth = entity.maxHealth() * entity.configParameter("dismountHealthRatio")
    if entity.health() < dismountHealth then
      self.dismounted = true
      world.spawnNpc(self.position, "glitch", "knight", entity.level())
    end
  end

  if args.sourceId ~= self.targetId then
    self.targetId = args.sourceId
    self.targetPosition = world.entityPosition(self.targetId)
    self.state.pickState()
  end
end

--------------------------------------------------------------------------------
function setAnimationState(stateName)
  entity.setAnimationState("mount", stateName)

  if self.dismounted then
    entity.setAnimationState("rider", "dismounted")
  else
    entity.setAnimationState("rider", stateName)
  end
end

--------------------------------------------------------------------------------
function jump(direction)
  self.jumpDirection = direction
  entity.jump()
  setAnimationState("jump")
end

--------------------------------------------------------------------------------
function move(direction, traverseObstacles)
  if not entity.onGround() and self.jumpDirection ~= nil then
    entity.holdJump()

    if self.jumpDirection < 0 then
      entity.moveLeft()
    else
      entity.moveRight()
    end

    return true
  end

  local bounds = entity.configParameter("metaBoundBox")
  local width = bounds[3] - bounds[1]
  bounds = {
    bounds[1] + self.position[1],
    bounds[2] + self.position[2],
    bounds[3] + self.position[1],
    bounds[4] + self.position[2]
  }

  -- Jump over obstacles
  local jumpRegion = { bounds[1], bounds[2] + 3, bounds[3], bounds[4] }
  if direction > 0 then
    jumpRegion[1] = jumpRegion[1] + width
    jumpRegion[3] = jumpRegion[3] + 4
  else
    jumpRegion[1] = jumpRegion[1] - 4
    jumpRegion[3] = jumpRegion[3] - width
  end

  if world.rectCollision(jumpRegion, true) then
    local jumpClearanceRegion = {
      bounds[1] + direction * (bounds[3] - bounds[1]),
      bounds[2] + 3.125,
      bounds[3] + direction * (4 + bounds[3] - bounds[1]),
      bounds[4] + 3
    }
    if direction > 0 then
      jumpClearanceRegion[1] = jumpClearanceRegion[1] + width
      jumpClearanceRegion[3] = jumpClearanceRegion[3] + (4 + width)
    else
      jumpClearanceRegion[1] = jumpClearanceRegion[1] - (4 + width)
      jumpClearanceRegion[3] = jumpClearanceRegion[3] - width
    end
    if not world.rectCollision(jumpClearanceRegion, true) then
      if traverseObstacles then
        jump(direction)
      end
      return traverseObstacles
    end
  end

  -- Jump over gaps
  local gapRegion = { bounds[1], bounds[2] - 4, bounds[3], bounds[2] }
  if direction > 0 then
    gapRegion[1] = gapRegion[1] + width
    gapRegion[3] = gapRegion[3] + width / 2
  else
    gapRegion[1] = gapRegion[1] - width / 2
    gapRegion[3] = gapRegion[3] - width
  end

  if not world.rectCollision(gapRegion, false) then
    if traverseObstacles then
      jump(direction)
    end
    return traverseObstacles
  end

  self.jumpDirection = nil

  if not traverseObstacles then
    local blockedRect = {
      bounds[1] + direction, bounds[2] + 1,
      bounds[3] + direction, bounds[4]
    }
    if world.rectCollision(blockedRect, true) then
      return false
    end
  end

  setAnimationState("run")
  entity.setFacingDirection(direction)
  if direction < 0 then
    entity.moveLeft()
  else
    entity.moveRight()
  end

  return true
end

--------------------------------------------------------------------------------
function hasTarget()
  return self.targetId ~= nil
end

--------------------------------------------------------------------------------
chargeAttack = {}

function chargeAttack.enter()
  if not hasTarget() then return nil end

  return {}
end

function chargeAttack.enteringState(stateData)
  entity.setDamageOnTouch(true)
  entity.setRunning(true)
end

function chargeAttack.update(dt, stateData)
  if not hasTarget() then return true end

  if stateData.changeDirectionTimer ~= nil then
    stateData.changeDirectionTimer = stateData.changeDirectionTimer - dt
    if stateData.changeDirectionTimer <= 0 then
      stateData.changeDirectionTimer = nil
    end
  end

  local toTarget = world.distance(self.targetPosition, self.position)
  local targetDirection = util.toDirection(toTarget[1])
  if stateData.chargeDirection == nil or world.magnitude(toTarget) > entity.configParameter("chargeAttackOvershootDistance") then
    stateData.chargeDirection = targetDirection
    stateData.changeDirectionTimer = entity.configParameter("changeDirectionCooldown")
  end

  entity.setFacingDirection(stateData.chargeDirection)
  if not move(stateData.chargeDirection, stateData.chargeDirection == targetDirection) then
    if stateData.changeDirectionTimer == nil then
      stateData.chargeDirection = targetDirection
      stateData.changeDirectionTimer = entity.configParameter("changeDirectionCooldown")
    end
  end

  return false
end