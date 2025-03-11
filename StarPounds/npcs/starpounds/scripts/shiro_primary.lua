local init_old = init
function init(...)
  self.bounces = 0
  init_old(...)
end

function applyDamageRequest(damageRequest)
  if self.hitInvulnerabilityTime > 0 or world.getProperty("nonCombat") then
    damageRequest.damage = 0
    damageRequest.damageType = "Knockback"
    if damageRequest.damageSourceKind ~= "nodamage" and
       damageRequest.damageSourceKind ~= "hidden" and
       damageRequest.damageSourceKind ~= "direct" and
         damageRequest.damageSourceKind ~= "starpoundsstomachsmash"
    then
      damageRequest.damageSourceKind = "bugnet"
    end
    damageRequest.statusEffects = {}
  end

  local damage = 0
  if damageRequest.damageType == "Damage" or damageRequest.damageType == "Knockback" then
    damage = damage + root.evalFunction2("protection", damageRequest.damage, status.stat("protection"))
  elseif damageRequest.damageType == "IgnoresDef" then
    damage = damage + damageRequest.damage
  elseif damageRequest.damageType == "Status" then
    -- only apply status effects
    status.addEphemeralEffects(damageRequest.statusEffects, damageRequest.sourceEntityId)
    return {}
  elseif damageRequest.damageType == "Environment" then
    return {}
  end

  if damageRequest.hitType == "ShieldHit" and status.statPositive("shieldHealth") and status.resourcePositive("shieldStamina") then
    status.modifyResource("shieldStamina", -damage / status.stat("shieldHealth"))
    status.setResourcePercentage("shieldStaminaRegenBlock", 1.0)
    damage = 0
    damageRequest.statusEffects = {}
    damageRequest.damageSourceKind = "shield"
  end

  local healthLost = math.min(damage, status.resource("health"))
  if healthLost > 0 and damageRequest.damageType ~= "Knockback" then
    status.modifyResource("health", -healthLost)
    self.damageFlashTime = 0.07
    if status.statusProperty("hitInvulnerability") then
      local damageHealthPercentage = healthLost / status.resourceMax("health")
      if damageHealthPercentage > status.statusProperty("hitInvulnerabilityThreshold") then
        self.hitInvulnerabilityTime = status.statusProperty("hitInvulnerabilityTime")
      end
    end
  end

  status.addEphemeralEffects(damageRequest.statusEffects, damageRequest.sourceEntityId)

  local knockbackFactor = 1.5 -- God speed, Shiro.
  local momentum = knockbackMomentum(vec2.mul(damageRequest.knockbackMomentum, knockbackFactor))
  if status.resourcePositive("health") and vec2.mag(momentum) > 0 then
    mcontroller.setVelocity({0,0})
    mcontroller.addMomentum(momentum)
    status.addEphemeralEffect("ragdoll_nocorrect")
    self.bounces = 3
    status.setResource("stunned", math.max(status.resource("stunned"), status.stat("knockbackStunTime")))
  end

  local hitType = damageRequest.hitType
  if not status.resourcePositive("health") then
    hitType = "kill"
  end
  return {{
    sourceEntityId = damageRequest.sourceEntityId,
    targetEntityId = entity.id(),
    position = mcontroller.position(),
    damageDealt = damage,
    healthLost = healthLost,
    hitType = hitType,
    kind = "Normal",
    damageSourceKind = damageRequest.damageSourceKind,
    targetMaterialKind = status.statusProperty("targetMaterialKind")
  }}
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
