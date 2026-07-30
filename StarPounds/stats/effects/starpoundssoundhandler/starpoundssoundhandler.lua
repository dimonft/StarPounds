require "/scripts/messageutil.lua"

function init()
  message.setHandler("starPounds.sound.handler.playSound", localHandler(animator.playSound))
  message.setHandler("starPounds.sound.handler.stopSound", localHandler(animator.stopAllSounds))
  message.setHandler("starPounds.sound.handler.setSoundVolume", localHandler(animator.setSoundVolume))
  message.setHandler("starPounds.sound.handler.setSoundPitch", localHandler(animator.setSoundPitch))
  message.setHandler("starPounds.sound.handler.setSoundPool", localHandler(animator.setSoundPool))
  message.setHandler("starPounds.expireEffects", localHandler(effect.expire))
end

function update(dt)
  effect.modifyDuration(dt)
end
