function init(virtual)
  if not virtual then
    self.detectArea = entity.configParameter("detectArea")
    self.detectArea[1] = entity.toAbsolutePosition(self.detectArea[1])
    self.detectArea[2] = entity.toAbsolutePosition(self.detectArea[2])

    entity.setAnimationState("console", "off")
    entity.setLightColor({0, 0, 0, 0})
  end
end

function main()
  local players = world.entityQuery(self.detectArea[1], self.detectArea[2], {
      includedTypes = {"player"},
      boundMode = "CollisionArea"
    })

  if #players > 0 and entity.animationState("console") == "off" then
    entity.setAnimationState("console", "turnon")
    entity.playSound("onSounds");
    entity.setLightColor(entity.configParameter("lightColor", {255, 255, 255}))
  elseif #players == 0 and entity.animationState("console") == "on" then
    entity.setAnimationState("console", "turnoff")
    entity.playSound("offSounds");
    entity.setLightColor({0, 0, 0, 0})
  end
end