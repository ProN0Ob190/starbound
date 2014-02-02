function init(args)
  entity.setInteractive(true)
  entity.setAllOutboundNodes(false)
  entity.setAnimationState("switchState", "off")
  self.projectileCooldown = 0
end

function trigger()
  entity.setAllOutboundNodes(true)
  entity.setAnimationState("switchState", "on")
  if entity.configParameter("firstProjectile") ~= nil then
    world.spawnProjectile(entity.configParameter("firstProjectile"), entity.toAbsolutePosition({ 0.0, 0.2 }))
  end
  self.projectileCooldown = entity.configParameter("timer")
end

function onInteraction(args)
  trigger()
end

function main() 
  if self.projectileCooldown > 0 then
    self.projectileCooldown = self.projectileCooldown - 1
    if self.projectileCooldown == 0 then
      if entity.configParameter("secondProjectile") ~= nil then
        world.spawnProjectile(entity.configParameter("secondProjectile"), entity.toAbsolutePosition({ 0.0, 0.2 }))
      end
      entity.smash()
    end
  else
    local radius = entity.configParameter("detectRadius")
    local entityIds = world.entityQuery(entity.position(), radius, { creature = true })
    if #entityIds > 0 then
      if entity.isTouching(entityIds[1]) then
        trigger()
      end
    end
  end
end