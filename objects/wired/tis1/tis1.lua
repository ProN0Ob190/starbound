function init(args)
  if storage.initialized == nil then
    entity.setAnimationState("tis1State", "active")
    entity.setInteractive(true)
    entity.setColliding(false)
    storage.initialized = true
  end
end

function onInteraction(args)
  if isActive() then
  	use(args)
  end
end

function hasCapability(capability)
  if capability == 'tis1' then
    return true
  else
    return false
  end
end

function isActive()
  return entity.animationState("tis1State") == "active"
end

function use(args)
  if isActive() then
    entity.setAnimationState("tis1State", "expire")
    entity.setInteractive(false)
    entity.playSound("useSounds")
    
    local projectile = entity.randomizeParameter("projectileOptions")
    
    world.spawnProjectile(projectile.projectileType, entity.position(), entity.id(), args.source, false, projectile.projectileParams)
  end
end
