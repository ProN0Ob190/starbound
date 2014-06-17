function init(args)

end

function main(args)
  if world.lightLevel(entity.position()) >= entity.configParameter("detectThresholdLow") then
    entity.setOutboundNodeLevel(0, true)
  else
    entity.setOutboundNodeLevel(0, false)
  end

  if world.lightLevel(entity.position()) >= entity.configParameter("detectThresholdHigh") then
    entity.setOutboundNodeLevel(1, true)
  else
    entity.setOutboundNodeLevel(1, false)
  end
end