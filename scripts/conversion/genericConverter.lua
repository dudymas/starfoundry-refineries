
genericConverter = {}

genericConverter.emptyProduct = {requirement = -1,  count = -1, name = "empty", byproduct = "nil", byproductQty = -1}

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

getn = getn or function ( map )
	local result = 0
	for i,_ in ipairs(map) do
		result = i
	end
	return result
end

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
	genericConverter.conversions = configFctn("conversions") or {}
	genericConverter.productIngredients = configFctn("productIngredients") or {}

	for ingredientName,conversion in pairs(genericConverter.conversions) do
		local productIngredients = genericConverter.productIngredients[conversion.name] or {}
		productIngredients[ingredientName] = conversion.requirement
		genericConverter.productIngredients[conversion.name] = productIngredients
	end
end

function genericConverter.statusMessage( ingredients )
	local result = "Status: \n"
	if ingredients then
		if ingredients.name then
			result = result .. "Trying to convert "..ingredients.name..".\n"
		end
		if genericConverter.canConvert(ingredients) then
			local conversion = genericConverter.convert(ingredients)
			result = result .. "I can convert this into "..conversion.name.."\n"..
				"with a byproduct of "..conversion.byproduct..".\n"..
				"This requires "..conversion.requirement.." of "..ingredients.name..".\n"
		else
			result = result .. "I cannot find a conversion for this."
		end
	else
		result = result .. "There are no ingredients to convert.\n"
	end
	result = result .. "There are "..getn(genericConverter.conversions).." conversions that I know of."
	return result
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

function genericConverter.product( ingredients )
	if not ingredients then
		return genericConverter.emptyProduct
	elseif ingredients.name then
  	return genericConverter.convert(ingredients) or genericConverter.emptyProduct
  else
  	local result = {}
  	local haveResults = false
  	for _,ingredient in pairs(ingredients) do
  		if genericConverter.canConvert(ingredient) then
  			local conversion = genericConverter.convert(ingredient)
  			if conversion.requirement and ingredient.count and conversion.requirement <= ingredient.count then
  				result[conversion.name] = conversion.count
  				haveResults = true
  				return result --only allow one conversion for now.. simultaneous is incoming later
  			end
  		end
  	end
  	return haveResults and result or genericConverter.emptyProduct
  end
end

function genericConverter.productNotEmpty( ingredients )
	return genericConverter.product(ingredients).byproduct ~= genericConverter.emptyProduct
end

function genericConverter.convert( item )
	if item.name then
		return genericConverter.conversions[item.name]
	else
		return genericConverter.conversions[item]
	end
end

function genericConverter.canConvert( item )
	return genericConverter.convert(item) ~= nil
end

function genericConverter.conversionsFilter()
  local pullFilter = {}
  for matitem,conversion in pairs(genericConverter.conversions) do
    pullFilter[matitem] = {conversion.requirement, conversion.requirement}
  end
  return pullFilter
end

function genericConverter.cook( ... )
	local ingredients = genericConverter.flattenIngredients(args)
	local products = genericConverter.product(ingredients)
	if products ~= genericConverter.emptyProduct then
		return genericConverter.productsAndConsumedIngredients(products, ingredients)
	end
end

function genericConverter.flattenIngredients( ingredientArrays )
	local result = {}
	for _,itemMap in ipairs(ingredientArrays) do
		for itemName,ingredient in ipairs(itemMap) do
			ingredient = ingredient.name and ingredient or {name = itemName, count = ingredient}
  		result[ingredientName] = ingredient
		end
	end
	return result
end

function genericConverter.productsAndConsumedIngredients( products, ingredients )
	local result = products
	for productName,amount in pairs(products) do
		local consumedIngredients = genericConverter.productIngredients[productName]
		for ingredientName,amountConsumed in pairs(consumedIngredients) do
			result[ingredientName] = ingredients[ingredientName].count - amountConsumed
		end
	end
	return result
end