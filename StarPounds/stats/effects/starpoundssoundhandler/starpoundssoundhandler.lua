require "/scripts/messageutil.lua"

function init()
  message.setHandler("starPounds.handler_playSound", localHandler(playSound))
  message.setHandler("starPounds.handler_stopSound", localHandler(animator.stopAllSounds))
  message.setHandler("starPounds.handler_setSoundVolume", localHandler(setSoundVolume))
  message.setHandler("starPounds.handler_setSoundPitch", localHandler(setSoundPitch))
  message.setHandler("starPounds.expire", localHandler(effect.expire))
end

function update(dt)
  effect.modifyDuration(dt)
  -- Secret c:
  local starPounds = getmetatable ''.starPounds
  if secret and not starPounds.moduleFunc("skills", "has", "secret") then
    effect.expire()
  end
  if starPounds and not secret then
    secret = starPounds.moduleFunc("skills", "has", "secret")
  end
end

function playSound(soundPool, loops)
  local starPounds = getmetatable ''.starPounds
  if starPounds and starPounds.hasOption("disableSound") then return end
  if secret then
    animator.setSoundPool(soundPool, {"/sfx/starpounds/other/secret.ogg"})
  end
  animator.playSound(soundPool, loops)
end

function setSoundVolume(soundPool, volume, rampTime)
  local starPounds = getmetatable ''.starPounds
  if starPounds then
    if secret then
      volume = (volume + 0.35) * 0.5
    end
    if starPounds.hasOption("quietSounds") then
      volume = volume * 0.5
    end
  end

  animator.setSoundVolume(soundPool, volume, rampTime)
end

function setSoundPitch(soundPool, pitch, rampTime)
  local starPounds = getmetatable ''.starPounds
  if starPounds then
    -- Belch options.
    if soundPool == "belch" then
      if starPounds.hasOption("disableBelches") then return end
      if starPounds.hasOption("higherBelches") then pitch = pitch * 1.25 end
      if starPounds.hasOption("deeperBelches") then pitch = pitch * 0.75 end
    end
  end

  animator.setSoundPitch(soundPool, pitch, rampTime)
end
