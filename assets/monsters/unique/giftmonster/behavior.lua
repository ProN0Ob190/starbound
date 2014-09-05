--------------------------------------------------------------------------------
function init()
  self.state = stateMachine.create({
    "idleState",
    "bounceState",
    "moveState"
  })

  self.state.leavingState = function(stateName)
    entity.setAnimationState("movement", "idle")
    self.state.moveStateToEnd(stateName)
  end

  entity.setAggressive(false)
  entity.setDamageOnTouch(false)
  entity.setDeathParticleBurst("deathPoof")
end

--------------------------------------------------------------------------------
function main()
  if util.trackTarget(entity.configParameter("noticeDistance")) then
    self.state.pickState(self.targetId)
  end

  self.state.update(entity.dt())
end

--------------------------------------------------------------------------------
function move(direction)
  entity.setFacingDirection(direction)
  if direction < 0 then
    entity.moveLeft()
  else
    entity.moveRight()
  end
end

--------------------------------------------------------------------------------
idleState = {}

function idleState.enter()
  return { timer = entity.randomizeParameterRange("idleTimeRange") }
end

function idleState.update(dt, stateData)
  stateData.timer = stateData.timer - dt
  return stateData.timer <= 0
end

--------------------------------------------------------------------------------
moveState = {}

function moveState.enter()
  return {
    direction = util.randomDirection(),
    timer = entity.randomizeParameterRange("moveTimeRange"),
    changeDirectionTimer = 0
  }
end

function moveState.update(dt, stateData)
  local bounds = entity.configParameter("metaBoundBox")
  bounds[1] = bounds[1] + stateData.direction
  bounds[3] = bounds[3] + stateData.direction

  if world.rectCollision(bounds, true) then
    if stateData.changeDirectionTimer > 0 then
      return true
    end

    stateData.direction = -stateData.direction
    stateData.changeDirectionTimer = entity.configParameter("moveChangeDirectionCooldown")
  end

  stateData.timer = stateData.timer - dt
  if entity.animationState("movement") == "idle" and stateData.timer <= 0 then
    return true
  end

  move(stateData.direction)
  entity.setAnimationState("movement", "bounce")

  if stateData.changeDirectionTimer > 0 then
    stateData.changeDirectionTimer = stateData.changeDirectionTimer - dt
  end

  return false
end

--------------------------------------------------------------------------------
bounceState = {}

function bounceState.enterWith(targetId)
  return {}
end

function bounceState.update(dt, stateData)
  if entity.animationState("movement") == "idle" then
    if self.targetId == nil then
      return true
    end

    entity.setAnimationState("movement", "bounce")
  end

  return false
end
