function init(virtual)
  self.placed = not virtual
end

function main()
  if self.placed then
    world.spawnMonster(entity.configParameter("monsterType"), entity.position())
    entity.smash()
  end
end