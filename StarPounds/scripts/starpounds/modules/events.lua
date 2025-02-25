local events = starPounds.module:new("events")

function events:init()
  -- Stops this being reset when we toggle the mod.
  if not self.events then
    self.events = {}
  end
end

function events:on(event, listener)
  if type(listener) ~= "function" then
    return
  end

  if not self.events[event] then
    self.events[event] = {}
  end
  table.insert(self.events[event], listener)
end

-- Function to remove a listener for an event.
function events:off(event, listener)
  if not self.events[event] then return end

  for i, l in ipairs(self.events[event]) do
    if l == listener then
      table.remove(self.events[event], i)
      break
    end
  end

  -- Remove event entry if no listeners remain.
  if #self.events[event] == 0 then
    self.events[event] = nil
  end
end

function events:fire(event, ...)
  if not self.events[event] then return end
  for _, listener in ipairs(self.events[event]) do
    listener(...)
  end
  -- Remove the event if no listeners are left.
  if #self.events[event] == 0 then
    self.events[event] = nil
  end
end

starPounds.modules.events = events
-- Copy the reference here since this will get used a lot.
starPounds.events = starPounds.modules.events
