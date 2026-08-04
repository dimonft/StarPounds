descriptionFunctions.breastMilk = descriptionFunctions.breastMilk or function(descriptionWidget)
  descriptionWidget.onClick = function()
    local starPounds = getmetatable ''.starPounds
    starPounds.moduleFunc("breasts", "setMilkType", "milk")
  end
end
