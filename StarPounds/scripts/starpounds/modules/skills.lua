local skills = starPounds.module:new("skills")

function skills:init()
  message.setHandler("starPounds.upgradeSkill", function(_, _, ...) return self:upgrade(...) end)
  message.setHandler("starPounds.getSkillLevel", function(_, _, ...) return self:level(...) end)
  message.setHandler("starPounds.hasSkill", function(_, _, ...) return self:has(...) end)

  self:parse()
end

function skills:getSkillList()
  return self.data.skills
end

function skills:unlockedLevel(skill)
  -- Argument sanitisation.
  skill = tostring(skill)
  return math.min(storage.starPounds.skills[skill] and storage.starPounds.skills[skill][2] or 0, self.data.skills[skill] and (self.data.skills[skill].levels or 1) or 0)
end

function skills:hasUnlocked(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level) or 1
  return (self:unlockedLevel(skill) >= level)
end

function skills:level(skill)
  -- Argument sanitisation.
  skill = tostring(skill)
  return math.min(storage.starPounds.skills[skill] and storage.starPounds.skills[skill][1] or 0, self.data.skills[skill] and (self.data.skills[skill].levels or 1) or 0)
end

function skills:has(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level) or 1
  -- Legacy mode disables skills.
  return (self:level(skill) >= level) and not starPounds.hasOption("legacyMode")
end

function skills:upgrade(skill, cost)
  -- Argument sanitisation.
  skill = tostring(skill)
  cost = tonumber(cost) or 0
  storage.starPounds.skills[skill] = storage.starPounds.skills[skill] or jarray()
  if self:unlockedLevel(skill) == self:level(skill) then
    storage.starPounds.skills[skill][1] = math.min(self:unlockedLevel(skill) + 1, self.data.skills[skill].levels or 1)
  end
  storage.starPounds.skills[skill][2] = math.min(self:unlockedLevel(skill) + 1, self.data.skills[skill].levels or 1)

  local experienceConfig = starPounds.moduleFunc("experience", "config")
  local experienceProgress = storage.starPounds.experience.amount/(experienceConfig.experienceAmount * (1 + storage.starPounds.experience.level * experienceConfig.experienceIncrement))
  storage.starPounds.experience.level = math.max(storage.starPounds.experience.level - math.round(cost), 0)
  storage.starPounds.experience.amount = math.round(experienceProgress * experienceConfig.experienceAmount * (1 + storage.starPounds.experience.level * experienceConfig.experienceIncrement))
  starPounds.moduleFunc("experience", "add")
  self:parse()
  starPounds.events:fire("stats:calculate", "upgradeSkill")
end

function skills:forceUnlock(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level)
  -- Need a level to do anything here.
  if not level then return end
  -- If we're forcing the skill, also increase the unlocked level (and initialise it).
  if self.data.skills[skill] then
    storage.starPounds.skills[skill] = storage.starPounds.skills[skill] or jarray()
    storage.starPounds.skills[skill][1] = math.max(level, self:level(skill))
    storage.starPounds.skills[skill][2] = math.max(level, self:unlockedLevel(skill))
  end
  self:parse()
  -- Update stats if we're already up and running.
  if starPounds.currentSize then
    starPounds.events:fire("stats:calculate", "forceUnlockSkill")
  end
end

function skills:set(skill, level)
  -- Argument sanitisation.
  skill = tostring(skill)
  level = tonumber(level)
  -- Need a level to do anything here.
  if not level then return end
  -- Skip if there's no such skill.
  if not storage.starPounds.skills[skill] then return end
  if self:unlockedLevel(skill) > 0 then
    storage.starPounds.skills[skill][1] = util.clamp(level, 0, self:unlockedLevel(skill))
  end
  self:parse()
  starPounds.events:fire("stats:calculate", "setSkill")
end

function skills:parse()
  for skill in pairs(storage.starPounds.skills) do
    -- Remove the skill if it doesn't exist.
    if not self.data.skills[skill] then
      storage.starPounds.skills[skill] = nil
    else
      -- Cap skills at their maximum possible level.
      storage.starPounds.skills[skill][2] = math.min(self.data.skills[skill].levels or 1, storage.starPounds.skills[skill][2])
      storage.starPounds.skills[skill][1] = math.min(storage.starPounds.skills[skill][1], storage.starPounds.skills[skill][2])
    end
  end
  -- This is stupid, but prevents 'null' data being saved.
  getmetatable(storage.starPounds.skills).__nils = {}
end

-- Add the module.
starPounds.modules.skills = skills
