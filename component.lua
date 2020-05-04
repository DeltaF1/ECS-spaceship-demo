local Component = Class()

function Component:init(tbl)
  tbl = tbl or {}
  for k,v in pairs(self._defaults) do
    if tbl[k] == nil then
      tbl[k] = clone(v)
    end
  end
  for k,v in pairs(tbl) do
    self[k] = v
  end
end

function makeComponentClass(name, defaults, tbl)
  local class = Class(tbl, {Component})
  class._name = name
  class._defaults = defaults or {}
  
  return class
end

return {Component = Component, makeComponentClass = makeComponentClass}