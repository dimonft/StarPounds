require "/scripts/vec2.lua"
require "/scripts/poly.lua"
require "/scripts/util.lua"
require "/scripts/drawingutil.lua"

local canvasWidget, centerCoordinates, menuOptions, optionCount, sliceAngle, lastHoveredTarget
local radiusInner, radiusOuter, radiusHover, hoveredOptionIndex, hasSelectedOption = 36, 58, 10, nil, false
local isMouseDown = false
local isMouseReleased = false
local menuStack = {}

local animationTimer = 0
local animationDuration = 0.2 -- Initial grow animation time.

local needsRedraw = true
local prevMouseDown = false

-- Colours.
local defaultColours = {
  center = {60, 50, 80, 180},
  base = {190, 180, 200, 160},
  hover = {157, 114, 237, 180},
  press = {180, 140, 255, 200},
  hidden = {0, 0, 0, 0},
  -- Text.
  text = {190, 180, 200},
  textHover = {255, 255, 255},
  textGrey = {170, 170, 170},
  -- Border.
  iconBorder = "beb4c888"
}

local iconBorderDirective = "?border=1;%s;00000000"

local shared = getmetatable ""
shared.starPoundsRadialMenu = shared.starPoundsRadialMenu or {}
local radialMenu = shared.starPoundsRadialMenu

local colours = util.mergeTable(copy(defaultColours), shared.starPoundsRadialMenu.colours or {})

local function loadMenu(newOptionsList)
  menuOptions = newOptionsList
  optionCount = #menuOptions
  if optionCount == 0 then return pane.dismiss() end

  hoveredOptionIndex = nil
  isMouseDown = false
  isMouseReleased = false
  lastHoveredTarget = nil

  animationTimer = 0
  needsRedraw = true

  local totalWeight = 0
  for _, option in ipairs(menuOptions) do
    option.weight = tonumber(option.weight) or 1
    totalWeight = totalWeight + option.weight
  end
  -- Start at counterclockwise edge of option 1 so it's centered. (math.pi * 0.5)
  local firstSweep = (menuOptions[1].weight / totalWeight) * (math.pi * 2)
  local currentEndAngle = (math.pi * 0.5) + (firstSweep * 0.5)

  for optionIndex, option in ipairs(menuOptions) do
    local sweepAngle = (option.weight / totalWeight) * (math.pi * 2)
    option.endAngle = currentEndAngle
    option.startAngle = currentEndAngle - sweepAngle
    option.midpointAngle = currentEndAngle - (sweepAngle * 0.5)

    currentEndAngle = option.startAngle

    if option.init and type(option.init) == "function" then
      option:init(optionIndex)
    end
  end
end

function init()
  radialMenu.result = nil

  self.uuid = config.getParameter("uuid") or radialMenu.uuid

  canvasWidget = widget.bindCanvas("canvas")
  widget.focus("canvas")

  local canvasSize = canvasWidget:size()
  local canvasWidth = (canvasSize[1] > 0) and canvasSize[1] or 200
  local canvasHeight = (canvasSize[2] > 0) and canvasSize[2] or 200
  centerCoordinates = vec2.mul({canvasWidth, canvasHeight}, 0.5)

  local options = radialMenu.options or config.getParameter("options", {})
  loadMenu(options)
end

-- HELL. HELL. HATE. HELL.
local function drawArcSegment(startAngle, endAngle, innerArcRadius, outerArcRadius, fillColour, gap)
  local halfGap = (gap or 0) * 0.5
  local deltaAngleInner = (innerArcRadius > 0) and (halfGap / innerArcRadius) or 0
  local deltaAngleOuter = (outerArcRadius > 0) and (halfGap / outerArcRadius) or 0

  local startAngleInner = startAngle + deltaAngleInner
  local endAngleInner = endAngle - deltaAngleInner
  local startAngleOuter = startAngle + deltaAngleOuter
  local endAngleOuter = endAngle - deltaAngleOuter

  local arcSteps = math.max(2, math.ceil((endAngle - startAngle) * 6))
  local angleStepInner = (endAngleInner - startAngleInner) / arcSteps
  local angleStepOuter = (endAngleOuter - startAngleOuter) / arcSteps

  for stepIndex = 0, arcSteps - 1 do
    local currentAngleInner = startAngleInner + stepIndex * angleStepInner
    local nextAngleInner = startAngleInner + (stepIndex + 1) * angleStepInner
    local currentAngleOuter = startAngleOuter + stepIndex * angleStepOuter
    local nextAngleOuter = startAngleOuter + (stepIndex + 1) * angleStepOuter

    local innerStartPoint = vec2.add(centerCoordinates, vec2.withAngle(currentAngleInner, innerArcRadius))
    local outerStartPoint = vec2.add(centerCoordinates, vec2.withAngle(currentAngleOuter, outerArcRadius))
    local outerEndPoint = vec2.add(centerCoordinates, vec2.withAngle(nextAngleOuter, outerArcRadius))
    local innerEndPoint = vec2.add(centerCoordinates, vec2.withAngle(nextAngleInner, innerArcRadius))

    canvasWidget:drawTriangles({{innerStartPoint, outerStartPoint, outerEndPoint}, {innerStartPoint, outerEndPoint, innerEndPoint}}, fillColour)
  end
end

function update(dt)
  if radialMenu.close or radialMenu.uuid ~= self.uuid then
    radialMenu.close = nil
    return pane.dismiss()
  end

  if animationTimer < animationDuration then
    animationTimer = math.min(animationDuration, animationTimer + dt)
    needsRedraw = true
  end
  local animationProgress = animationTimer / animationDuration
  local animationScale = 1 - (1 - animationProgress)^3
  -- Arc detection.
  local mousePosition = canvasWidget:mousePosition()
  local diff = vec2.sub(mousePosition, centerCoordinates)
  local distanceFromCenter = vec2.mag(diff)

  local previousHoveredIndex = hoveredOptionIndex
  hoveredOptionIndex = nil
  local isCenterHovered = false
  local currentHoverTarget = nil

  if distanceFromCenter < (radiusInner - 5) then
    isCenterHovered = true
    currentHoverTarget = "center"
  elseif distanceFromCenter >= radiusInner then
    local mouseAngle = vec2.angle(diff)
    local targetIndex = nil

    for optionIndex, option in ipairs(menuOptions) do
      local diff = util.angleDiff(option.midpointAngle, mouseAngle)
      local halfSweep = (option.endAngle - option.startAngle) * 0.5
      if math.abs(diff) <= (halfSweep + 0.0001) then
        targetIndex = optionIndex
        break
      end
    end

    if targetIndex then
      local maxRadius = (targetIndex == previousHoveredIndex) and (radiusOuter + radiusHover) or radiusOuter
      if distanceFromCenter <= maxRadius then
        hoveredOptionIndex = targetIndex
        currentHoverTarget = hoveredOptionIndex
      end
    end
  end
  -- Play sound (and queue redraw) on hover change.
  if currentHoverTarget ~= lastHoveredTarget then
    if currentHoverTarget ~= nil then
      pane.playSound("/sfx/interface/hoverover_bumb.ogg")
    end
    needsRedraw = true
  end
  lastHoveredTarget = currentHoverTarget
  -- Queue redraw on clicks.
  if isMouseDown ~= prevMouseDown then
    needsRedraw = true
    prevMouseDown = isMouseDown
  end
  -- Trigger on mouse release.
  if isMouseReleased then
    isMouseReleased = false
    needsRedraw = true -- Redraw on mouse releases.
    if hoveredOptionIndex and menuOptions[hoveredOptionIndex] then
      local selectedOption = menuOptions[hoveredOptionIndex]

      if selectedOption.onClick and type(selectedOption.onClick) == "function" then
        local preventDefault = selectedOption:onClick(hoveredOptionIndex)
        if preventDefault == true then return end
      end
      -- Clicky.
      pane.playSound("/sfx/interface/clickon_success.ogg")
      -- Load new menu if it has children.
      if selectedOption.options and #selectedOption.options > 0 then
        table.insert(menuStack, menuOptions)
        loadMenu(selectedOption.options)
        return
      end
      -- Bubbly sound when we select a new action.
      pane.playSound("/sfx/interface/crafting_medical.ogg")

      hasSelectedOption = true

      radialMenu.result = {
        selection = selectedOption.action or selectedOption.name,
        data = selectedOption.data,
        type = config.getParameter("type"),
        instant = selectedOption.instant,
        keepOpen = selectedOption.keepOpen,
        pressed = true,
        uuid = self.uuid
      }

      if not selectedOption.keepOpen then
        return pane.dismiss()
      end
    elseif isCenterHovered then
      pane.playSound("/sfx/interface/clickon_success.ogg")
      -- Load the previous menu if it exists, or close.
      if #menuStack > 0 then
        local parentMenu = table.remove(menuStack)
        loadMenu(parentMenu)
        return
      else
        return pane.dismiss()
      end
    end
  end

  for optionIndex = 1, optionCount do
    local isHovered = (optionIndex == hoveredOptionIndex)
    local currentOption = menuOptions[optionIndex]
    if currentOption.update then
      currentOption:update(dt, isHovered, optionIndex)
    end
  end
  -- Skip the rest if we're not redrawing.
  if not needsRedraw then return end
  needsRedraw = false

  canvasWidget:clear()

  for optionIndex = 1, optionCount do
    local isHovered = (optionIndex == hoveredOptionIndex)
    local isPressed = isHovered and isMouseDown
    local currentOption = menuOptions[optionIndex]

    local startAngle = currentOption.startAngle
    local endAngle = currentOption.endAngle
    local midpointAngle = currentOption.midpointAngle

    local currentOuterRadius = isHovered and (radiusOuter + radiusHover) or radiusOuter

    local sliceColour = isPressed and (currentOption.pressColour or colours.press) or (isHovered and (currentOption.hoverColour or colours.hover) or (currentOption.baseColour or colours.base))

    local animationInnerRadius = radiusInner
    local animationOuterRadius = radiusInner + (currentOuterRadius - radiusInner) * animationScale

    drawArcSegment(startAngle, endAngle, animationInnerRadius, animationOuterRadius, sliceColour, 3.5)

    local iconRadius = (radiusInner + animationOuterRadius) * 0.5
    local elementPosition = vec2.add(centerCoordinates, vec2.withAngle(midpointAngle, iconRadius))
    local displayText = currentOption.pretty or currentOption.name or ""

    if currentOption.icon then
      local iconPosition = (isHovered and displayText ~= "") and vec2.add(elementPosition, {0, 4}) or elementPosition
      canvasWidget:drawImage(currentOption.icon..string.format(iconBorderDirective, currentOption.iconBorderColour or colours.iconBorder), iconPosition, nil, nil, true)

      if isHovered then
        local textPosition = vec2.sub(elementPosition, {0, 8})
        canvasWidget:drawText("^shadow,set;"..displayText, {position = textPosition, horizontalAnchor = "mid", verticalAnchor = "mid"}, 6, colours.textHover)
      end
    else
      -- Fallback to the title/name if there's no icon.
      canvasWidget:drawText("^shadow,set;"..displayText, {position = elementPosition, horizontalAnchor = "mid", verticalAnchor = "mid"}, 8, isHovered and colours.textHover or colours.textGrey)
    end
  end
  -- Inner circle.
  local isCenterPressed = isCenterHovered and isMouseDown
  local centerBackgroundColour = isCenterPressed and colours.press or (isCenterHovered and colours.hover or colours.center)
  local centerRingColour = not (isCenterPressed or isCenterHovered) and colours.base or colours.hidden
  canvasWidget:drawTriangles(fillCircle(radiusInner - 6, 38, centerCoordinates), centerBackgroundColour)
  canvasWidget:drawTriangles(wideCircle(radiusInner - 6, 38, 2, centerCoordinates), centerRingColour)
  -- Default center text.
  local centerText = (#menuStack > 0) and "Back" or "Close"
  local centerTextColour = isCenterHovered and colours.textHover or colours.text
  local centerDescription = nil
  -- Set the center text if we're hovering an option.
  if hoveredOptionIndex and menuOptions[hoveredOptionIndex] then
    centerText = menuOptions[hoveredOptionIndex].title or menuOptions[hoveredOptionIndex].pretty or menuOptions[hoveredOptionIndex].name or "?"
    centerTextColour = colours.textHover
    centerDescription = menuOptions[hoveredOptionIndex].description
  end
  -- Shift title up slightly if there is a description to make room.
  local titleYOffset = centerDescription and 5 or 0
  local titlePosition = vec2.add(centerCoordinates, {0, titleYOffset})

  canvasWidget:drawText("^shadow,set;"..centerText, {position = titlePosition, horizontalAnchor = "mid", verticalAnchor = "mid"}, 8, centerTextColour)
  -- Title and description text in center.
  if centerDescription then
    local descriptionPosition = vec2.sub(centerCoordinates, {0, 2})
    canvasWidget:drawText("^shadow,set;"..centerDescription, {position = descriptionPosition, horizontalAnchor = "mid", verticalAnchor = "top"}, 6, colours.textGrey)
  end
end

function canvasClickEvent(clickPosition, mouseButton, isButtonDown)
  if mouseButton == 0 then
    if isButtonDown ~= isMouseDown then
      needsRedraw = true
    end
    if isButtonDown then
      isMouseDown = true
    else
      if isMouseDown then
        isMouseReleased = true
        isMouseDown = false
      end
    end
  elseif mouseButton == 2 and isButtonDown then
    -- Right click immediately closes the menu.
    pane.dismiss()
  end
end

function uninit()
  if radialMenu.uuid == self.uuid then
    radialMenu.uuid = nil
  end
  if not hasSelectedOption then
    radialMenu.result = {selection = "cancel", pressed = true, uuid = self.uuid}
  end
  radialMenu.options = nil
end
