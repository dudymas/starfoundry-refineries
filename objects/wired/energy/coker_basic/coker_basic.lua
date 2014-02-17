function init( virtual )
  entity.setInteractive(true)
  if not virtual then
    energy.init()
    pipes.init({liquidPipe, itemPipe}) --ohsnap
    
    self.emptyProduct = {requirement = -1,  count = -1, name = "", byproduct = "", byproductQty = -1}

    if storage.state == nil then storage.state = false end

    genericConverter.config(entity.configParameter)

    self.allowedItems = entity.configParameter("allowedItems") or {}
    self.allowedLiquids = entity.configParameter("allowedLiquids") or {}

    self.liquidDrainIds = entity.configParameter("liquidDrainIds") or {}
    self.solidDrainIds = entity.configParameter("solidDrainIds") or {}
    self.liquidInputIds = entity.configParameter("liquidInputIds") or {}
    self.solidInputIds = entity.configParameter("solidInputIds") or {}
    
    self.cookRate = entity.configParameter("cookRate") or 5
    self.selfCleaningRate = entity.configParameter("selfCleaningRate") or 10
    self.cookTimer = 0
    self.liquidCapacity = entity.configParameter("liquidCapacity") or 1000
    self.liquidPushAmount = entity.configParameter("liquidPushAmount") or 100
    self.liquidPushRate = entity.configParameter("liquidPushRate") or 1

    self.liquidPushMinPressure = entity.configParameter("liquidPushMinPressure") or 0.0
    self.liquidPushScalesWithPressure = entity.configParameter("liquidPushScalesWithPressure") or false
    self.liquidPressures = entity.configParameter("liquidPressures") or {}

    storage.liquids = {}
    self.storageLimit = entity.configParameter("storageLimit") or {}
    self.defaultLimit = 1000
    self.startingLiquids = entity.configParameter("startingLiquids") or {}

    resetLiquids()
  end
end

function onInteraction( args )
  local statusMessage = genericConverter.statusMessage(storedLiquids()) .. "\n\n"
  return { "ShowPopup", {message = statusMessage}}
end

function resetLiquids()
  for _,liquidName in ipairs(self.allowedLiquids) do
    storage.liquids[liquidName] = { name = liquidName }
    storage.liquids[liquidName].count = self.startingLiquids[liquidName] or 0
  end
end

function storedLiquids()
  return storage.liquids or {}
end

function storedSolids()
  return storage.items or {}
end

function storedLiquid( liquidName )
  local liquids = storedLiquids()
  if not liquids[liquidName] then
    liquids[liquidName] = {name = liquidName, count = 0}
  end
  return liquids[liquidName]
end

function setLiquidStorage( liquidName, quantity )
  storedLiquid(liquidName).count = quantity
end

function main()
  energy.update()
  pipes.update(entity.dt())
  if genericConverter.canCook(storedLiquids(), storedSolids()) and energy.consumeEnergy() then
    local products = genericConverter.cook(storedLiquids(), storedSolids())
    if products then
      for _,product in pairs(products) do
        tryToStore(product)
      end
    end
  end
  decay()
  drain()
end

function die()
  energy.die()
end

function decay()
  local sourCoke = storedLiquid("sourCoke")
  if sourCoke.count > 0 then
    sourCoke.count = math.max(sourCoke.count - self.selfCleaningRate, 0)
  end
end

function drain()
  for liquidName,liquid in pairs( storedLiquids() ) do
    local quantity = liquid.count or liquid or 0
    if quantity > 0 then
      local packetCount = math.min( quantity, self.liquidPushAmount )
      local result = tryDrain( liquidName, packetCount )
      setLiquidStorage( liquidName, quantity - result )
    end
  end
end

function tryToStore( item )
  if isLiquid(item.name) then
    local excess = tryToStoreLiquid(item)
  else
    local excess = tryToStoreSolid(item)
  end
end

function tryToStoreSolid( item )
  return item.count
end

function tryToStoreLiquid( liquid )
  local excess = updateLiquid(liquid.name, liquid.count)
  return excess
end

function updateLiquid( liquidName, quantity )
  local amountAllowed = math.min(getLiquidCapacity(liquidName), quantity)
  local newQuantity = math.max(amountAllowed, 0)
  setLiquidStorage(liquidName, newQuantity)
  return quantity - amountAllowed
end

function getLiquidCapacity( liquidName )
  return getLimit(liquidName) - storedLiquid(liquidName).count
end

function getLimit( itemName )
  if self.storageLimit[itemName] then
    return self.storageLimit[itemName]
  elseif isLiquid(itemName) then
    return self.liquidCapacity or self.defaultLimit
  else
    return self.defaultLimit
  end
end

function tryDrain( type, quantity )
  local result = 0
  for _,nodeId in ipairs(getValidDrains(type)) do
    if isNodeConnected(type, nodeId) then
      local amountAllowed = tryPush(nodeId, { getLiquidId(type), quantity })
      result = result + amountAllowed
      if result == quantity then return quantity end
    end
  end
  return result
end

function isNodeConnected( type, nodeId )
  if isLiquid(type) then
    return isLiquidNodeConnected(nodeId)
  else
    return isItemNodeConnected(nodeId)
  end
end

function tryPush( nodeId, packet )
  local result = 0
  if isLiquid(getPacketName(packet)) then
    if sufficientPressure(getPacketName(packet)) then
      local scaledPacket = adjustPacketToPressure(nodeId, packet)
      result = pushLiquid(nodeId, scaledPacket)
    end
  else
    result = pushItem(nodeId, packet)
  end
  if result then
    return result ~= true and result or packet[2]
  else
    return 0
  end
end

function sufficientPressure( nodeId, packet )
  if self.liquidPushScalesWithPressure then
    return self.liquidPushMinPressure <= getPressureInBars(getPacketName(packet))
  else
    return true
  end
end

function adjustPacketToPressure( nodeId, packet )
  local result, liquidName = packet, getPacketName(packet)
  if self.liquidPushScalesWithPressure and self.liquidPressures[liquidName] then
    local scaledQuantity = getPressureInBars(liquidName) * getPacketCount(result)
    result = setPacketCount(result, scaledQuantity)
  end
  return result
end

function getPressureInBars( liquidName )
  local pressureConfig = self.liquidPressures[liquidName]
  if not pressureConfig then return 1.0 end
  local volumeOverhead = math.max(storedLiquid(liquidName).count - pressureConfig.minVolumeBeforePressureBuild, 0)
  local volumePerBar = math.max(pressureConfig.volumePerBar or volumeOverhead, 1.0)
  local calculatedBars = (volumeOverhead / volumePerBar) - self.liquidPushMinPressure
  return math.min(calculatedBars, pressureConfig.maxBars or 1.0)
end

function getValidDrains( identifier )
  if self.liquidDrainIds[identifier] then
    return self.liquidDrainIds[identifier] -- specific filter already setup
  else
    return isLiquid(identifier) and self.liquidDrainIds or self.solidDrainIds
  end
end

function isLiquid( identifier )
  return genericConverter.liquidMap[identifier] ~= nil
end

function beforeLiquidPut( liquidPacket, nodeId )
  local liquidName = getPacketName(liquidPacket)
  local inputs = getValidInputs(liquidName)
  if arrayContains(inputs, nodeId) then
    local result = math.min(getLiquidCapacity(liquidName), getPacketCount(liquidPacket))
    return result, liquidName
  end
  return false
end

function getLiquidId( name )
  if type(name) ~= "number" then
    return genericConverter.liquidMap[name]
  end
  return name
end

function getPacketName( packet )
  local id = packet and packet[1] or ""
  if type(id) ~= "string" and isLiquid(id) then
    return genericConverter.liquidMap[id] or ""
  else
    return id
  end
end

function getPacketCount( packet )
  return type(packet[1]) ==  "table" and packet[1].count or packet[2] or 0
end

function setPacketCount( packet, quantity )
  if type(packet) == "table" and packet.count then
    packet.count = quantity
    return packet
  else
    return {packet[1], quantity, tail(3, packet)}
  end
end

function tail(tailStartIndex, array)
  return table.pack( select( tailStartIndex, table.unpack(array) ) )
end

function arrayContains( inputs, nodeId )
  for _,v in ipairs(inputs) do
    if nodeId == v then return true end
  end
  return false
end

function getValidInputs( liquidName )
  return self.liquidInputIds[liquidName] or {}
end

function onLiquidPut(...)
  local result, liquidName = beforeLiquidPut(...) --yep. lazy pants timeh
  if result then
    tryToStoreLiquid({name = liquidName, count = result})
  end
  return result
end
