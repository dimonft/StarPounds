local size = starPounds.module:new("size")

function size:init()
  local function nullFunction() end
  -- Kinda gross, but deal with it.
  local speciesData = {}
  if starPounds.type == "player" then
    self.setEquippedItem = player.setEquippedItem
    self.equippedItem = player.equippedItem
    self.giveItem = player.giveItem
    speciesData = starPounds.getSpeciesData(player.species())
  elseif starPounds.type == "npc" then
    self.setEquippedItem = npc.setItemSlot
    self.equippedItem = npc.getItemSlot
    self.giveItem = nullFunction
    speciesData = starPounds.getSpeciesData(npc.species())
  elseif starPounds.type == "monster" then
    self.setEquippedItem = nullFunction
    self.equippedItem = nullFunction
    self.giveItem = nullFunction
  end

  self.canGain = speciesData.weightGain

  -- Fetch the first supersize index for future use.
  self.supersizeIndex = math.huge
  for i, size in ipairs(starPounds.sizes) do
    if size.yOffset then
      self.supersizeIndex = math.min(self.supersizeIndex, i)
    end
  end

  message.setHandler("starPounds.getSize", function(_, _, ...) return self:get(...) end)
  message.setHandler("starPounds.getChestVariant", function(_, _, ...) return self:getVariant(...) end)
end

function size:update(dt)
  starPounds.currentSize, starPounds.currentSizeIndex = self:get(storage.starPounds.weight)
  starPounds.currentVariant = self:getVariant(starPounds.currentSize)
  starPounds.weight = storage.starPounds.weight
  starPounds.weightMultiplier = storage.starPounds.enabled and math.round(1 + (storage.starPounds.weight/entity.weight), 1) or 1

  if starPounds.currentSizeIndex ~= self.oldSizeIndex then
    starPounds.events:fire("sizes:changed", starPounds.currentSizeIndex - (self.oldSizeIndex or 0))
    -- Force stat update.
    starPounds.events:fire("main:statChange")
    -- Don't play the sound on the first load.
    if self.oldSizeIndex then
      -- Play sound to indicate size change.
      starPounds.moduleFunc("sound", "play", "digest", 0.75, math.random(10,15) * 0.1 - storage.starPounds.weight/(starPounds.settings.maxWeight * 2))
    end
    -- Update status effect tracker.
    starPounds.moduleFunc("trackers", "clearStatuses")
    starPounds.moduleFunc("trackers", "createStatuses")
  elseif starPounds.weightMultiplier ~= self.oldWeightMultiplier then
    starPounds.events:fire("main:statChange")
  end

  self.oldSizeIndex = starPounds.currentSizeIndex
  self.oldWeightMultiplier = starPounds.weightMultiplier

  self:cursorCheck()
  self:trackVehicleCap()
  self:equip(self:equipmentConfig(starPounds.currentSizeIndex))
end

function size:get(weight)
  -- Default to base size if the mod is off.
  if not (storage.starPounds.enabled and self.canGain) then
    return starPounds.sizes[1], 1
  end
  -- Argument sanitisation.
  weight = math.max(tonumber(weight) or 0, 0)

  local sizeIndex = 0
  -- Go through all starPounds.sizes (smallest to largest) to find which size.
  for i in ipairs(starPounds.sizes) do
    -- Disable supersized stages with options, or on the tech missions so you can actually complete them.
    local supersizeDisabled = starPounds.hasOption("disableSupersize") or status.uniqueStatusEffectActive("starpoundstechmissionmobility")
    local skipSize = starPounds.sizes[i].yOffset and supersizeDisabled
    if weight >= starPounds.sizes[i].weight and not skipSize then
      sizeIndex = i
    end
  end

  return starPounds.sizes[sizeIndex], sizeIndex
end

function size:getVariant(size)
  -- Don't do anything if the mod is disabled.
  if not (storage.starPounds.enabled and self.canGain) then return "" end
  -- Argument sanitisation.
  local size = type(size) == "table" and size or {}
  local variants = size.variants or jarray()
  local variant = nil
  local thresholdMultiplier = starPounds.currentSize.thresholdMultiplier
  local breastThresholds = starPounds.settings.thresholds.breasts
  local stomachThresholds = starPounds.settings.thresholds.stomach

  local breastSize = (starPounds.hasOption("disableBreastGrowth") and 0 or (starPounds.moduleFunc("breasts", "get").contents or 0)) + (
    starPounds.hasOption("busty") and breastThresholds[1].amount * thresholdMultiplier or (
    starPounds.hasOption("milky") and breastThresholds[2].amount * thresholdMultiplier or 0)
  )

  local stomachSize = (starPounds.hasOption("disableStomachGrowth") and 0 or (starPounds.moduleFunc("stomach", "get").interpolatedContents or 0)) + (
    starPounds.hasOption("stuffed") and stomachThresholds[2].amount * thresholdMultiplier or (
    starPounds.hasOption("filled") and stomachThresholds[4].amount * thresholdMultiplier or (
    starPounds.hasOption("gorged") and stomachThresholds[6].amount * thresholdMultiplier or 0))
  )

  for _, v in ipairs(breastThresholds) do
    if contains(variants, v.name) then
      if breastSize >= (v.amount * thresholdMultiplier) then
        variant = v.name
      end
    end
  end

  for _, v in ipairs(stomachThresholds) do
    if contains(variants, v.name) then
      if stomachSize >= (v.amount * thresholdMultiplier) then
        variant = v.name
      end
    end
  end

  if starPounds.hasOption("hyper") then
    variant = "hyper"
  end

  return variant
end

function size:equipmentConfig(sizeIndex)
  if not (storage.starPounds.enabled and self.canGain) then
    return {
      chest = "",
      legs = "",
      chestVariant = ""
    }
  end
  -- Size cap based on occupied vehicle. Uses math.huge by default because
  -- math.min doesn't ignore nils and I'd rather not do 10 more if statements.
  local vehicleCap = self.vehicleCap or math.huge
  -- These can be independent based on options.
  local chestIndex = math.min(sizeIndex, vehicleCap)
  local legsIndex = math.min(sizeIndex, vehicleCap)

  -- Don't do this for supersized stages.
  if not starPounds.sizes[sizeIndex].yOffset then
    -- Calculate the 'target' size based on options and vehicle caps.
    for option, amount in pairs(self.data.sizeOptions.chest) do
      if starPounds.hasOption(option) then
        chestIndex = math.min(math.max(sizeIndex + amount), self.supersizeIndex - 1, vehicleCap)
      end
    end
    -- Same for legs.
    for option, amount in pairs(self.data.sizeOptions.legs) do
      if starPounds.hasOption(option) then
        legsIndex = math.min(math.max(sizeIndex + amount), self.supersizeIndex - 1, vehicleCap)
      end
    end
  end
  -- Variant based on the 'adjusted' chest size.
  local chestVariant = self:getVariant(starPounds.sizes[chestIndex])

  return {
    chest = starPounds.sizes[chestIndex].size,
    legs = starPounds.sizes[legsIndex].size,
    chestVariant = chestVariant
  }
end

function size:equip(equipConfig)
  if not self.canGain then return end
  -- Immobile sizes looks like blob with the mobility skill.
  if starPounds.hasSkill("preventImmobile") then
    if equipConfig.chest == "immobile" then
      equipConfig.chest = "blob"
      equipConfig.legs = "blob"
    end
  end
  -- Only play the rip sound once per unequip.
  local playedSound
  -- Shorthand instead of 2 blocks.
  for _, itemType in ipairs({"legs", "chest"}) do
    local slot = itemType.."Cosmetic"
    local item = self.equippedItem(slot)
    -- If we have a generated item, check if it's invalid.
    if item and item.parameters.size then
      local variant = equipConfig[itemType.."Variant"] or ""
      if item.parameters.size ~= (equipConfig[itemType]..variant) then
        self.setEquippedItem(itemType.."Cosmetic", size:makeSizeItem(itemType, equipConfig))
      end
    -- If the item is not generated, try to update it. Otherwise, give it back and remove it.
    elseif item and not item.parameters.size then
      -- Item only needs to be updated if we're at base size and it has a size tag, or the size tag does not match our current size.
      local needsUpdate = (equipConfig[itemType] == "" and item.parameters.tempSize) or ((equipConfig[itemType] ~= "") and (equipConfig[itemType] ~= item.parameters.tempSize))
      if needsUpdate then
        local updatedItem, canUpdate = self:updateClothing(item, itemType, equipConfig)
        if canUpdate then
          self.setEquippedItem(slot, updatedItem)
        else
          self.setEquippedItem(slot)
          self.giveItem(updatedItem)
          item = nil
          -- Play clothing rip sound.
          if not playedSound then
            starPounds.moduleFunc("sound", "play", "clothingrip", 0.75)
            playedSound = true
          end
        end
      end
    -- Otherwise, apply the base item.
    elseif not item then
      local variant = equipConfig[itemType.."Variant"] or ""
      if (equipConfig[itemType]..variant) ~= "" then
        self.setEquippedItem(itemType.."Cosmetic", size:makeSizeItem(itemType, equipConfig))
      end
    end
  end
end

function size:makeSizeItem(itemType, equipConfig)
  if not self.canGain then return end
  -- Get entity species.
  local species = starPounds.getVisualSpecies()
  -- Get entity directives
  local directives = starPounds.getDirectives()
  -- Get the variant if necessary.
  local variant = equipConfig[itemType.."Variant"] or ""
  -- Return nothing if we're base size with no variant.
  if (equipConfig[itemType]..variant) == "" then
    return
  end
  -- Generate the item.
  return {
    name = string.format("%s%s%s%s", equipConfig[itemType], variant, species:lower(), itemType),
    parameters = { directives = directives, price = 0, size = equipConfig[itemType]..variant, rarity = "essential" },
    count = 1
  }
end

function size:updateClothing(item, itemType, equipConfig)
  -- Just restore the item back at base size.
  if equipConfig[itemType] == "" then
    return self:restoreClothing(item), true
  end

  local itemName = item.parameters.baseName or item.name
  local newItemName = equipConfig[itemType]..itemName
  if pcall(root.itemType, newItemName) then
    -- If found, give the new item some parameters for easier checking.
    item.parameters.baseName = itemName
    item.parameters.tempSize = equipConfig[itemType]
    item.name = newItemName
    return item, true
  end
  -- Return the old, restored item if a new one could not be found.
  return self:restoreClothing(item), false
end

function size:restoreClothing(item)
  -- Only run if it's actually a scaled up piece.
  if item.parameters.tempSize and item.parameters.baseName then
    -- Restore the original item.
    item = {
      name = item.parameters.baseName,
      parameters = item.parameters,
      count = item.count
    }
    item.parameters.tempSize = nil
    item.parameters.baseName = nil
    return item
  end
  -- Return the old one if we don't need to do anything.
  return item
end

function size:trackVehicleCap()
  -- Reset if the mod is disabled.
  if not (storage.starPounds.enabled and self.canGain) then self.anchored = nil return end
  local anchored = starPounds.mcontroller.anchorState
  if self.anchored ~= anchored then
    local anchorEntity = anchored and world.entityName(anchored) or nil
    self.vehicleCap = anchorEntity and self.data.vehicleCap[anchorEntity] or nil
  end
  self.anchored = anchored
end

function size:cursorCheck()
  -- Return if not a player.
  if not starPounds.type == "player" then return end
  -- Check the item the player is holding.
  if starPounds.swapSlotItem then
    local item = starPounds.swapSlotItem
    item.parameters = item.parameters or {}
    -- Delete base size items.
    if starPounds.swapSlotItem.parameters.size then
      player.setSwapSlotItem(nil)
      return
    end
    -- Restore scaled up clothing items.
    if item.parameters.tempSize and item.parameters.baseName then
      item = self:restoreClothing(item)
      player.setSwapSlotItem(item)
    end
  end
end

starPounds.modules.size = size
