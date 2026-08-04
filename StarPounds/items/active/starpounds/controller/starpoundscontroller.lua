require "/scripts/vec2.lua"
require "/scripts/util.lua"

local shared = getmetatable ""
local starPounds = shared.starPounds

shared.starPoundsRadialMenu = shared.starPoundsRadialMenu or {}
local radialMenu = shared.starPoundsRadialMenu

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

local selectionColours = {
  base = {135, 90, 219, 160},
  hover = defaultColours.hover,
  press = defaultColours.press
}

local path = "/items/active/starpounds/controller/"

function buildActions()
  actions = {
    menu = {
      onClick = function(self, shiftHeld)
        player.interact("ScriptPane", {gui = {}, scripts = {"/metagui.lua"}, ui = "starpounds:main"})
      end
    },
    -- Lactate.
    lactate = {
      icon = colourStarPoundsImage(path.."icons/inventory_lactate.png"),
      init = function(self)
        self.cooldown = 0
        self.cooldownTime = 0.1
        self.capacityFrames = 12
      end,

      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        activeItem.setFacingDirection(starPounds.mcontroller.movingDirection)

        local breasts = starPounds.moduleFunc("breasts", "get") or {type = "milk", fullness = 0}
        local cursor = "empty"
        if breasts.fullness >= 1 then
          cursor = "full"
        elseif breasts.fullness > 0 then
          cursor = "capacity_"..math.floor(breasts.fullness * self.capacityFrames)
        end

        activeItem.setCursor(string.format("/cursors/starpoundsmilk.cursor:%s_%s", breasts.type, cursor))

        if self.cooldown > 0 then
          self.cooldown = math.max(0, self.cooldown - dt)
        end

        if isButtonHeld and self.cooldown == 0 then
          starPounds.moduleFunc("breasts", "lactate", math.random(5, 10)/10)
          self.cooldown = self.cooldownTime
        end
      end
    },
    -- Milk types.
    breastMilk = {onClick = function(self, shiftHeld)
      starPounds.moduleFunc("breasts", "setMilkType", "milk")
    end},
    breastChocolate = {onClick = function(self, shiftHeld)
      if starPounds.moduleFunc("skills", "has", "breastChocolate") then
        starPounds.moduleFunc("breasts", "setMilkType", "starpoundschocolateliquid")
      end
    end},
    breastHoney = {onClick = function(self, shiftHeld)
      if starPounds.moduleFunc("skills", "has", "breastHoney") then
        starPounds.moduleFunc("breasts", "setMilkType", "bees_liquidhoney")
      end
    end},
    -- Vore actions.
    voreEat = {
      icon = colourStarPoundsImage(path.."icons/inventory_voreEat.png"),
      init = function(self)
        self.range = config.getParameter("range", 2.5)
        self.querySize = config.getParameter("querySize", 0.5)
        self.readyEmote = config.getParameter("readyEmote", "Happy")
        self.cooldownFrames = 8
        self.cursorType = "pred"
        self.wasValid = false
        self.emoteActive = false
        self.cooldown = 0
        self.eatOptions = {particles = true, triggerPreyCooldown = true}

        self.syncCooldown = function() self.cooldown = starPounds.moduleFunc("pred", "cooldown") end
        starPounds.events:on("pred:eatEntity", self.syncCooldown)
        starPounds.events:on("pred:bite", self.syncCooldown)
        starPounds.events:on("pred:entityEscape", self.syncCooldown)
      end,

      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        local aimPosition = activeItem.ownerAimPosition()
        local aimAngle, aimDirection = activeItem.aimAngleAndDirection(0, aimPosition)
        activeItem.setFacingDirection(aimDirection)

        if self.cooldown > 0 then
          self.cooldown = math.max(0, self.cooldown - (dt / starPounds.getStat("voreCooldown")))
        end

        if shiftHeld then
          if shiftHeld then
            activeItem.setCursor(string.format("/cursors/starpoundsvore.cursor:release%s", canRelease() and "_valid" or ""))
            return
          end
        end

        local target = activeItem.ownerAimPosition()
        local valid = not world.getProperty("nonCombat") and starPounds.moduleFunc("pred", "eatNearby", target, self.range - (starPounds.currentSize.yOffset or 0), self.querySize, self.eatOptions, true)
        local safe = (valid and valid[3]) and "safe_" or ""
        self.cursorType = (valid and valid[1]) and (valid[2] and "pred_"..safe.."valid" or "pred_"..safe.."nearby") or "pred"

        if self.readyEmote ~= "none" then
          if self.cursorType:find("valid") and self.cooldown == 0 then
            activeItem.emote(self.readyEmote)
            self.emoteActive = true
          elseif self.emoteActive then
            activeItem.emote("Idle")
            self.emoteActive = false
          end
        end

        local readyPercent = 1 - (self.cooldown / starPounds.moduleFunc("pred", "cooldownTime"))
        local frameIndex = math.min(math.floor(readyPercent * self.cooldownFrames), self.cooldownFrames - 1)
        local frameSuffix = (self.cooldown > 0) and ("_" .. frameIndex) or ""
        activeItem.setCursor(string.format("/cursors/starpoundsvore.cursor:%s%s", self.cursorType, frameSuffix))
      end,

      onClick = function(self, shiftHeld)
        -- Release.
        if shiftHeld then
          starPounds.moduleFunc("pred", "queueRelease")
          return
        end

        if self.cooldown == 0 then
          local target = getVoreTargetPosition(self)
          local valid = not world.getProperty("nonCombat") and starPounds.moduleFunc("pred", "eatNearby", target, self.range - (starPounds.currentSize.yOffset or 0), self.querySize, self.eatOptions)

          if (valid and valid[1]) then
            starPounds.moduleFunc("pred", "cooldownStart")
            self.cooldown = starPounds.moduleFunc("pred", "cooldownTime")
          end
        end
      end,

      uninit = function(self)
        starPounds.events:off("pred:eatEntity", self.syncCooldown)
        starPounds.events:off("pred:bite", self.syncCooldown)
        starPounds.events:off("pred:entityEscape", self.syncCooldown)
        if self.emoteActive then activeItem.emote("Idle") end
        activeItem.setCursor()
      end
    },
    voreEatSafe = {
      icon = colourStarPoundsImage(path.."icons/inventory_voreEatSafe.png"),
      init = function(self, ...)
        actions.voreEat.init(self)
        self.eatOptions.noDamage = true
      end,
      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        actions.voreEat.update(self, dt, fireMode, isButtonHeld, shiftHeld)
      end,
      onClick = function(self, shiftHeld) actions.voreEat.onClick(self, shiftHeld) end,
      uninit = function(self) actions.voreEat.uninit(self) end
    },
    voreEatUnsafe = {
      icon = path.."icons/inventory_voreEatUnsafe.png", -- No hueshift because it only really shifts the tongue.
      init = function(self)
        actions.voreEat.init(self)
        self.eatOptions.unsafe = true
      end,
      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        actions.voreEat.update(self, dt, fireMode, isButtonHeld, shiftHeld)
      end,
      onClick = function(self, shiftHeld) actions.voreEat.onClick(self, shiftHeld) end,
      uninit = function(self) actions.voreEat.uninit(self) end
    },
    vorePrey = {
      icon = colourStarPoundsImage(path.."icons/inventory_vorePrey.png"),
      init = function(self)
        self.range = config.getParameter("range", 2.5)
        self.querySize = config.getParameter("querySize", 0.5)
        self.monsterBehaviors = root.assetJson("/scripts/starpounds/modules/pred.config:monsterBehaviors")
      end,

      isTargetPred = function(self, target)
        if not target or target == activeItem.ownerEntityId() then return false end

        local targetType = world.entityTypeName(target)
        if world.entityType(target) == "monster" then
          local scriptCheck = contains(root.monsterParameters(targetType).scripts or {}, "/scripts/starpounds/loaders/monster.lua")
          local parameters = root.monsterParameters(targetType)
          local behaviorCheck = parameters.behavior and contains(self.monsterBehaviors, parameters.behavior) or false
          if parameters.starPounds_options and parameters.starPounds_options.disablePred then return false end
          if not (scriptCheck or behaviorCheck) then
            return false
          end
        elseif world.entityType(target) == "npc" then
          if not contains(root.npcConfig(targetType).scripts or {}, "/scripts/starpounds/loaders/npc.lua") then return false end
          if world.getNpcScriptParameter(target, "starPounds_options", {}).disablePred then return false end
        end

        return not world.lineTileCollision(world.entityMouthPosition(target), world.entityPosition(activeItem.ownerEntityId()), {"Null", "Block", "Dynamic", "Slippery"})
      end,

      findValidTarget = function(self)
        if not starPounds.isEnabled() or starPounds.hasOption("disablePrey") or world.getProperty("nonCombat") then
          return nil
        end

        local mouthPosition = starPounds.mcontroller.mouthPosition
        if starPounds.currentSize.yOffset then
          mouthPosition = vec2.add(mouthPosition, {0, starPounds.currentSize.yOffset})
        end

        local aimPosition = activeItem.ownerAimPosition()

        if world.magnitude(mouthPosition, aimPosition) > (self.range + self.querySize) then
          return nil
        end

        local positionMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), self.range - self.querySize - (starPounds.currentSize.yOffset or 0))
        local targetPosition = vec2.add(mouthPosition, vec2.mul(vec2.norm(world.distance(aimPosition, mouthPosition)), math.max(positionMagnitude, 0)))
        local entities = world.entityQuery(targetPosition, self.querySize, {order = "nearest", includedTypes = {"player", "npc", "monster"}, withoutEntityId = activeItem.ownerEntityId()}) or {}

        for _, target in ipairs(entities) do
          if self:isTargetPred(target) then
            return target
          end
        end
        return nil
      end,

      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        local aimPosition = activeItem.ownerAimPosition()
        local aimAngle, aimDirection = activeItem.aimAngleAndDirection(0, aimPosition)
        activeItem.setFacingDirection(aimDirection)

        local validTarget = self:findValidTarget()
        activeItem.setCursor(validTarget and "/cursors/starpoundsvore.cursor:prey_valid" or "/cursors/starpoundsvore.cursor:prey")
      end,

      onClick = function(self, shiftHeld)
        local validTarget = self:findValidTarget()
        if validTarget then
          world.sendEntityMessage(validTarget, "starPounds.pred.eat", activeItem.ownerEntityId(), {ignoreSkills = true, ignoreCapacity = true, ignoreEnergyRequirement = true, energyMultiplier = 0})
        end
      end,

      uninit = function(self)
        activeItem.setCursor()
      end
    },
    voreBite = {
      icon = colourStarPoundsImage(path.."icons/inventory_voreBite.png"),
      init = function(self)
        self.range = config.getParameter("range", 2.5)
        self.querySize = config.getParameter("querySize", 0.5)
        self.cooldownFrames = 8
        self.cooldown = 0

        self.syncCooldown = function() self.cooldown = starPounds.moduleFunc("pred", "cooldown") end
        starPounds.events:on("pred:eatEntity", self.syncCooldown)
        starPounds.events:on("pred:bite", self.syncCooldown)
        starPounds.events:on("pred:entityEscape", self.syncCooldown)
      end,

      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        local aimPosition = activeItem.ownerAimPosition()
        local aimAngle, aimDirection = activeItem.aimAngleAndDirection(0, aimPosition)
        activeItem.setFacingDirection(aimDirection)

        if self.cooldown > 0 then
          self.cooldown = math.max(0, self.cooldown - (dt / starPounds.getStat("voreCooldown")))
        end

        local readyPercent = 1 - (self.cooldown / starPounds.moduleFunc("pred", "cooldownTime"))
        local frameIndex = math.min(math.floor(readyPercent * self.cooldownFrames), self.cooldownFrames - 1)
        local frameSuffix = (self.cooldown > 0) and ("_" .. frameIndex) or ""

        activeItem.setCursor(string.format("/cursors/starpoundsvore.cursor:bite%s", frameSuffix))
      end,

      onClick = function(self, shiftHeld)
        if self.cooldown == 0 and not starPounds.hasOption("disablePredBite") then
          local target = getVoreTargetPosition(self)
          local collision = world.lineCollision(starPounds.mcontroller.mouthPosition, target)
          starPounds.moduleFunc("pred", "cooldownStart")
          starPounds.moduleFunc("pred", "bite", collision or target, true)
          self.cooldown = starPounds.moduleFunc("pred", "cooldownTime")
        end
      end,

      uninit = function(self)
        starPounds.events:off("pred:eatEntity", self.syncCooldown)
        starPounds.events:off("pred:bite", self.syncCooldown)
        starPounds.events:off("pred:entityEscape", self.syncCooldown)
        activeItem.setCursor()
      end
    },
    -- Sounds.
    soundBelch = {
      icon = colourStarPoundsImage(path.."icons/inventory_belch.png"),
      init = function(self)
        self.cooldownFrames = 8
        self.cooldown = 0
        self.cooldownTime = 0.5
      end,

      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        activeItem.setFacingDirection(starPounds.mcontroller.movingDirection)

        if self.cooldown > 0 then
          self.cooldown = math.max(0, self.cooldown - dt)
        end

        local readyPercent = 1 - (self.cooldown / self.cooldownTime)
        local frameIndex = math.min(math.floor(readyPercent * self.cooldownFrames), self.cooldownFrames - 1)
        local frameSuffix = (self.cooldown > 0) and ("_" .. frameIndex) or ""

        activeItem.setCursor(string.format("/cursors/starpoundssound.cursor:sound%s", frameSuffix))
      end,

      onClick = function(self, shiftHeld)
        if self.cooldown == 0 then
          starPounds.moduleFunc("belch", "belch", 0.75, nil, false)
          self.cooldown = self.cooldownTime
        end
      end
    },
    soundRumble = {
      icon = colourStarPoundsImage(path.."icons/inventory_rumble.png"),
      init = function(self)
        self.cooldownFrames = 8
        self.cooldown = 0
        self.cooldownTime = 0.35
      end,

      update = function(self, dt, fireMode, isButtonHeld, shiftHeld)
        activeItem.setFacingDirection(starPounds.mcontroller.movingDirection)

        if self.cooldown > 0 then
          self.cooldown = math.max(0, self.cooldown - dt)
        end
        -- Loops when held.
        if isButtonHeld and self.cooldown == 0 then
          starPounds.moduleFunc("sound", "play", shiftHeld and "digest" or "rumble", 0.75, (math.random(90,110)/100))
          self.cooldown = self.cooldownTime
        end

        local readyPercent = 1 - (self.cooldown / self.cooldownTime)
        local frameIndex = math.min(math.floor(readyPercent * self.cooldownFrames), self.cooldownFrames - 1)
        local frameSuffix = (self.cooldown > 0) and ("_" .. frameIndex) or ""

        activeItem.setCursor(string.format("/cursors/starpoundssound.cursor:sound%s", frameSuffix))
      end
    },
    -- Tool colour.
    setColour = {
      onClick = function(self, shiftHeld, hue)
        if not hue then
          -- Reset if nil.
          storage.hue = nil
          storage.colours = nil
        else
          local shiftedColours = {}
          local baseHue = hue + 90 -- Base colours are purple.
          for k, v in pairs(defaultColours) do
            if type(v) == "table" then
              shiftedColours[k] = hueshift(v, baseHue)
            elseif type(v) == "string" and v:len() == 8 then
              -- Convert hex strings too.
              local r = tonumber(v:sub(1, 2), 16)
              local g = tonumber(v:sub(3, 4), 16)
              local b = tonumber(v:sub(5, 6), 16)
              local a = tonumber(v:sub(7, 8), 16)
              if r and g and b and a then
                local shifted = hueshift({r, g, b}, baseHue)
                shiftedColours[k] = string.format("%02x%02x%02x%02x", shifted[1], shifted[2], shifted[3], a)
              else
                shiftedColours[k] = v
              end
            else
              shiftedColours[k] = v
            end
          end
          storage.hue = hue
          storage.colours = shiftedColours
        end
        buildActions()
        equipAction(storage.action, storage.actionData)
      end
    },

    default = {
      icon = colourStarPoundsImage(string.format(path.."icons/inventory_default%s.png", config.getParameter("twoHanded", true) and "" or "_oneHanded")),
      init = function(self) end,
      update = function(self, dt, fireMode, isButtonHeld, shiftHeld) end,
      onClick = function(self, shiftHeld) end,
      uninit = function(self) end
    }
  }
end

function buildMenu()
  local menu = {
    { name = "menu", pretty = "Menu", instant = true, weight = 0.5, description = "Open the\n^#ccbbff;StarPounds^reset;\nmenu", icon = colourStarPoundsImage(path.."icons/menu.png") },
    {
      name = "breastsMenu",
      pretty = "Breasts", description = "Bind breast\nabilities", icon = colourStarPoundsImage(path.."icons/breastsMenu.png"),
      options = compact(
        { name = "lactate", pretty = "Lactate", weight = 1 + (starPounds.moduleFunc("skills", "has", "breastChocolate") and 1 or 0) + (starPounds.moduleFunc("skills", "has", "breastHoney") and 1 or 0), icon = "/interface/scripted/starpounds/main/icons/skills/breastEfficiency.png" },
        starPounds.moduleFunc("skills", "has", "breastHoney") and { name = "breastHoney", pretty = "Honey", description = "Set your milk\ntype", instant = true, keepOpen = true, icon = "/interface/scripted/starpounds/main/icons/skills/breastHoney.png",
          hoverColour = {247, 166, 25, 180},
          pressColour = {255, 177, 43, 200}
        } or nil,
        starPounds.moduleFunc("skills", "has", "breastChocolate") and { name = "breastChocolate", pretty = "Chocolate", description = "Set your milk\ntype", instant = true, keepOpen = true, icon = "/interface/scripted/starpounds/main/icons/skills/breastChocolate.png",
          hoverColour = {117, 70, 26, 180},
          pressColour = {135, 86, 39, 200}
        } or nil,
        { name = "breastMilk", pretty = "Milk", description = "Set your milk\ntype", instant = true, keepOpen = true, icon = "/interface/scripted/starpounds/main/icons/skills/breastMilk.png",
          hoverColour = {151, 221, 247, 180},
          pressColour = {173, 233, 255, 200}
        }
      )
    },
    {
      name = "voreMenu",
      pretty = "Vore", description = "Bind vore\nabilities", icon = colourStarPoundsImage(path.."icons/voreMenu.png"),
      options = {
        { name = "voreEat", pretty = "Eat", description = "Hold ^#ccbbff;[Shift]^reset; to\nrelease prey", icon = path.."icons/voreEat.png" },
        { name = "voreEatUnsafe", pretty = "Fatal", title = "Eat: ^#ed7272;Fatal^reset;", weight = 0.5, description = "^#ccbbff;Eat^reset;, but ignores\nskills for safe\nvore", icon = path.."icons/voreEat.png",
          hoverColour = {237, 114, 114, 180},
          pressColour = {255, 140, 140, 200},
          iconBorderColour = "ed7272bb"
        },
        { name = "voreBite", pretty = "Bite", description = string.format("^#ccbbff;%g^reset; damage", string.format("%.2f", starPounds.moduleFunc("pred", "biteDamage"))), icon = path.."icons/voreBite.png" },
        { name = "vorePrey", pretty = "Feed", description = "Become prey for\nothers", icon = path.."icons/vorePrey.png" },
        { name = "voreEatSafe", pretty = "Endo", title = "Eat: ^#72ed72;Endo^reset;", weight = 0.5, description = "^#ccbbff;Eat^reset;, but will\nnever digest\nprey", icon = path.."icons/voreEat.png",
          hoverColour = {114, 237, 114, 180},
          pressColour = {140, 255, 140, 200},
          iconBorderColour = "72ed72bb"
        }
      }
    },
    {name = "colourMenu", pretty = "Colour", description = "Set tool and\ninterface\ncolour", weight = 0.5, icon = colourStarPoundsImage(path.."icons/colourMenu.png"), options = {
      {action = "setColour", pretty = "", title = "^#ccbbff;Default", weight = 3, instant = true, icon = path.."icons/colour.png", baseColour = selectionColours.base, hoverColour = selectionColours.hover, pressColour = selectionColours.press},
      {action = "setColour", data = 300, pretty = "", title = "^#ff4dff;Magenta", instant = true, icon = removeStarPoundsHue(path.."icons/colour.png").."?hueshift=300", baseColour = hueshift(selectionColours.base, 30), hoverColour = hueshift(selectionColours.hover, 30), pressColour = hueshift(selectionColours.press, 30)},
      {action = "setColour", data = 330, pretty = "", title = "^#ff4da6;Pink", instant = true, icon = removeStarPoundsHue(path.."icons/colour.png").."?hueshift=330", baseColour = hueshift(selectionColours.base, 60), hoverColour = hueshift(selectionColours.hover, 60), pressColour = hueshift(selectionColours.press, 60)},
      {action = "setColour", data = 0, pretty = "", title = "^#ff4d4d;Red", instant = true, icon = removeStarPoundsHue(path.."icons/colour.png"), baseColour = hueshift(selectionColours.base, 90), hoverColour = hueshift(selectionColours.hover, 90), pressColour = hueshift(selectionColours.press, 90)},
      {action = "setColour", data = 30, pretty = "", title = "^#ffa64d;Orange", instant = true, icon = removeStarPoundsHue(path.."icons/colour.png").."?hueshift=30", baseColour = hueshift(selectionColours.base, 120), hoverColour = hueshift(selectionColours.hover, 120), pressColour = hueshift(selectionColours.press, 120)},
      {action = "setColour", data = 60, pretty = "", title = "^#ffff4d;Yellow", instant = true, icon = removeStarPoundsHue(path.."icons/colour.png").."?hueshift=60", baseColour = hueshift(selectionColours.base, 150), hoverColour = hueshift(selectionColours.hover, 150), pressColour = hueshift(selectionColours.press, 150)},
      {action = "setColour", data = 90, pretty = "", title = "^#a6ff4d;Lime", instant = true, icon = removeStarPoundsHue(path.."icons/colour.png").."?hueshift=90", baseColour = hueshift(selectionColours.base, 180), hoverColour = hueshift(selectionColours.hover, 180), pressColour = hueshift(selectionColours.press, 180)},
      {action = "setColour", data = 120, pretty = "", title = "^#4dff4d;Green", instant = true, icon = removeStarPoundsHue(path.."icons/colour.png").."?hueshift=120", baseColour = hueshift(selectionColours.base, 210), hoverColour = hueshift(selectionColours.hover, 210), pressColour = hueshift(selectionColours.press, 210)},
      {action = "setColour", data = 150, pretty = "", title = "^#4dffa6;Sea Green", instant = true, icon = removeStarPoundsHue(path.."icons/colour.png").."?hueshift=150", baseColour = hueshift(selectionColours.base, 240), hoverColour = hueshift(selectionColours.hover, 240), pressColour = hueshift(selectionColours.press, 240)},
      {action = "setColour", data = 180, pretty = "", title = "^#4dffff;Cyan", instant = true, icon = removeStarPoundsHue(path.."icons/colour.png").."?hueshift=180", baseColour = hueshift(selectionColours.base, 270), hoverColour = hueshift(selectionColours.hover, 270), pressColour = hueshift(selectionColours.press, 270)},
      {action = "setColour", data = 210, pretty = "", title = "^#4da6ff;Azure", instant = true, icon = removeStarPoundsHue(path.."icons/colour.png").."?hueshift=210", baseColour = hueshift(selectionColours.base, 300), hoverColour = hueshift(selectionColours.hover, 300), pressColour = hueshift(selectionColours.press, 300)},
      {action = "setColour", data = 240, pretty = "", title = "^#4d4dff;Blue", instant = true, icon = removeStarPoundsHue(path.."icons/colour.png").."?hueshift=240", baseColour = hueshift(selectionColours.base, 330), hoverColour = hueshift(selectionColours.hover, 330), pressColour = hueshift(selectionColours.press, 330)}
    }},
    {
      name = "soundMenu",
      pretty = "Sound", description = "Bind sound\neffects", icon = colourStarPoundsImage(path.."icons/soundMenu.png"),
      options = {
        { name = "soundBelch", pretty = "Belch", icon = path.."icons/soundBelch.png" },
        { name = "soundRumble", pretty = "Rumble", description = "Hold ^#ccbbff;[Shift]^reset; to\nchange sound", icon = path.."icons/soundRumble.png" },
      }
    },
    {
      name = "abilityMenu",
      pretty = "Abilities", description = "Bind abilities", icon = colourStarPoundsImage(path.."icons/abilityMenu.png"),
      options = {
        { name = "voreEat", pretty = "Eat", description = "Hold ^#ccbbff;[Shift]^reset; to\nrelease prey", icon = path.."icons/voreEat.png" },
        { name = "voreBite", pretty = "Bite", description = string.format("^#ccbbff;%g^reset; damage", string.format("%.2f", starPounds.moduleFunc("pred", "biteDamage"))), icon = path.."icons/voreBite.png" },
        { name = "lactate", pretty = "Lactate", icon = "/interface/scripted/starpounds/main/icons/skills/breastEfficiency.png" },
      }
    }
  }

  return menu
end

function canRelease()
  local canRelease = false
  local stomachEntities = starPounds.moduleFunc("data", "get", "stomachEntities")
  for preyIndex = #stomachEntities, 1, -1 do
    local prey = stomachEntities[preyIndex]
    if not prey.noRelease then
      canRelease = true
      break
    end
  end
  return canRelease
end

function getVoreTargetPosition(self)
  local mouthPosition = {starPounds.mcontroller.mouthPosition[1], starPounds.mcontroller.mouthPosition[2] + (starPounds.currentSize.yOffset or 0)}
  local aimPosition = activeItem.ownerAimPosition()
  local maxMagnitude = math.min(world.magnitude(mouthPosition, aimPosition), self.range - self.querySize - (starPounds.currentSize.yOffset or 0))
  local distance = world.distance(aimPosition, mouthPosition)
  local magnitude = world.magnitude(aimPosition, mouthPosition) + 0.001

  return {
    mouthPosition[1] + (distance[1] / magnitude * math.max(maxMagnitude, 0)),
    mouthPosition[2] + (distance[2] / magnitude * math.max(maxMagnitude, 0))
  }
end

function init()
  shared = getmetatable ""
  starPounds = shared.starPounds

  shared.starPoundsRadialMenu = shared.starPoundsRadialMenu or {}
  radialMenu = shared.starPoundsRadialMenu

  activeItem.setHoldingItem(false)

  self.uuid = sb.makeUuid()
  self.click = true

  if not radialMenu.uuid then
    radialMenu.close = nil
    radialMenu.result = nil
  end
  -- Remove old nulls.
  setmetatable(storage, nil)

  storage.action = storage.action or "default"
  buildActions()
  equipAction(storage.action, storage.actionData)
end

function equipAction(actionName, data)
  local actionTemplate = actions[actionName] or actions["default"]
  -- Clean up old module if it exists.
  if self.action and type(self.action.uninit) == "function" then
    self.action:uninit()
  end

  local newAction = {}
  for key, value in pairs(actionTemplate) do
    newAction[key] = value
  end

  self.action = newAction
  self.action.data = data
  storage.action = actionName
  storage.actionData = data

  if type(self.action.init) == "function" then
    self.action:init(data)
  end
  -- Set the icon.
  if self.action.icon then
    activeItem.setInventoryIcon(self.action.icon)
  end
end

function update(dt, fireMode, shiftHeld)
  shared = getmetatable ""
  starPounds = shared.starPounds

  shared.starPoundsRadialMenu = shared.starPoundsRadialMenu or {}
  radialMenu = shared.starPoundsRadialMenu

  -- Default just opens the menu. (Converts left clicks into right clicks)
  if storage.action == "default" and fireMode == "primary" then
    fireMode = "alt"
  end
  -- self.click prevents the menu/actions rapidly spamming.
  if fireMode == "none" then
    self.click = false
  end

  checkInterface()

  if radialMenu.uuid then
    if radialMenu.uuid == self.uuid then
      activeItem.setCursor()
      -- Close the menu on right click.
      if not self.click and fireMode == "alt" then
        self.click = true
        radialMenu.close = true
      end
    end
  else
    local isPrimaryHeld = (fireMode == "primary")
    if self.action and type(self.action.update) == "function" then
      self.action:update(dt, fireMode, isPrimaryHeld, shiftHeld)
    end

    if not self.click then
      if fireMode == "primary" then
        self.click = true
        if self.action and type(self.action.onClick) == "function" then
          self.action:onClick(shiftHeld, self.action.data)
        end
      elseif fireMode == "alt" then
        self.click = true
        local offset
        if starPounds.openStarbound then
          offset = vec2.div(vec2.sub(camera.worldToScreen(activeItem.ownerAimPosition()), camera.worldToScreen(camera.position())), interface.scale())
        end

        openRadialInterface(offset)
      end
    end
  end
end

function openRadialInterface(offset)
  radialMenu.result = nil
  radialMenu.uuid = self.uuid
  radialMenu.colours = storage.colours

  local menuConfig = root.assetJson("/interface/scripted/starpounds/radialmenu/radialmenu.config")
  menuConfig.uuid = self.uuid
  menuConfig.options = buildMenu()

  if offset then
    menuConfig.gui.panefeature = {
      type = "panefeature",
      anchor = "center",
      offset = offset
    }
  end

  activeItem.interact("ScriptPane", menuConfig, activeItem.ownerEntityId())
end

function checkInterface()
  local result = radialMenu.result

  if result and result.pressed and result.uuid == self.uuid then
    if result.selection ~= "cancel" then
      if result.instant then
        local targetModule = actions[result.selection]
        if targetModule and type(targetModule.onClick) == "function" then
          targetModule:onClick(false, result.data)
        end
      else
        equipAction(result.selection, result.data)
      end
    end
    radialMenu.result = nil
    self.click = true
  end
end

function uninit()
  if radialMenu.uuid == self.uuid then
    radialMenu.close = true
    radialMenu.uuid = nil
  end
  if self.action and self.action.uninit then self.action:uninit() end
end

function compact(...)
  local clean = {}
  for i = 1, select('#', ...) do
    local val = select(i, ...)
    if val ~= nil then clean[#clean+1] = val end
  end
  return clean
end

function hueshiftImage(image, hue)
  if hue then
    return string.format("%s?hueshift=%s;", image, hue)
  else
    return image
  end
end

function removeStarPoundsHue(image)
  return image.."?replace;7743b2=b24343;9d72ed=ed7272;d0bfff=ffa7a7;ffffff=ffffff;"
end

function colourStarPoundsImage(image)
  if storage.hue then
    return hueshiftImage(removeStarPoundsHue(image), storage.hue)
  end
  return image
end

function hueshift(rgba, degrees)
  local r, g, b, a = rgba[1] / 255, rgba[2] / 255, rgba[3] / 255, rgba[4]
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local delta = max - min
  if delta == 0 then return {rgba[1], rgba[2], rgba[3], a} end
  local h = (max == r and (g - b) / delta or max == g and 2 + (b - r) / delta or 4 + (r - g) / delta) * 60
  h = (h + degrees) % 360
  local function f(n)
    local k = (n + h / 60) % 6
    return math.floor((max - delta * math.max(0, math.min(k, 4 - k, 1))) * 255 + 0.5)
  end

  return {f(5), f(3), f(1), a}
end
