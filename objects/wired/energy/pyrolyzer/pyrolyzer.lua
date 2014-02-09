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
    self.pushAmount = entity.configParameter("liquidPushAmount")
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
  if storedLiquidLevel() > 0 and self.liquidPushRate then
    local liquidPacketSize = math.min(storedLiquidLevel(), self.liquidPushRate)
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
  exploooosions()
end

function onInteraction(args)
  local liqLevel = storedLiquidLevel() or "nada"
  local woodLev = storedOre() and storedOre().count or "nada"
  if canCook() then
    world.logInfo("I can cook schtuff :P I've been cookin fer " .. genericConverter.cookTimer)
  else
    world.logInfo("No soup for you! >:-^ ")--snap!
    if liquidAtCapacity() then
      world.logInfo(" - liquidAtCapacity()")
    end
    if not sufficientOre() then
      world.logInfo(" - not sufficientOre()")
    end
    if not genericConverter.productNotEmpty(storedOre()) then
      world.logInfo(" - product() is empty... can't convert stored ore ")
    elseif not roomForConversion() then
      world.logInfo(" - not roomForConversion()")
      if not roomForByproduct() then
        world.logInfo(" - - not roomForByproduct()")
        local product = genericConverter.product(storedOre())
        if storedLiquidLevel() > 0 and not (storedLiquidType() == product.byproduct) then
          world.logInfo(" - - - already have a different liquid (".. storedLiquidType()
            ..") being stored. Can't store (".. product.byproduct
            ..")")
        elseif (storedLiquidLevel() + product.byproductQty) >= self.capacity then
          local cap = self.capacity or "zilch"
          local bypAmnt = genericConverter.product(storedOre()).byproductQty or "itty bits"
          world.logInfo(" - - - capacity at max ( " .. cap
            .. " ) because we already store (".. liqLevel
            ..") and need room for (".. bypAmnt
            ..") ")
        end
      end
    end
  end
  return { "ShowPopup", {message = "imma cookur :3 I gotz " .. woodLev .. " wood and " .. liqLevel .. " pitch, suckaa! ^_^"}}
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
  if storedLiquidLevel() > 0 and not (storedLiquidType() == genericConverter.product(storedOre()).byproduct) then
    return false
  else
    return (storedLiquidLevel() + genericConverter.product(storedOre()).byproductQty) < self.capacity
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
  storage.liquid[1] = genericConverter.liquidMap[genericConverter.product(storedOre()).byproduct]
  updateLiquidLevel(genericConverter.product(storedOre()).byproductQty)
end

function exploooosions()
  --determine if we are working on any material
  --if so, and our liquids are above the explosive limit
  --spew flames
  --otherwise just dump a % of liquids
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
