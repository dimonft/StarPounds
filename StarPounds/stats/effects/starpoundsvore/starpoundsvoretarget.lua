function init()
  local source = effect.sourceEntity()
  local options = effect.getParameter("options", {})
  -- Set the max mass option to the effect's duration if we have the tag.
  local maxWeight = effect.getParameter("maxWeight")
  if maxWeight then options.maxWeight = effect.duration() end
  if source ~= entity.id() then
    world.sendEntityMessage(source, "starPounds.pred.eat", entity.id(), options)
  end
  effect.expire()
end

function update()
  effect.expire()
end
