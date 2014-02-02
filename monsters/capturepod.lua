-- Helper functions for entities that can be captured by a capturepod
capturepod = {}

--------------------------------------------------------------------------------
function capturepod.onInit()
  if storage.ownerUuid == nil then
    local ownerUuid = entity.configParameter("ownerUuid", nil)
    if ownerUuid ~= nil then
      storage.ownerUuid = ownerUuid
    end
  end

  if storage.killCount == nil then
    local killCount = entity.configParameter("killCount", nil)
    if killCount ~= nil then
      storage.killCount = killCount
    end
  end
end

--------------------------------------------------------------------------------
function capturepod.onMonsterKilled()
  if capturepod.isCaptive() then
    if storage.killCount == nil then storage.killCount = 0 end
    storage.killCount = storage.killCount + 1

    if storage.killCount > entity.configParameter("killsPerLevel", 10) then
      local levelUpParticles = entity.configParameter("levelUpParticles", nil)
      if levelUpParticles ~= nil then
        entity.setDeathParticleBurst(levelUpParticles)
      end

      storage.killCount = 0
      self.levelUp = true
      self.dead = true
    end
  end
end

--------------------------------------------------------------------------------
function capturepod.onDamage(args)
  if args.sourceKind ~= "capture" then return false end

  local captured = false

  if capturepod.isCaptive() then
    if world.entityUuid(args.sourceId) == storage.ownerUuid then
      captured = true
    end
  else
    local captureHealthFraction = entity.configParameter("captureHealthFraction", nil)
    if captureHealthFraction ~= nil then
      local healthFraction = entity.health() / entity.maxHealth()
      if healthFraction <= captureHealthFraction then
        storage.ownerUuid = world.entityUuid(args.sourceId)
        captured = true
      end
    end
  end

  if captured then
    local captureParticles = entity.configParameter("captureParticles", nil)
    if captureParticles ~= nil then
      entity.setDeathParticleBurst(captureParticles)
    end

    self.dead = true
  end

  return captured
end

--------------------------------------------------------------------------------
function capturepod.onDie()
  if not capturepod.isCaptive() then return false end

  local parameters = entity.uniqueParameters()
  parameters.aggressive = true
  parameters.persistent = true

  parameters.damageTeamType = "friendly"
  parameters.damageTeam = 0

  parameters.ownerUuid = storage.ownerUuid
  parameters.killCount = storage.killCount

  parameters.seed = entity.seed()
  parameters.level = entity.level()
  parameters.familyIndex = entity.familyIndex()

  if self.levelUp then
    parameters.level = parameters.level + 1
    world.spawnMonster(entity.type(), entity.position(), parameters)
  else
    -- Spawn a filled capture pod that will re-create this monster
    world.spawnItem("filledcapturepod", entity.toAbsolutePosition({ 0, 4 }), 1, {
      projectileConfig = {
        speed = 70,
        level = 7,
        actionOnReap = {
          {
            action = "spawnmonster",
            offset = { 0, 2 },
            type = entity.type(),
            arguments = parameters
          }
        }
      }
    })
  end

  entity.setDropPool(nil)

  return true
end

--------------------------------------------------------------------------------
function capturepod.isCaptive()
  return storage.ownerUuid ~= nil
end