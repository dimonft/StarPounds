require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  source = projectile.sourceEntity()
  amplitude = config.getParameter("shakeAmplitude")

  message.setHandler("stop", function()
    update = function() end
    projectile.die()
  end)

  message.setHandler("setAmplitude", function(_, _, amount)
    amplitude = util.clamp(tonumber(amount) or 0, -1, 1)
  end)
end

function update(dt)
  if source and world.entityExists(source) then
    projectile.setTimeToLive(1.0)
    local offset = {
      (math.random() - 0.5) * amplitude * 2,
      (math.random() - 0.5) * amplitude * 2
    }
    mcontroller.setPosition(vec2.add(world.entityPosition(source), offset))
  else
    projectile.die()
  end
end
