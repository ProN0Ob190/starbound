function init()
  data.holdingJump = false
  data.ranOut = false
end

function input(args)
  if args.moves["jump"] and tech.jumping() then
    data.holdingJump = true
  elseif not args.moves["jump"] then
    data.holdingJump = false
  end

  if args.moves["jump"] and not tech.canJump() and not data.holdingJump then
    return "jetpack"
  else
    return nil
  end
end

function update(args)
  local jetpackSpeed = tech.parameter("jetpackSpeed")
  local jetpackControlForce = tech.parameter("jetpackControlForce")
  local energyUsagePerSecond = tech.parameter("energyUsagePerSecond")
  local energyUsage = energyUsagePerSecond * args.dt

  if args.availableEnergy < energyUsage then
    data.ranOut = true
  elseif tech.onGround() or tech.inLiquid() then
    data.ranOut = false
  end

  if args.actions["jetpack"] and not data.ranOut then
    tech.setAnimationState("jetpack", "on")
    tech.yControl(jetpackSpeed, jetpackControlForce, true)
    return energyUsage
  else
    tech.setAnimationState("jetpack", "off")
    return 0
  end

  return usedEnergy
end
