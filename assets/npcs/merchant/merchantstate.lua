merchantState = {}

--------------------------------------------------------------------------------
function merchantState.enterWith(args)
  if args.interactArgs == nil then return nil end
  if args.interactArgs.sourceId == 0 then return nil end

  if not merchantState.isInStore() then
    return nil
  end

  if self.tradingConfig == nil then
    self.tradingConfig = merchantState.buildTradingConfig()
  end

  return {
    sourceId = args.interactArgs.sourceId,
    timer = entity.configParameter("merchant.waitTime")
  }
end

--------------------------------------------------------------------------------
function merchantState.enteringState(stateData)
  sayToTarget("merchant.dialog.start", stateData.sourceId)
end

--------------------------------------------------------------------------------
function merchantState.update(dt, stateData)
  local sourcePosition = world.entityPosition(stateData.sourceId)
  if sourcePosition == nil then return true end

  local toSource = world.distance(sourcePosition, entity.position())
  setFacingDirection(toSource[1])

  stateData.timer = stateData.timer - dt
  return stateData.timer <= 0
end

--------------------------------------------------------------------------------
function merchantState.leavingState(stateData)
  if world.entityExists(stateData.sourceId) then
    sayToTarget("merchant.dialog.end", stateData.sourceId)
  end
end

--------------------------------------------------------------------------------
function merchantState.isInStore()
  local storeRadius = entity.configParameter("merchant.storeRadius")
  if storeRadius == -1 then
    return true
  end

  local position = entity.position()
  local distance = world.magnitude(storage.spawnPosition, position)

  return distance < storeRadius and isInside(position) == isInside(storage.spawnPosition)
end

--------------------------------------------------------------------------------
function merchantState.buildTradingConfig()
  -- Build list of all possible items
  local level = entity.level()
  local items = {}
  for _, category in pairs(entity.configParameter("merchant.categories")) do
    local levelSets = entity.configParameter("merchant.items." .. category, nil)
    if levelSets ~= nil then
      -- Find the highest available level within the category
      local highestLevel, highestLevelSet = -1, nil
      for _, levelSet in pairs(levelSets) do
        if level >= levelSet[1] and levelSet[1] > highestLevel then
          highestLevel, highestLevelSet = levelSet[1], levelSet[2]
        end
      end

      if highestLevelSet ~= nil then
        for _, item in pairs(highestLevelSet) do
          table.insert(items, item)
        end
      end
    end
  end

  -- Reset the PRNG so the same seed always generates the same set of items.
  -- The uint64_t seed can get truncated when converted to a lua double, but
  -- it will at least provide a deterministic seed, even if the full range of
  -- input seeds can't be used
  local seed = tonumber(entity.seed())
  math.randomseed(seed)

  -- Shuffle the list
  for i = #items, 2, -1 do
    local j = math.random(i)
    items[i], items[j] = items[j], items[i]
  end

  local selectedItems, skippedItems = {}, {}
  local numItems = entity.configParameter("merchant.numItems")
  for _, item in pairs(items) do
    if item.rarity == nil or math.random() > item.rarity then
      table.insert(selectedItems, item)

      if #selectedItems == numItems then
        break
      end
    else
      table.insert(skippedItems, item)
    end
  end

  -- May need to dip into the rare items to get enough
  for i = 1, math.min(#skippedItems, numItems - #selectedItems) do
    table.insert(selectedItems, skippedItems[i])
  end

  -- Now build the actual trading config
  local tradingConfig = {
    config = "/interface/windowconfig/shop.config",
    recipes = { }
  }

  -- In absense of a staticRandomizeParameterRange...
  if storage.priceVariance == nil then
    storage.priceVariance = entity.randomizeParameterRange("merchant.priceVarianceRange")
  end

  local level = entity.level()
  for _, item in pairs(selectedItems) do
    local output = item.item

    if output.name ~= nil and string.find(output.name, "^generated") then
      if output.data then
        if output.data.level == nil then
          output.data.level = level
        end

        if output.data.seed == nil then
          output.data.seed = math.random() * seed
        end
      end
    end

    local recipe = {
      input = { { name = "money", count = item.cost * storage.priceVariance } },
      output = output
    }

    table.insert(tradingConfig.recipes, recipe)
  end

  math.randomseed(os.time())

  return tradingConfig
end