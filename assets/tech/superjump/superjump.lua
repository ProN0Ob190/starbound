function init()
  data.superJumpTimer = 0
end

function input(args)
  if args.moves["jump"] and args.moves["up"] and tech.onGround() then
    return "superjump"
  else
    return nil
  end
end

function update(args)
  local energyUsage = tech.parameter("energyUsage")
  local superJumpSpeed = tech.parameter("superjumpSpeed")
  local superJumpControlForce = tech.parameter("superjumpControlForce")
  local superJumpTime = tech.parameter("superjumpTime")
  local superjumpSound = tech.parameter("superjumpSound")

  local usedEnergy = 0

  if args.actions["superjump"] and tech.onGround() and data.superJumpTimer <= 0 and args.availableEnergy > energyUsage then
    tech.playImmediateSound(superjumpSound)
    data.superJumpTimer = superJumpTime
    usedEnergy = energyUsage
  end

  if data.superJumpTimer > 0 then
    tech.yControl(superJumpSpeed, superJumpControlForce)
    tech.setParticleEmitterActive("jumpParticles", true)
    data.superJumpTimer = data.superJumpTimer - args.dt
  else
    tech.setParticleEmitterActive("jumpParticles", false)
  end

  return usedEnergy
end
