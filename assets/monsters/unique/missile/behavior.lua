function init()
  entity.setGravityEnabled(false)
  entity.setDamageOnTouch(false)
  entity.setDeathParticleBurst(entity.configParameter("deathParticles"))
  entity.setDeathSound(entity.randomizeParameter("deathNoise"))

  self.dead = false
  self.target = 0

  self.speed = 5
  self.maxSpeed = 35
  self.acceleration = 10

  self.angle = math.pi / 2
  self.rotateSpeed = 0.06

  self.timeToLive = entity.configParameter("timeToLive", 4.0)

  local nearbyPlayers = world.playerQuery(entity.position(), 50)
  if #nearbyPlayers > 0 then self.target = nearbyPlayers[1] end
end

function main()
  if self.target ~= 0 then
    --get relative target position
    local tarDelta = world.distance(world.entityPosition(self.target), entity.position())

    --calculate angle and angular distance to target
    local tarAngle = util.wrapAngle(math.atan2(tarDelta[2], tarDelta[1]))

    local angleDelta = tarAngle - self.angle
    if angleDelta > math.pi then angleDelta = angleDelta - 2 * math.pi end
    if angleDelta < -math.pi then angleDelta = angleDelta + 2 * math.pi end

    --rotate toward target as much as rotateSpeed allows
    local rotateAmount = util.clamp(angleDelta, -self.rotateSpeed, self.rotateSpeed)
    self.angle = util.wrapAngle(self.angle + rotateAmount)

    --match visual rotation to velocity
    entity.rotateGroup("body", self.angle)

    --explode in proximity
    if world.magnitude(tarDelta) <= 2 then
      detonate()
    end
  end

  --accelerate up to maximum speed
  self.speed = math.min(self.speed + (self.acceleration * entity.dt()), self.maxSpeed)
  entity.applyMovementParameters({flySpeed=self.speed})

  --fly in current direction
  entity.fly({self.speed * math.cos(self.angle), self.speed * math.sin(self.angle)})

  --blow up on impact or timeout
  if isBlocked() or self.timeToLive <= 0 then
    detonate()
  end

  --fizzle in liquid
  if entity.inLiquid() then
    self.dead = true
  end

  --decrement life timer
  self.timeToLive = self.timeToLive - entity.dt()
end

function damage()
  self.dead = true
end

function shouldDie()
  return self.dead
end

function setTarget(targetId)
  self.target = targetId
end

function detonate()
  world.spawnProjectile("zbomb", entity.position(), entity.id(), {math.cos(self.angle), math.sin(self.angle)}, true, { timeToLive = 0 })
  self.dead = true
end

--------------------------------------------------------------------------------
function isBlocked()
  return world.pointCollision(entity.toAbsolutePosition({1.5 * math.cos(self.angle - 0.2), 1.5 * math.sin(self.angle - 0.2)})) or world.pointCollision(entity.toAbsolutePosition({1.5 * math.cos(self.angle + 0.2), 1.5 * math.sin(self.angle + 0.2)}))
end