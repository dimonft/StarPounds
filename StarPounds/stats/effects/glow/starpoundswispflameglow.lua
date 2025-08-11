function init()
  animator.setParticleEmitterOffsetRegion("sparkles", mcontroller.boundBox())
  animator.setParticleEmitterActive("sparkles", config.getParameter("particles", true))
  effect.setParentDirectives("fade=FFBC47;0.03?border=2;FFBC4720;00000000")
end

function update(dt)
  
end

function uninit()
  
end
