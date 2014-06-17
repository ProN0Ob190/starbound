scatterState = {}

function scatterState.enterWith(event)
  if event.scatterSource then
    return {
      source = event.scatterSource,
      timer = entity.configParameter("scatterTime")
    }
  end

  return nil
end

function scatterState.update(dt, stateData)
  if stateData.timer < 0 then
    return true
  end
  stateData.timer = stateData.timer - dt

  local movement = world.distance(entity.position(), stateData.source)
  local distance = world.magnitude(movement)
  if distance > entity.configParameter("scatterDistance") then
    return true
  end

  self.movement = movement
  self.movementWeight = entity.configParameter("scatterMovementWeight")
  return false
end
