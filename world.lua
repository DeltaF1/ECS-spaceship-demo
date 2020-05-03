local World = Class()

function World:init()
  self.entities = {}
  self.systems = {}
  self.events = Queue()
  
  self._toremove = {}
end

function World:addSystem(system)
  self.systems[#self.systems+1] = system
end

function World:processEvent(entity, eventName, eventArgs)
  for i = 1, #self.systems do
    local system = self.systems[i]
    local func = system["on"..(eventName:gsub("^%l", string.upper))]
    if func then
      if entity and system:filter(entity) then        
        local continue = func(system, entity, eventArgs)
        if continue == false then
          break
        end
      elseif entity == nil then
        -- global event
        -- apply to all entities
        -- This should eventually be moved inside system for caching
        for i = 1, #self.entities do
          local entity = self.entities[i]
          if system:filter(entity) then
            func(system, entity, eventArgs)
          end
        end
      end
    end
  end
end

function World:addEvent(entity, eventName, eventArgs)
  self.events:push_left({entity, eventName, eventArgs or {}})
end

function World:addEventForAll(eventName, eventArgs)
  for i = 1, #self.entities do
    self:addEvent(self.entities[i], eventName, eventArgs)
  end
end

function World:update(dt)
  deltaTime = dt
  self:addEventForAll("update", {dt=dt})
end

function World:process()
  while not self.events:is_empty() do
    local event = self.events:pop_right()
    self:processEvent(unpack(event))
  end
  
  self:garbageCollect()
end

function World:garbageCollect()
  for i = #self.entities, 1,-1 do
    if self._toremove[self.entities[i]] then
      table.remove(self.entities, i)
    end
  end
  self._toremove = {}
end

function World:draw()
  self:addEventForAll("draw")
end

function World:addEntity(e)
  self.entities[#self.entities+1] = e
  e._index = #self.entities
end

function World:addEntities(...)
  local list = {...}
  for i = 1, #list do
    self:addEntity(list[i])
  end
end

function World:removeEntity(e)
  self._toremove[e] = true
  
  
  -- FIXME: Add onRemove callback
  if e.collider then
    HC.remove(e.collider)
  end
  
  -- stop it being processed
  for k,v in pairs(e) do
    e[k] = nil
  end
end

return World