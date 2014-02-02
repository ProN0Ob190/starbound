function init(args)
  self.movement = { 1, 0 }
  self.movementWeight = 1.0
  self.wanderTimer = 0
  self.collisionAvoidance = {}

  local scripts = entity.configParameter("scripts")
  local states = stateMachine.scanScripts(scripts, "(%a+State)%.lua")
  self.state = stateMachine.create(states)
  self.state.leavingState = function(state)
    self.wanderTimer = 0
  end

  entity.setAnimationState("movement", "swimming")
end

function flockSwimmerInfo()
  return {
    movement = self.movement,
    damaged = self.damagedTimer ~= nil,
    isLeader = self.isFlockLeader
  }
end

function damage(args)
  self.damagedTimer = 0.5
end

function main()
  local dt = entity.dt()

  if self.damagedTimer ~= nil then
    if self.damagedTimer < 0 then
      self.damagedTimer = nil
    else
      self.damagedTimer = self.damagedTimer - dt
    end
  end

  if not self.state.update(dt) then
    wander(dt)
  end

  if self.movement ~= nil then
    self.movement = calculateFinalMovement(dt, self.movement, self.movementWeight)
    self.movementWeight = 1.0

    if self.movement[2] ~= 0 then
      local rotateAmount = -math.atan2(self.movement[2], self.movement[1])
      if rotateAmount < 0 then rotateAmount = rotateAmount + 2 * math.pi end
      if self.movement[1] < 0 then rotateAmount = math.pi - rotateAmount end
      entity.rotateGroup("all", rotateAmount)
    else
      entity.rotateGroup("all", 0)
    end

    entity.setFacingDirection(util.toDirection(self.movement[1]))
    entity.fly(vec2.mul({ self.movement[1], self.movement[2] }, entity.flySpeed()))
  end
end

function wander(dt)
  self.movement[1] = util.toDirection(self.movement[1])
  if self.wanderTimer > entity.configParameter("wanderChangeDirectionTime") then
    self.movement[2] = 0
  end

  self.wanderTimer = self.wanderTimer + dt
  if self.wanderTimer > entity.configParameter("wanderChangeDirectionCooldown") then
    if self.isFlockLeader then
      self.movement[2] = entity.randomizeParameterRange("wanderChangeDirectionYRange")
      self.movement[1] = -self.movement[1]
    end

    self.wanderTimer = 0
  end
end

function calculateFinalMovement(dt, intendedMovement, intendedMovementWeight)
  local movements = { { intendedMovement, intendedMovementWeight } }

  local collisionMovement = calculateCollisionMovement(intendedMovement)
  if collisionMovement ~= nil then
    self.collisionAvoidance.timer = entity.configParameter("collisionAvoidanceTime")
    self.collisionAvoidance.movement = collisionMovement
  end

  if self.collisionAvoidance.movement ~= nil then
    table.insert(movements, { self.collisionAvoidance.movement, entity.configParameter("collisionAvoidanceWeight") })
  end

  -- Keep responding to collision avoidance for a while, to prevent bouncing
  -- back and forth between collision and where the flock or state wants the
  -- monster to move to. This is particularly noticable when a flock hits a wall
  -- the leading swimmers start to turn around
  if self.collisionAvoidance.timer ~= nil then
    self.collisionAvoidance.timer = self.collisionAvoidance.timer - dt
    if self.collisionAvoidance.timer < 0 then
      self.collisionAvoidance.timer = nil
      self.collisionAvoidance.movement = nil
    end
  end

  local flockEntities = { damaged = 0 }
  local flockMovement = flocking.calculateMovement("flockSwimmerInfo", flockEntities)
  if flockEntities.damaged ~= 0 then
    local entityPosition = world.entityPosition(flockEntities.damaged)
    if entityPosition ~= nil then
      self.state.pickState({ scatterSource = entityPosition })
    end
  end

  -- Flock leaders get to move wherever they want, without being influenced by
  -- the rest of the flock, while the rest of the flock doesn't have as much say
  -- in where they want to go
  if not self.isFlockLeader then
    table.insert(movements, { flockMovement, entity.configParameter("flockMovementWeight") })
  end

  local combinedMovement = { 0, 0 }
  for i, movementComponent in ipairs(movements) do
    local movement, weight = table.unpack(movementComponent)
    vec2.add(combinedMovement, vec2.mul(movement, weight))
  end

  return vec2.norm(combinedMovement)
end

function calculateCollisionMovement(intendedMovement)
  local hasCollision = false
  local movement = { intendedMovement[1], intendedMovement[2] }

  if util.blockSensorTest("blockedSensors", movement[1]) then
    movement[1] = -movement[1]
    hasCollision = true
  end

  if util.blockSensorTest("upSensors", movement[1]) then
    if movement[2] < 0 then
      movement[2] = -movement[2]
    else
      movement[2] = 1
    end
    hasCollision = true
  elseif util.blockSensorTest("downSensors", movement[1]) then
    if movement[2] > 0 then
      movement[2] = -movement[2]
    else
      movement[2] = -1
    end
    hasCollision = true
  end

  if hasCollision then
    return movement
  else
    return nil
  end
end
