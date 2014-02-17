require 'busted'
require 'genericConverter'

entity = { dt = function () return 1 end }

describe("genericConverter", function()
	it("exists", function()
		assert.is.truthy(genericConverter)
	end)
	it("converts products from ingredients", function()
		local ingredients = { 
				a = { name = "a", count = 2}, 
				g = { name = "g", count = 4},
				i = { name = "i", count = 50}
			}
		genericConverter.conversions = { 
				a = {requirement = 2, count = 1, name = "b", byProduct = "c", byProductQty = 3},
				g = {requirement = 5, count = 1, name = "h"},
				i = {requirement = 20, count = 101, name = "j"}
			}
		genericConverter.storageLimits = { j = 100}
		describe("checking ingredients", function()
			it("flattens ingredients", function()
				local flatstuff = genericConverter.flattenIngredients({ingredients})
				assert.is.truthy(flatstuff and flatstuff["a"])
			end)
			it("gets empty product if there are no ingredients", function()
				local products = genericConverter.product({})
				assert.are.equal(genericConverter.emptyProduct, products)
			end)
			it("gets potential products", function()
				local products = genericConverter.product(ingredients)
				assert.is.truthy(products and products["a"])
			end)
			it("returns false if products cannot be made", function()
				assert.is_not.truthy(genericConverter.canCook({}))
			end)
			it("returns true if products can be made", function()
				assert.is.truthy(genericConverter.canCook({},ingredients))
			end)
		end)
		describe("storageLimits", function()
			it("does not allow products that can't be stored", function()
				local products = genericConverter.product(ingredients)
				assert.is.truthy(products and not products["i"])
			end)
		end)
		local updated = genericConverter.cook(ingredients)
		it("updates ingredients", function()
			assert.is.truthy(updated and updated["a"])
			assert.are.equal(0, updated["a"].count)
		end)
		it("udpates products", function()
			assert.is.truthy(updated and updated["b"])
			assert.are.equal(1, updated["b"].count)
		end)
		it("updates byProducts", function()
			assert.is.truthy(updated and updated["c"])
			assert.are.equal(3, updated["c"].count)
		end)
		it("does not convert if requirment not met", function()
			assert.is.truthy(updated and not updated["h"])
		end)
		describe("reductions", function()
			genericConverter.conversions["d"] = {requirement = 1, count = -1, name = "e"}
			local ingredients = {}
			ingredients["e"] = {name = "e", count = 2}
			ingredients["d"] = {name = "d", count = 2}
			it("reduces other ingredients", function()
				local updated = genericConverter.cook(ingredients)
				assert.is.truthy(updated and updated["e"])
				assert.are.equal(1, updated["e"].count)
				it("does not have side effects", function()
					assert.are.equal(2, ingredients["e"].count)
				end)
			end)
		end)
		describe("cooking", function()
			it("uses the timer", function()
				genericConverter.cookRate = 10
				genericConverter.resetTimer()
				local updated = genericConverter.cook(ingredients)
				assert.is.truthy(updated)
				assert.are.equal(0, getn(updated))
				it("and cooks when timer rate is up", function()
					genericConverter.cookRate = 1
					local updated = genericConverter.cook(ingredients)
					assert.is.truthy(updated and getn(updated) > 0)
					it("resets the timer if it finished", function()
						assert.is.truthy(not genericConverter.cookTimerFinished())
					end)
				end)
			end)
		end)
	end)
end)