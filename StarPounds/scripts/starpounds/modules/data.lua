local data = starPounds.module:new("data")

function data:init()
  message.setHandler("starPounds.getData", function(_, _, ...) return self:get(...) end)
  self:load()
end

function data:load()
  -- Load player backup data if it exists, but we have no storage. (e.g. from a script crash)
  if starPounds.type == "player" then
    loadBackup = not storage.starPounds
    -- Backup storage.
    if loadBackup then
      storage.starPounds = player.getProperty("starPoundsBackup", {})
    end
  end
  -- Merge base data on top.
  storage.starPounds = sb.jsonMerge(self.data.data, storage.starPounds)
  -- jsonMerge turns it into a jobject, which has metadata for storing nils.
  setmetatable(storage.starPounds, nil)
  -- Cross script voodoo for players.
  if starPounds.type == "player" then
    getmetatable ''.starPounds = starPounds
  end
  -- Versioning.
  storage.starPounds = starPounds.moduleFunc("versioning", "update", storage.starPounds)
end

function data:get(key)
  if key then return storage.starPounds[key] end
  return storage.starPounds
end

function data:reset()
  storage.starPounds = nil
  -- Clear the backup.
  if starPounds.type == "player" then
    player.setProperty("starPoundsBackup", nil)
  end
  -- Reinitialise data.
  self:load()
end

function data:backup()
  if starPounds.type == "player" then
    player.setProperty("starPoundsBackup", storage.starPounds)
  end
end

starPounds.modules.data = data
