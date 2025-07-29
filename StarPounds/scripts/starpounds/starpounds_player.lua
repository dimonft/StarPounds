-- Run on load.
function init()
  -- Load StarPounds.
  require "/scripts/starpounds/starpounds.lua"
  -- Used in functions for detection.
  starPounds.type = "player"
  -- Base module.
  starPounds.moduleInit("base")
  -- Setup message handlers
  starPounds.messageHandlers()
  -- Setup species traits.
  local speciesTrait = starPounds.traits[starPounds.getSpecies()] or starPounds.traits.default
  for _, skill in ipairs(speciesTrait.skills or jarray()) do
    starPounds.forceUnlockSkill(skill[1], skill[2])
  end
  -- Reload whenever the entity loads in/beams/etc.
  starPounds.statCache = {}
  starPounds.statCacheTimer = starPounds.settings.statCacheTimer
  starPounds.parseSkills()
  starPounds.parseStats()
  starPounds.accessoryModifiers = starPounds.getAccessoryModifiers()
  starPounds.moduleInit({"entity", "humanoid", "player", "vore"})
  starPounds.effectInit()
  starPounds.moduleFunc("size", "setWeight", storage.starPounds.weight)

  starPounds.events:on("main:statChange", function(trace)
    -- Kill the cache, and force an update to stats.
    starPounds.statCacheTimer = 0
    starPounds.statCache = {}
    starPounds.updateStats(true)
  end)
end

function update(dt)
  -- Check promises.
  promises:update()
  -- Reset stat cache.
  starPounds.statCacheTimer = math.max(starPounds.statCacheTimer - dt, 0)
  if starPounds.statCacheTimer == 0 then
    starPounds.statCache = {}
    starPounds.statCacheTimer = starPounds.settings.statCacheTimer
  end
  -- Modules.
  starPounds.moduleUpdate(dt)
  -- Stat/status updating stuff.
  starPounds.updateStats()
  starPounds.updateEffects(dt)
end

function uninit()
  starPounds.moduleFunc("pred", "release", nil, true)
  starPounds.moduleUninit()
  starPounds.backup()
end
