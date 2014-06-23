function init(virtual)
  if virtual then return end

  entity.setInteractive(entity.configParameter("interactive", false))
  entity.setAllOutboundNodes(false)
  entity.setAnimationState("switchState", "off")
  self.triggerTimer = 0
end

function trigger()
  entity.setAllOutboundNodes(true)
  entity.setAnimationState("switchState", "on")
  self.triggerTimer = entity.configParameter("detectDuration")
end

function onInteraction(args)
  trigger()
end

function main() 
  if self.triggerTimer > 0 then
    self.triggerTimer = self.triggerTimer - entity.dt()
  elseif self.triggerTimer <= 0 then
    local entityIds = world.entityQuery(entity.position(), entity.configParameter("detectRadius"), { notAnObject = true })
    if #entityIds > 0 then
      trigger()
    else
      entity.setAllOutboundNodes(false)
      entity.setAnimationState("switchState", "off")
    end
  end
end

