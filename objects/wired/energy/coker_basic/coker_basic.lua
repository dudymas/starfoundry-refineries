function init(virtual)
  entity.setInteractive(true)
  if not virtual then
  energy.init()
  pipes.init({liquidPipe, itemPipe}) --ohsnap
  
  self.emptyProduct = {requirement = -1,  count = -1, name = "", byproduct = "", byproductQty = -1}

  self.conversions = {}
  self.conversions["tar"] = {requirement = 5,  count = 3, name = "coke", byproduct = "sourWater", byproductQty = 100}

  --upcoming liquids
  --self.liquidMap["hotPitch"] = -1 -- made from boiler and also output by pyrolyzer (later)
  --self.liquidMap["gaseousWoodAlcohol"] = -1 -- byproduct from pyrolyzing wood
  --self.liquidMap["woodAlcohol"] = -1 -- made in a condenser by processing gaseousWoodAlcohol
  --self.liquidMap["bitumen"] = -1 -- made by pyrolyzing tar blocks... product will be asphalt
  --self.liquidMap["synbit"] = -1 -- made by pyrolyzing tar when there is wood alcohol in pyrolyzer tank
  self.liquidMap["sourWater"] = 20 -- made in coker, from adding water to hot pitch/tar
  --self.liquidMap["wetCoke"] = -1 -- product from advanced coker... separates into sour water and needle coke in a pneumatic pump
  --self.liquidMap["pretrol"] = -1 -- byproduct from coker and the mixture of water and hot pitch

  if storage.state == nil then storage.state = false end

  self.drains = entity.configParameter("drains") or {}
  self.liquidDrains = entity.configParameter("liquidDrains") or {}
  self.solidDrains = entity.configParameter("solidDrains") or {}
  
  self.cookRate = entity.configParameter("cookRate")
  self.cookTimer = 0
  self.capacity = entity.configParameter("liquidCapacity")
  self.pushAmount = entity.configParameter("liquidPushAmount")
  self.pushRate = entity.configParameter("liquidPushRate")

  end
end

function main()
  local products = genericConverter:cook()
  if products then
    for k,v in pairs(products) do
      storage.products[k] = storage.products[k] + v
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
  return self.liquidMap[identifier] ~= nil
end
