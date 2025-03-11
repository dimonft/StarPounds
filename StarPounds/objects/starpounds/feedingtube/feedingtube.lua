require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"

function init()
  self.gulpDelay = config.getParameter("gulpDelay", 0.8)
  self.gulpTimer = self.gulpDelay
  self.collectTimer = 0
  self.capacity = config.getParameter("capacity", 1000)
  self.maxWeight = root.assetJson("/scripts/starpounds/starpounds.config:settings.maxWeight")
  self.liquids = root.assetJson("/scripts/starpounds/modules/liquid.config:liquids")
  self.pickupBounds = rect.pad(object.boundBox(), -1)

  self.statusBlacklist = {
    "wet", "swimming", "slimeslow", "tarslow",
    "starpoundschocolateslow", "starpoundshoneyslow", "caloriumliquid"
  }

  local liquidName, liquidAmount = table.unpack(config.getParameter("defaultLiquid", jarray()))
  if liquidName then
    defaultLiquid = {
      name = liquidName,
      statusEffects = root.liquidConfig(liquidName).config.statusEffects or jarray(),
      item = root.liquidConfig(liquidName).config.itemDrop
    }
  end

  object.setConfigParameter("defaultLiquid", nil)

  storage = sb.jsonMerge({
    liquid = defaultLiquid,
    amount = liquidAmount or 0,
  }, storage)

  if storage.liquid then
    setLiquidType(storage.liquid.name)
  end

  self.liquidLevel = storage.amount
  animator.setGlobalTag("liquidLevel", math.max(0, math.min(math.ceil(self.liquidLevel * 39/self.capacity), 39)))
end

function update(dt)
  promises:update()
  -- Player/NPC detection. Resets the target if nobody lounging.
  if self.feedTarget and not self.startedLounging then
    if not world.loungeableOccupied(entity.id()) then
      self.feedTarget = nil
    end
  else
    self.startedLounging = false
  end
  -- Main loop.
  if self.feedTarget then
    if canFeed() then
      if animator.animationState("feedState") == "default" then
        -- Remove stored liquid.
        storage.amount = math.max(0, storage.amount - 1)
        -- Give food.
        for foodType, foodAmount in pairs(self.liquids[storage.liquid.name] or self.liquids.default) do
          world.sendEntityMessage(self.feedTarget, "starPounds.feed", foodAmount, foodType)
        end
        -- Give status effects.
        for _, statusEffect in pairs(storage.liquid.statusEffects) do
          if not contains(self.statusBlacklist, statusEffect) then
            world.sendEntityMessage(self.feedTarget, "applyStatusEffect", statusEffect)
          end
        end
        -- Prevent belches, and spawn drinking particles.
        world.sendEntityMessage(self.feedTarget, "starPounds.spawnDrinkingParticles", {storage.liquid.name, 1})
        world.sendEntityMessage(self.feedTarget, "applyStatusEffect", "starpoundsdrinking")
        -- Play sound.
        animator.playSound("drink")
        -- Reset delay.
        self.gulpTimer = self.gulpDelay
        -- Connected to mouth, animated.
        animator.setAnimationState("feedState", "feeding")
      end
    else
      self.gulpTimer = self.gulpDelay
      -- Make NPCs hop off when empty.
      if world.entityType(self.feedTarget ) == "npc" then
        world.callScriptedEntity(self.feedTarget, "status.setResource", "stunned", 0)
        world.callScriptedEntity(self.feedTarget, "mcontroller.resetAnchorState")
      end
      -- Connected to mouth, static.
      animator.setAnimationState("feedState", "default")
    end
  else
    -- Disconnected.
    animator.setAnimationState("feedState", "idle")
  end
  -- Reset the liquid if we're empty.
  if storage.amount <= 0 then
    setLiquidType()
  end
  -- Set the displayed liquid amount.
  self.liquidLevel = math.round(util.lerp(dt * 2, self.liquidLevel, storage.amount), 4)
  animator.setGlobalTag("liquidLevel", math.max(0, math.min(math.ceil(self.liquidLevel * 39/self.capacity), 39)))
  -- Grab nearby liquid items.
  self.collectTimer = math.max(self.collectTimer - dt, 0)
  if self.collectTimer == 0 then
    collectLiquid()
    self.collectTimer = 1
  end
end

function canFeed()
  return storage.amount > 0
end

function onInteraction(args)
  if not world.loungeableOccupied(entity.id()) then
    self.feedTarget = args.sourceId
    self.startedLounging = true
    -- Connect.
    animator.setAnimationState("feedState", canFeed() and "feeding" or "default")
  end
end

function onNpcPlay(npcId)
  onInteraction({sourceId = npcId})
  if self.feedTarget == npcId then
    world.callScriptedEntity(npcId, "lounge", {entity = entity.id()})
    world.callScriptedEntity(npcId, "mcontroller.clearControls")
    world.callScriptedEntity(npcId, "status.setResource", "stunned", math.random(5, 30))
  end
end

function die()
  if storage.liquid then
    world.spawnItem(storage.liquid.item, entity.position(), storage.amount)
  end
end

function collectLiquid()
  if storage.amount < self.capacity then
    local items = world.itemDropQuery(rect.ll(self.pickupBounds), rect.ur(self.pickupBounds))
    for _, itemId in pairs(items) do
      local item = world.itemDropItem(itemId)
      if root.itemType(item.name) == "liquid" then
        local liquidName = root.itemConfig(item.name).config.liquid
        if not storage.liquid or liquidName == storage.liquid.name then
          local itemDrop = world.takeItemDrop(itemId, entity.id())
          if itemDrop then
            storage.liquid = {
              name = liquidName,
              statusEffects = root.liquidConfig(liquidName).config.statusEffects or jarray(),
              item = item.name
            }
            storage.amount = storage.amount + itemDrop.count
            setLiquidType(liquidName)
            if storage.amount > self.capacity then
              local excess = storage.amount - self.capacity
              world.spawnItem(storage.liquid.item, entity.position(), excess)
              storage.amount = self.capacity
            end
          end
        end
      end
    end
  end
end

function setLiquidType(liquidName)
  if liquidName then
    local liquidConfig = root.liquidConfig(liquidName).config
    local rgb = liquidConfig.color
    animator.setGlobalTag("liquidImage", string.format("%s?multiply=%s", liquidConfig.texture, string.format("%02X%02X%02X%02X", rgb[1], rgb[2], rgb[3], rgb[4])))
    object.setLightColor(liquidConfig.radiantLight or {0, 0, 0})
  else
    storage.liquid = nil
    animator.setGlobalTag("liquidImage", "")
    object.setLightColor({0, 0, 0})
  end
end

function math.round(num, numDecimalPlaces)
  local format = string.format("%%.%df", numDecimalPlaces or 0)
  return tonumber(string.format(format, num))
end
