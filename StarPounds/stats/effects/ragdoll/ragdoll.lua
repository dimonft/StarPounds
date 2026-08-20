require "/scripts/vec2.lua"

function init()
  self.bounds = mcontroller.boundBox()
  self.entityType = world.entityType(entity.id())

  self.width = math.max(math.abs(self.bounds[3] - self.bounds[1]), 0.1)
  self.height = math.max(math.abs(self.bounds[4] - self.bounds[2]), 0.1)

  self.corners = {
    {self.bounds[1], self.bounds[2]},
    {self.bounds[3], self.bounds[2]},
    {self.bounds[3], self.bounds[4]},
    {self.bounds[1], self.bounds[4]}
  }

  self.collisionBlocks = {"Null", "Block", "Dynamic", "Platform", "Slippery"}

  self.size = math.max(self.width, self.height)
  self.radius = math.max(self.width / 2, 0.5)
  self.spinMultiplier = 0.25

  self.angularVelocity = 0
  self.rotation = mcontroller.rotation() or 0
  self.baseDuration = effect.duration() or 0
end

function update(dt)
  mcontroller.controlModifiers({
    facingSuppressed = true,
    movementSuppressed = true
  })
  -- Treat as stunned during the ragdoll.
  if status.isResource("stunned") then
    status.setResource("stunned", math.max(status.resource("stunned"), effect.duration() or 0))
  end
  -- Extend the effect while not on the ground.
  local inAir = not (mcontroller.onGround() or mcontroller.liquidMovement() or mcontroller.zeroG())
  local velocity = mcontroller.velocity()
  local speed = math.abs(velocity[1])
  if inAir and speed > 0.5 then
    effect.modifyDuration(self.baseDuration - (effect.duration() or 0))
  end
  -- Don't bother rotating monsters.
  if self.entityType == "monster" then return end
  -- Spin if moving, level out if we're on the ground (or the parameter is disabled), stop rotation if we're on the ground and not moving.
  if speed > 0.5 then
    local targetAngularVelocity = (-velocity[1] / self.radius) * self.spinMultiplier
    self.angularVelocity = self.angularVelocity + (targetAngularVelocity - self.angularVelocity) * 15 * dt
  elseif not inAir and effect.getParameter("correct", true) then
    local groundAngle = getGroundAngle()

    local relativeRotation = (self.rotation - groundAngle) % (2 * math.pi)
    if relativeRotation > math.pi then relativeRotation = relativeRotation - (2 * math.pi) end
    local angle = math.atan((self.width / self.height) ^ 3)
    local target = 0
    if math.abs(relativeRotation) <= angle then
      target = 0
    elseif math.abs(relativeRotation) >= math.pi - angle then
      target = math.pi
    elseif relativeRotation > 0 then
      target = math.pi / 2
    else
      target = -math.pi / 2
    end

    local targetRotation = groundAngle + target

    local angleDiff = (targetRotation - self.rotation) % (2 * math.pi)
    if angleDiff > math.pi then angleDiff = angleDiff - (2 * math.pi) end

    local springStiffness = 100
    local damping = 25

    local angularAcceleration = (angleDiff * springStiffness) - (self.angularVelocity * damping)
    self.angularVelocity = self.angularVelocity + (angularAcceleration * dt)

    local friction = 8
    if self.angularVelocity > 0 then
      self.angularVelocity = math.max(0, self.angularVelocity - (friction * dt))
    elseif self.angularVelocity < 0 then
      self.angularVelocity = math.min(0, self.angularVelocity + (friction * dt))
    end
  elseif not inAir then
    self.angularVelocity = 0
  end

  self.rotation = self.rotation + (self.angularVelocity * dt)
  mcontroller.setRotation(self.rotation)
end

function getGroundAngle()
  if not mcontroller.onGround() then return 0 end
  local position = mcontroller.position()
  local minX, maxX = -self.size * 0.4, self.size * 0.4
  local terrain = {}
  local spacing = (maxX - minX) / 4

  local checkStart = position[2] + (self.size * 0.75)
  local checkEnd = checkStart - (self.size * 2.5) -- Extended slightly to ensure we hit bottoms of steps

  for i = 0, 4 do
    local x = position[1] + minX + (spacing * i)
    local pos = world.lineCollision({x, checkStart}, {x, checkEnd}, self.collisionBlocks)
    if pos then table.insert(terrain, pos) end
  end
  -- Skip if we can't draw a line.
  if #terrain < 2 then return 0 end
  -- Finds a slope between all points.
  local selectedSlope = nil
  for i = 1, #terrain - 1 do
    local startPosition = terrain[i]
    for i2 = i + 1, #terrain do
      local endPosition = terrain[i2]
      local dx = endPosition[1] - startPosition[1]
      -- If we're perfectly vertical, there's a chance the difference could be 0.
      if dx > 0.001 then
        local slope = (endPosition[2] - startPosition[2]) / dx
        -- Ignore slopes over 1.2 (~50 degrees).
        if math.abs(slope) < 1.2 then
          local yIntercept = startPosition[2] - (slope * startPosition[1])
          local clipping = false
          for _, point in ipairs(terrain) do
            if point[2] > ((slope * point[1]) + yIntercept) then clipping = true break end
          end
          -- Don't pick a slope that start and end at a single side, only slopes that cross the middle.
          if not clipping then
            local throughCenter = (position[1] >= startPosition[1] - 0.1) and (position[1] <= endPosition[1] + 0.1)
            if throughCenter or selectedSlope == nil then
              selectedSlope = slope
            end
          end
        end
      end
    end
  end

  return selectedSlope and math.atan(selectedSlope) or 0
end

function uninit()
  if self.entityType == "monster" then return end

  local currentRotation = mcontroller.rotation() or 0
  mcontroller.setRotation(0)

  local minY = math.huge
  for _, corner in ipairs(self.corners) do
    local rotatedY = corner[1] * math.sin(currentRotation) + corner[2] * math.cos(currentRotation)
    if rotatedY < minY then minY = rotatedY end
  end

  local offset = minY - self.bounds[2]
  if offset > 0 then
    mcontroller.translate({0, offset})
  end

  if world.entityType(entity.id()) == "npc" then
    world.callScriptedEntity(entity.id(), "npc.endPrimaryFire")
    world.callScriptedEntity(entity.id(), "npc.endAltFire")
  end
end
