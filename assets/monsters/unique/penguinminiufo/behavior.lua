function init(args)
  entity.setDeathParticleBurst("deathPoof")
  entity.setAnimationState("movement", "flying")
end

function shouldDie()
  if entity.health() <= 0 then return true end

  if self.hadMaster ~= nil and not self.hadMaster then
    return true
  end

  return false
end

function main()
  local masterId, minionIndex, minionTimer = findMaster()
  if masterId ~= 0 then
    self.hadMaster = true

    local angle = ((minionIndex - 1) * math.pi / 2.0) + minionTimer
    local target = vec2.add(world.entityPosition(masterId), {
      20.0 * math.cos(angle),
      8.0 * math.sin(angle)
    })

    entity.flyTo(target, true)
  else
    self.hadMaster = false

    entity.fly({0,0}, true)
  end

  util.trackTarget(30.0, 10.0)

  if self.targetPosition ~= nil then
    entity.setFireDirection({0,0}, world.distance(self.targetPosition, entity.position()))
    -- entity.startFiring("plasmabullet")
  else
    -- entity.stopFiring()
  end
end

function findMaster()
  local position = entity.position()
  local regionMin = { position[1] - 25.0, position[2] - 25.0 }
  local regionMax = { position[1] + 25.0, position[2] + 25.0 }

  local selfEntityId = entity.id()

  for i, entityId in ipairs(world.monsterQuery(regionMin, regionMax, { callScript = "isPenguinMaster" })) do
    local minionState = world.callScriptedEntity(entityId, "minionState")
    if minionState ~= nil then
      for minionIndex, minionId in ipairs(minionState.slots) do
        if minionId == selfEntityId then
          return entityId, minionIndex, minionState.timer
        end
      end
    end
  end

  return 0
end