function init()
  animator.setParticleEmitterActive("flames", true)
  hangoverDuration = effect.getParameter("hangoverDuration") 
  hangoverStatus = effect.getParameter("hangoverStatus")

  baseDuration = effect.duration()
end

function update(dt)

end

function uninit()
    status.addEphemeralEffect(hangoverStatus, baseDuration * hangoverDuration)
end
