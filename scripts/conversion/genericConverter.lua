
genericConverter = {}

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
