function init()
  modifiers = effect.getParameter("controlModifiers", {})
end

function update(dt)
  mcontroller.controlModifiers(modifiers)
end
