function patch(data)
  local layout = data.paneLayout
  local slots = assets.json("/scripts/starpounds/modules/size.config:oSBSlots")

  for slot, itemType in pairs(slots) do
    layout[slot].backingImage = "/interface/inventory/starpounds_backingimage" .. itemType .. ".png"
    layout[slot].data = {tooltipText = layout[slot].data.tooltipText.." | Supports ^#ccbbff;StarPounds^reset;"}
  end

  return data
end
