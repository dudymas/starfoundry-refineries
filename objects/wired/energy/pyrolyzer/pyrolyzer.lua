function init(virtual)
  entity.setInteractive(true)
  if not virtual then
    energy.init()
    pipes.init({liquidPipe, itemPipe}) --ohsnap
    
    if storage.state == nil then storage.state = false end
    
    genericConverter.config(entity.configParameter)
    
    self.inputItemNodeId = 1
    self.outputItemNodeId = 2
    self.inputLiquidNodeId = 1
    self.outputLiquidNodeId = 2
    self.capacity = entity.configParameter("liquidCapacity")
    self.liquidPushAmount = entity.configParameter("liquidPushAmount")
    self.liquidPushRate = entity.configParameter("liquidPushRate") or 100

    if not storage.liquid then
      storage.liquid = {}
      storage.liquid[1] = nil
      storage.liquid[2] = 0
    end
  end
end

function storedLiquidID()
  if storage.liquid and storage.liquid[1] then
    return storage.liquid[1]
  else
    return 0
  end
end

function storedLiquidLevel()
  if storage.liquid and storage.liquid[2] then
    return storage.liquid[2]
  else
    return 0
  end
end

function storedLiquidType()
  return genericConverter.liquidMap[storedLiquidID()]
end

function drip()
  if storedLiquidLevel() > 0 and self.liquidPushAmount then
    local liquidPacketSize = math.min(storedLiquidLevel(), self.liquidPushAmount)
    local packet = {storedLiquidID(), liquidPacketSize}
    local success = pushLiquid(self.outputLiquidNodeId, packet)
    if success then
      local amount = -(success ~= true and success or liquidPacketSize)
      updateLiquidLevel(amount)
    end
  end
end

function setLiquidLevel( level )
  if level < 0 then
    storage.liquid[2] = 0
  elseif level > self.capacity then
    storage.liquid[2] = self.capacity --TODO: push excess if possible
  else
    storage.liquid[2] = level
  end
end

function updateLiquidLevel( delta )
  local leftover = 0
  if storedLiquidType() and (storedLiquidLevel() > 0 or delta > 0) then
    leftover = storedLiquidLevel() + delta
    setLiquidLevel(leftover)
  end
end

function clearLiquid()
  if storedLiquidLevel() ~= nil and storedLiquidLevel() == 0 then
    storage.liquid = {}
  end
end

function storedOre()
  if storage.ore and storage.ore.name then
    return storage.ore
  else
    return nil
  end
end

function resetStoredOre(itm)
  storage.ore = itm or {}
end

function die()
  energy.die()
end

function onInteraction(args)
  local statusMessage = genericConverter.statusMessage(storedOre()) .. "\n\n"
  if storedLiquidLevel() > 0 then
    statusMessage = statusMessage..
      "There is "..storedLiquidLevel().." of "..storedLiquidType()
  end
  return { "ShowPopup", {message = statusMessage}}
end

function main()
  mainUpdate()
  if canCook() then
    cook()
    genericConverter.updateTimer(entity.dt())
  end
end

function mainUpdate()
  energy.update()
  pipes.update(entity.dt())
  updateOre()
  drip()
end

function updateOre()
  if not storedOre() then
    pullOre()
  end
end

function canCook()
  if liquidAtCapacity() or not sufficientOre() or not roomForConversion() then
    return false
  else
    return energy.consumeEnergy()
  end
end

function liquidAtCapacity()
  local level = storedLiquidLevel()
  return level and self.capacity and level >= self.capacity
end

function sufficientOre()
  local stored = storedOre()
  if stored and genericConverter.productNotEmpty(storedOre()) then
    return stored.count >= genericConverter.product(stored).requirement
  else
    return false
  end
end

function roomForConversion()
  local conversionProduct = genericConverter.product(storedOre())
  if conversionProduct == self.emptyProduct or not roomForByproduct() then
    return false --can't determine if there's room without a product. default false
  else
    return peekPushItem(self.outputItemNodeId, {conversionProduct.name, conversionProduct.count, data = {}})
  end
end

function roomForByproduct()
  if storedLiquidLevel() > 0 and not (storedLiquidType() == genericConverter.product(storedOre()).byProduct) then
    return false
  else
    return (storedLiquidLevel() + genericConverter.product(storedOre()).byProductQty) < self.capacity
  end
end

function pullOre()
  local pulledItem = pullItem(self.inputItemNodeId, genericConverter.conversionsFilter())
  resetStoredOre(pulledItem)
end

function cook()
  if genericConverter.cookTimerFinished() then
    local success = tryProcessOres()
    if success then
      genericConverter.resetTimer()
    end
  end
end

function tryProcessOres()
  if roomForConversion() and tryPushingProduct() then
    storeByproducts()
    resetStoredOre()
    return true
  else
    world.logInfo("Processing phailed D:")
    return false
  end
end

function tryPushingProduct()
  local conversion = genericConverter.product(storedOre())
  local itemProduced = {name = conversion.name, count = conversion.count, data = {}}
  return pushItem(self.outputItemNodeId, itemProduced)
end

function storeByproducts()
  storage.liquid[1] = genericConverter.liquidMap[genericConverter.product(storedOre()).byProduct]
  updateLiquidLevel(genericConverter.product(storedOre()).byProductQty)
end

function beforeItemPut(item, nodeId)
  if nodeId == self.inputItemNodeId then
    return canStoreItem(item)
  end
end

function onItemPut(item, nodeId)
  if nodeId == self.inputItemNodeId and canStoreItem(item) then
      local requirementsMet, amountUsed = tryConversion(item)
      return amountUsed or requirementsMet
  end
  return false
end

function canStoreItem( item )
  return item and item.name and not storedOre() and genericConverter.canConvert(item)
end

function tryConversion( item )
  local conversion = genericConverter.convert(item.name)
  if item.count >= conversion.requirement then
    item.count = conversion.requirement
    resetStoredOre(item)
    return true, conversion.requirement
  else
    return false, nil
  end
end
