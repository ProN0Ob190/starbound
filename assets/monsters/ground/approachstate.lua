approachState = {}

function approachState.enter()
  if self.noOptionCount > 5 or not hasTarget() then return nil end

  return {}
end

function approachState.enteringState(stateData)
  stateData.prepTimer = 2.0
  entity.setAnimationState("movement", "run")
  entity.setAnimationState("attack", "idle")
end

function approachState.update(dt, stateData)
  if not hasTarget() then return true end

  stateData.prepTimer = stateData.prepTimer - dt
  if stateData.prepTimer <= 0 then
    return true
  end

  if #self.skillOptions > 0 then
    local option = self.skillOptions[1]
    
    if pointWithinRect(entity.position(), option.startRect) then
      --just stand around and wait, I guess...
      entity.setAnimationState("movement", "idle")
      faceTarget()
    else
      if checkStuck() > 4 then
        self.state.pickState({flee=true})
        return true
      end

      entity.setAnimationState("movement", "run")
      entity.setRunning(option.approachDistance >= 1.0)

      --TODO: how to handle separation movement?
      move(option.approachDelta, 0.2, math.abs(option.approachDelta[1]) >= 3 or math.abs(self.toTarget[1]) > 6)
    end
  end  

  return false
end