function init()
  self.fireInterval = 0.1
  self.fireTimer = self.fireInterval * 0.5
  self.minLiquidLevel = 230
  self.range = 15
  self.dropItems = {
    [1] = "ice", --water
    [2] = "ice", --endless water
    [3] = "magmarock", --lava
    [5] = "magmarock", --endless lava
    [4] = "dirtmaterial", --acid (or poison if you prefer)
    [6] = "fleshblock", --tentacle juice
    [7] = "tar"  --tar
  }
end

function fireTriggered()
  self.fireTimer = self.fireInterval * 0.5
end

function continueFire(dt)
  self.fireTimer = self.fireTimer - dt
  if self.fireTimer <= 0 and suckLiquid() then
    self.fireTimer = self.fireInterval
  end
end

function suckLiquid()
  local tarPos = item.ownerAimPosition()
  local srcPos = item.ownerPosition()
  if world.magnitude(tarPos, srcPos) > self.range or world.lineCollision(srcPos, tarPos) then
    return false
  end

  -- target tile plus tiles to right and left
  local checkTiles = {
    tarPos,
    {tarPos[1] + 1, tarPos[2]},
    {tarPos[1] - 1, tarPos[2]}
  }

  -- try to drain tiles within range until we have a full unit (super wasteful!)
  local totalLevel = 0
  local liquidId = 0
  for i, pos in ipairs(checkTiles) do
    local liquid = world.visibleLiquidAt(pos)
    if liquid and self.dropItems[liquid[1]] and (liquidId == 0 or liquid[1] == liquidId) then
      liquidId = liquid[1]
      totalLevel = totalLevel + liquid[2]
      if totalLevel >= self.minLiquidLevel then
        while i > 0 do
          world.destroyLiquid(checkTiles[i])
          i = i - 1
        end
        world.spawnItem(self.dropItems[liquidId], srcPos)
        return true
      end
    end
  end

  return false
end

function startTriggered() end

function attemptedFire() end

function endFire() end

function triggerWindup() end

function triggerCooldown() end