local init_old = init
function init(...)
  self.bounces = 0
  init_old(...)
end

local applyDamageRequest_old = applyDamageRequest
function applyDamageRequest(damageRequest, ...)
  if world.getProperty("nonCombat") then
    -- Hides blood particles.
    if damageRequest.damageSourceKind ~= "nodamage" and
       damageRequest.damageSourceKind ~= "hidden" and
       damageRequest.damageSourceKind ~= "direct" and
       damageRequest.damageSourceKind ~= "starpoundsstomachsmash"
    then
      damageRequest.damageSourceKind = "bugnet"
    end

    -- Apply knockback.
    local knockbackFactor = 1.5 -- God speed, Shiro.
    local momentum = knockbackMomentum(vec2.mul(damageRequest.knockbackMomentum, knockbackFactor))
    if status.resourcePositive("health") and vec2.mag(momentum) > 0 then
      mcontroller.setVelocity({0,0})
      mcontroller.addMomentum(momentum)
      status.addEphemeralEffect("ragdoll_nocorrect")
      self.bounces = 3
      status.setResource("stunned", math.max(status.resource("stunned"), status.stat("knockbackStunTime")))
    end

    -- No damage.
    return {{
      sourceEntityId = damageRequest.sourceEntityId,
      targetEntityId = entity.id(),
      position = mcontroller.position(),
      damageDealt = 0,
      healthLost = 0,
      hitType = damageRequest.hitType,
      kind = "Normal",
      damageSourceKind = damageRequest.damageSourceKind,
      targetMaterialKind = status.statusProperty("targetMaterialKind")
    }}
  end
  -- Return standard stuff.
  return applyDamageRequest_old(damageRequest, ...)
end

local update_old = update
function update(...)
  self.onGround = mcontroller.onGround()
  if status.uniqueStatusEffectActive("ragdoll_nocorrect") and (math.abs(mcontroller.yVelocity()) > 25 or math.abs(mcontroller.xVelocity()) > 40) then
    mcontroller.controlParameters({
      bounceFactor = 0.8
    })
    if self.onGround and not self.wasOnGround then
      self.bounces = self.bounces - 1
    end
  end
  self.wasOnGround = self.onGround
  update_old(...)
end
