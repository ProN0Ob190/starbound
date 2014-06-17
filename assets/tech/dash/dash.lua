function init()
  data.airDashing = false
  data.dashTimer = 0
  data.dashDirection = 0
  data.dashLastInput = 0
  data.dashTapLast = 0
  data.dashTapTimer = 0
end

function input(args)
  if data.dashTimer > 0 then
    return nil
  end

  local maximumDoubleTapTime = tech.parameter("maximumDoubleTapTime")

  if data.dashTapTimer > 0 then
    data.dashTapTimer = data.dashTapTimer - args.dt
  end

  if args.moves["right"] then
    if data.dashLastInput ~= 1 then
      if data.dashTapLast == 1 and data.dashTapTimer > 0 then
        data.dashTapLast = 0
        data.dashTapTimer = 0
        return "dashRight"
      else
        data.dashTapLast = 1
        data.dashTapTimer = maximumDoubleTapTime
      end
    end
    data.dashLastInput = 1
  elseif args.moves["left"] then
    if data.dashLastInput ~= -1 then
      if data.dashTapLast == -1 and data.dashTapTimer > 0 then
        data.dashTapLast = 0
        data.dashTapTimer = 0
        return "dashLeft"
      else
        data.dashTapLast = -1
        data.dashTapTimer = maximumDoubleTapTime
      end
    end
    data.dashLastInput = -1
  else
    data.dashLastInput = 0
  end

  return nil
end

function update(args)
  local dashControlForce = tech.parameter("dashControlForce")
  local dashSpeed = tech.parameter("dashSpeed")
  local dashDuration = tech.parameter("dashDuration")
  local energyUsage = tech.parameter("energyUsage")

  local usedEnergy = 0
  if args.actions["dashRight"] and data.dashTimer <= 0 and args.availableEnergy > energyUsage then
    data.dashTimer = dashDuration
    data.dashDirection = 1
    usedEnergy = energyUsage
    data.airDashing = not tech.onGround()
  elseif args.actions["dashLeft"] and data.dashTimer <= 0 and args.availableEnergy > energyUsage then
    data.dashTimer = dashDuration
    data.dashDirection = -1
    usedEnergy = energyUsage
    data.airDashing = not tech.onGround()
  end

  if data.dashTimer > 0 then
    tech.xControl(dashSpeed * data.dashDirection, dashControlForce, true)

    if data.airDashing then
      tech.applyMovementParameters({gravityEnabled = false})
      tech.yControl(0, dashControlForce, true)
    end

    if data.dashDirection == -1 then
      tech.moveLeft()
      tech.setFlipped(true)
    else
      tech.moveRight()
      tech.setFlipped(false)
    end
    tech.setAnimationState("dashing", "on")
    tech.setParticleEmitterActive("dashParticles", true)
    data.dashTimer = data.dashTimer - args.dt
  else
    tech.setAnimationState("dashing", "off")
    tech.setParticleEmitterActive("dashParticles", false)
  end

  return usedEnergy
end
