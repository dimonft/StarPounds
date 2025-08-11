require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

function init()
  activeItem.setCursor("/cursors/reticle0.cursor")
  animator.setGlobalTag("paletteSwaps", config.getParameter("paletteSwaps", ""))
  local itemName = item.name()
  animator.setGlobalTag("heatMask", root.itemConfig(itemName).directory..itemName.."heat.png:mask")

  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, 0)
  self.weapon:addTransformationGroup("muzzle", self.weapon.muzzleOffset, 0)

  local primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(primaryAbility)

  local secondaryAbility = getAltAbility(self.weapon.elementalType)
  if secondaryAbility then
    self.weapon:addAbility(secondaryAbility)
  end

  self.weapon:init()

  local _, aimDirection = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
  if aimDirection == -1 then
    self.weapon.aimAngle = math.pi
  end
end

function update(dt, fireMode, shiftHeld)
  self.weapon:update(dt, fireMode, shiftHeld)
end

function uninit()
  self.weapon:uninit()
end

function Weapon:updateAim()
  for _,group in pairs(self.transformationGroups) do
    animator.resetTransformationGroup(group.name)
    animator.translateTransformationGroup(group.name, group.offset)
    animator.rotateTransformationGroup(group.name, group.rotation, group.rotationCenter)
    animator.translateTransformationGroup(group.name, self.weaponOffset)
    animator.rotateTransformationGroup(group.name, self.relativeWeaponRotation, self.relativeWeaponRotationCenter)
  end

  self.aimDirection = vec2.withAngle(self.aimAngle)[1] > (self.directionBuffer or 0) and 1 or -1
  local aimAngle = activeItem.aimAngle(self.aimOffset * self.aimDirection, activeItem.ownerAimPosition())
  self.directionBuffer = -0.025 * self.aimDirection

  if self.stance.allowRotate then
    self.aimAngle = slerp(math.min(1, (mcontroller.mass() ^ 0.5) * script.updateDt()), self.aimAngle, aimAngle)
  elseif self.stance.aimAngle then
    self.aimAngle = self.stance.aimAngle
  end

  self.aimRecoil = self.aimRecoil or 0
  self.aimRecoilLerp = slerp(0.5 * script.updateDt(), self.aimRecoilLerp or 0, self.aimRecoil)

  self.heat = self.heat or 0
  local heatRate = ((self.heatLerp or 0) < self.heat) and 0.2 or 1
  self.heatLerp = util.clamp(util.lerp(heatRate * script.updateDt(), self.heatLerp or 0, self.heat * 1.2 - 0.1), 0, 1) -- Extra 10% so it doesn't get 'caught' near the ends with float math.

  animator.setGlobalTag("heat", string.format("%02X", math.floor(self.heatLerp * 255 + 0.5)))

  activeItem.setFacingDirection(self.aimDirection)

  if self.aimDirection == -1 then
    activeItem.setArmAngle(-(self.aimAngle + self.relativeArmRotation) - math.pi + self.aimRecoilLerp)
  else
    activeItem.setArmAngle(self.aimAngle + self.relativeArmRotation + self.aimRecoilLerp)
  end

  activeItem.setFrontArmFrame(self.stance.frontArmFrame)
  activeItem.setBackArmFrame(self.stance.backArmFrame)
end

function slerp(t, a, b)
  local two_pi = math.pi * 2
  a = (a + two_pi) % two_pi
  b = (b + two_pi) % two_pi
  local diff = math.abs(a - b)
  if (diff > math.pi) then
    if (a > b) then
      a = a - two_pi
    elseif (b > a) then
      b = b - two_pi
    end
  end
  return a + (b - a) * t
end
