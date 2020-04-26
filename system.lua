local System = Class()

-- Default filter just checks for dependencies
function System:filter(entity)
  for i = 1, #self._deps do
    local key = self._deps[i]
    if key == "domainTraveller" then
      print()
    end
    if entity[key] == nil then
      return false
    end
  end
  return true
end

local ProcessingSystem = Class(nil, {System})

function ProcessingSystem:callFunc(funcName, entity, ...)
  if not self[funcName] then return false end
  if entity and self:filter(entity) then
    return self[funcName](self, entity, ...)
  elseif entity == nil then
    for i = 1, #self.world.entities do
      local entity = self.world.entities[i]
      if self:filter(entity) then
        self[funcName](self, entity, ...)
      end
    end
  end
end

local function makeSystemClass(deps, tbl)
  local class = Class(tbl, {System})
  class._deps = deps
  
  return class
end

local function makeProcessingSystemClass(deps, tbl)
  local class = Class(tbl, {ProcessingSystem})
  class._deps = deps
  
  return class
end

return {System = System, makeSystemClass = makeSystemClass, makeProcessingSystemClass = makeProcessingSystemClass}