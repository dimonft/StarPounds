local sound = starPounds.module:new("sound")

function sound:init()
  if storage.starPounds.enabled then
    status.addEphemeralEffect("starpoundssoundhandler")
  end

  message.setHandler("starPounds.playSound", function(_, _, ...) return self:play(...) end)
  message.setHandler("starPounds.stopSound", function(_, _, ...) return self:stop(...) end)
  message.setHandler("starPounds.setSoundVolume", function(_, _, ...) return self:setVolume(...) end)
  message.setHandler("starPounds.setSoundPitch", function(_, _, ...) return self:setPitch(...) end)
end

function sound:update(dt)
  -- Don't do anything if the mod is disabled.
  if not storage.starPounds.enabled then return end
  -- Don't create if we can't add statuses anyway.
  if status.statPositive("statusImmunity") then return end
  -- Check if status doesn't exist.
  if not status.uniqueStatusEffectActive("starpoundssoundhandler") then
    status.addEphemeralEffect("starpoundssoundhandler")
  end
end

function sound:play(soundPool, volume, pitch, loops)
  self:setVolume(soundPool, volume or 1)
  self:setPitch(soundPool, pitch or 1)

  world.sendEntityMessage(entity.id(), "starPounds.handler_playSound", soundPool, loops)
end

function sound:stop(soundPool)
  world.sendEntityMessage(entity.id(), "starPounds.handler_stopSound", soundPool)
end

function sound:setVolume(soundPool, volume, rampTime)
  world.sendEntityMessage(entity.id(), "starPounds.handler_setSoundVolume", soundPool, volume, rampTime)
end

function sound:setPitch(soundPool, pitch, rampTime)
  world.sendEntityMessage(entity.id(), "starPounds.handler_setSoundPitch", soundPool, pitch, rampTime)
end

starPounds.modules.sound = sound
