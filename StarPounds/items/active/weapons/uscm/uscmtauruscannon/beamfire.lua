require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"

BeamFire = WeaponAbility:new()

function BeamFire:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime

  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime
  self.impactSoundTimer = 0

  self.weapon.onLeaveAbility = function()
    self.weapon:setDamage()
    activeItem.setScriptedAnimationParameter("chains", {})
    animator.setParticleEmitterActive("beamCollision", false)
    animator.stopAllSounds("fireLoop")
    self.weapon:setStance(self.stances.idle)
  end
end

function BeamFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.impactSoundTimer = math.max(self.impactSoundTimer - self.dt, 0)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy") then

    self:setState(self.fire)
  end
end

function BeamFire:fire()
  self.weapon:setStance(self.stances.fire)

  animator.playSound("fireStart")
  animator.playSound("fireLoop", -1)
  animator.setSoundPitch("fireLoop", 0.75)
  animator.setSoundVolume("fireLoop", 1)

  animator.setAnimationState("indicator", "active")

  local hasCameraProjectile = self.shakeProjectile and world.entityExists(self.shakeProjectile)
  self.shakeProjectile = hasCameraProjectile and self.shakeProjectile or world.spawnProjectile("uscmtauruscannoncamera", mcontroller.position(), entity.id())
  activeItem.setCameraFocusEntity(self.shakeProjectile)

  local wasColliding = false
  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt * (0.2 + 0.8 * self.weapon.heatLerp ^ 3)) do
    local beamStart = self:firePosition()
    local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(self:aimVector(0)), self.beamLength))
    local beamLength = self.beamLength

    local collidePoint = world.lineCollision(beamStart, beamEnd)
    if collidePoint then
      beamEnd = collidePoint

      beamLength = world.magnitude(beamStart, beamEnd)

      animator.setParticleEmitterActive("beamCollision", true)
      animator.resetTransformationGroup("beamEnd")
      animator.translateTransformationGroup("beamEnd", {beamLength, 0})

      if self.impactSoundTimer == 0 then
        animator.setSoundPosition("beamImpact", {beamLength, 0})
        animator.playSound("beamImpact")
        self.impactSoundTimer = self.fireTime
      end
    else
      animator.setParticleEmitterActive("beamCollision", false)
    end

    world.debugText(sb.print(math.floor((self.energyUsage or 0) * self.dt * (0.2 + 0.8 * self.weapon.heatLerp ^ 3) + 0.5)).." energy/sec", vec2.add(activeItem.ownerAimPosition(), {1, 0}), "green")

    local knockbackFactor = (1 - status.stat("grit"))
    local knockbackForce = 100
    local knockback = 10 * knockbackFactor
    -- Target heat.
    self.weapon.heat = 1
    -- Decrease shaking based on mass/knockback.
    self.baseMass = self.baseMass or mcontroller.baseParameters().mass
    local amplitude = 0.05 + 0.2 * (self.baseMass / mcontroller.mass())
    -- Recoil.
    self.weapon.aimRecoil = amplitude * math.pi/2

    local heat = math.floor(100 * self.weapon.heatLerp + 0.5)/100

    animator.setSoundPitch("fireLoop", 0.75 + heat * 0.5)
    animator.setSoundVolume("fireLoop", 1 + heat * 0.5)
    amplitude = amplitude * math.min(heat * 3, 1)
    amplitude = math.floor(amplitude * 100 + 0.5)/100

    if mcontroller.crouching() then
      -- -25% shake.
      amplitude = amplitude * 0.75
      -- -75% knockback force.
      knockbackForce = knockbackForce * 0.25
      -- -50% recoil.
      self.weapon.aimRecoil = self.weapon.aimRecoil * 0.5
    end

    mcontroller.controlModifiers({
      runningSuppressed = true
    })

    -- Knockback.
    mcontroller.controlApproachVelocityAlongAngle(self.weapon.aimAngle + math.pi, knockback * math.min(heat * 2, 1), knockbackForce, true)
    -- Shake.
    if self.lastAmplitude ~= amplitude then
      if self.shakeProjectile and world.entityExists(self.shakeProjectile) then
        world.sendEntityMessage(self.shakeProjectile, "setAmplitude", amplitude)
      end
      self.lastAmplitude = amplitude
    end

    self.weapon:setDamage(self.damageConfig, {self.weapon.muzzleOffset, {self.weapon.muzzleOffset[1] + beamLength, self.weapon.muzzleOffset[2]}}, self.fireTime)

    self:drawBeam(beamEnd, collidePoint)

    coroutine.yield()
  end

  self:reset()
  animator.playSound("fireEnd")
  -- 0.25 -> 1.5 volume based on heat.
  animator.setSoundVolume("fireEndHeat", 0.25 + 1.25 * self.weapon.heatLerp)
  animator.playSound("fireEndHeat")

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function BeamFire:drawBeam(endPos, didCollide)
  local newChain = copy(self.chain)
  newChain.startOffset = self.weapon.muzzleOffset
  newChain.endPosition = endPos

  if didCollide then
    newChain.endSegmentImage = nil
  end

  activeItem.setScriptedAnimationParameter("chains", {newChain})
end

function BeamFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  util.wait(self.stances.cooldown.duration, function()

  end)
end

function BeamFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function BeamFire:aimVector(inaccuracy)
  local angle = self.weapon.aimAngle

  if self.weapon.aimDirection == -1 then
    angle = -angle - math.pi
  else
    angle = angle
  end

  angle = angle + self.weapon.aimRecoilLerp

  local aimVector = vec2.rotate({1, 0}, angle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * self.weapon.aimDirection
  return aimVector
end

function BeamFire:uninit()
  self:reset()
end

function BeamFire:reset()
  self.weapon:setDamage()
  activeItem.setScriptedAnimationParameter("chains", {})
  animator.setAnimationState("indicator", "inactive")
  animator.setParticleEmitterActive("beamCollision", false)
  animator.stopAllSounds("fireStart")
  animator.stopAllSounds("fireLoop")

  if self.shakeProjectile then
    if world.entityExists(self.shakeProjectile) then
      world.sendEntityMessage(self.shakeProjectile, "stop")
    end
    self.lastAmplitude = nil
    self.shakeProjectile = nil
    self.weapon.aimAngle = self.weapon.aimAngle + (self.weapon.aimRecoilLerp * self.weapon.aimDirection)
    self.weapon.aimRecoil = 0
    self.weapon.aimRecoilLerp = 0
    self.weapon.heat = 0
  end
end
