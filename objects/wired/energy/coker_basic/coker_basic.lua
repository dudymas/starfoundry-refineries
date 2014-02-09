function init(virtual)
  entity.setInteractive(true)
  if not virtual then
    energy.init()
    pipes.init({liquidPipe, itemPipe}) --ohsnap
    
    self.emptyProduct = {requirement = -1,  count = -1, name = "", byproduct = "", byproductQty = -1}

    if storage.state == nil then storage.state = false end

    genericConverter.config(entity.configParameter)

    self.drains = entity.configParameter("drains") or {}
    self.liquidDrains = entity.configParameter("liquidDrains") or {}
    self.solidDrains = entity.configParameter("solidDrains") or {}
    
    self.cookRate = entity.configParameter("cookRate")
    self.cookTimer = 0
    self.capacity = entity.configParameter("liquidCapacity")
    self.pushAmount = entity.configParameter("liquidPushAmount")
    self.pushRate = entity.configParameter("liquidPushRate")

    storage.liquids = {}
    storage.allowedLiquids = {"water","tar","sourWater","crude","wetCoke"}
    storage.storageLimit = {}
    self.defaultLimit = 1000
  end
end

function main()
  local products = genericConverter.cook(storage.liquids, storage.solids)
  if products then
    for k,v in pairs(products) do
      tryToStore(k, v)
    end
  end
  drain()
end

function die()
  energy.die()
end

function drain()
  for k,v in pairs(storage.products) do
    if v > 0 then
      local packet = math.min(v, self.drainLimit)
      local result = tryDrain(k, packet)
      storage.products[k] = v - result
    end
  end
end

function tryToStore( item, quantity )
  if isLiquid(item) then
    local excess = tryToStoreLiquid(item, quantity)
  else
    local excess = tryToStoreSolid(item, quantity)
  end
end

function tryToStoreLiquid( liquidName, quantity )
  if canStoreLiquid(liquidName) then
    local excess = updateLiquid(liquidName, quantity)
    return excess
  end
  return 0
end

function canStoreLiquid( liquidName )
  return self.allowedLiquids[liquidName] ~= nil
end

function updateLiquid( liquidName, quantity )
  local stored = storage.liquids[liquidName] or 0
  local excess = (stored + quantity) - getLimit(liquidName)
  storage.liquids[liquidName] = (stored + quantity) - excess
  return excess
end

function getLimit( itemName )
  return self.storageLimit[itemName] or self.defaultLimit
end

function tryDrain(type, amnt)
  local result = 0
  for _,v in ipairs(getValidDrains(type)) do
    local amntAccepted = tryPush(v, {type, amnt})
    result = result + amntAccepted
    if result == amnt then return amnt end
  end
  return result
end

function tryPush( pipeId, itm )
  local result = 0
  if isLiquid(itm[1]) then
    result = pushLiquid(pipeId, itm)
  else
    result = pushItem(pipeId, itm)
  end
  if result then
    return result ~= true and result or itm[2]
  else
    return 0
  end
end

function getValidDrains( identifier )
  if self.drains[identifier] then
    return self.drains[identifier] -- specific filter already setup
  else
    return isLiquid(identifier) and self.liquidDrains or self.solidDrains
  end
end

function isLiquid( identifier )
  return genericConverter.liquidMap[identifier] ~= nil
end
