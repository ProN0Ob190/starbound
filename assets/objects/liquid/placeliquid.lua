function init(virtual)
  if not virtual then
    world.spawnLiquid(entity.position(), entity.configParameter("liquidId", 1), entity.configParameter("liquidAmount", 800))
    entity.smash()
  end
end