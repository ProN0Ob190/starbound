workState = {}

function workState.enter()
  if not isTimeFor("work.timeOfDayRanges") then
    return nil, entity.configParameter("work.cooldown", nil)
  end

  if isInside(entity.position()) then return nil end

  local position = entity.position()
  for _, toolConfig in pairs(entity.configParameter("work.tools")) do
    local targetPosition = workState.findTargetPosition(position, toolConfig[1])
    if targetPosition ~= nil then
      return {
        targetPosition = targetPosition,
        tool = toolConfig[1],
        timer = entity.randomizeParameterRange("work.timeRange"),
        useTimer = 0,
        useTime = toolConfig[2],
        useCooldownTimer = toolConfig[3],
        useCooldownTime = toolConfig[3]
      }
    end
  end

  return nil, entity.configParameter("work.cooldown", nil)
end

function workState.enteringState(stateData)
  local oldPrimaryItem = entity.getItemSlot("primary")
  if oldPrimaryItem ~= nil and oldPrimaryItem[1] ~= "" then
    stateData.oldPrimaryItem = oldPrimaryItem[1]
  end

  local oldAltItem = entity.getItemSlot("alt")
  if oldAltItem ~= nil and oldAltItem[1] ~= "" then
    stateData.oldAltItem = oldAltItem[1]
  end

  entity.setItemSlot("alt", nil)
  entity.setItemSlot("primary", stateData.tool)
end

function workState.update(dt, stateData)
  stateData.timer = stateData.timer - dt
  if stateData.timer < 0 then
    return true, entity.configParameter("work.cooldown", nil)
  end

  local position = entity.position()
  local toTarget = world.distance(stateData.targetPosition, position)
  local distance = world.magnitude(toTarget)
  if distance < entity.configParameter("work.toolRange") then
    if stateData.useTimer > 0 then
      workState.useTool(position, toTarget, stateData)

      stateData.useTimer = stateData.useTimer - dt
      if stateData.useTimer <= 0 then
        entity.endPrimaryFire()
        stateData.useCooldownTimer = stateData.useCooldownTime
      end

      return false
    end

    if stateData.useCooldownTimer > 0 then
      stateData.useCooldownTimer = stateData.useCooldownTimer - dt
      if stateData.useCooldownTimer <= 0 then
        stateData.useTimer = stateData.useTime
      end

      return false
    end
  else
    move(toTarget, dt)
  end

  return false
end

function workState.leavingState(stateData)
  entity.endPrimaryFire()

  entity.setItemSlot("primary", stateData.oldPrimaryItem)
  entity.setItemSlot("alt", stateData.oldAltItem)

  setFacingDirection(entity.facingDirection()) -- Resets aim position
end

function workState.useTool(position, toTarget, stateData)
  if stateData.tool == "hoetool" then
    entity.setAimPosition(stateData.targetPosition)
    entity.beginPrimaryFire()
  elseif stateData.tool == "stoneaxe" then
    local ratio = 1 - (stateData.useTimer / stateData.useTime)
    local offset = math.sin(ratio * math.pi * 2)
    setFacingDirection(toTarget[1])
    entity.setAimPosition({
      position[1] + entity.facingDirection(),
      position[2] + offset
    })
  end
end

function workState.findTargetPosition(position, tool)
  local direction = entity.facingDirection()

  if tool == "hoetool" then
    -- This is the block below the leading foot
    local basePosition = {
      math.floor(position[1] + 0.5) + direction,
      math.floor(position[2] + 0.5) - 4
    }

    for offset = 0, entity.configParameter("work.searchDistance"), 1 do
      local targetPosition = vec2.add({ offset * direction, 0 }, basePosition)
      local modName = world.mod(targetPosition, "foreground")
      if modName ~= nil and string.find(modName, "grass") then
        return { targetPosition[1], targetPosition[2] + 1.5 }
      end
    end
  elseif tool == "stoneaxe" then
    local objectIds = world.entityQuery(position, entity.configParameter("work.searchDistance"), {
      includedTypes = {"object"},
      callScript = "entity.configParameter",
      callScriptArgs = {"objectName"},
      callScriptResult = "anvil" })
    if #objectIds > 0 then
      return vec2.add(world.entityPosition(objectIds[1]), { 0, 2.0 })
    end
  end

  return nil
end