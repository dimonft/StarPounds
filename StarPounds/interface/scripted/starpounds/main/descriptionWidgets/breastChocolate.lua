descriptionFunctions.breastChocolate = descriptionFunctions.breastChocolate or function(descriptionWidget)
  descriptionWidget.onClick = function()
    local starPounds = getmetatable ''.starPounds
    starPounds.moduleFunc("breasts", "setMilkType", "starpoundschocolateliquid")
    starPounds.moduleFunc("skills", "upgrade", "breastMilk", 0)
  end
end
