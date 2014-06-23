function init(virtual)
  if virtual then return end

  self.alarmSoundTimer = 0
  self.alarmSoundDuration = entity.configParameter("alarmSoundDuration")

  self.lightColor = entity.configParameter("lightColor", {255, 0, 0})
end

function main()
  if entity.getInboundNodeLevel(0) then
    entity.setAnimationState("alarmState", "on")

    local lightWave = math.sin((self.alarmSoundTimer / self.alarmSoundDuration) * math.pi) * 0.5 + 0.5
    entity.setLightColor({lightWave * self.lightColor[1], lightWave * self.lightColor[2], lightWave * self.lightColor[3]})

    if self.alarmSoundTimer <= 0 then
      entity.playImmediateSound(entity.configParameter("alarmSound"))
      self.alarmSoundTimer = self.alarmSoundDuration
    else
      self.alarmSoundTimer = self.alarmSoundTimer - entity.dt()
    end
  else
    self.alarmSoundTimer = 0
    entity.setAnimationState("alarmState", "off")
    entity.setLightColor({0, 0, 0, 0})
  end
end