converseState = {}

function converseState.enterWith(args)
  if args.interactArgs == nil then return nil end
  if args.interactArgs.sourceId == 0 then return nil end
  
  local selfname = world.entityName(entity.id())

  if not sayToTarget("converse.dialog", args.interactArgs.sourceId, { name = selfname }) then
    return nil
  end

  return {
    sourceId = args.interactArgs.sourceId,
    timer = entity.configParameter("converse.waitTime")
  }
end

function converseState.update(dt, stateData)
  local sourcePosition = world.entityPosition(stateData.sourceId)
  if sourcePosition == nil then return true end

  local toSource = world.distance(sourcePosition, entity.position())
  setFacingDirection(toSource[1])

  stateData.timer = stateData.timer - dt
  return stateData.timer <= 0
end