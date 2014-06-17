
function goodReception()
  if world.underground(entity.position()) then
    return false
  end
  
  local ll = entity.toAbsolutePosition({ -4.0, 1.0 })
  local tr = entity.toAbsolutePosition({ 4.0, 32.0 })
  
  local bounds = {0, 0, 0, 0}
  bounds[1] = ll[1]
  bounds[2] = ll[2]
  bounds[3] = tr[1]
  bounds[4] = tr[2]
  
  return not world.rectCollision(bounds, true)
end

function init(args)
  entity.setInteractive(true)
end

function onInteraction(args)
  if not goodReception() then
    return { "ShowPopup", { message = "I should take it to the planet surface and see what it attracts." } }
  else
    entity.smash()
    world.spawnProjectile("regularexplosion2", entity.toAbsolutePosition({ 0.0, 1.0 }))
    world.spawnMonster("dragonboss", entity.toAbsolutePosition({ 0.0, 30.0 }), { level = 3 })
  end
end

function hasCapability(capability)
  return false
end
