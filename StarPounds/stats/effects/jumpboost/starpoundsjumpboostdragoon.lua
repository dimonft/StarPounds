function init()
  local bounds = mcontroller.boundBox()
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = 2.0},
	{stat = "fallDamageMultiplier", effectiveMultiplier = 0.20}
  })
end

function update(dt)
  mcontroller.controlModifiers({
      airJumpModifier = 2.00
    })
end

function uninit()
  
end
