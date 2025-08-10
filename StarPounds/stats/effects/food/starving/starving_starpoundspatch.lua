local init_old = init or function() end
local update_old = update or function() end

function init()
  starPounds = getmetatable ''.starPounds
end

function update(dt)
  if starPounds and starPounds.isEnabled() then
    if not starPounds.modules.hunger.isStarving then
      mcontroller.controlModifiers(self.movementModifiers)
    else
      update_old(dt)
    end
  end
end
