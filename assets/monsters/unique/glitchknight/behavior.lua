--------------------------------------------------------------------------------
function init(args)
  self.dismounted = false

  local setAnimationState = function(stateName)
    entity.setAnimationState("mount", stateName)

    if self.dismounted then
      entity.setAnimationState("rider", "dismounted")
    else
      entity.setAnimationState("rider", stateName)
    end
  end

  self.state = stateMachine.create({
    "chargeAttack"
  })
  self.state.leavingState = function(stateName)
    setAnimationState("idle")
    entity.setDamageOnTouch(false)
    entity.setRunning(false)
  end

  entity.setAggressive(false)
  setAnimationState("idle")

  self.movement = groundMovement.create(3, 4, setAnimationState)
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
  if not self.movement.move(self.position, stateData.chargeDirection, stateData.chargeDirection == targetDirection) then
    if stateData.changeDirectionTimer == nil then
      stateData.chargeDirection = targetDirection
      stateData.changeDirectionTimer = entity.configParameter("changeDirectionCooldown")
    end
  end

  return false
end