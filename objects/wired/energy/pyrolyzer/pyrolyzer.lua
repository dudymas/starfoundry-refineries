function init(virtual)
  entity.setInteractive(true)
  if not virtual then
    energy.init()
    pipes.init({liquidPipe, itemPipe}) --ohsnap
    
    self.emptyProduct = {requirement = -1,  count = -1, name = "", byproduct = "", byproductQty = -1}

    self.conversions = {}
    self.conversions["fullwood1"] = {requirement = 5,  count = 3, name = "charcoal", byproduct = "tar", byproductQty = 100}
    
    self.liquidMap = {}
    self.liquidMap["water"] = 1
    self.liquidMap["lava"] = 3
    self.liquidMap["poison"] = 4
    self.liquidMap["juice"] = 6
    self.liquidMap["tar"] = 7

    self.liquidMap[1] = "water"
    self.liquidMap[3] = "lava"
    self.liquidMap[4] = "poison"
    self.liquidMap[6] = "juice"
    self.liquidMap[7] = "tar"

    --upcoming liquids
    --self.liquidMap["hotPitch"] = -1 -- made from boiler and also output by pyrolyzer (later)
    --self.liquidMap["gaseousWoodAlcohol"] = -1 -- byproduct from pyrolyzing wood
    --self.liquidMap["woodAlcohol"] = -1 -- made in a condenser by processing gaseousWoodAlcohol
    --self.liquidMap["bitumen"] = -1 -- made by pyrolyzing tar blocks... product will be asphalt
    --self.liquidMap["synbit"] = -1 -- made by pyrolyzing tar when there is wood alcohol in pyrolyzer tank
    --self.liquidMap["sourWater"] = -1 -- made in coker, from adding water to hot pitch/tar
    --self.liquidMap["wetCoke"] = -1 -- product from coker... separates into sour water and needle coke in a pneumatic pump
    --self.liquidMap["pretrol"] = -1 -- byproduct from coker and the mixture of water and hot pitch

    if storage.state == nil then storage.state = false end
    
    self.cookRate = entity.configParameter("cookRate")
    self.cookTimer = 0
    self.inputItemNodeId = 1
    self.outputItemNodeId = 2
    self.inputLiquidNodeId = 1
    self.outputLiquidNodeId = 2
    self.capacity = entity.configParameter("liquidCapacity")
    self.pushAmount = entity.configParameter("liquidPushAmount")
    self.pushRate = entity.configParameter("liquidPushRate")
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
    return nil
  end
end

function storedLiquidType()
  return self.liquidMap[storedLiquidID()]
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

function product()
  if storedOre() then
    return self.conversions[storedOre().name] or self.emptyProduct
  else
    return self.emptyProduct
  end
end

function resetTimer()
  self.cookTimer = 0
end

function updateTimer(timeDelta)
  if self.cookTimer > self.cookRate then
    self.cookTimer = self.cookTimer + timeDelta
  end
end

function die()
  energy.die()
  exploooosions()
end

function onInteraction(args)
  local liqLevel = storedLiquidLevel() or "nada"
  if storage then
    world.logInfo("I gotz storaaage")
    for k,v in pairs(storage) do
      world.logInfo("I see " .. k)
    end
  else
    world.logInfo("no storage for me")
  end
  return { "ShowPopup", {message = "imma cookur :3 I gotz " .. liqLevel .. " pitch, suckaa! ^_^"}}
end

function main()
  mainUpdate()
  if canCook() then
    cook()
    updateTimer(entity.dt())
  end
end

function mainUpdate()
  energy.update()
  pipes.update(entity.dt())
  updateOre()
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
  if stored and not product() == self.emptyProduct then
    return stored.count >= product().requirement
  else
    return false
  end
end

function roomForConversion()
  local conversionProduct = product()
  if conversionProduct == self.emptyProduct or not roomForByproduct() then
    return false --can't determine if there's room without a product. default false
  else
    return peekPushItem(self.outputItemNodeId, {conversionProduct.name, conversionProduct.count, data = {}})
  end
end

function roomForByproduct()
  if storedLiquidLevel() > 0 and not storedLiquidType() == product().byproduct then
    return false
  else
    return (storedLiquidLevel() + product().byproductQty) > self.capacity
  end
end

function pullOre()
  local pulledItem = pullItem(1, pulledItemConversionsFilter())
  resetStoredOre(pulledItem)
end

function pulledItemConversionsFilter()
  local pullFilter = {}
  for matitem,conversion in pairs(self.conversions) do
    pullFilter[matitem] = {conversion[1], conversion[1]}
  end
  return pullFilter
end

function cook()
  if self.cookTimer > self.cookRate then
    processOres()
  end
end

function processOres()
  if roomForConversion() and tryPushingProduct() then
    storeByproducts()
    resetStoredOre()
  end
end

function tryPushingProduct()
  local conversion = product()
  local itemProduced = {name = conversion.name, count = conversion.count, data = {}}
  return pushItem(self.outputItemNodeId, itemProduced)
end

function storeByproducts()
  storage.liquid[1] = self.liquidMap[product().byproduct]
  storage.liquid[2] = storage.liquid[2] + product().byproductQty
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
  return item and item.name and not storedOre() and self.conversions[item.name]
end

function tryConversion( item )
  local conversion = self.conversions[item.name]
  if item.count >= conversion.requirement then
    item.count = conversion.requirement
    resetStoredOre(item)
    return true, conversion.requirement
  else
    return false, nil
  end
end
