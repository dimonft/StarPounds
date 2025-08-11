local sound = starPounds.module:new("sound")

function sound:init()
  message.setHandler("starPounds.playSound", function(_, _, ...) return self:play(...) end)
  message.setHandler("starPounds.stopSound", function(_, _, ...) return self:stop(...) end)
  message.setHandler("starPounds.setSoundVolume", function(_, _, ...) return self:setVolume(...) end)
  message.setHandler("starPounds.setSoundPitch", function(_, _, ...) return self:setPitch(...) end)

  if storage.starPounds.enabled then
    status.addEphemeralEffect("starpoundssoundhandler")
  end

  self.secret = false
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

  local secret = starPounds.moduleFunc("skills", "has", "secret")
  if self.secret ~= secret then
    self.secret = secret
    -- Refesh sound pools.
    if not secret then
      status.removeEphemeralEffect("starpoundssoundhandler")
    end
  end
end

function sound:play(soundPool, volume, pitch, loops)
  -- No sound with the option.
  if starPounds.hasOption("disableSound") then return end

  self:setVolume(soundPool, volume)
  self:setPitch(soundPool, pitch)
  -- Hehe.
  if self.secret then
    world.sendEntityMessage(entity.id(), "starPounds.handler_setSoundPool", soundPool, {"/sfx/starpounds/other/secret.ogg"})
  end

  world.sendEntityMessage(entity.id(), "starPounds.handler_playSound", soundPool, loops)
end

function sound:stop(soundPool)
  world.sendEntityMessage(entity.id(), "starPounds.handler_stopSound", soundPool)
end

function sound:setVolume(soundPool, volume, rampTime)
  volume = util.clamp(tonumber(volume) or 1, 0, self.data.maxVolume)
  -- Secret volume should be a bit quieter.
  if self.secret then
    volume = (volume + 0.35) * 0.5
  end
  -- Quiet sound option.
  if starPounds.hasOption("quietSounds") then
    volume = volume * 0.5
  end

  world.sendEntityMessage(entity.id(), "starPounds.handler_setSoundVolume", soundPool, volume, rampTime)
end

function sound:setPitch(soundPool, pitch, rampTime)
  pitch = util.clamp(tonumber(pitch) or 1, self.data.minPitch, self.data.maxPitch)

  world.sendEntityMessage(entity.id(), "starPounds.handler_setSoundPitch", soundPool, pitch, rampTime)
end

starPounds.modules.sound = sound
