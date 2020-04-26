local World = Class()

function World:init()
  self.entities = {}
  self.systems = {}
  self.events = Queue()
  
  self._toremove = {}
end

function World:addSystem(system)
  system.world = self
  self.systems[#self.systems+1] = system
end

function World:processEvent(entity, eventName, eventArgs)
  for i = 1, #self.systems do
    local system = self.systems[i]
    local funcName = "on"..(eventName:gsub("^%l", string.upper))
    if system[funcName] then
      local continue = system:callFunc(funcName, entity, eventArgs)
      if continue == false then
        break
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
  
  -- stop it being processed
  for k,v in pairs(e) do
    e[k] = nil
  end
end

return World