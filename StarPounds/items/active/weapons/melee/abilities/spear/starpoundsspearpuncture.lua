require "/items/active/weapons/melee/meleeslash.lua"

-- Spear stab attack
-- Extends normal melee attack and adds a hold state
StarPoundsSpearPuncture = MeleeSlash:new()

function StarPoundsSpearPuncture:init()
  MeleeSlash.init(self)

  self.punctureDamageConfig.baseDamage = self.baseDps * self.minCooldownTime
  self.punctureDamageConfig = sb.jsonMerge(self.damageConfig, self.punctureDamageConfig)

  -- A little confusing, but effectively just allows knockback at the same rate as the regular stab.
  self.punctureKnockback = self.punctureDamageConfig.knockback
  self.punctureKnockbackCycle = math.ceil(self.fireTime / self.minCooldownTime)
  self.punctureKnockbackCycleCount = 0
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

      -- Adds 1 - 3 (Avg. 2) to the cycle count (which is doubled). A little bit of randomness never hurt anyone ;)
      local knockbackCycleCount = self.punctureKnockbackCycleCount
      self.punctureKnockbackCycleCount = (self.punctureKnockbackCycleCount + math.random(1, 3)) % (self.punctureKnockbackCycle * 2)
      self.punctureDamageConfig.knockback = (knockbackCycleCount > self.punctureKnockbackCycleCount) and self.punctureKnockback or 0

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
      self.cooldownTimer = self:cooldownTime()

      local count = #self.cycleRotationOffsets
      currentRotationOffset = (currentRotationOffset + math.random(1, count - 1)) % count
      if currentRotationOffset == 0 then currentRotationOffset = count end
    end
  end
end
