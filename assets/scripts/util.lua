util = {}

--------------------------------------------------------------------------------
function util.blockSensorTest(sensorGroup, direction)
  local reverse = false
  if direction ~= nil then
    reverse = util.toDirection(direction) ~= entity.facingDirection()
  end

  for i, sensor in ipairs(entity.configParameter(sensorGroup)) do
    if reverse then
      sensor[1] = -sensor[1]
    end

    if world.pointCollision(entity.toAbsolutePosition(sensor), true) then
      return true
    end
  end

  return false
end

--------------------------------------------------------------------------------
function util.toDirection(value)
  if value < 0 then
    return -1
  else
    return 1
  end
end

--------------------------------------------------------------------------------
function util.clamp(value, min, max)
  return math.max(min, math.min(value, max))
end

--------------------------------------------------------------------------------
function util.incWrap(value, max)
  if value >= max then
    return 1
  else
    return value + 1
  end
end

--------------------------------------------------------------------------------
function util.trackTarget(distance, switchTargetDistance)
  local targetIdWas = self.targetId

  if self.targetId == nil then
    self.targetId = entity.closestValidTarget(distance)
  end

  if switchTargetDistance ~= nil then
    -- Switch to a much closer target if there is one
    local targetId = entity.closestValidTarget(switchTargetDistance)
    if targetId ~= 0 and targetId ~= self.targetId then
      self.targetId = targetId
    end
  end

  util.trackExistingTarget()

  return self.targetId ~= targetIdWas and self.targetId ~= nil
end

--------------------------------------------------------------------------------
function util.trackExistingTarget()
  -- Lose track of the target if they hide (but their last position is retained)
  if self.targetId ~= nil and not entity.entityInSight(self.targetId) then
    self.targetId = nil
  end

  if self.targetId ~= nil then
    self.targetPosition = world.entityPosition(self.targetId)
  end
end

--------------------------------------------------------------------------------
function util.easeInOutQuad(ratio, initial, delta)
  ratio = ratio * 2
  if ratio < 1 then
    return delta / 2 * math.pow(ratio, 2) + initial
  else
    return -delta / 2 * ((ratio - 1) * (ratio - 3) - 1) + initial
  end
end

--------------------------------------------------------------------------------
function util.randomDirection()
  return util.toDirection(math.random(0, 2) - 1)
end

--------------------------------------------------------------------------------
function util.debugRect(rect, color)
  if self.debug then
    world.debugLine({rect[1], rect[2]}, {rect[3], rect[2]}, color)
    world.debugLine({rect[3], rect[2]}, {rect[3], rect[4]}, color)
    world.debugLine({rect[3], rect[4]}, {rect[1], rect[4]}, color)
    world.debugLine({rect[1], rect[4]}, {rect[1], rect[2]}, color)
  end
end

--------------------------------------------------------------------------------
function util.debugLine(p1, p2, color)
  if self.debug then
    world.debugLine(p1, p2, color)
  end
end

--------------------------------------------------------------------------------
function util.debugLog(...)
  if self.debug then
    world.logInfo(...)
  end
end

--------------------------------------------------------------------------------
-- Useful in coroutines to wait for the given duration, optionally performing
-- some action each update
function util.wait(duration, action)
  local timer = duration
  while timer > 0 do
    local dt = entity.dt()
    if action ~= nil and action(dt) then return end

    timer = timer - dt
    coroutine.yield(false)
  end
end
