
genericConverter = {}

genericConverter.liquidMap = {}
genericConverter.liquidMap["water"] = 1
genericConverter.liquidMap["lava"] = 3
genericConverter.liquidMap["poison"] = 4
genericConverter.liquidMap["juice"] = 6
genericConverter.liquidMap["tar"] = 7

genericConverter.liquidMap[1] = "water"
genericConverter.liquidMap[3] = "lava"
genericConverter.liquidMap[4] = "poison"
genericConverter.liquidMap[6] = "juice"
genericConverter.liquidMap[7] = "tar"

    --upcoming liquids
    --self.liquidMap["hotPitch"] = -1 -- made from boiler and also output by pyrolyzer (later)
    --self.liquidMap["gaseousWoodAlcohol"] = -1 -- byproduct from pyrolyzing wood
    --self.liquidMap["woodAlcohol"] = -1 -- made in a condenser by processing gaseousWoodAlcohol
    --self.liquidMap["bitumen"] = -1 -- made by pyrolyzing tar blocks... product will be asphalt
    --self.liquidMap["synbit"] = -1 -- made by pyrolyzing tar when there is wood alcohol in pyrolyzer tank
    --self.liquidMap["sourWater"] = -1 -- made in coker, from adding water to hot pitch/tar
    --self.liquidMap["wetCoke"] = -1 -- product from coker... separates into sour water and needle coke in a pneumatic pump
    --self.liquidMap["pretrol"] = -1 -- byproduct from coker and the mixture of water and hot pitch


function genericConverter.config( configFctn )
	genericConverter.cookTimer = 0

	genericConverter.cookRate = configFctn("cookRate")
	genericConverter.conversions = configFctn("conversions")
end

function genericConverter.resetTimer()
  genericConverter.cookTimer = 0
end

function genericConverter.cookTimerFinished()
  return genericConverter.cookTimer >= genericConverter.cookRate
end

function genericConverter.updateTimer(timeDelta)
  if not genericConverter.cookTimerFinished() then
    genericConverter.cookTimer = genericConverter.cookTimer + timeDelta
  end
end
