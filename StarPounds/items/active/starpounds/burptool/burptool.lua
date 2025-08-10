function init()
  activeItem.setHoldingItem(false)
end

function activate(fireMode, shiftHeld)
  world.sendEntityMessage(activeItem.ownerEntityId(), "starPounds.belch", 0.75, 1, false)
end
