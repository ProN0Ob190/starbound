aggroHopState = {
  jumpForce = 0.25
}

function aggroHopState.enterWith(params)
  if not params.aggroHop then return nil end

  return { wasOffGround = false }
end

function aggroHopState.enteringState(stateData)
  entity.playSound(entity.randomizeParameter("turnHostileNoise"))
end

function aggroHopState.update(dt, stateData)
  if entity.onGround() then
    if stateData.wasOffGround then
      return true
    else
      entity.setVelocity({0, aggroHopState.jumpForce * world.gravity(entity.position())})
    end
  else
    stateData.wasOffGround = true
  end
end