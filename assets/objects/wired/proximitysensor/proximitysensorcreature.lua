function init(args)
  entity.setInteractive(true)
  entity.setAllOutboundNodes(false)
  entity.setAnimationState("switchState", "off")
  self.countdown = 0
end

function trigger()
  entity.setAllOutboundNodes(true)
  entity.setAnimationState("switchState", "on")
  self.countdown = entity.configParameter("detectTickDuration")
end

function onInteraction(args)
  trigger()
end

function main() 
  if self.countdown > 0 then
    self.countdown = self.countdown - 1
  else
    if self.countdown == 0 then
      local radius = entity.configParameter("detectRadius")
      local entityIds = world.entityQuery(entity.position(), radius, { creature = true })
      if #entityIds > 0 then
        trigger()
      else
        entity.setAllOutboundNodes(false)
        entity.setAnimationState("switchState", "off")
      end
    end
  end
end