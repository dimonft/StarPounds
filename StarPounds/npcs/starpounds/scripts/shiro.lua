local init_old = init
function init(...)
  init_old(...)
  if world.getProperty("nonCombat") then
    npc.setDamageTeam({damageTeam = 2, type = "passive"})
  end
end
