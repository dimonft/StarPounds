local init_old = Flurry.init
function Flurry:init()
  self.damageConfig.baseDamage = self.baseDps * self.minCooldownTime
  self.damageConfig.timeoutGroup = "primary"
  self.energyUsage = self.energyUsage or 0

  self.weapon:setStance(self.stances.idle)

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end

  init_old(self)
end

local update_old = Flurry.update
function Flurry:update(dt, fireMode, shiftHeld)
  -- Switcharoo.
  self.fireMode = fireMode
  if fireMode == "primary" then self.fireMode = "alt" end
  if fireMode == "alt" then self.fireMode = "primary" end

  update_old(self, dt, self.fireMode, shiftHeld)
end

local swing_old = Flurry.swing
function Flurry:swing()
  if self.energyUsage == 0 then
    local overConsumeResource_old = status.overConsumeResource
    status.overConsumeResource = function() return true end

    swing_old(self)
    status.overConsumeResource = overConsumeResource_old
  else
    swing_old(self)
  end
end
