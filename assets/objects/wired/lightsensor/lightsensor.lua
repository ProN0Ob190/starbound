function init(virtual)
  if virtual then return end
  
  self.detectThresholdHigh = entity.configParameter("detectThresholdHigh")
  self.detectThresholdLow = entity.configParameter("detectThresholdLow")
end

function getSample()
  local sample = world.lightLevel(entity.position())
  return math.floor(sample * 1000) * 0.1
end

function main()
  local sample = getSample()

  if sample >= self.detectThresholdLow then
    entity.setOutboundNodeLevel(0, true)
    entity.setAnimationState("sensorState", "med")
  else
    entity.setOutboundNodeLevel(0, false)
    entity.setAnimationState("sensorState", "min")
  end

  if sample >= self.detectThresholdHigh then
    entity.setOutboundNodeLevel(1, true)
    entity.setAnimationState("sensorState", "max")
  else
    entity.setOutboundNodeLevel(1, false)
  end
end