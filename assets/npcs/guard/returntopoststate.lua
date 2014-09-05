returnToPostState = {}

function returnToPostState.enter()
  local distance = world.magnitude(entity.position(), storage.spawnPosition)
  if distance < entity.configParameter("returnToPost.minDistance") then
    return nil
  end

  return {
    timer = entity.configParameter("returnToPost.moveTime")
  }
end

function returnToPostState.update(dt, stateData)
  local distance = world.magnitude(entity.position(), storage.spawnPosition)
  if distance < entity.configParameter("returnToPost.minDistance") then
    return true
  end

  moveTo(storage.spawnPosition, dt)

  stateData.timer = stateData.timer - dt
  return stateData.timer < 0
end