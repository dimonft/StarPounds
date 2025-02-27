require "/scripts/messageutil.lua"

function init()
  message.setHandler("starPounds.playSound", simpleHandler(playSound))
  message.setHandler("starPounds.stopSound", simpleHandler(animator.stopAllSounds))
  message.setHandler("starPounds.setSoundVolume", simpleHandler(setSoundVolume))
  message.setHandler("starPounds.setSoundPitch", simpleHandler(setSoundPitch))
  message.setHandler("starPounds.expire", localHandler(effect.expire))
end

function update(dt)
  effect.modifyDuration(dt)
end

function playSound(soundPool, loops)
  local starPounds = getmetatable ''.starPounds
  if starPounds and starPounds.hasOption("disableSound") then return end

  animator.playSound(soundPool, loops)
end

function setSoundVolume(soundPool, volume, rampTime)
  local starPounds = getmetatable ''.starPounds
  if starPounds then
    if starPounds.hasSkill("secret") then
      soundPool = "secret"
      volume = (volume + 0.5) * 0.5
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
    -- Secret sound
    if starPounds.hasSkill("secret") then
      soundPool = "secret"
      pitch = (pitch + 1) * 0.5
    end
  end

  animator.setSoundPitch(soundPool, pitch, rampTime)
end
