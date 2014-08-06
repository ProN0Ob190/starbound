function init()
  self.fireInterval = 0.2
  self.fireTimer = self.fireInterval * 0.5
  self.minLiquidLevel = 230
  self.range = 15
  self.dropItems = {
    [1] = "liquidwater", --water
    [2] = "liquidwater", --endless water
    [3] = "liquidlava", --lava
    [5] = "liquidlava", --endless lava
    [4] = "liquidacid", --acid (or poison if you prefer)
    [6] = "liquidtentaclejuice", --tentacle juice
    [7] = "liquidoil"  --oil
  }
end

function fireTriggered()
  self.fireTimer = self.fireInterval * 0.5
end

function continueFire(dt)
  self.fireTimer = self.fireTimer - dt
  if self.fireTimer <= 0 then
    suckLiquid()
    self.fireTimer = self.fireInterval
  end
end

function suckLiquid()
  local tarPos = item.ownerAimPosition()
  local srcPos = item.ownerPosition()
  local range = world.magnitude(tarPos, srcPos)
  if range > self.range or world.lineCollision(srcPos, tarPos) then
    return false
  end

  -- target tile plus tiles to right and left
  local checkTiles = {
    tarPos,
    vec2.add(tarPos, {1, 0}),
    vec2.add(tarPos, {-1, 0})
  }

  -- drain tiles and drop items (VERY approximate)
  local totalLevel = 0
  local liquidId = 0
  local didSuck = false
  for i, pos in ipairs(checkTiles) do
    local liquid = world.visibleLiquidAt(pos)
    if liquid and self.dropItems[liquid[1]] and (liquidId == 0 or liquid[1] == liquidId) then
      liquidId = liquid[1]
      totalLevel = totalLevel + liquid[2]
      while totalLevel >= self.minLiquidLevel do
        totalLevel = totalLevel - self.minLiquidLevel
        while i > 0 do
          world.destroyLiquid(checkTiles[i])
          i = i - 1
        end
        world.spawnItem(self.dropItems[liquidId], srcPos)
        didSuck = true
      end
    end
  end

  local direction = world.distance(srcPos, tarPos)
  world.spawnProjectile("vacuum", tarPos, 0, direction, false, { speed = math.max(range - 3, 0) * 2 })

  return didSuck
end

function startTriggered() end

function attemptedFire() end

function endFire() end

function triggerWindup() end

function triggerCooldown() end