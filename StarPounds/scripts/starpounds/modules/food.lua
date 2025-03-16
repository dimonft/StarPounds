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
    local recipeFatValue = 0

    for _, input in ipairs(recipe.input) do
      local inputFatValue = self:getFatValue(input.name)
      if inputFatValue > 0 then
        recipeFatValue = recipeFatValue + (input.count * inputFatValue) / (recipe.output.count or 1)
      end
    end

    fatValue = math.max(fatValue, recipeFatValue)
  end

  self.cache[itemName] = fatValue
  return fatValue
end

function food:updateItem(item)
  local foodValue = configParameter(item, "foodValue", 0)
  local fatValue = configParameter(item, "fatValue", starPounds.moduleFunc("food", "getFatValue", item.name))

  if not configParameter(item, "starpounds_effectApplied", false) then
    local effects = configParameter(item, "effects", jarray())

    if not effects[1] then
      table.insert(effects, jarray())
    end
    -- Get the specific food type for the item category.
    local category = configParameter(item, "category", ""):lower()
    local foodType = self.data.categoryTypes[category:lower()] or self.data.categoryTypes.food
    -- Add food.
    if foodValue > 0 then
      table.insert(effects[1], { effect = foodType.food..(disableExperience and "_noexperience" or ""), duration = foodValue })
    end
    -- Add fat.
    if foodValue > 0 then
      table.insert(effects[1], { effect = foodType.fat, duration = fatValue })
    end
    -- Add experience.
    local rarity = configParameter(item, "rarity", "common"):lower()
    local disableExperience = configParameter(item, "starpounds_disableExperience", false)
    if (foodValue > 0) and self.data.experienceBonus[rarity] and not disableExperience then
      bonusExperience = foodValue * self.data.experienceBonus[rarity]
      table.insert(effects[1], { effect = "starpoundsfood_bonusexperience", duration = bonusExperience })
    end

    item.parameters.starpounds_effectApplied = true
    item.parameters.effects = effects
    item.parameters.starpounds_foodValue = foodValue
    item.parameters.foodValue = 0

    return item
  end
  return false
end


starPounds.modules.food = food
