local HammerSmashFire_old = HammerSmash.fire
function HammerSmash:fire(...)
  local defaultDamage = self.damageConfig.baseDamage

  local starPounds = getmetatable ''.starPounds
  if starPounds then
    self.damageConfig.baseDamage = defaultDamage * (1 + starPounds.getStat("smashDamage") * starPounds.moduleFunc("size", "effectScaling"))
  end

  HammerSmashFire_old(self, ...)
  self.damageConfig.baseDamage = defaultDamage
end
