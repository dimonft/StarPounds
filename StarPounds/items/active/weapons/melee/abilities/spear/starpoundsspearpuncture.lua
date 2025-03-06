require "/items/active/weapons/melee/meleeslash.lua"

-- Spear stab attack
-- Extends normal melee attack and adds a hold state
StarPoundsSpearPuncture = MeleeSlash:new()

function StarPoundsSpearPuncture:init()
  MeleeSlash.init(self)

  self.punctureDamageConfig.baseDamage = self.baseDps * self.minCooldownTime
  self.punctureDamageConfig = sb.jsonMerge(self.damageConfig, self.punctureDamageConfig)

  self.punctureKnockback = self.punctureDamageConfig.knockback
  self.punctureKnockbackCycle = 0
end

function StarPoundsSpearPuncture:fire()
  MeleeSlash.fire(self)
  if self.fireMode == "primary" and self.allowHold ~= false then
    self.firstSwing = true
    self:setState(self.swing)
  end
end

function StarPoundsSpearPuncture:swing()
  local cooldownTime = self.maxCooldownTime
  local currentRotationOffset = 1
  while self.fireMode == "primary" do
    if self.firstSwing then
      self.weapon:setStance(self.stances.idle)
      util.wait(self.punctureWindupTime, function(dt)
        return self.fireMode ~= "primary"
      end)
      self.firstSwing = false
    end

    if not self.firstSwing then
      self.weapon:setStance(self.stances.swing)
      self.weapon.relativeWeaponRotation = util.toRadians(self.stances.swing.weaponRotation + self.cycleRotationOffsets[currentRotationOffset])
      self.weapon.relativeArmRotation = util.toRadians(self.stances.swing.armRotation + self.cycleRotationOffsets[currentRotationOffset])
      self.weapon:updateAim()

      animator.setAnimationState("swoosh", "fire")
      animator.playSound("flurry")

      self.punctureDamageConfig.knockback = self.punctureKnockbackCycle == 0 and self.punctureKnockback or 0
      self.punctureKnockbackCycle = (self.punctureKnockbackCycle + 1) % self.punctureDamageConfig.knockbackCycle

      util.wait(self.stances.swing.duration, function(dt)
        local damageArea = partDamageArea("swoosh")

        self.weapon:setDamage(self.punctureDamageConfig, damageArea)
      end)

      -- allow changing aim during cooldown
      self.weapon:setStance(self.stances.swingWindup)
      util.wait(cooldownTime - self.stances.swing.duration, function(dt)
        return self.fireMode ~= "primary"
      end)

      cooldownTime = math.max(self.minCooldownTime, cooldownTime - self.cooldownSwingReduction)

      currentRotationOffset = currentRotationOffset + 1
      if currentRotationOffset > #self.cycleRotationOffsets then
        currentRotationOffset = 1
      end
    end
  end
end
