knockoutState = {}

function knockoutState.enterWith(params)
  if not params.knockout then return nil end

  return { timer = entity.configParameter("knockoutTime") }
end

function knockoutState.enteringState(stateData)
  entity.setAnimationState("movement", "knockout")
  entity.setAnimationState("attack", "idle")
  setAggressive(true, false)
  entity.setEffectActive(entity.configParameter("knockoutEffect"), true)
end

function knockoutState.update(dt, stateData)
  if stateData.timer <= 0 then
    self.dead = true
  else
    stateData.timer = stateData.timer - dt
  end

  return false
end

function knockoutState.preventStateChange(stateData)
  return true
end