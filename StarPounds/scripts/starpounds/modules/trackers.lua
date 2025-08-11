local trackers = starPounds.module:new("trackers")

function trackers:init()
  self.thresholds = starPounds.settings.thresholds.strain
  -- Just incase this gets used on an init.
  starPounds.progress = 0
end

function trackers:update(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Progress to next stage.
  local currentSizeWeight = starPounds.currentSize.weight
  local nextSizeWeight = starPounds.sizes[starPounds.currentSizeIndex + 1] and starPounds.sizes[starPounds.currentSizeIndex + 1].weight or starPounds.settings.maxWeight
  if nextSizeWeight ~= starPounds.settings.maxWeight and starPounds.sizes[starPounds.currentSizeIndex + 1].yOffset and starPounds.hasOption("disableSupersize") then
    nextSizeWeight = starPounds.settings.maxWeight
  end
  starPounds.progress = math.round((storage.starPounds.weight - currentSizeWeight)/(nextSizeWeight - currentSizeWeight) * 100)
  -- Don't create if we can't add statuses anyway.
  if status.statPositive("statusImmunity") then return end
  -- Don't create if we're eaten.
  if storage.starPounds.pred then return end
  -- Check if statuses don't exist.
  if not (starPounds.hasOption("disableStomachMeter") or starPounds.hasOption("legacyMode")) then
    local stomachTracker = self:getStomachTracker()
    if not status.uniqueStatusEffectActive(stomachTracker) then
      self:createStatuses()
      return
    end
  end
  -- Size status.
  if not starPounds.hasOption("disableSizeMeter") then
    if not status.uniqueStatusEffectActive("starpounds"..starPounds.currentSize.size) then
      self:createStatuses()
      return
    end
  end
  -- Tiddy status.
  if starPounds.hasOption("breastMeter") then
    if not status.uniqueStatusEffectActive("starpoundsbreast") then
      self:createStatuses()
      return
    end
  end
end

function trackers:uninit()
  self:clearStatuses()
end

function trackers:createStatuses()
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  local stomachTracker = self:getStomachTracker()
  local sizeTracker = "starpounds"..starPounds.currentSize.size
  -- Removing them just puts them back in order (Size tracker before stomach tracker)
  self:clearStatuses()
  if not starPounds.hasOption("disableSizeMeter") then
    status.addEphemeralEffect(sizeTracker)
  end
  if not (starPounds.hasOption("disableStomachMeter") or starPounds.hasOption("legacyMode")) then
    status.addEphemeralEffect(stomachTracker)
  end
  if starPounds.hasOption("breastMeter") then
    status.addEphemeralEffect("starpoundsbreast")
  end
end

function trackers:clearStatuses()
  local stomachTracker = self:getStomachTracker()
  local sizeTracker = "starpounds"..starPounds.currentSize.size
  status.removeEphemeralEffect(stomachTracker)
  status.removeEphemeralEffect(sizeTracker)
  status.removeEphemeralEffect("starpoundsbreast")
  world.sendEntityMessage(entity.id(), "starPounds.expireSizeTracker")
end

function trackers:getStomachTracker()
  local stomachTracker = "starpoundsstomach"
  if starPounds.stomach.interpolatedFullness >= self.thresholds.starpoundsstomach2 then
    stomachTracker = "starpoundsstomach3"
  elseif starPounds.stomach.interpolatedFullness >= self.thresholds.starpoundsstomach then
    stomachTracker = "starpoundsstomach2"
  end
  return stomachTracker
end

starPounds.modules.trackers = trackers
