-- Dummy empty function so we save memory.
local function nullFunction()
end
-- Old functions. (we call these in functons we replace)
local init_old = init or nullFunction
local update_old = update or nullFunction
local uninit_old = uninit or nullFunction
-- Run on load.
function init()
  -- Run old NPC/Monster stuff.
  init_old()
  require "/scripts/starpounds/starpounds.lua"
  storage.starPounds = sb.jsonMerge(starPounds.baseData, storage.starPounds)
  -- This is stupid, but prevents 'null' data being saved.
  getmetatable(storage.starPounds).__nils = {}
  -- Used in functions for detection.
  starPounds.type = "npc"
  starPounds.moduleInit("base")
  -- Setup message handlers
  starPounds.messageHandlers()
  -- Setup species traits.
  storage.starPounds.overrideSpecies = config.getParameter("starPounds_overrideSpecies")
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
  starPounds.moduleInit({"entity", "humanoid", "npc", "vore"})
  starPounds.effectInit()
  starPounds.setWeight(storage.starPounds.weight)

  starPounds.events:on("main:statChange", function()
    starPounds.updateStats(true)
  end)
end

function update(dt)
  -- Run old NPC/Monster stuff.
  update_old(dt)
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
  starPounds.updateStats(nil, dt)
  starPounds.updateEffects(dt)
end

function uninit()
  starPounds.moduleUninit()
  uninit_old()
end
