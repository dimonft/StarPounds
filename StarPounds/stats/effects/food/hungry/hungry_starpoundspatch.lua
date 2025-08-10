local init_old = init or function() end
local update_old = update or function() end

function init()
  starPounds = getmetatable ''.starPounds
end

function update(dt)
  if starPounds and starPounds.isEnabled() then
    if starPounds.moduleFunc("skills", "has", "preventStarving") and not starPounds.hasOption("disableLoss") then
      self.soundTimer = self.soundInterval
    end
  end
  update_old(dt)
end
