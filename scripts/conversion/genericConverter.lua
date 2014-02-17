
genericConverter = {}

genericConverter.emptyProduct = {requirement = -1,  count = -1, name = "empty", byProduct = "nil", byProductQty = -1}

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
--genericConverter.liquidMap["hotPitch"] = -1 -- made from boiler and also output by pyrolyzer (later)
--genericConverter.liquidMap["gaseousWoodAlcohol"] = -1 -- byProduct from pyrolyzing wood
--genericConverter.liquidMap["woodAlcohol"] = -1 -- made in a condenser by processing gaseousWoodAlcohol
--genericConverter.liquidMap["bitumen"] = -1 -- made by pyrolyzing tar blocks... product will be asphalt
--genericConverter.liquidMap["synbit"] = -1 -- made by pyrolyzing tar when there is wood alcohol in pyrolyzer tank
genericConverter.liquidMap["sourCoke"] = -1 -- after heating tar, cokes are mixed with byproducts. this can only be cleaned with water
genericConverter.liquidMap["sourWater"] = -1 -- made in coker, from adding water to hot pitch/tar
genericConverter.liquidMap["wetCoke"] = -1 -- product from coker... separates into sour water and needle coke in a pneumatic pump
genericConverter.liquidMap["crude"] = -1 -- product from coker ... tar reduces to crude

getn = getn or function ( map )
	local result = 0
	for _,_ in pairs(map) do
		result = result + 1
	end
	return result
end

function genericConverter.config( configFctn )
	genericConverter.cookTimer = 0

	genericConverter.cookRate = configFctn("cookRate")
	genericConverter.conversions = configFctn("conversions") or {}
	genericConverter.productIngredients = configFctn("productIngredients") or {}
	genericConverter.storageLimits = configFctn("storageLimits") or {}

end

function genericConverter.statusMessage( ingredients )
	local result = "Status: \n"
	if ingredients then
		if ingredients.name then
			result = result .. "Trying to convert "..ingredients.name..".\n"
		else
			result = result .. "Trying to convert { "
			for k,v in pairs(ingredients) do
				result = result .. " " .. (v.name or k) .. " : " .. (v.count or v) .. " ,  "
			end
			result = result .. " } \n"
		end
		result = result .. genericConverter.conversionStatus(ingredients)
	else
		result = result .. "There are no ingredients to convert.\n"
	end
	result = result .. "There are "..getn(genericConverter.conversions).." conversions that I know of."
	return result
end

function genericConverter.conversionStatus( ingredients )
	local result = ""
	if ingredients.name then
		if genericConverter.canConvert(ingredients) then
			local conversion = genericConverter.convert(ingredients)
			result = result .. "I can convert this into "..conversion.name.."\n"..
				"with a byProduct of "..conversion.byProduct..".\n"..
				"This requires "..conversion.requirement.." of "..ingredients.name..".\n"
		else
			result = result .. "I cannot find a conversion for this. "
		end
	else
		result = result .. "I'm not sure how to status multiple ingredients yet. "
	end
	return result
end

function genericConverter.resetTimer()
  genericConverter.cookTimer = 0
end

function genericConverter.cookTimerFinished()
	if not genericConverter.cookTimer then genericConverter.resetTimer() end
  return not genericConverter.cookRate or genericConverter.cookTimer >= genericConverter.cookRate
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
  		if genericConverter.canConvert(ingredient, ingredients) then
  			result[ingredient.name] = genericConverter.convert(ingredient)
  			haveResults = true
  		end
  	end
  	return haveResults and result or genericConverter.emptyProduct
  end
end

function genericConverter.productNotEmpty( ingredients )
	return genericConverter.product(ingredients).byProduct ~= genericConverter.emptyProduct
end

function genericConverter.convert( item )
	if item.name then
		return genericConverter.conversions[item.name]
	else
		return genericConverter.conversions[item]
	end
end

function genericConverter.canConvert( item, ingredients )
	local conversion = genericConverter.convert(item)
	if conversion and not genericConverter.roomFor(conversion, ingredients) then
		return false
	end
	if ingredients and conversion and genericConverter.isReduction(conversion) then
		return genericConverter.canReduce(conversion, ingredients)
	else
		return conversion ~= nil and conversion.count > 0 and conversion.requirement <= item.count
	end
end

function genericConverter.roomFor( conversion, ingredients )
	local limits = genericConverter.storageLimits
	local productLimit, byProductLimit = limits[conversion.name], limits[conversion.byProduct]
	if productLimit then
		local stored = ingredients[conversion.name] or { count = 0 }
		if stored.count + conversion.count > productLimit then return false end
	end
	if byProductLimit then
		local stored = ingredients[conversion.byProduct] or { count = 0 }
		if stored.count + conversion.byProductQty > byProductLimit then return false end
	end
	return true
end

function genericConverter.isReduction( conversion )
	return conversion.count < 0 or conversion.byProductQty and conversion.byProductQty < 0
end

function genericConverter.getReducedIngredients( reduction, ingredients )
	local result = {}
	if reduction.count < 0 then
		local reductant = ingredients[reduction.name] or {count = 0}
		result[reduction.name] = reductant.count + reduction.count
	end
	if reduction.byProductQty and reduction.byProductQty < 0 then
		local reductant = ingredients[reduction.byProduct] or {count = 0}
		result[reduction.byProduct] = reductant.count + reduction.byProductQty
	end
	return result
end

function genericConverter.canReduce( reduction, ingredients )
	local reducedIngredients = genericConverter.getReducedIngredients(reduction, ingredients)
	if reducedIngredients then
		for reducedIngredient,reduction in pairs(reducedIngredients) do
			if reduction < 0 then return false end
		end
		return true
	else
		return false
	end
end

function genericConverter.conversionsFilter()
  local pullFilter = {}
  for matitem,conversion in pairs(genericConverter.conversions) do
    pullFilter[matitem] = {conversion.requirement, conversion.requirement}
  end
  return pullFilter
end

function genericConverter.canCook( ... )
	local ingredients = genericConverter.flattenIngredients(table.pack(...))
	local products = genericConverter.product(ingredients)
	return products ~= genericConverter.emptyProduct
end

function genericConverter.cook( ... )
	if not genericConverter.cookTimerFinished() then
		genericConverter.updateTimer(entity.dt())
		return {}
	end
	local ingredients = genericConverter.flattenIngredients(table.pack(...))
	local products = genericConverter.product(ingredients)
	if products ~= genericConverter.emptyProduct then
		genericConverter.resetTimer()
		return genericConverter.productsAndConsumedIngredients(products, ingredients)
	else
		return {}
	end
end

function genericConverter.flattenIngredients( ingredientArrays )
	local result = {}
	for _,itemMap in ipairs(ingredientArrays) do
		for itemName,ingredient in pairs(itemMap or {}) do
			ingredient = ingredient.name and ingredient or {name = itemName, count = ingredient}
  			result[itemName] = {name = ingredient.name, count = ingredient.count}
  		end
	end
	return result
end

function genericConverter.addIngredientUpdate( ingredientUpdates, update )
	if not update.name then return {count = 0} end
	local update = ingredientUpdates[update.name] or update
	ingredientUpdates[update.name] = update
	return update
end

function genericConverter.updateIngredients( ingredientUpdates, ingredient, conversion )
	local updatedIngredient = genericConverter.addIngredientUpdate(ingredientUpdates, ingredient)
	local product = genericConverter.addIngredientUpdate( ingredientUpdates, {name = conversion.name, count = 0})
	local byProduct = genericConverter.addIngredientUpdate( ingredientUpdates, {name = conversion.byProduct, count = 0})
	if genericConverter.canConvert(updatedIngredient, ingredientUpdates) then
		updatedIngredient.count = updatedIngredient.count - math.max(conversion.requirement, 0)
		product.count = product.count + conversion.count
		if conversion.byProductQty then
			byProduct.count = byProduct.count + conversion.byProductQty
		end
	end
	return ingredientUpdates
end

function genericConverter.productsAndConsumedIngredients( products, ingredients )
	local result = ingredients
	for consumedIngredientName,conversion in pairs(products) do
		local ingredient = ingredients[consumedIngredientName]
		result = genericConverter.updateIngredients(result, ingredient, conversion)
	end
	return result
end