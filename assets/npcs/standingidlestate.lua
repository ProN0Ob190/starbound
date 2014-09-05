standingIdleState = {}

function standingIdleState.enter()
  return { timer = entity.randomizeParameterRange("idleTimeRange") }
end

function standingIdleState.update(dt, stateData)
  stateData.timer = stateData.timer - dt

  return stateData.timer <= 0
end

