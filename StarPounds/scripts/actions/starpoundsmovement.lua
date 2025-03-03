require "/scripts/poly.lua"
require "/scripts/rect.lua"
local moveToPosition_old = moveToPosition
-- param entity
function moveToPosition(args, board, node)
  if args.position == nil then return false end

  if starPounds then
    local offset = starPounds.moduleFunc("size", "offset") or {0, 0}
    args.position = vec2.sub(args.position, offset)
  end

  return moveToPosition_old(args, board, node)
end
