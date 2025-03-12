local food = starPounds.module:new("food")

function food:init()
  self.cache = copy(self.data.cache)
end

function food:getFatValue(itemName)
  if self.cache[itemName] then
    return self.cache[itemName]
  end

  local itemConfig = root.itemConfig(itemName)
  if not itemConfig then return 0 end

  if itemConfig.config.fatValue then
    self.cache[itemName] = itemConfig.config.fatValue
    return itemConfig.config.fatValue
  end

  local fatValue = 0
  local recipes = root.recipesForItem(itemName)
  for _, recipe in ipairs(recipes) do
    for _, input in ipairs(recipe.input) do
      local inputFatValue = self:getFatValue(input.name)
      if inputFatValue > 0 then
        fatValue = fatValue + (input.count * inputFatValue) / (recipe.output.count or 1)
      end
    end
  end

  self.cache[itemName] = fatValue
  return fatValue
end


starPounds.modules.food = food
