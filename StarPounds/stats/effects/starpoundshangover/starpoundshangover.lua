function init()
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = -0.3}
  })
end

function update(dt)
  mcontroller.controlModifiers({
      groundMovementModifier = 0.55,
      speedModifier = 0.65,
      airJumpModifier = 0.8
    })
end

function uninit()

end
