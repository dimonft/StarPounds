function patch(data)
  local layout = data.paneLayout

  layout.imgCosmeticBack.file = "/interface/inventory/starpounds_cosmeticsback.png"

  layout["cosmetic8"].backingImage = "/interface/inventory/starpounds_backingimagechest.png"
  layout["cosmetic8"].data = {tooltipText = "Scaled by ^#ccbbff;StarPounds^reset;"}

  layout["cosmetic4"].backingImage = "/interface/inventory/starpounds_backingimagelegs.png"
  layout["cosmetic4"].data = {tooltipText = "Scaled by ^#ccbbff;StarPounds^reset;"}

  return data
end
