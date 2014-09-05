function init()
  self.spawnedEntityIds = {}

  self.state = stateMachine.create({
    "spawnState"
  })
  self.state.leavingState = function(stateName)
    setAnimation("idle")
  end

  setAnimation("idle")
  entity.setInteractive(false)
end

function main()
  updateSpawnedEntityIds()
  self.state.update(entity.dt())
end

function updateSpawnedEntityIds()
  local spawnedEntityIds = {}

  for i, entityId in ipairs(self.spawnedEntityIds) do
    if world.entityExists(entityId) then
      table.insert(spawnedEntityIds, entityId)
    end
  end

  self.spawnedEntityIds = spawnedEntityIds
end


function setAnimation(desiredAnimation)
  local animation = entity.animationState("movement")
  if animation == desiredAnimation then
    return true
  end

  if animation == "idle" then
    entity.setAnimationState("movement", desiredAnimation)
    return true
  elseif animation ~= "close" then
    entity.setAnimationState("movement", "close")
  end

  return false
end

--------------------------------------------------------------------------------
spawnState = {}

function spawnState.enter()
  if #self.spawnedEntityIds >= entity.configParameter("maxSpawnedRobots") then return nil end

  local rand = math.random(90)
  local monstertype
  if rand > 60 then
    monstertype = "serpentdroid"
  elseif rand > 30 then
    monstertype = "repairbot"
  else
    monstertype = "cleaningbot"
  end

  return { timer = 0, spawned = false, monstertype = monstertype }
end

function spawnState.update(dt, stateData)
  local animation = entity.animationState("movement")
  if animation == "idle" then
    if stateData.spawned then
      return true, entity.configParameter("spawnCooldownTime")
    else
      setAnimation(stateData.monstertype .. "Spawn")
    end
  elseif animation == stateData.monstertype .. "Spawn" then
    stateData.timer = stateData.timer + dt

    if not stateData.spawned and stateData.timer > entity.configParameter("spawnTime") then
      table.insert(self.spawnedEntityIds, world.spawnMonster(stateData.monstertype, spawnState.spawnPosition(stateData.monstertype .. "SpawnOffset")))
      stateData.spawned = true
    end
  end

  return false
end

function spawnState.spawnPosition(configKey)
  return vec2.add(entity.position(), entity.configParameter(configKey))
end