function init()
  data.multiJumps = 0
  data.lastJump = false
end

function input(args)
  if args.moves["jump"] and not tech.jumping() and not tech.canJump() and not data.lastJump then
    data.lastJump = true
    return "multiJump"
  else
    data.lastJump = args.moves["jump"]
    return nil
  end
end

function update(args)
  local multiJumpCount = tech.parameter("multiJumpCount")
  local energyUsage = tech.parameter("energyUsage")

  if args.actions["multiJump"] and data.multiJumps < multiJumpCount and args.availableEnergy > energyUsage then
    tech.jump(true)
    data.multiJumps = data.multiJumps + 1
    tech.burstParticleEmitter("multiJumpParticles")
    tech.playImmediateSound(tech.parameter("sound"))
    return energyUsage
  else
    if tech.onGround() or tech.inLiquid() then
      data.multiJumps = 0
    end

    return 0.0
  end
end
