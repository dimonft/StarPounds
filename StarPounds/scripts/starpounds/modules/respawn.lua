local respawn = starPounds.module:new("respawn")

function respawn:uninit()
  if not status.resourcePositive("health") then
    local experienceConfig = starPounds.moduleFunc("experience", "config")
    local experienceProgress = storage.starPounds.experience.amount/(experienceConfig.experienceAmount * (1 + storage.starPounds.experience.level * experienceConfig.experienceIncrement))
    local experienceCost = math.ceil(self.data.experiencePercentile * storage.starPounds.experience.level * starPounds.getStat("deathPenalty"))
    local weightCost = math.ceil(storage.starPounds.weight * self.data.weightPercentile * starPounds.getStat("deathPenalty"))
    -- Reduce levels and progress to next experience level.
    storage.starPounds.experience.level = math.max(storage.starPounds.experience.level - experienceCost, 0)
    storage.starPounds.experience.amount = math.max(experienceProgress - (self.data.experiencePercentile * starPounds.getStat("deathPenalty")), 0) * experienceConfig.experienceAmount * (1 + storage.starPounds.experience.level * experienceConfig.experienceIncrement)
    -- Lose weight.
    starPounds.moduleFunc("size", "loseWeight", weightCost)
    -- Reset stomach/breasts.
    starPounds.moduleFunc("stomach", "reset")
    starPounds.moduleFunc("breasts", "reset")
  end
end

starPounds.modules.respawn = respawn
