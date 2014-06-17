function init(args)
  entity.alarmSoundTimer = 0

  if storage.alarmSoundDuration == nil then
    storage.alarmSoundDuration = entity.configParameter("alertSoundDuration")
  end

  if storage.state == nil then
    output(false)
  else
    output(storage.state)
  end
end

function output(state)
  if state ~= storage.state then
    entity.alarmSoundTimer = 0

    storage.state = state
    if state then
      entity.setAnimationState("alarmState", "on")
    else
      entity.setAnimationState("alarmState", "off")
    end
  end
end

function main(args)
  if entity.getInboundNodeLevel(0) then
    output(true)

    entity.alarmSoundTimer = entity.alarmSoundTimer - entity.dt()
    if entity.alarmSoundTimer <= 0 then
      entity.playSound("alertSounds")
      entity.alarmSoundTimer = storage.alarmSoundDuration
    end
  else
    output(false)
  end
end