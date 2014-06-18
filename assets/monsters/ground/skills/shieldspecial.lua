shieldSpecial = {
  active = false,
  health = 0,
  duration = 0
}

function shieldSpecial.onDamage(args)
  if shieldSpecial.active then
    entity.heal(math.min(shieldSpecial.health, args.damage))
    shieldSpecial.health = math.max(0, shieldSpecial.health - args.damage)

    if shieldSpecial.health == 0 then
      shieldSpecial.deactivateShield()
    end
  elseif self.skillCooldownTimers["shieldSpecial"] <= 0 then
    shieldSpecial.activateShield()
  end
end

function shieldSpecial.onUpdate(dt)
  if shieldSpecial.active then
    shieldSpecial.duration = shieldSpecial.duration - dt
    if shieldSpecial.duration <= 0 then
      shieldSpecial.deactivateShield()
    end
  end
end

function shieldSpecial.activateShield()
  shieldSpecial.active = true
  shieldSpecial.health = entity.configParameter("shieldSpecial.shieldBaseHealth") * root.evalFunction("monsterLevelHealthMultiplier", entity.level())
  shieldSpecial.duration = entity.configParameter("shieldSpecial.shieldTime")
  -- entity.setAnimationState("shield", "on")
  entity.setEffectActive("shield", true)

  self.skillCooldownTimers["shieldSpecial"] = entity.configParameter("shieldSpecial.cooldownTime")
end

function shieldSpecial.deactivateShield()
  shieldSpecial.active = false
  shieldSpecial.health = 0
  shieldSpecial.duration = 0
  -- entity.setAnimationState("shield", "off")
  entity.setEffectActive("shield", false)
end